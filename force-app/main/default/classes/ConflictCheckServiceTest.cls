@IsTest
private class ConflictCheckServiceTest {

    private static Id personRtId() {
        return [SELECT Id FROM RecordType
                WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount'
                LIMIT 1].Id;
    }

    private static Account newPerson(String first, String last) {
        Account pa = new Account(RecordTypeId = personRtId(), FirstName = first, LastName = last);
        insert pa;
        return pa;
    }

    // Client_Name__c is a read-only formula in this org, so it is not set here.
    private static Opportunity newOpp(String opposing, String client) {
        return newOpp(opposing, null, null);
    }

    /**
     * The client is the Opportunity's Account (and Client 2 is Spouse__c) -- both
     * lookups, which is how ConflictCheckService identifies the potential client.
     */
    private static Opportunity newOpp(String opposing, Id clientAccId, Id client2AccId) {
        Opportunity opp = new Opportunity(
            Name = 'Conflict Test Opp',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(30),
            Area_of_Law__c = 'Adoption',
            Opposing_Party_s_Full_Name__c = opposing,
            AccountId = clientAccId,
            Spouse__c = client2AccId
        );
        insert opp;
        return opp;
    }

    /** A matter whose Name marks it as a prosecution, at the given status. */
    private static AcctSeed__Project__c newProsecutionMatter(String status) {
        AcctSeed__Project__c m = new AcctSeed__Project__c(
            Name = 'City of Testville- Prosecution', AcctSeed__Status__c = status);
        insert m;
        return m;
    }

    private static void linkRelatedPerson(Id personAccId, Id matterId) {
        insert new Related_People__c(
            Person_Account_Name__c = personAccId,
            Matter_Name__c = matterId,
            Related_People_Class__c = 'Opposing Party');
    }

    private static ConflictCheckService.Result run(Id oppId) {
        ConflictCheckService.Request req = new ConflictCheckService.Request();
        req.opportunityId = oppId;
        return ConflictCheckService.check(new List<ConflictCheckService.Request>{ req })[0];
    }

