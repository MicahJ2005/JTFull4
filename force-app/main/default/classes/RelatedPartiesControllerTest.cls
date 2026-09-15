@IsTest
private class RelatedPartiesControllerTest {

    // ─── Shared test data ───────────────────────────────────────────────

    private static AcctSeed__Project__c makeMatter() {
        AcctSeed__Project__c m = new AcctSeed__Project__c(Name = 'Test Matter - RelatedParties');
        insert m;
        return m;
    }

    private static Account makePersonAccount(String firstName, String lastName) {
        Id personAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')?.getRecordTypeId();
        Account pa = new Account(
            FirstName = firstName,
            LastName = lastName,
            PersonMobilePhone = '555-0100',
            PersonEmail = firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@example.com'
        );
        if (personAccountRtId != null) {
            pa.RecordTypeId = personAccountRtId;
        }
        insert pa;
        return pa;
    }

    private static Account makeOrgAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Contact makeBusinessContact(String firstName, String lastName, Id accountId) {
        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Phone = '555-0200',
            Email = firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@example.com'
        );
        if (accountId != null) {
            c.AccountId = accountId;
        }
        insert c;
        return c;
    }

    // ─── getMatterName ──────────────────────────────────────────────────

    @IsTest static void testGetMatterName_returnsName() {
        AcctSeed__Project__c m = makeMatter();

        Test.startTest();
        String result = RelatedPartiesController.getMatterName(m.Id);
        Test.stopTest();

        System.assertEquals(m.Name, result, 'Should return the matter Name');
    }

    // ─── getRelatedPeople ───────────────────────────────────────────────

    @IsTest static void testGetRelatedPeople_returnsLinkedPeople() {
        AcctSeed__Project__c m = makeMatter();
        Account client = makePersonAccount('Jane', 'Client');
        Account relative = makePersonAccount('Sam', 'Relative');

        insert new List<Related_People__c>{
            new Related_People__c(Matter_Name__c = m.Id, Person_Account_Name__c = client.Id, Related_People_Class__c = 'Client'),
            new Related_People__c(Matter_Name__c = m.Id, Person_Account_Name__c = relative.Id, Related_People_Class__c = 'Client Relative')
        };

        Test.startTest();
        List<Related_People__c> results = RelatedPartiesController.getRelatedPeople(m.Id);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return both related people');
    }

    @IsTest static void testGetRelatedPeople_scopedToMatter() {
        AcctSeed__Project__c m1 = makeMatter();
        AcctSeed__Project__c m2 = makeMatter();
        Account p1 = makePersonAccount('Alice', 'OnMatterOne');
        Account p2 = makePersonAccount('Bob', 'OnMatterTwo');

        insert new List<Related_People__c>{
            new Related_People__c(Matter_Name__c = m1.Id, Person_Account_Name__c = p1.Id, Related_People_Class__c = 'Witness'),
            new Related_People__c(Matter_Name__c = m2.Id, Person_Account_Name__c = p2.Id, Related_People_Class__c = 'Witness')
        };

        Test.startTest();
        List<Related_People__c> results = RelatedPartiesController.getRelatedPeople(m1.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should only return people linked to the requested matter');
        System.assertEquals(p1.Id, results[0].Person_Account_Name__c);
    }

    // ─── getRelatedProfessionals ────────────────────────────────────────

    @IsTest static void testGetRelatedProfessionals_returnsLinkedProfessionalsWithAssistant() {
        AcctSeed__Project__c m = makeMatter();
        Account firm = makeOrgAccount('Test Law Firm');
        Contact assistant = makeBusinessContact('Pat', 'Paralegal', firm.Id);
        Contact opposingCounsel = makeBusinessContact('Terry', 'Attorney', firm.Id);
        opposingCounsel.Opposing_Paralegal_Assistant__c = assistant.Id;
        update opposingCounsel;

        insert new Related_Professionals__c(
            Matter_Name__c = m.Id,
            Business_Contact__c = opposingCounsel.Id,
            Related_Professional_Type__c = 'Opposing Counsel'
        );

        Test.startTest();
        List<Related_Professionals__c> results = RelatedPartiesController.getRelatedProfessionals(m.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return the linked professional');
        System.assertEquals(
            assistant.Id,
            results[0].Business_Contact__r.Opposing_Paralegal_Assistant__c,
            'Linked assistant should come through the relationship'
        );
    }

    // ─── searchPersonAccounts ───────────────────────────────────────────

    @IsTest static void testSearchPersonAccounts_matchesByName() {
        makePersonAccount('Unique', 'Searchtarget');
        makeOrgAccount('Some Business Account'); // should never come back for person search

        Test.startTest();
        List<Account> results = RelatedPartiesController.searchPersonAccounts('Searchtarget');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find exactly the matching person account');
        System.assert(results[0].Name.contains('Searchtarget'));
    }

    @IsTest static void testSearchPersonAccounts_shortTermReturnsEmpty() {
        makePersonAccount('Short', 'Term');

        Test.startTest();
        List<Account> results = RelatedPartiesController.searchPersonAccounts('S');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Search terms under 2 chars should short-circuit to empty');
    }

    // ─── searchBusinessContacts ─────────────────────────────────────────

    @IsTest static void testSearchBusinessContacts_matchesByName() {
        Account firm = makeOrgAccount('Findable Firm');
        makeBusinessContact('Uniquely', 'Findable', firm.Id);

        Test.startTest();
        List<Contact> results = RelatedPartiesController.searchBusinessContacts('Findable');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find the matching business contact');
    }

    // ─── createRelatedPerson / createRelatedProfessional (link existing) ─

    @IsTest static void testCreateRelatedPerson_persists() {
        AcctSeed__Project__c m = makeMatter();
        Account pa = makePersonAccount('Existing', 'Person');

        Test.startTest();
        Id newId = RelatedPartiesController.createRelatedPerson(m.Id, pa.Id, 'Friend');
        Test.stopTest();

        Related_People__c rp = [SELECT Matter_Name__c, Person_Account_Name__c, Related_People_Class__c FROM Related_People__c WHERE Id = :newId];
        System.assertEquals(m.Id, rp.Matter_Name__c);
        System.assertEquals(pa.Id, rp.Person_Account_Name__c);
        System.assertEquals('Friend', rp.Related_People_Class__c);
    }

    @IsTest static void testCreateRelatedProfessional_persists() {
        AcctSeed__Project__c m = makeMatter();
        Account firm = makeOrgAccount('Existing Firm');
        Contact c = makeBusinessContact('Existing', 'Professional', firm.Id);

        Test.startTest();
        Id newId = RelatedPartiesController.createRelatedProfessional(m.Id, c.Id, 'Mediator');
        Test.stopTest();

        Related_Professionals__c rp = [SELECT Matter_Name__c, Business_Contact__c, Related_Professional_Type__c FROM Related_Professionals__c WHERE Id = :newId];
        System.assertEquals(m.Id, rp.Matter_Name__c);
        System.assertEquals(c.Id, rp.Business_Contact__c);
        System.assertEquals('Mediator', rp.Related_Professional_Type__c);
    }

    // ─── createPersonAndLink / createProfessionalAndLink (create new) ────

    @IsTest static void testCreatePersonAndLink_createsAccountAndJunction() {
        AcctSeed__Project__c m = makeMatter();

        Test.startTest();
        Id newId = RelatedPartiesController.createPersonAndLink(
            m.Id, 'Newly', 'Created', '555-0300', 'newly.created@example.com', 'Heir'
        );
        Test.stopTest();

        Related_People__c rp = [SELECT Person_Account_Name__r.Name, Related_People_Class__c FROM Related_People__c WHERE Id = :newId];
        System.assertEquals('Heir', rp.Related_People_Class__c);
        System.assert(rp.Person_Account_Name__r.Name.contains('Newly'));
    }

    @IsTest static void testCreateProfessionalAndLink_reusesExistingOrgAccount() {
        AcctSeed__Project__c m = makeMatter();
        Account existingOrg = makeOrgAccount('Shared Firm LLC');

        Test.startTest();
        Id newId = RelatedPartiesController.createProfessionalAndLink(
            m.Id, 'Brand', 'New', '555-0400', 'brand.new@example.com', 'Shared Firm LLC', null, 'Judge'
        );
        Test.stopTest();

        Related_Professionals__c rp = [SELECT Business_Contact__r.AccountId FROM Related_Professionals__c WHERE Id = :newId];
        System.assertEquals(existingOrg.Id, rp.Business_Contact__r.AccountId, 'Should reuse the existing org account instead of creating a duplicate');

        // Confirm no duplicate org account was created
        List<Account> orgAccounts = [SELECT Id FROM Account WHERE Name = 'Shared Firm LLC'];
        System.assertEquals(1, orgAccounts.size(), 'Should not create a duplicate org account');
    }

    @IsTest static void testCreateProfessionalAndLink_createsNewOrgAccountWhenNoneExists() {
        AcctSeed__Project__c m = makeMatter();

        Test.startTest();
        Id newId = RelatedPartiesController.createProfessionalAndLink(
            m.Id, 'Another', 'Pro', '555-0500', 'another.pro@example.com', 'Brand New Org', null, 'Expert Witness'
        );
        Test.stopTest();

        Related_Professionals__c rp = [SELECT Business_Contact__r.Account.Name FROM Related_Professionals__c WHERE Id = :newId];
        System.assertEquals('Brand New Org', rp.Business_Contact__r.Account.Name);
    }

    @IsTest static void testCreateProfessionalAndLink_usesExplicitAccountIdWhenProvided() {
        AcctSeed__Project__c m = makeMatter();
        Account pickedOrg = makeOrgAccount('Picked From Dropdown Inc');
        Account decoyOrg = makeOrgAccount('Picked From Dropdown Inc - Decoy');

        Test.startTest();
        // organizationAccountId takes precedence over the free-typed organization
        // name, even when that name doesn't exactly match the picked account --
        // this is what happens when the user selects from the typeahead dropdown.
        Id newId = RelatedPartiesController.createProfessionalAndLink(
            m.Id, 'Picked', 'Result', '555-0600', 'picked.result@example.com',
            'Picked From Dropdown Inc', pickedOrg.Id, 'Mediator'
        );
        Test.stopTest();

        Related_Professionals__c rp = [SELECT Business_Contact__r.AccountId FROM Related_Professionals__c WHERE Id = :newId];
        System.assertEquals(pickedOrg.Id, rp.Business_Contact__r.AccountId, 'Should use the explicitly-picked account, not name-match or create a new one');

        List<Account> orgAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Picked From Dropdown Inc%'];
        System.assertEquals(2, orgAccounts.size(), 'Should not create any additional org account beyond the two seeded');
    }

    // ─── searchOrganizationAccounts ─────────────────────────────────────

    @IsTest static void testSearchOrganizationAccounts_matchesBusinessAccountsOnly() {
        makeOrgAccount('Searchable Org Match');
        makePersonAccount('Searchable', 'PersonShouldNotMatch');

        Test.startTest();
        List<Account> results = RelatedPartiesController.searchOrganizationAccounts('Searchable');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should only match the business account, not the person account');
        System.assertEquals('Searchable Org Match', results[0].Name);
    }

    // ─── removeRelatedPerson / removeRelatedProfessional ─────────────────

    @IsTest static void testRemoveRelatedPerson_deletesJunction() {
        AcctSeed__Project__c m = makeMatter();
        Account pa = makePersonAccount('ToBe', 'Removed');
        Related_People__c rp = new Related_People__c(
            Matter_Name__c = m.Id, Person_Account_Name__c = pa.Id, Related_People_Class__c = 'Other'
        );
        insert rp;

        Test.startTest();
        RelatedPartiesController.removeRelatedPerson(rp.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Related_People__c WHERE Id = :rp.Id]);
    }

    @IsTest static void testRemoveRelatedProfessional_deletesJunction() {
        AcctSeed__Project__c m = makeMatter();
        Account firm = makeOrgAccount('Removal Firm');
        Contact c = makeBusinessContact('To', 'Remove', firm.Id);
        Related_Professionals__c rp = new Related_Professionals__c(
            Matter_Name__c = m.Id, Business_Contact__c = c.Id, Related_Professional_Type__c = 'Other'
        );
        insert rp;

        Test.startTest();
        RelatedPartiesController.removeRelatedProfessional(rp.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Related_Professionals__c WHERE Id = :rp.Id]);
    }
}