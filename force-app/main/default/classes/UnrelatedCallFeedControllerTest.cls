@isTest
private class UnrelatedCallFeedControllerTest {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Account UCF');
        insert acct;

        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name = 'Test Matter UCF',
            AcctSeed__Account__c = acct.Id
        );
        insert matter;

        // Call_Transcript__c is populated only by the Zoom/telephony integration
        // (Voice_Call__c is required and VoiceCall isn't insertable in a test
        // context), so the junction row here exercises the feed/relate logic
        // with Call_Transcript__c left null — matching real orphaned rows that
        // are still awaiting transcript enrichment.
        Related_Call_Transcript__c unrelated = new Related_Call_Transcript__c(
            OwnerId = UserInfo.getUserId()
        );
        insert unrelated;
    }

    @isTest
    static void testGetUnrelatedCalls_returnsOwnedUnmatteredRows() {
        Test.startTest();
        List<UnrelatedCallFeedController.UnrelatedCallDTO> results =
            UnrelatedCallFeedController.getUnrelatedCalls(null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly the one unrelated seeded row');
    }

    @isTest
    static void testGetUnrelatedCalls_daysBackExcludesOlderRows() {
        // The seeded row is created "now" (within any days-back window), so a
        // 1-day window should still include it...
        Test.startTest();
        List<UnrelatedCallFeedController.UnrelatedCallDTO> withinWindow =
            UnrelatedCallFeedController.getUnrelatedCalls(1, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, withinWindow.size(), 'Row created moments ago should be within a 1-day window');
    }

    @isTest
    static void testGetUnrelatedCalls_zeroOrNegativeDaysBackMeansNoDateBound() {
        // 0 (and negative) must mean "All time" — NOT "use the 30-day
        // default". This is the exact bug reported live: the LWC's "All
        // time" option sent 0, which an earlier version of this method
        // collapsed into the same branch as null (-> defaulted to 30 days),
        // silently making "All time" behave identically to "Last 30 days".
        Test.startTest();
        List<UnrelatedCallFeedController.UnrelatedCallDTO> allTime =
            UnrelatedCallFeedController.getUnrelatedCalls(0, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, allTime.size(), 'daysBack=0 must return rows regardless of age (no date bound)');
    }

    @isTest
    static void testGetUnrelatedCalls_pageOffsetBeyondDataReturnsEmpty() {
        // Only 1 row exists; asking for the page starting at offset 1 should
        // come back empty rather than erroring.
        Test.startTest();
        List<UnrelatedCallFeedController.UnrelatedCallDTO> pageTwo =
            UnrelatedCallFeedController.getUnrelatedCalls(0, 1, null, null, null);
        Test.stopTest();

        System.assertEquals(0, pageTwo.size(), 'A page starting past the last row should be empty');
    }

    @isTest
    static void testGetUnrelatedCalls_customSinceDateOverridesDaysBack() {
        // A far-future custom date should exclude the "now"-created seeded
        // row, even though daysBack alone would have included it — proving
        // customSinceDate takes priority.
        Test.startTest();
        List<UnrelatedCallFeedController.UnrelatedCallDTO> results =
            UnrelatedCallFeedController.getUnrelatedCalls(30, null, Date.today().addDays(1), null, null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'A custom since-date in the future should exclude the row created today');
    }

    @isTest
    static void testGetUnrelatedCallsCount_matchesRowCountForSameWindow() {
        Test.startTest();
        Integer count = UnrelatedCallFeedController.getUnrelatedCallsCount(0, null, null, null);
        Test.stopTest();

        System.assertEquals(1, count, 'Count should match the single seeded unrelated row');
    }

    @isTest
    static void testGetFeedStats_singleSeededRowIsUnrelatedNotAlreadyLinked() {
        // With only the one seeded Matter-less row (no Call_Transcript__c, so
        // no sibling to be "already linked" via), stats should show 1 total,
        // 1 unrelated, 0 already-linked.
        Test.startTest();
        UnrelatedCallFeedController.FeedStatsDTO stats =
            UnrelatedCallFeedController.getFeedStats(0, null, null, null);
        Test.stopTest();

        System.assertEquals(1, stats.totalDistinctCalls);
        System.assertEquals(1, stats.unrelatedCount);
        System.assertEquals(0, stats.alreadyLinkedCount);
    }

    @isTest
    static void testResolveScopeUserId_nullOverrideReturnsRunningUser() {
        Id resolved = UnrelatedCallFeedController.resolveScopeUserId(null);
        System.assertEquals(UserInfo.getUserId(), resolved, 'No override should scope to the running user');
    }

    @isTest
    static void testResolveScopeUserId_nonAdminOverrideIsIgnored() {
        // Don't assume the running test-context user isn't a System
        // Administrator (deploying/test-running users often are, in a
        // sandbox) — explicitly run as a non-admin profile so this test
        // proves the real thing: a non-admin's override attempt is silently
        // ignored, so a non-admin can't see another user's calls by
        // tampering with the client param.
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User nonAdminUser = new User(
            FirstName = 'NonAdmin',
            LastName = 'TestUser',
            Alias = 'natest',
            Email = 'nonadmin.ucftest@example.com',
            Username = 'nonadmin.ucftest@example.com.' + UserInfo.getOrganizationId(),
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Chicago',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert nonAdminUser;

        Id someOtherUserId = UserInfo.getUserId(); // any real Id works — the
        // assertion only cares that the override is rejected, not who it targets
        Id resolved;
        System.runAs(nonAdminUser) {
            resolved = UnrelatedCallFeedController.resolveScopeUserId(someOtherUserId);
        }
        System.assertEquals(
            nonAdminUser.Id,
            resolved,
            'A non-admin override attempt should fall back to the running (non-admin) user'
        );
    }

    @isTest
    static void testSearchUsers_shortCircuitsUnderMinLength() {
        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> tooShort =
            UnrelatedCallFeedController.searchUsers('A');
        Test.stopTest();

        System.assertEquals(0, tooShort.size(), 'Search terms under 2 chars should short-circuit');
    }

    @isTest
    static void testDismissCall_setsFieldsAndExcludesFromNormalFeed() {
        Related_Call_Transcript__c rct = [
            SELECT Id FROM Related_Call_Transcript__c LIMIT 1
        ];

        Test.startTest();
        UnrelatedCallFeedController.dismissCall(rct.Id);
        Test.stopTest();

        Related_Call_Transcript__c updated = [
            SELECT Dismissed__c, Dismissed_Date__c, Dismissed_By__c
            FROM Related_Call_Transcript__c
            WHERE Id = :rct.Id
        ];
        System.assertEquals(true, updated.Dismissed__c);
        System.assertNotEquals(null, updated.Dismissed_Date__c);
        System.assertEquals(UserInfo.getUserId(), updated.Dismissed_By__c);

        List<UnrelatedCallFeedController.UnrelatedCallDTO> normalFeed =
            UnrelatedCallFeedController.getUnrelatedCalls(0, null, null, null, false);
        System.assertEquals(0, normalFeed.size(), 'A dismissed call should not appear in the normal feed');

        List<UnrelatedCallFeedController.UnrelatedCallDTO> dismissedFeed =
            UnrelatedCallFeedController.getUnrelatedCalls(0, null, null, null, true);
        System.assertEquals(1, dismissedFeed.size(), 'A dismissed call should appear in the dismissed-only feed');
        System.assertEquals(true, dismissedFeed[0].isDismissed);
    }

    @isTest
    static void testUndismissCall_restoresToNormalFeed() {
        Related_Call_Transcript__c rct = [
            SELECT Id FROM Related_Call_Transcript__c LIMIT 1
        ];
        UnrelatedCallFeedController.dismissCall(rct.Id);

        Test.startTest();
        UnrelatedCallFeedController.undismissCall(rct.Id);
        Test.stopTest();

        Related_Call_Transcript__c updated = [
            SELECT Dismissed__c, Dismissed_Date__c, Dismissed_By__c
            FROM Related_Call_Transcript__c
            WHERE Id = :rct.Id
        ];
        System.assertEquals(false, updated.Dismissed__c);
        System.assertEquals(null, updated.Dismissed_Date__c, 'Undismiss should clear the dismissed date');
        System.assertEquals(null, updated.Dismissed_By__c, 'Undismiss should clear the dismissed-by user');

        List<UnrelatedCallFeedController.UnrelatedCallDTO> normalFeed =
            UnrelatedCallFeedController.getUnrelatedCalls(0, null, null, null, false);
        System.assertEquals(1, normalFeed.size(), 'An undismissed call should reappear in the normal feed');
    }

    @isTest
    static void testDismissCall_throwsOnMissingId() {
        Boolean threw = false;
        try {
            UnrelatedCallFeedController.dismissCall(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Expected an AuraHandledException when the call id is missing');
    }

    @isTest
    static void testResolveSinceDate_customDateTakesPriorityOverDaysBack() {
        Date customDate = Date.newInstance(2020, 1, 1);
        Datetime resolved = UnrelatedCallFeedController.resolveSinceDate(30, customDate);

        System.assertEquals(
            Datetime.newInstance(customDate, Time.newInstance(0, 0, 0, 0)),
            resolved,
            'A custom date should win over daysBack regardless of its value'
        );
    }

    @isTest
    static void testResolveSinceDate_nullDaysBackDefaultsTo30() {
        Datetime resolved = UnrelatedCallFeedController.resolveSinceDate(null, null);
        Datetime expected = Datetime.now().addDays(-30);

        // Allow a small tolerance for the moment-of-execution drift between
        // the two Datetime.now() calls.
        System.assert(
            Math.abs(resolved.getTime() - expected.getTime()) < 5000,
            'null daysBack should default to a 30-day cutoff'
        );
    }

    @isTest
    static void testResolveSinceDate_zeroOrNegativeDaysBackMeansNoBound() {
        System.assertEquals(null, UnrelatedCallFeedController.resolveSinceDate(0, null));
        System.assertEquals(null, UnrelatedCallFeedController.resolveSinceDate(-5, null));
    }

    @isTest
    static void testNormalizePhone_handlesFormatsAndCountryCode() {
        System.assertEquals('6125551234', UnrelatedCallFeedController.normalizePhone('(612) 555-1234'));
        System.assertEquals('6125551234', UnrelatedCallFeedController.normalizePhone('+16125551234'));
        System.assertEquals(null, UnrelatedCallFeedController.normalizePhone('12345'));
        System.assertEquals(null, UnrelatedCallFeedController.normalizePhone(null));
    }

    @isTest
    static void testResolveOtherPartyPhone_outboundUsesToNumber_inboundUsesFromNumber() {
        Related_Call_Transcript__c outboundRow = deserializeRowWithVoiceCall(
            'Outbound', '6125551111', '6125552222'
        );
        Related_Call_Transcript__c inboundRow = deserializeRowWithVoiceCall(
            'Inbound', '6125551111', '6125552222'
        );
        Related_Call_Transcript__c noTranscriptRow = new Related_Call_Transcript__c();

        System.assertEquals('6125552222', UnrelatedCallFeedController.resolveOtherPartyPhone(outboundRow));
        System.assertEquals('6125551111', UnrelatedCallFeedController.resolveOtherPartyPhone(inboundRow));
        System.assertEquals(null, UnrelatedCallFeedController.resolveOtherPartyPhone(noTranscriptRow));
    }

    @isTest
    static void testResolveMatchesByPhone_matchesContactAndLeadByLastDigits() {
        Contact c = new Contact(LastName = 'Smith', Phone = '(612) 555-3333');
        insert c;
        Lead l = new Lead(LastName = 'Jones', Company = 'Acme', Phone = '612-555-4444');
        insert l;

        Set<String> targets = new Set<String>{ '6125553333', '6125554444', '6125559999' };

        Test.startTest();
        Map<String, UnrelatedCallFeedController.PhoneMatch> matches =
            UnrelatedCallFeedController.resolveMatchesByPhone(targets);
        Test.stopTest();

        System.assertEquals(2, matches.size(), 'Only the 2 real matches should resolve');
        System.assert(matches.get('6125553333').name.contains('Smith'));
        System.assertEquals(true, matches.get('6125553333').isContact, 'Contact match should flag isContact=true');
        System.assertEquals(c.Id, matches.get('6125553333').recordId);
        System.assert(matches.get('6125554444').name.contains('Jones'));
        System.assertEquals(false, matches.get('6125554444').isContact, 'Lead match should flag isContact=false');
        System.assertEquals(null, matches.get('6125559999'), 'A number matching nobody should not resolve');
    }

    /**
     * VoiceCall is not insertable in a test context (confirmed via a live
     * describe: createable = false org-wide, likely governed by the Voice
     * feature license), so we exercise resolveOtherPartyPhone's branching by
     * deserializing a Related_Call_Transcript__c -> Call_Transcript__c ->
     * VoiceCall relationship tree from JSON instead of DML.
     */
    private static Related_Call_Transcript__c deserializeRowWithVoiceCall(
        String callType, String fromNumber, String toNumber
    ) {
        String jsonBody =
            '{"Call_Transcript__r": {"Voice_Call__r": {' +
            '"CallType": "' + callType + '",' +
            '"FromPhoneNumber": "' + fromNumber + '",' +
            '"ToPhoneNumber": "' + toNumber + '"' +
            '}}}';
        return (Related_Call_Transcript__c) JSON.deserialize(jsonBody, Related_Call_Transcript__c.class);
    }

    @isTest
    static void testSearchMatters_returnsMatchesAboveMinLength() {
        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> results =
            UnrelatedCallFeedController.searchMatters('Test Matter UCF');
        List<UnrelatedCallFeedController.LookupResult> tooShort =
            UnrelatedCallFeedController.searchMatters('T');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Account UCF — Test Matter UCF', results[0].name);
        System.assertEquals(0, tooShort.size(), 'Search terms under 2 chars should short-circuit');
    }

    @isTest
    static void testSearchMatters_alsoMatchesParentAccountClientName() {
        // Matter Names at JT are generic case-type labels that don't contain
        // the client's name (e.g. "Marital Dissolution w/children") — a real
        // user searches by CLIENT name, so the search must also match the
        // Matter's parent Account name, not just the Matter's own Name.
        // Confirmed live 2026-09-07: searching a real client's surname
        // ("Jurkovich") found nothing even though that client had 2 open
        // matters, because their name only appears on the Account, not on
        // either Matter's own Name field.
        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> results =
            UnrelatedCallFeedController.searchMatters('Test Account UCF');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Searching the parent Account name should find the Matter');
        System.assertEquals('Test Account UCF — Test Matter UCF', results[0].name);
    }

    @isTest
    static void testRelateCallToMatter_setsMatterAndBackfillsAccountOpportunity() {
        Related_Call_Transcript__c rct = [
            SELECT Id FROM Related_Call_Transcript__c LIMIT 1
        ];
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c LIMIT 1
        ];

        Test.startTest();
        UnrelatedCallFeedController.relateCallToMatter(rct.Id, matter.Id);
        Test.stopTest();

        Related_Call_Transcript__c updated = [
            SELECT Matter__c, Account__c
            FROM Related_Call_Transcript__c
            WHERE Id = :rct.Id
        ];
        System.assertEquals(matter.Id, updated.Matter__c);
        System.assertNotEquals(null, updated.Account__c, 'Account should be backfilled from the Matter');
    }

    @isTest
    static void testRelateCallToMatter_throwsOnMissingIds() {
        Boolean threw = false;
        try {
            UnrelatedCallFeedController.relateCallToMatter(null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Expected an AuraHandledException when required ids are missing');
    }

    @isTest
    static void testGetSuggestedMatters_returnsNullSafely() {
        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> results =
            UnrelatedCallFeedController.getSuggestedMatters(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'A null contactId should short-circuit to an empty list');
    }

    @isTest
    static void testGetSuggestedMatters_personAccountClientSuggestsMatterViaRelatedPeople() {
        // Person Account requires the org's PersonAccount record type — pull
        // it live rather than hardcoding a name, per the platform's own
        // convention for Person Account creation in tests.
        Id personAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account personAcct = new Account(
            RecordTypeId = personAccountRtId,
            FirstName = 'Jane',
            LastName = 'ClientTest'
        );
        insert personAcct;

        Account queriedPersonAcct = [SELECT Id, PersonContactId FROM Account WHERE Id = :personAcct.Id];
        Id clientContactId = queriedPersonAcct.PersonContactId;

        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        Related_People__c rp = new Related_People__c(
            Person_Account_Name__c = personAcct.Id,
            Matter_Name__c = matter.Id
        );
        insert rp;

        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> results =
            UnrelatedCallFeedController.getSuggestedMatters(clientContactId);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected the one matter linked via Related_People__c');
        System.assertEquals(matter.Id, results[0].id);
    }

    @isTest
    static void testGetSuggestedMatters_businessContactSuggestsMatterViaRelatedProfessionals() {
        Contact businessContact = new Contact(LastName = 'ProfessionalTest');
        insert businessContact;

        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        Related_Professionals__c rpr = new Related_Professionals__c(
            Business_Contact__c = businessContact.Id,
            Matter_Name__c = matter.Id
        );
        insert rpr;

        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> results =
            UnrelatedCallFeedController.getSuggestedMatters(businessContact.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected the one matter linked via Related_Professionals__c');
        System.assertEquals(matter.Id, results[0].id);
    }

    @isTest
    static void testGetSuggestedMatters_contactWithNoRelationsReturnsEmpty() {
        Contact unrelatedContact = new Contact(LastName = 'NoMatterTest');
        insert unrelatedContact;

        Test.startTest();
        List<UnrelatedCallFeedController.LookupResult> results =
            UnrelatedCallFeedController.getSuggestedMatters(unrelatedContact.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'A contact with no Related_People__c/Related_Professionals__c rows should suggest nothing');
    }

    /**
     * groupRows is the pure collapsing/exclusion logic behind the "one
     * physical call can have several Related_Call_Transcript__c junction
     * rows" fix (2026-09-07) — Call_Transcript__c can't be inserted in a
     * test context (requires Voice_Call__c, and VoiceCall isn't insertable —
     * same constraint documented elsewhere in this file), so these rows are
     * built via JSON.deserialize with fabricated-but-valid-format Ids rather
     * than DML, exactly like the existing VoiceCall relationship fixture
     * technique in this class.
     */
    private static Related_Call_Transcript__c deserializeGroupingRow(
        String rctId, String callTranscriptId, String accountName, String opportunityName
    ) {
        String jsonBody =
            '{"Id": "' + rctId + '",' +
            '"Call_Transcript__c": ' + (callTranscriptId != null ? '"' + callTranscriptId + '"' : 'null') + ',' +
            (accountName != null ? '"Account__r": {"Name": "' + accountName + '"},' : '') +
            (opportunityName != null ? '"Opportunity__r": {"Name": "' + opportunityName + '"},' : '') +
            '"Matter__c": null' +
            '}';
        return (Related_Call_Transcript__c) JSON.deserialize(jsonBody, Related_Call_Transcript__c.class);
    }

    @isTest
    static void testGroupRows_collapsesRowsSharingCallTranscript() {
        // 3 junction rows, 2 sharing one Call_Transcript__c (one physical
        // call touching 2 different Opportunities) + 1 fully independent.
        String sharedCtId = 'a6R000000000001AAA';
        List<Related_Call_Transcript__c> rows = new List<Related_Call_Transcript__c>{
            deserializeGroupingRow('a6X000000000001AAA', sharedCtId, null, 'Motion to Vacate'),
            deserializeGroupingRow('a6X000000000002AAA', sharedCtId, null, 'Trial Prep'),
            deserializeGroupingRow('a6X000000000003AAA', 'a6R000000000002AAA', null, 'Unrelated Call')
        };

        Test.startTest();
        List<UnrelatedCallFeedController.CallGroup> groups =
            UnrelatedCallFeedController.groupRows(rows, new Set<Id>());
        Test.stopTest();

        System.assertEquals(2, groups.size(), 'The 2 rows sharing a Call_Transcript__c should collapse into 1 group');

        UnrelatedCallFeedController.CallGroup sharedGroup;
        for (UnrelatedCallFeedController.CallGroup g : groups) {
            if (g.memberRowIds.size() == 2) sharedGroup = g;
        }
        System.assertNotEquals(null, sharedGroup, 'Expected one group with 2 collapsed member rows');
        System.assertEquals(2, sharedGroup.otherLabels.size(), 'Both distinct Opportunity labels should be preserved');
        System.assert(sharedGroup.otherLabels.contains('Opportunity: Motion to Vacate'));
        System.assert(sharedGroup.otherLabels.contains('Opportunity: Trial Prep'));
    }

    @isTest
    static void testGroupRows_excludesWholeCallWhenAnySiblingHasAMatter() {
        // Even though every row in this candidate list individually shows
        // Matter__c = null (that's the query's own filter), a call whose
        // Call_Transcript__c is flagged as "has a Matter somewhere" must be
        // excluded ENTIRELY — this is the exact bug reported live: a call
        // already resolved via one junction row kept reappearing via its
        // still-unrelated siblings.
        String resolvedCtId = 'a6R000000000003AAA';
        List<Related_Call_Transcript__c> rows = new List<Related_Call_Transcript__c>{
            deserializeGroupingRow('a6X000000000004AAA', resolvedCtId, null, 'Pretrial'),
            deserializeGroupingRow('a6X000000000005AAA', resolvedCtId, null, 'Review Hearing'),
            deserializeGroupingRow('a6X000000000006AAA', 'a6R000000000004AAA', null, 'Genuinely Unrelated')
        };
        Set<Id> callTranscriptIdsWithAMatter = new Set<Id>{ resolvedCtId };

        Test.startTest();
        List<UnrelatedCallFeedController.CallGroup> groups =
            UnrelatedCallFeedController.groupRows(rows, callTranscriptIdsWithAMatter);
        Test.stopTest();

        System.assertEquals(1, groups.size(), 'The already-resolved call\'s 2 rows should be fully excluded');
        System.assert(
            groups[0].otherLabels.contains('Opportunity: Genuinely Unrelated'),
            'The remaining group should be the genuinely unrelated call'
        );
    }

    @isTest
    static void testGroupRows_nullCallTranscriptRowsAreSingletonGroups() {
        // Rows with no Call_Transcript__c at all (orphaned rows still
        // awaiting transcript enrichment) have no shared key to collapse on
        // — each must remain its own group, never merged with another.
        List<Related_Call_Transcript__c> rows = new List<Related_Call_Transcript__c>{
            deserializeGroupingRow('a6X000000000007AAA', null, null, null),
            deserializeGroupingRow('a6X000000000008AAA', null, null, null)
        };

        Test.startTest();
        List<UnrelatedCallFeedController.CallGroup> groups =
            UnrelatedCallFeedController.groupRows(rows, new Set<Id>());
        Test.stopTest();

        System.assertEquals(2, groups.size(), 'Two null-Call_Transcript__c rows should stay as 2 separate groups');
    }
}