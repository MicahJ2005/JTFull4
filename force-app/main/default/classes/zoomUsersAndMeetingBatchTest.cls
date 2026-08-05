@isTest
private class zoomUsersAndMeetingBatchTest {

    // Mock class for Zoom callouts made from ZoomMeetingTranscriptService during the batch run
    class MockZoomBatchHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/recordings')) {
                res.setStatusCode(200);

                ZoomMeetingTranscriptService.RecordingFile rf = new ZoomMeetingTranscriptService.RecordingFile();
                rf.file_type = 'TRANSCRIPT';
                rf.download_url = 'https://zoom.test/download/transcript';
                rf.meeting_id = '999999999';
                rf.id = 'file123';

                ZoomMeetingTranscriptService.Meeting meeting = new ZoomMeetingTranscriptService.Meeting();
                meeting.id = Long.valueOf('12345678901');
                meeting.uuid = 'uuid-batch-test-abc';
                meeting.recording_files = new List<ZoomMeetingTranscriptService.RecordingFile>{ rf };

                ZoomMeetingTranscriptService.RecordingWrapper wrapper = new ZoomMeetingTranscriptService.RecordingWrapper();
                wrapper.meetings = new List<ZoomMeetingTranscriptService.Meeting>{ meeting };

                res.setBody(JSON.serialize(wrapper));
            } else if (endpoint.contains('redirected')) {
                res.setStatusCode(200);
                res.setBody('WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nHello from batch test');
            } else if (endpoint.contains('/download/transcript')) {
                res.setStatusCode(302);
                res.setHeader('location', 'https://zoom.test/redirected');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }

            return res;
        }
    }

    private static User createZoomUser(String uniqueKey) {
        User u = new User(
            Username = 'zoombatch' + uniqueKey + '@example.com',
            Email = 'zoombatch' + uniqueKey + '@example.com',
            LastName = 'ZoomBatch' + uniqueKey,
            Alias = ('zb' + uniqueKey).left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US',
            Zoom_User_Id__c = 'zoomBatchUser' + uniqueKey
        );
        insert u;
        return u;
    }

    @isTest
    static void testExecuteWithLeadEvent() {
        User testUser = createZoomUser('1');

        Lead testLead = new Lead(LastName = 'BatchLead', Company = 'BatchCo');
        insert testLead;

        Event e = new Event(
            OwnerId = testUser.Id,
            Subject = 'Zoom Meeting',
            StartDateTime = Datetime.now(),
            EndDateTime = Datetime.now().addHours(1),
            Description = 'Meeting ID: 123 4567 8901',
            WhoId = testLead.Id
        );
        insert e;

        Test.setMock(HttpCalloutMock.class, new MockZoomBatchHttpResponseGenerator());

        zoomUsersAndMeetingBatch batchJob = new zoomUsersAndMeetingBatch('mockToken', UserInfo.getUserId());

        Test.startTest();
        batchJob.execute(null, new List<SObject>{ testUser });
        Test.stopTest();

        List<Meeting_Transcript__c> transcripts = [SELECT Id, Lead__c, Contact__c, Account__c, OwnerId, Zoom_Event_Id__c, Transcript__c FROM Meeting_Transcript__c];
        System.assertEquals(1, transcripts.size(), 'Expected one transcript to be created');
        System.assertEquals(testLead.Id, transcripts[0].Lead__c, 'Lead should be linked from the matching Event');
        System.assertEquals(testUser.Id, transcripts[0].OwnerId, 'Owner should come from the matched Event owner, not the fallback queue');
        System.assertEquals('12345678901', transcripts[0].Zoom_Event_Id__c);
        System.assert(transcripts[0].Transcript__c.contains('Hello from batch test'), 'Transcript text should come from the mocked VTT content');
    }

    @isTest
    static void testExecuteWithContactEvent() {
        User testUser = createZoomUser('2');

        Account testAccount = new Account(Name = 'BatchAccount');
        insert testAccount;

        Contact testContact = new Contact(LastName = 'BatchContact', AccountId = testAccount.Id);
        insert testContact;

        // Note: Salesforce does not persist WhatId on an Event when WhoId is set to a
        // Contact, so this scenario only exercises the Contact__c branch. Account linkage
        // (WhatId with no WhoId) is covered separately in testExecuteWithAccountOnlyEvent.
        Event e = new Event(
            OwnerId = testUser.Id,
            Subject = 'Zoom Meeting',
            StartDateTime = Datetime.now(),
            EndDateTime = Datetime.now().addHours(1),
            Description = 'Meeting ID: 123 4567 8901',
            WhoId = testContact.Id
        );
        insert e;

        Test.setMock(HttpCalloutMock.class, new MockZoomBatchHttpResponseGenerator());

        zoomUsersAndMeetingBatch batchJob = new zoomUsersAndMeetingBatch('mockToken', UserInfo.getUserId());

        Test.startTest();
        batchJob.execute(null, new List<SObject>{ testUser });
        Test.stopTest();

        List<Meeting_Transcript__c> transcripts = [SELECT Id, Lead__c, Contact__c, Account__c, OwnerId FROM Meeting_Transcript__c];
        System.assertEquals(1, transcripts.size(), 'Expected one transcript to be created');
        System.assertEquals(testContact.Id, transcripts[0].Contact__c, 'Contact should be linked from the matching Event WhoId');
        System.assertEquals(testUser.Id, transcripts[0].OwnerId, 'Owner should come from the matched Event owner');
    }

    @isTest
    static void testExecuteWithAccountOnlyEvent() {
        User testUser = createZoomUser('3');

        Account testAccount = new Account(Name = 'BatchAccountOnly');
        insert testAccount;

        Event e = new Event(
            OwnerId = testUser.Id,
            Subject = 'Zoom Meeting',
            StartDateTime = Datetime.now(),
            EndDateTime = Datetime.now().addHours(1),
            Description = 'Meeting ID: 123 4567 8901',
            WhatId = testAccount.Id
        );
        insert e;

        Test.setMock(HttpCalloutMock.class, new MockZoomBatchHttpResponseGenerator());

        zoomUsersAndMeetingBatch batchJob = new zoomUsersAndMeetingBatch('mockToken', UserInfo.getUserId());

        Test.startTest();
        batchJob.execute(null, new List<SObject>{ testUser });
        Test.stopTest();

        List<Meeting_Transcript__c> transcripts = [SELECT Id, Lead__c, Contact__c, Account__c, OwnerId FROM Meeting_Transcript__c];
        System.assertEquals(1, transcripts.size(), 'Expected one transcript to be created');
        System.assertEquals(null, transcripts[0].Contact__c, 'No Contact should be linked when the Event has no WhoId');
        System.assertEquals(testAccount.Id, transcripts[0].Account__c, 'Account should be linked from the matching Event WhatId');
        System.assertEquals(testUser.Id, transcripts[0].OwnerId, 'Owner should come from the matched Event owner');
    }

    @isTest
    static void testExecuteWithNoMatchingEvent() {
        User testUser = createZoomUser('4');

        Test.setMock(HttpCalloutMock.class, new MockZoomBatchHttpResponseGenerator());

        Id fallbackQueueId = UserInfo.getUserId();
        zoomUsersAndMeetingBatch batchJob = new zoomUsersAndMeetingBatch('mockToken', fallbackQueueId);

        Test.startTest();
        batchJob.execute(null, new List<SObject>{ testUser });
        Test.stopTest();

        List<Meeting_Transcript__c> transcripts = [SELECT Id, Lead__c, Contact__c, Account__c, OwnerId FROM Meeting_Transcript__c];
        System.assertEquals(1, transcripts.size(), 'Expected one transcript to be created even without a matching Event');
        System.assertEquals(null, transcripts[0].Lead__c);
        System.assertEquals(null, transcripts[0].Contact__c);
        System.assertEquals(null, transcripts[0].Account__c);
        System.assertEquals(fallbackQueueId, transcripts[0].OwnerId, 'Owner should fall back to the queue id when no Event matches');
    }

    @isTest
    static void testGetUserEvents() {
        User testUser = createZoomUser('5');

        Lead testLead = new Lead(LastName = 'DirectLead', Company = 'DirectCo');
        insert testLead;

        Event matchingEvent = new Event(
            OwnerId = testUser.Id,
            Subject = 'Matches',
            StartDateTime = Datetime.now(),
            EndDateTime = Datetime.now().addHours(1),
            Description = 'Meeting ID: 111 2222 3333',
            WhoId = testLead.Id
        );
        Event noDescriptionEvent = new Event(
            OwnerId = testUser.Id,
            Subject = 'No Description',
            StartDateTime = Datetime.now(),
            EndDateTime = Datetime.now().addHours(1)
        );
        insert new List<Event>{ matchingEvent, noDescriptionEvent };

        Test.startTest();
        Map<String, Event> result = zoomUsersAndMeetingBatch.getUserEvents(new Set<String>{ testUser.Id });
        Test.stopTest();

        System.assert(result.containsKey('11122223333'), 'Expected the parsed Meeting ID to be present as a map key');
        System.assertEquals(matchingEvent.Id, result.get('11122223333').Id);
    }

    // Mock that simulates a Zoom callout timeout for one specific Zoom user while succeeding
    // for everyone else, so we can verify a failure is logged without blocking other users.
    class MockZoomBatchWithTimeoutForOneUser implements HttpCalloutMock {
        String failingZoomUserId;
        MockZoomBatchWithTimeoutForOneUser(String failingZoomUserId) {
            this.failingZoomUserId = failingZoomUserId;
        }
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains(failingZoomUserId + '/recordings')) {
                throw new CalloutException('Read timed out');
            }
            return new MockZoomBatchHttpResponseGenerator().respond(req);
        }
    }

    @isTest
    static void testExecuteLogsErrorAndContinuesOnCalloutFailure() {
        User failingUser = createZoomUser('7');
        User succeedingUser = createZoomUser('8');

        Test.setMock(HttpCalloutMock.class, new MockZoomBatchWithTimeoutForOneUser(failingUser.Zoom_User_Id__c));

        zoomUsersAndMeetingBatch batchJob = new zoomUsersAndMeetingBatch('mockToken', UserInfo.getUserId());

        Test.startTest();
        batchJob.execute(null, new List<SObject>{ failingUser, succeedingUser });
        Test.stopTest();

        List<Zoom_Integration_Error__c> errors = [SELECT Error_Type__c, Zoom_User_Id__c, Zoom_Meeting_Id__c, Apex_Class__c, Apex_Method__c, Error_Message__c FROM Zoom_Integration_Error__c];
        String debugInfo = '';
        for (Zoom_Integration_Error__c err : errors) {
            debugInfo += '[' + err.Apex_Class__c + '.' + err.Apex_Method__c + ' type=' + err.Error_Type__c
                + ' user=' + err.Zoom_User_Id__c + ' meeting=' + err.Zoom_Meeting_Id__c + ' msg=' + err.Error_Message__c + '] ';
        }
        System.assertEquals(1, errors.size(), 'Expected one logged error for the failing Zoom user. Got: ' + debugInfo);
        System.assertEquals('Callout Timeout', errors[0].Error_Type__c);
        System.assertEquals(failingUser.Zoom_User_Id__c, errors[0].Zoom_User_Id__c);
        System.assertEquals('getRecentMeetings', errors[0].Apex_Method__c);

        List<Meeting_Transcript__c> transcripts = [SELECT Id, OwnerId FROM Meeting_Transcript__c];
        System.assertEquals(1, transcripts.size(), 'The succeeding user\'s transcript should still be created');
    }

    @isTest
    static void testFullBatchLifecycle() {
        // Exercises start() and finish() in addition to execute(), which is covered in detail above.
        User testUser = createZoomUser('6');

        Test.setMock(HttpCalloutMock.class, new MockZoomBatchHttpResponseGenerator());

        Test.startTest();
        Database.executeBatch(new zoomUsersAndMeetingBatch('mockToken', UserInfo.getUserId()), 1);
        Test.stopTest();

        // start() scopes to a single active, Zoom-enabled User in test context, which may not
        // be the User created above if other such Users already exist in the org, so we only
        // assert the full batch lifecycle completes without error.
        System.assert(true);
    }
}