    // ---- no opposing name -> Not Done Yet (check could not be completed) ----
    @IsTest
    static void testBlankOpposing_recommendsNotDone() {
        Opportunity opp = newOpp(null, 'Acme Client');
        Test.startTest();
        ConflictCheckService.Result r = run(opp.Id);
        Test.stopTest();
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'blank opposing name means the check could not be completed');
        System.assertEquals(0, r.matchCount);
        System.assert(r.summaryHtml.contains('could not be completed'),
            'summary must state the check could not be completed');
        System.assert(!r.summaryHtml.contains('nothing to match'),
            'must not describe this as a successful/no-op check');
    }

    // ---- a name that is only titles/suffixes is unusable -> Not Done Yet ----
    @IsTest
    static void testTitleOnlyOpposing_recommendsNotDone() {
        Opportunity opp = newOpp('Mr.', 'Acme Client');
        Test.startTest();
        ConflictCheckService.Result r = run(opp.Id);
        Test.stopTest();
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'a name consisting only of a title is unusable');
    }

    // ---- an unsearchable placeholder must NOT auto-Pass ---------------------
    // "N/A" parses to a name but yields no token long enough to search, so zero
    // searches run. Reporting Pass there would be a clean bill of health nobody
    // earned -- and the automation writes Pass through without a human.
    @IsTest
    static void testUnsearchablePlaceholder_recommendsNotDone() {
        for (String junk : new List<String>{ 'N/A', 'n/a', 'T B D', '?' }) {
            Opportunity opp = newOpp(junk, null, null);
            ConflictCheckService.Result r = run(opp.Id);
            System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
                '"' + junk + '" is not a searchable name and must not Pass');
            System.assert(r.summaryHtml.contains('could not be completed'),
                '"' + junk + '" should report that no search was run');
        }
    }

    @IsTest
    static void testIsSearchable() {
        System.assertEquals(false, ConflictCheckService.isSearchable(null));
        System.assertEquals(false, ConflictCheckService.isSearchable('   '));
        System.assertEquals(false, ConflictCheckService.isSearchable('N A'),  'single letters are not searchable');
        System.assertEquals(false, ConflictCheckService.isSearchable('J R R'), 'bare initials are not searchable');
        System.assertEquals(true,  ConflictCheckService.isSearchable('Bo Li'), 'two-letter tokens are searchable');
        System.assertEquals(true,  ConflictCheckService.isSearchable('J Smith'));
    }

    // ---- match, no matter -> Not Done Yet ----------------------------------
    @IsTest
    static void testMatchNoMatter_recommendsNotDone() {
        Account pa = newPerson('Jeffrey', 'Clemons');
        Opportunity opp = newOpp('Jeff Clemons', 'Some Client'); // nickname + surname
        Test.setFixedSearchResults(new List<Id>{ pa.Id });
        Test.startTest();
        ConflictCheckService.Result r = run(opp.Id);
        Test.stopTest();
        System.assertEquals(1, r.matchCount, 'should find the person account');
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'a match with no active matter should force human review');
        System.assert(r.matches[0].score >= 60, 'score should clear threshold: ' + r.matches[0].score);
        System.assert(r.summaryHtml.contains('Clemons'), 'summary should name the match');
        System.assert(r.plainNotes.contains('Clemons'), 'plain notes should name the match');
    }

    // ---- last-name typo is still found via the first-name search pass -------
    @IsTest
    static void testSurnameTypoStillFoundViaFirstName() {
        // Account surname differs from the searched surname by one letter, so a
        // surname-prefix search can never reach it; the first-name pass must.
        Account pa = newPerson('Veronica', 'Ezuka');
        Opportunity opp = newOpp('Veronica Ezeka', 'Some Client');
        Test.setFixedSearchResults(new List<Id>{ pa.Id });
        Test.startTest();
        ConflictCheckService.Result r = run(opp.Id);
        Test.stopTest();
        System.assertEquals(1, r.matchCount, 'one-letter surname typo should still surface');
        System.assert(r.matches[0].score >= 75,
            'same first name + one-letter surname typo should score high: ' + r.matches[0].score);
    }

    // ---- matched party has an OPEN opportunity -> surfaced as a line item ---
    @IsTest
    static void testMatchWithOpenOpportunity() {
        Account pa = newPerson('Olivia', 'Openheim');
        // pa's own in-flight opportunity (they are the client here)
        insert new Opportunity(
            Name = 'Olivia inbound', StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(15), Area_of_Law__c = 'Adoption',
            AccountId = pa.Id);
        Opportunity intake = newOpp('Olivia Openheim', 'Different Client');
        Test.setFixedSearchResults(new List<Id>{ pa.Id });
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();
        System.assertEquals(1, r.matchCount);
        System.assertEquals(true, r.matches[0].hasOpenOpp, 'open opportunity should be flagged');
        System.assert(r.summaryHtml.contains('Open opportunities'), 'summary should list open opportunities');
        System.assert(r.plainNotes.contains('Open opportunity'), 'plain notes should list open opportunity');
    }

    // ---- CLIENT is a related person on an ACTIVE prosecution matter -> Fail --
    // The firm cannot be hired by someone it is currently prosecuting.
    @IsTest
    static void testClientOnActiveProsecution_recommendsFail() {
        Account client = newPerson('Danny', 'Defendant');
        linkRelatedPerson(client.Id, newProsecutionMatter('Active').Id);
        Opportunity intake = newOpp('Someone Else', client.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();
        System.assertEquals(true, r.clientProsecution, 'client prosecution link should be flagged');
        System.assertEquals(true, r.clientProsecutionActive, 'the matter is Active');
        System.assertEquals(ConflictCheckService.STATUS_FAIL, r.recommendedStatus,
            'we cannot be hired by someone we are actively prosecuting');
        System.assert(r.summaryHtml.contains('PROSECUTION FLAG'), 'summary should surface the prosecution flag');
        System.assert(r.summaryHtml.contains('POTENTIAL CLIENT'),
            'the flag must name the client as the flagged party');
        System.assert(r.notesSummary.contains('ACTIVE PROSECUTION - CLIENT'),
            'saved note should carry the client prosecution flag: ' + r.notesSummary);
    }

    // ---- CLIENT on a CLOSED prosecution matter -> Not Done Yet --------------
    @IsTest
    static void testClientOnClosedProsecution_recommendsNotDone() {
        Account client = newPerson('Carla', 'Closedcase');
        linkRelatedPerson(client.Id, newProsecutionMatter('Completed').Id);
        Opportunity intake = newOpp('Someone Else', client.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();
        System.assertEquals(true, r.clientProsecution, 'closed prosecution link should still surface');
        System.assertEquals(false, r.clientProsecutionActive, 'the matter is Completed, not active');
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'a closed prosecution is a judgment call, not an automatic Fail');
        System.assert(r.plainNotes.contains('PROSECUTION FLAG'), 'plain notes should carry the flag');
    }

    // ---- Client 2 (Spouse__c) is checked too --------------------------------
    @IsTest
    static void testClient2OnActiveProsecution_recommendsFail() {
        Account client  = newPerson('Clean', 'Clientone');
        Account client2 = newPerson('Dirk', 'Clienttwo');
        linkRelatedPerson(client2.Id, newProsecutionMatter('Active').Id);
        Opportunity intake = newOpp('Someone Else', client.Id, client2.Id);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();
        System.assertEquals(true, r.clientProsecutionActive, 'Client 2 must be checked as well');
        System.assertEquals(ConflictCheckService.STATUS_FAIL, r.recommendedStatus,
            'an active prosecution against Client 2 is still a conflict');
        System.assert(r.summaryHtml.contains('Clienttwo'), 'summary should name Client 2');
    }

    // ---- client check must run even with NO opposing-party name -------------
    // Regression guard: the client check does not depend on the opposing name, so
    // a blank opposing name must not suppress it.
    @IsTest
    static void testClientProsecutionSurfacesWithBlankOpposingName() {
        Account client = newPerson('Blank', 'Opposing');
        linkRelatedPerson(client.Id, newProsecutionMatter('Active').Id);
        Opportunity intake = newOpp(null, client.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();
        System.assertEquals(ConflictCheckService.STATUS_FAIL, r.recommendedStatus,
            'an active client prosecution outranks the missing opposing name');
        System.assert(r.summaryHtml.contains('PROSECUTION FLAG'),
            'the client flag must still render with no opposing name');
        System.assert(r.summaryHtml.contains('could not be completed'),
            'and the opposing-party side must still report that it could not run');
    }

    // ---- client is the OPPOSING PARTY on another opportunity ----------------
    // The Dan / Sally / Heather case. Dan is our potential client and lists Heather
    // as his opposing party; we already have a case where DAN is the opposing party.
    // Searching Heather never surfaces that -- searching Dan does.
    @IsTest
    static void testClientNamedAsOpposingPartyElsewhere() {
        Account dan   = newPerson('Daniel', 'Kowalski');
        Account sally = newPerson('Sally', 'Nowak');
        // our existing case: we act for Sally, against Dan
        insert new Opportunity(
            Name = 'Sally Nowak - Custody', StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(20), Area_of_Law__c = 'Adoption',
            AccountId = sally.Id,
            Opposing_Party_s_Full_Name__c = 'Dan Kowalski');   // nickname, not "Daniel"

        // Dan now walks in listing a different opposing party
        Opportunity intake = newOpp('Heather Bergstrom', dan.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();

        System.assertEquals(true, r.clientNamedAsOpposing,
            'Dan must be found as the opposing party on Sally\'s opportunity');
        System.assertEquals(1, r.clientNamedAsOpposingCount);
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'this check never auto-Fails -- a human confirms every free-text hit');
        System.assert(r.summaryHtml.contains('OPPOSING PARTY ELSEWHERE'),
            'summary should raise the flag');
        System.assert(r.summaryHtml.contains('Sally Nowak'),
            'summary should name who we acted for: ' + r.summaryHtml);
        System.assert(r.notesSummary.contains('CLIENT IS OPPOSING PARTY'),
            'saved note should carry the flag: ' + r.notesSummary);
    }

    // ---- a shared surname alone must NOT flag ------------------------------
    // In family law the opposing party very often shares the client's surname, so
    // the surname LIKE scan must be filtered by the Apex scorer.
    @IsTest
    static void testSharedSurnameAloneIsNotFlagged() {
        Account jodie = newPerson('Jodie', 'Darwitz');
        Account other = newPerson('Kent', 'Peterson');
        // someone else's case whose opposing party merely shares Jodie's surname
        insert new Opportunity(
            Name = 'Kent Peterson - Family Law', StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(20), Area_of_Law__c = 'Adoption',
            AccountId = other.Id,
            Opposing_Party_s_Full_Name__c = 'Eric Darwitz');   // same surname, different person

        Opportunity intake = newOpp('Someone Else', jodie.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();

        System.assertEquals(false, r.clientNamedAsOpposing,
            'a shared surname with a different first name must not flag');
        System.assertEquals(ConflictCheckService.STATUS_PASS, r.recommendedStatus,
            'nothing found on either side should Pass');
    }

    // ---- the client's OWN opportunities are excluded ------------------------
    // A divorce intake commonly lists a same-surname spouse as the opposing party;
    // the client's own records must never be reported back at them.
    @IsTest
    static void testClientOwnOpportunitiesExcluded() {
        Account jodie = newPerson('Jodie', 'Darwitz');
        // Jodie's own earlier case, opposing party shares her surname
        insert new Opportunity(
            Name = 'Jodie Darwitz - Family Law', StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(20), Area_of_Law__c = 'Adoption',
            AccountId = jodie.Id,
            Opposing_Party_s_Full_Name__c = 'Jodie Darwitz');  // worst case: her own name

        Opportunity intake = newOpp('Eric Darwitz', jodie.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();

        System.assertEquals(false, r.clientNamedAsOpposing,
            'the client\'s own opportunities must be excluded from this check');
    }

    // ---- an OPEN opportunity is called out but still does not Fail ----------
    @IsTest
    static void testClientAsOpposingOnOpenOpp_stillNotDone() {
        Account dan   = newPerson('Daniel', 'Kowalski');
        Account sally = newPerson('Sally', 'Nowak');
        insert new Opportunity(
            Name = 'Sally Nowak - Custody', StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(20), Area_of_Law__c = 'Adoption',
            AccountId = sally.Id,
            Opposing_Party_s_Full_Name__c = 'Daniel Kowalski');

        // A real opposing name, so Not Done Yet can only come from the adverse hit
        // and not from the blank-name path.
        Opportunity intake = newOpp('Heather Bergstrom', dan.Id, null);
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();

        System.assertEquals(true, r.clientNamedAsOpposing);
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'even an OPEN adverse opportunity only asks for review, per the firm');
        System.assert(r.summaryHtml.contains('OPEN'), 'the open stage should be called out');
        System.assert(r.plainNotes.contains('OPPOSING PARTY ELSEWHERE'),
            'plain notes should carry the flag');
    }

    // ---- OPPOSING party on a prosecution matter is NOT flagged --------------
    // Lift-and-shift guard: the firm only cares about prosecutions involving the
    // potential client, so an opposing party on a prosecution matter is silent.
    @IsTest
    static void testOpposingPartyProsecutionIsNotFlagged() {
        Account opposing = newPerson('Danny', 'Defendant');
        linkRelatedPerson(opposing.Id, newProsecutionMatter('Active').Id);
        Opportunity intake = newOpp('Danny Defendant', null, null);
        Test.setFixedSearchResults(new List<Id>{ opposing.Id });
        Test.startTest();
        ConflictCheckService.Result r = run(intake.Id);
        Test.stopTest();
        System.assertEquals(1, r.matchCount, 'the opposing party should still be matched by name');
        System.assertEquals(false, r.clientProsecution, 'no client is linked, so no client flag');
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus,
            'a name match with no active matter still just needs review');
        System.assert(!r.summaryHtml.contains('PROSECUTION FLAG'),
            'an opposing party on a prosecution matter must not raise the flag');
        System.assert(!r.notesSummary.contains('PROSECUTION'),
            'and must not stamp the saved note: ' + r.notesSummary);
    }

    // ---- match with active matter -> Fail ----------------------------------
    @IsTest
    static void testMatchActiveMatter_recommendsFail() {
        Account pa = newPerson('Robert', 'Vaughn');
        // Type_of_Case__c is a read-only formula, so it is not set here.
        AcctSeed__Project__c m = new AcctSeed__Project__c(
            AcctSeed__Account__c = pa.Id,
            AcctSeed__Status__c = 'Active'
        );
        insert m;
        Opportunity opp = newOpp('Bob Vaughn', 'Client X'); // Bob -> Robert nickname
        Test.setFixedSearchResults(new List<Id>{ pa.Id });
        Test.startTest();
        ConflictCheckService.Result r = run(opp.Id);
        Test.stopTest();
        System.assertEquals(1, r.matchCount);
        System.assertEquals(ConflictCheckService.STATUS_FAIL, r.recommendedStatus,
            'active matter should recommend Fail');
        System.assert(r.matches[0].verdict.startsWith('ACTIVE'), 'verdict should flag active matter: ' + r.matches[0].verdict);
        System.assert(r.summaryHtml.contains('ACTIVE'), 'summary should surface the active matter');
    }

    // ---- opportunity not found ---------------------------------------------
    @IsTest
    static void testOppNotFound() {
        Id fakeId = Opportunity.sObjectType.getDescribe().getKeyPrefix() + '000000000000';
        Test.startTest();
        ConflictCheckService.Result r = run(fakeId);
        Test.stopTest();
        System.assertEquals(ConflictCheckService.STATUS_NOT_DONE, r.recommendedStatus);
        System.assert(r.summaryHtml.contains('not found'), 'should report not found');
    }

    // ---- name parsing ------------------------------------------------------
    @IsTest
    static void testParseNames() {
        System.assertEquals(0, ConflictCheckService.parseNames(null).size());
        System.assertEquals(0, ConflictCheckService.parseNames('   ').size());

        List<String> two = ConflictCheckService.parseNames('John Doe and Jane Doe');
        System.assertEquals(2, two.size(), 'connector "and" should split parties: ' + two);

        List<String> reordered = ConflictCheckService.parseNames('Smith, John');
        System.assertEquals('John Smith', reordered[0], 'Last, First should reorder');

        List<String> vs = ConflictCheckService.parseNames('State v. Miller');
        System.assert(vs.size() >= 2, 'v. should split: ' + vs);
    }

    // ---- title / suffix stripping ------------------------------------------
    @IsTest
    static void testTitleAndSuffixStripping() {
        System.assertEquals('John Smith',    ConflictCheckService.parseNames('Dr. John Smith')[0]);
        System.assertEquals('John Smith',    ConflictCheckService.parseNames('John Smith Jr.')[0]);
        System.assertEquals('Michael Jones', ConflictCheckService.parseNames('Mr Michael Jones III')[0]);
        System.assertEquals('Jane Doe',      ConflictCheckService.parseNames('Jane Doe, Esq.')[0]);
        // strip must run before the Last, First reorder
        System.assertEquals('John Smith',    ConflictCheckService.parseNames('Smith, John Jr.')[0]);
        System.assertEquals('Jane Smith',    ConflictCheckService.parseNames('Dr. Smith, Jane')[0]);
        // real names that merely contain title/suffix letters must be preserved
        System.assertEquals('Vera Vaughn',   ConflictCheckService.parseNames('Vera Vaughn')[0]);
        System.assertEquals('Ivan Ivanov',   ConflictCheckService.parseNames('Ivan Ivanov')[0]);
    }

    // ---- scoring -----------------------------------------------------------
    @IsTest
    static void testScoreName() {
        // exact
        System.assertEquals(100, ConflictCheckService.scoreName('John Smith', 'John', 'Smith', 'John Smith'));
        // nickname
        System.assert(ConflictCheckService.scoreName('Jeff Clemons', 'Jeffrey', 'Clemons', 'Jeffrey Clemons') >= 90,
            'nickname first name should score high');
        // typo in surname (nickname first + one-letter surname typo)
        System.assert(ConflictCheckService.scoreName('Jeff Clemons', 'Jeffrey', 'Clemens', 'Jeffrey Clemens') >= 60,
            'one-letter surname typo should still surface');
        // shared surname, different first name -> must collapse toward zero
        System.assert(ConflictCheckService.scoreName('Jillian Stover', 'Larry', 'Stover', 'Larry Stover') < 60,
            'same last name with a different first name should NOT be flagged: '
                + ConflictCheckService.scoreName('Jillian Stover', 'Larry', 'Stover', 'Larry Stover'));
        // unrelated
        System.assert(ConflictCheckService.scoreName('John Smith', 'Maria', 'Gonzalez', 'Maria Gonzalez') < 60,
            'unrelated names should fall below threshold');
    }
}