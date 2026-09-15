@IsTest
private class ZoomCreateMeetingActionTest {

    private static final String TOKEN_BODY = '{"access_token":"test_token_abc123","token_type":"bearer"}';

    // ─────────────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static ZoomConfig__mdt config(String defaultUserId) {
        return new ZoomConfig__mdt(
            AccountId__c     = 'test_account_id',
            ClientId__c      = 'test_client_id',
            ClientSecret__c  = 'test_client_secret',
            DefaultUserId__c = defaultUserId
        );
    }

    private static ZoomCreateMeetingAction.ActionRequest req(String topic) {
        ZoomCreateMeetingAction.ActionRequest r = new ZoomCreateMeetingAction.ActionRequest();
        r.topic = topic;
        return r;
    }

    private static List<ZoomCreateMeetingAction.ActionRequest> one(
            ZoomCreateMeetingAction.ActionRequest r) {
        return new List<ZoomCreateMeetingAction.ActionRequest>{ r };
    }

    private static String meetingBody() {
        return JSON.serialize(new Map<String, Object>{
            'id'         => 123456789,
            'join_url'   => 'https://zoom.us/j/123456789',
            'host_id'    => 'hostZoomId0000000000AA',
            'host_email' => 'kristi@johnsonturner.com'
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK — routes by endpoint so an extra user lookup does not shift responses
    // ─────────────────────────────────────────────────────────────────────────

    private class ZoomMock implements HttpCalloutMock {
        Integer meetingStatus;
        String  meetingBody;
        public Integer userLookupStatus = 200;
        public Integer tokenStatus      = 200;
        public String  lastMeetingEndpoint;
        public String  lastMeetingBody;

        ZoomMock(Integer meetingStatus, String meetingBody) {
            this.meetingStatus = meetingStatus;
            this.meetingBody   = meetingBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint();

            if (ep.contains('oauth/token')) {
                res.setStatusCode(tokenStatus);
                res.setBody(tokenStatus == 200 ? TOKEN_BODY : '{"reason":"bad creds"}');
                return res;
            }
            if (ep.endsWith('/meetings')) {
                lastMeetingEndpoint = ep;
                lastMeetingBody     = req.getBody();
                res.setStatusCode(meetingStatus);
                res.setBody(meetingBody);
                return res;
            }
            res.setStatusCode(userLookupStatus);
            res.setBody(userLookupStatus == 200
                ? '{"id":"lookedUpZoomId1234567","email":"found@x.com","type":2}'
                : '{"code":1001,"message":"User does not exist"}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HAPPY PATH
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void createsMeetingUnderResolvedHostNotMe() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'kristi@johnsonturner.com', Zoom_User_Id__c = 'kristiZoomId000000AAA');

        ZoomMock mock = new ZoomMock(201, meetingBody());
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success,
            'Expected success. errorMessage was: ' + results[0].errorMessage);
        System.assertEquals('https://zoom.us/j/123456789', results[0].joinUrl);
        System.assertEquals('hostZoomId0000000000AA', results[0].hostId, 'host_id must be captured');
        System.assertEquals('kristi@johnsonturner.com', results[0].hostEmail, 'host_email must be captured');

        System.assert(mock.lastMeetingEndpoint.contains('kristiZoomId000000AAA'),
            'Meeting must be created under the resolved host. Was: ' + mock.lastMeetingEndpoint);
        System.assert(!mock.lastMeetingEndpoint.contains('/users/me/'),
            'Endpoint must never target "me".');
        System.assert(!mock.lastMeetingBody.contains('alternative_hosts'),
            'No other users should be added to the meeting.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EMAIL FALLBACK
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void resolvesZoomIdByEmailWhenFieldBlank() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'kelly.hurley@johnsonturner.com', Zoom_User_Id__c = null);

        ZoomMock mock = new ZoomMock(201, meetingBody());
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Expected success. errorMessage was: ' + results[0].errorMessage);
        System.assert(mock.lastMeetingEndpoint.contains('lookedUpZoomId1234567'),
            'A blank Zoom Id must be resolved by email lookup. Was: ' + mock.lastMeetingEndpoint);
    }

    @IsTest
    static void failsWhenEmailLookupFinsNothing() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'nobody@johnsonturner.com', Zoom_User_Id__c = null);

        ZoomMock mock = new ZoomMock(201, meetingBody());
        mock.userLookupStatus = 404;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(null, mock.lastMeetingEndpoint,
            'No meeting may be created when the host cannot be resolved.');
        System.assert(
            [SELECT COUNT() FROM Zoom_Integration_Error__c WHERE Apex_Class__c = 'ZoomCreateMeetingAction'] > 0,
            'A failed lookup must be logged, not swallowed.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEVER "me"
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void unresolvableHostFailsRatherThanUsingMe() {
        ZoomCreateMeetingAction.testConfig = config(null);

        ZoomMock mock = new ZoomMock(201, meetingBody());
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Must fail when no host resolves.');
        System.assertNotEquals(null, results[0].errorMessage);
        System.assertEquals(null, mock.lastMeetingEndpoint,
            'No meeting may be created when no host can be resolved.');
    }

    @IsTest
    static void groupIdIsNotTreatedAsAHost() {
        // A queue Id in the default host slot must be skipped, not sent to Zoom.
        ZoomCreateMeetingAction.testConfig = config('00G5w0000049t2oEAA');

        ZoomMock mock = new ZoomMock(201, meetingBody());
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'A group cannot host a Zoom meeting.');
        System.assertEquals(null, mock.lastMeetingEndpoint);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PAYLOAD
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void joinExperienceLetsAttendeesInWithoutTheHost() {
        Map<String, Object> payload = ZoomCreateMeetingAction.buildZoomPayload('Consult', 30, null);
        Map<String, Object> settings = (Map<String, Object>) payload.get('settings');

        System.assertEquals(true,  settings.get('join_before_host'),
            'Attendees must not be stuck on a wait screen.');
        System.assertEquals(false, settings.get('waiting_room'),
            'Waiting room and join before host are mutually exclusive in Zoom.');
        System.assertEquals(0, settings.get('jbh_time'));
    }

    @IsTest
    static void preservesUniqueMeetingType() {
        Map<String, Object> payload = ZoomCreateMeetingAction.buildZoomPayload('Consult', 45, null);
        System.assertEquals(3,  payload.get('type'), 'Per consult unique meeting type must not change.');
        System.assertEquals(45, payload.get('duration'));
    }

    @IsTest
    static void defaultsDurationWhenNotSupplied() {
        Map<String, Object> payload = ZoomCreateMeetingAction.buildZoomPayload('Consult', 30, null);
        System.assertEquals(30, payload.get('duration'));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FAILURE PATHS
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void tokenFailureReportsEveryRequest() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'a@b.com', Zoom_User_Id__c = 'zoomId000000000000AAA');

        ZoomMock mock = new ZoomMock(201, meetingBody());
        mock.tokenStatus = 401;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(new List<ZoomCreateMeetingAction.ActionRequest>{
                req('One'), req('Two')
            });
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Every request must get a result.');
        for (ZoomCreateMeetingAction.ActionResult r : results) {
            System.assertEquals(false, r.success);
            System.assert(r.errorMessage.contains('Could not connect to Zoom'), r.errorMessage);
        }
    }

    @IsTest
    static void meetingApiErrorIsReportedAndLogged() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'a@b.com', Zoom_User_Id__c = 'zoomId000000000000AAA');

        Test.setMock(HttpCalloutMock.class,
            new ZoomMock(400, '{"code":300,"message":"Invalid request body."}'));

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('400'), results[0].errorMessage);
        System.assertEquals(1,
            [SELECT COUNT() FROM Zoom_Integration_Error__c WHERE Apex_Class__c = 'ZoomCreateMeetingAction'],
            'API failures must be written to the error log, not swallowed.');
    }

    @IsTest
    static void missingJoinUrlIsTreatedAsFailure() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'a@b.com', Zoom_User_Id__c = 'zoomId000000000000AAA');

        Test.setMock(HttpCalloutMock.class, new ZoomMock(201, '{"id":999}'));

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('Consult')));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('no join_url'), results[0].errorMessage);
    }

    @IsTest
    static void blankTopicIsRejected() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'a@b.com', Zoom_User_Id__c = 'zoomId000000000000AAA');
        Test.setMock(HttpCalloutMock.class, new ZoomMock(201, meetingBody()));

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(one(req('')));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('Meeting Topic is required'), results[0].errorMessage);
    }

    @IsTest
    static void emptyRequestListReturnsEmpty() {
        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(new List<ZoomCreateMeetingAction.ActionRequest>());
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ALTERNATIVE HOSTS — the assigned CES must be able to start the meeting
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void poolMembersBecomeAlternativeHosts() {
        ZoomCreateMeetingAction.testConfig   = config(null);
        ZoomCreateMeetingAction.testHostUser =
            new User(Email = 'chris@johnsonturner.com', Zoom_User_Id__c = 'chrisZoomId00000000AA');
        ZoomCreateMeetingAction.testAlternativeHosts =
            'kristi@johnsonturner.com;denise@johnsonturner.com;anne@johnsonturner.com;kelly.hurley@johnsonturner.com';

        ZoomCreateMeetingAction.ActionRequest r = req('Consult');
        r.hostPoolGroupId = '00G5w0000049t2oEAA';

        ZoomMock mock = new ZoomMock(201, meetingBody());
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>{ r });
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Expected success. errorMessage was: ' + results[0].errorMessage);
        System.assert(mock.lastMeetingBody.contains('alternative_hosts'),
            'Pool members must be alternative hosts so the assigned CES can start the meeting.');
        System.assert(mock.lastMeetingBody.contains('kristi@johnsonturner.com'),
            'Every pool member must be able to start it.');
        System.assert(mock.lastMeetingBody.contains('kelly.hurley@johnsonturner.com'),
            'Every pool member must be able to start it.');
        System.assert(mock.lastMeetingBody.contains('"alternative_hosts_email_notification":false'),
            'Pool members must not be emailed about meetings they were not assigned.');
    }

    @IsTest
    static void noPoolMeansNoAlternativeHosts() {
        System.assertEquals(null,
            ZoomCreateMeetingAction.resolveAlternativeHosts(null, null),
            'No group means no alternative hosts.');
        System.assertEquals(null,
            ZoomCreateMeetingAction.resolveAlternativeHosts('005000000000001', null),
            'A user Id is not a group and must not be queried as one.');
    }
}