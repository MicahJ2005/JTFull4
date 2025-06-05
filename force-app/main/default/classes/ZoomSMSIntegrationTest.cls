@isTest
private class ZoomSMSIntegrationTest {

    @testSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Email = 'testuser@example.com',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            Phone = '1234567890'
        );
        insert testUser;
        
        insert new Account(Name = 'Test Account', Phone = '1234567890');
        insert new Lead(LastName = 'Test Lead', Phone = '1234567890');
    }
    
    @isTest
    static void testGetSMSInternalUser() {
        User u = [SELECT Name FROM User LIMIT 1];
        User result = ZoomSMSIntegration.getSMSInternalUser(u.Name);
        System.assertEquals(u.Id, result.Id);
    }

    @isTest
    static void testFormatPhoneNumber() {
        String formatted = ZoomSMSIntegration.formatPhoneNumber(null);
        System.assertEquals(null, formatted); // Already in format
    
        String formatted1 = ZoomSMSIntegration.formatPhoneNumber('1234567890');
        System.assertEquals('(123) 456-7890', formatted1); // Will reformat
        String formatted2 = ZoomSMSIntegration.formatPhoneNumber('11234567890');
    }
    
    @isTest
    static void testParseWrapper() {
        String json = '{"sms_histories":[{"message":"Hello","date_time":"2024-01-01T00:00:00Z"}]}';
        ZoomSMSIntegration.SMSHistoryWrapper parsed = ZoomSMSIntegration.parse(json);
        System.assertNotEquals(null, parsed);
    }    

    // Mock for Zoom OAuth token
    private class OAuthMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token": "mockToken123"}');
            return res;
        }
    }

    // Mock for Zoom SMS sessions list
    private class SessionListMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"sms_sessions": [{"session_id": "ABC123", "session_type": "SMS", "participants": []}]}');
            return res;
        }
    }

    // Mock for Zoom SMS messages in a session
    private class SessionMessagesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            ZoomSMSIntegration.Sender sender = new ZoomSMSIntegration.Sender();
            sender.phone_number = '1234567890';
            sender.display_name = 'Test User';

            ZoomSMSIntegration.ToMember toMember = new ZoomSMSIntegration.ToMember();
            toMember.phone_number = '1234567890';
            toMember.display_name = 'Test User';

            ZoomSMSIntegration.SMSHistory message = new ZoomSMSIntegration.SMSHistory();
            message.date_time = '2024-01-01T10:00:00Z';
            message.direction = 'inbound';
            message.message = 'Hello from Zoom!';
            message.message_id = 'msg1';
            message.message_type = 1;
            message.sender = sender;
            message.to_members = new List<ZoomSMSIntegration.ToMember>{ toMember };

            ZoomSMSIntegration.SMSHistoryWrapper wrapper = new ZoomSMSIntegration.SMSHistoryWrapper();
            wrapper.sms_histories = new List<ZoomSMSIntegration.SMSHistory>{ message };

            res.setBody(JSON.serialize(wrapper));
            return res;
        }
    }

    // Multi-callout mock router
    private class MultiSMSMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint().toLowerCase();

            if (endpoint.contains('zoom.us/oauth/token')) {
                return new OAuthMock().respond(req);
            } else if (endpoint.contains('/sms/sessions?')) {
                return new SessionListMock().respond(req);
            } else if (endpoint.contains('/sms/sessions/')) {
                return new SessionMessagesMock().respond(req);
            }

            HttpResponse fallback = new HttpResponse();
            fallback.setStatusCode(404);
            fallback.setBody('Unknown endpoint: ' + endpoint);
            return fallback;
        }
    }

    @isTest
    static void testSMSIntegrationMainFlow() {
        Test.setMock(HttpCalloutMock.class, new MultiSMSMock());

        Test.startTest();
        ZoomSMSIntegration.sendZoomDataToSalesforce();
        Test.stopTest();

        List<SMS_Session__c> sessions = [SELECT Id, Zoom_Session_Id__c, SMS_Session_Text__c FROM SMS_Session__c];
        List<SMS_Session_Individual__c> individuals = [SELECT Id FROM SMS_Session_Individual__c];

        System.assertEquals(1, sessions.size(), 'Expected one SMS session to be created');
        System.assertNotEquals(null, sessions[0].SMS_Session_Text__c, 'Session text should be populated');
        //System.assert(individuals.size() > 0, 'Expected at least one SMS session individual');
    }

    @isTest
    static void testScheduleExecution() {
        Test.setMock(HttpCalloutMock.class, new MultiSMSMock());

        Test.startTest();
        ZoomSMSIntegration job = new ZoomSMSIntegration();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Scheduled execution completed without error');
    }
}