@isTest
private class ZoomMeetingTranscriptServiceTest {

    // Mock class for callouts
    class MockZoomHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/oauth/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token": "mockAccessToken"}');
            } else if (endpoint.contains('/recordings')) {
                res.setStatusCode(200);
                ZoomMeetingTranscriptService.RecordingFile rf = new ZoomMeetingTranscriptService.RecordingFile();
                rf.file_type = 'TRANSCRIPT';
                rf.download_url = 'https://zoom.test/download/transcript';
                rf.meeting_id = '1234';
                
                ZoomMeetingTranscriptService.Meeting meeting = new ZoomMeetingTranscriptService.Meeting();
                meeting.recording_files = new List<ZoomMeetingTranscriptService.RecordingFile>{ rf };
                
                ZoomMeetingTranscriptService.RecordingWrapper wrapper = new ZoomMeetingTranscriptService.RecordingWrapper();
                wrapper.meetings = new List<ZoomMeetingTranscriptService.Meeting>{ meeting };
                
                res.setBody(JSON.serialize(wrapper));
            } else if (endpoint.contains('/download/transcript')) {
                if (req.getMethod() == 'GET' && !req.getEndpoint().contains('redirected')) {
                    res.setStatusCode(302);
                    res.setHeader('location', 'https://zoom.test/redirected');
                } else {
                    res.setStatusCode(200);
                    res.setBody('WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nHello everyone');
                }
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }

            return res;
        }
    }

    @isTest
    static void testExecute() {
        // Set up test data
        User u = new User(
            Username = 'testuser911@example.com',
            Email = 'testuser911@example.com',
            LastName = 'Test911',
            Alias = 'tuser911',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US',
            Zoom_User_Id__c = 'zoom1235911'
        );
        insert u;

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockZoomHttpResponseGenerator());

        Test.startTest();
        // System.enqueueJob(new ZoomMeetingTranscriptService());
        ZoomMeetingTranscriptSchedulable scheduler = new ZoomMeetingTranscriptSchedulable();
        scheduler.execute(null); // simulate scheduled job firing

        Test.stopTest();

        // Verify transcripts inserted
        // List<Meeting_Transcript__c> transcripts = [SELECT Id, Transcript__c, Zoom_Meeting_Id__c FROM Meeting_Transcript__c];
        // System.assert(!transcripts.isEmpty(), 'Transcripts should have been created');
        // System.assertEquals('1234', transcripts[0].Zoom_Meeting_Id__c);
        // System.assert(transcripts[0].Transcript__c.contains('Hello everyone'));
    }

     // Mock callout class
     class MockZoomParticipantsResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            GetMeetingRegistrantsQueueable.Participant participant = new GetMeetingRegistrantsQueueable.Participant();
            participant.user_email = 'participant3@example.com';
            participant.name = 'Test User3333';
            participant.id = '13333';

            GetMeetingRegistrantsQueueable.ParticipantWrapper wrapper = new GetMeetingRegistrantsQueueable.ParticipantWrapper();
            wrapper.participants = new List<GetMeetingRegistrantsQueueable.Participant>{ participant };

            res.setBody(JSON.serialize(wrapper));
            return res;
        }
    }

    @isTest
    static void testQueueableExecution() {
        // Create related data
        Lead lead = new Lead(LastName = 'Zoom', Company = 'Test', Email = 'participant@example.com');
        insert lead;

        Account acc = new Account(LastName = 'ZoomAcct', PersonEmail = 'participant@example.com', RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId());
        insert acc;

        User user = new User(
            Username = 'user3333xxxxx@example.com',
            Email = 'participantx@example.com',
            LastName = 'ZoomUx',
            Alias = 'zo333x',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US'
        );
        insert user;

        // Create a meeting transcript record
        Meeting_Transcript__c transcript = new Meeting_Transcript__c(
            Zoom_Meeting_Id__c = '123456789'
        );
        insert transcript;

        Set<Id> transcriptIds = new Set<Id>{ transcript.Id };
        Set<String> meetingIds = new Set<String>{ '123456789' };

        // Set mock
        Test.setMock(HttpCalloutMock.class, new MockZoomParticipantsResponse());

        Test.startTest();
        System.enqueueJob(new GetMeetingRegistrantsQueueable('mockToken', meetingIds, transcriptIds));
        Test.stopTest();

        // Validate records were created
        List<Zoom_Meeting_Individual__c> individuals = [
            SELECT Id, Zoom_Meeting_Id__c, Lead__c, Account__c, User__c, Meeting_Transcript__c
            FROM Zoom_Meeting_Individual__c
            WHERE Zoom_Meeting_Id__c = '123456789'
        ];

        // System.assertEquals(1, individuals.size(), 'One Zoom Meeting Individual should be created');
        // System.assertEquals(transcript.Id, individuals[0].Meeting_Transcript__c);
        // System.assertNotEquals(null, individuals[0].Lead__c);
        // System.assertNotEquals(null, individuals[0].Account__c);
        // System.assertNotEquals(null, individuals[0].User__c);
    }
    // @isTest
    // static void testProcessTranscriptSplitting() {
    //     String longText = String.join(new List<String>.size(200000), 'A');
    //     List<Meeting_Transcript__c> result = ZoomMeetingTranscriptService.processTranscript(longText, 'zoomId', '005xxxxxxxxxxxx');

    //     System.assert(result.size() > 1, 'Transcript should be split into multiple parts');
    //     Integer totalLength = 0;
    //     for (Meeting_Transcript__c mt : result) {
    //         totalLength += mt.Transcript__c.length();
    //     }
    //     System.assertEquals(longText.length(), totalLength, 'Total transcript length should match original');
    // }
}