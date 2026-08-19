@isTest
private class EventAccountMatchControllerTest {

    @testSetup
    static void setupData() {
        // Create Person Account match
        // Note: Make sure Person Accounts are enabled in the org or adjust record types accordingly
        Account pa = new Account(
            FirstName = 'Jane',
            LastName = 'TestUser',
            PersonEmail = 'testuser@example.com',
            Description = '<p>Rich text note from Agentforce candidate match.</p>'
        );
        insert pa;

        Lead ld = new Lead(
            FirstName = 'Jane',
            LastName = 'TestUser',
            Company = 'Acme Inc',
            Email = 'janetestuser@example.com',
            Description = 'Lead description text.'
        );
        insert ld;

        // Create Event without WhatId (Unlinked)
        Event unlinkedEvent = new Event(
            Subject = 'TestUser',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert unlinkedEvent;

        // Create Event with WhatId (Linked)
        Event linkedEvent = new Event(
            Subject = 'TestUser Linked',
            WhatId = pa.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert linkedEvent;
    }

    @isTest
    static void testGetPotentialMatches_UnlinkedEvent() {
        Event evt = [SELECT Id FROM Event WHERE WhatId = NULL LIMIT 1];

        Test.startTest();
        List<EventAccountMatchController.AccountMatchWrapper> matches =
            EventAccountMatchController.getPotentialMatches(evt.Id);
        Test.stopTest();

        // In a test context the real Agentforce/Einstein LLM callout cannot succeed,
        // so no name details are extracted and an empty list is returned.
        Assert.areEqual(0, matches.size(), 'No matches expected when the Agentforce callout is unavailable in tests.');
    }

    @isTest
    static void testGetPotentialMatches_AlreadyLinkedEvent() {
        Event evt = [SELECT Id FROM Event WHERE WhatId != NULL LIMIT 1];

        Test.startTest();
        List<EventAccountMatchController.AccountMatchWrapper> matches =
            EventAccountMatchController.getPotentialMatches(evt.Id);
        Test.stopTest();

        Assert.areEqual(0, matches.size(), 'Should return empty list when WhatId is already populated.');
    }

    @isTest
    static void testGetPotentialMatches_NullEventId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            EventAccountMatchController.getPotentialMatches(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw an AuraHandledException when eventId is null.');
    }

    @isTest
    static void testGetNameUsingAgentforce_BlankSubject() {
        Test.startTest();
        EventAccountMatchController.PromptResponseWrapper result =
            EventAccountMatchController.getNameUsingAgentforce('');
        Test.stopTest();

        Assert.isNull(result, 'Blank subject line should short-circuit to null.');
    }

    @isTest
    static void testGetNameUsingAgentforce_CalloutNotAvailableInTest() {
        Test.startTest();
        EventAccountMatchController.PromptResponseWrapper result =
            EventAccountMatchController.getNameUsingAgentforce('Jane TestUser');
        Test.stopTest();

        // The real ConnectApi callout cannot succeed in a unit test; the method
        // should catch the exception internally and return null rather than throwing.
        Assert.isNull(result, 'Should return null when the Prompt Template callout fails in a test context.');
    }

    @isTest
    static void testParsePromptResponseText_PlainJson() {
        Test.startTest();
        EventAccountMatchController.PromptResponseWrapper result =
            EventAccountMatchController.parsePromptResponseText('{"firstName":"Jane","lastName":"TestUser"}');
        Test.stopTest();

        Assert.areEqual('Jane', result.firstName);
        Assert.areEqual('TestUser', result.lastName);
    }

    @isTest
    static void testParsePromptResponseText_JsonCodeFence() {
        String fenced = '```json\n{"firstName":"Jane","lastName":"TestUser"}\n```';

        Test.startTest();
        EventAccountMatchController.PromptResponseWrapper result =
            EventAccountMatchController.parsePromptResponseText(fenced);
        Test.stopTest();

        Assert.areEqual('Jane', result.firstName);
        Assert.areEqual('TestUser', result.lastName);
    }

    @isTest
    static void testParsePromptResponseText_PlainCodeFence() {
        String fenced = '```\n{"firstName":"Jane","lastName":"TestUser"}\n```';

        Test.startTest();
        EventAccountMatchController.PromptResponseWrapper result =
            EventAccountMatchController.parsePromptResponseText(fenced);
        Test.stopTest();

        Assert.areEqual('Jane', result.firstName);
        Assert.areEqual('TestUser', result.lastName);
    }

    @isTest
    static void testFindPotentialMatches_FirstAndLastName() {
        EventAccountMatchController.PromptResponseWrapper nameDetails =
            new EventAccountMatchController.PromptResponseWrapper();
        nameDetails.firstName = 'Jane';
        nameDetails.lastName = 'TestUser';

        Test.startTest();
        List<EventAccountMatchController.AccountMatchWrapper> matches =
            EventAccountMatchController.findPotentialMatches(nameDetails);
        Test.stopTest();

        Assert.areEqual(2, matches.size(), 'Should return one Account match and one Lead match.');
    }

    @isTest
    static void testFindPotentialMatches_LastNameOnly() {
        EventAccountMatchController.PromptResponseWrapper nameDetails =
            new EventAccountMatchController.PromptResponseWrapper();
        nameDetails.lastName = 'TestUser';

        Test.startTest();
        List<EventAccountMatchController.AccountMatchWrapper> matches =
            EventAccountMatchController.findPotentialMatches(nameDetails);
        Test.stopTest();

        Assert.areEqual(2, matches.size(), 'Should return matches based on last name alone.');
    }

    @isTest
    static void testFindPotentialMatches_FirstNameOnlyFallback() {
        EventAccountMatchController.PromptResponseWrapper nameDetails =
            new EventAccountMatchController.PromptResponseWrapper();
        nameDetails.firstName = 'Jane';

        Test.startTest();
        List<EventAccountMatchController.AccountMatchWrapper> matches =
            EventAccountMatchController.findPotentialMatches(nameDetails);
        Test.stopTest();

        Assert.areEqual(2, matches.size(), 'Fallback branch should match on first name against both first and last name fields.');
    }

    @isTest
    static void testFindPotentialMatches_NoMatches() {
        EventAccountMatchController.PromptResponseWrapper nameDetails =
            new EventAccountMatchController.PromptResponseWrapper();
        nameDetails.firstName = 'Nonexistent';
        nameDetails.lastName = 'Nobody';

        Test.startTest();
        List<EventAccountMatchController.AccountMatchWrapper> matches =
            EventAccountMatchController.findPotentialMatches(nameDetails);
        Test.stopTest();

        Assert.areEqual(0, matches.size(), 'Should return an empty list when no Accounts or Leads match.');
    }
}
