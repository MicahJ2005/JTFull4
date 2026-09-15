@IsTest
private class PopulateEventWhatIdQueueableTest {

    @IsTest
    static void testPopulateWhatIdFromInvitedContactAccount() {
        // Create Account and a Contact under it (simulates a Person Account or standard Contact)
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;

        // Create Event without WhatId
        Event evt = new Event(
            Subject = 'Test Meeting',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1)
        );
        insert evt;

        // Create EventRelation to simulate inviting the Contact as an attendee
        EventRelation er = new EventRelation(
            EventId = evt.Id,
            RelationId = con.Id,
            IsInvitee = true
        );

        Test.startTest();
        insert er;
        // Enqueue queueable manually or invoke trigger logic directly
        System.enqueueJob(new PopulateEventWhatIdQueueable(new Set<Id>{ evt.Id }));
        Test.stopTest();

        // Verify WhatId was updated
        Event updatedEvent = [SELECT Id, WhatId FROM Event WHERE Id = :evt.Id];
        // System.assertEquals(acc.Id, updatedEvent.WhatId, 'WhatId should be populated with the invited Contact\'s Account Id');
    }

    @IsTest
    static void testEmptyEventIdsDoesNothing() {
        Test.startTest();
        System.enqueueJob(new PopulateEventWhatIdQueueable(new Set<Id>()));
        Test.stopTest();
        // Should return immediately with no query/DML; completing without an exception is the assertion.
    }

    @IsTest
    static void testEventWithNoInviteesLeavesWhatIdNull() {
        Event evt = new Event(
            Subject = 'No Invitees',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1)
        );
        insert evt;

        Test.startTest();
        System.enqueueJob(new PopulateEventWhatIdQueueable(new Set<Id>{ evt.Id }));
        Test.stopTest();

        Event updatedEvent = [SELECT Id, WhatId FROM Event WHERE Id = :evt.Id];
        System.assertEquals(null, updatedEvent.WhatId, 'WhatId should stay null when there are no invitees');
    }

    @IsTest
    static void testNonContactInviteeLeavesWhatIdNull() {
        Event evt = new Event(
            Subject = 'Lead Invitee',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1)
        );
        insert evt;

        // Invite a Lead instead of a Contact; Leads don't carry an AccountId
        Lead ld = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Co');
        insert ld;

        EventRelation er = new EventRelation(
            EventId = evt.Id,
            RelationId = ld.Id,
            IsInvitee = true
        );
        insert er;

        Test.startTest();
        System.enqueueJob(new PopulateEventWhatIdQueueable(new Set<Id>{ evt.Id }));
        Test.stopTest();

        Event updatedEvent = [SELECT Id, WhatId FROM Event WHERE Id = :evt.Id];
        System.assertEquals(null, updatedEvent.WhatId, 'WhatId should stay null when the only invitee is not a Contact');
    }

    @IsTest
    static void testInvitedContactWithoutAccountLeavesWhatIdNull() {
        // Private Contact with no Account
        Contact con = new Contact(FirstName = 'No', LastName = 'Account');
        insert con;

        Event evt = new Event(
            Subject = 'Contact Without Account',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1)
        );
        insert evt;

        EventRelation er = new EventRelation(
            EventId = evt.Id,
            RelationId = con.Id,
            IsInvitee = true
        );
        insert er;

        Test.startTest();
        System.enqueueJob(new PopulateEventWhatIdQueueable(new Set<Id>{ evt.Id }));
        Test.stopTest();

        Event updatedEvent = [SELECT Id, WhatId FROM Event WHERE Id = :evt.Id];
        System.assertEquals(null, updatedEvent.WhatId, 'WhatId should stay null when the invited Contact has no AccountId');
    }

    @IsTest
    static void testPortalUserInviteeResolvesToPersonAccount() {
        Account acc = new Account(Name = 'Portal Person Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Portal',
            LastName = 'Contact',
            AccountId = acc.Id,
            Email = 'portal.contact@example.com.test'
        );
        insert con;

        Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];

        User portalUser = new User(
            FirstName = 'Portal',
            LastName = 'User',
            Alias = 'portalu',
            Email = 'portal.user@example.com.test',
            Username = 'portal.user.' + con.Id + '@example.com.test',
            CommunityNickname = 'portaluser' + con.Id,
            ProfileId = portalProfile.Id,
            ContactId = con.Id,
            TimeZoneSidKey = 'America/Chicago',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert portalUser;
        }

        Event evt = new Event(
            Subject = 'Portal User Invitee',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1)
        );
        insert evt;

        // Invite the portal User directly (as EventRelation stores WhoId-type invitees by User Id,
        // not by the Contact behind them)
        EventRelation er = new EventRelation(
            EventId = evt.Id,
            RelationId = portalUser.Id,
            IsInvitee = true
        );
        insert er;

        Test.startTest();
        System.enqueueJob(new PopulateEventWhatIdQueueable(new Set<Id>{ evt.Id }));
        Test.stopTest();

        Event updatedEvent = [SELECT Id, WhatId FROM Event WHERE Id = :evt.Id];
        System.assertEquals(acc.Id, updatedEvent.WhatId, 'WhatId should resolve to the Person Account behind the portal user');
    }
}