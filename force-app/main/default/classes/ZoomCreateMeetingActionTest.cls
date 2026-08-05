@IsTest
private class ZoomCreateMeetingActionTest {

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK — HAPPY PATH (1 token + N meetings)
    // ─────────────────────────────────────────────────────────────────────────

    private class SuccessMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Callout 1 siempre es el token OAuth
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"fake_token_abc123"}');
            } else {
                // Callouts 2+ son las meetings
                res.setStatusCode(201);
                res.setBody('{"join_url":"https://zoom.us/j/123456789","id":123456789}');
            }

            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK — TOKEN FAILURE
    // ─────────────────────────────────────────────────────────────────────────

    private class TokenFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"invalid_client"}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK — MEETING API FAILURE (token OK + meeting falla)
    // ─────────────────────────────────────────────────────────────────────────

    private class MeetingFailMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"fake_token_abc123"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"code":300,"message":"Invalid parameter."}');
            }

            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK — NO JOIN_URL (token OK + meeting 201 pero sin join_url)
    // ─────────────────────────────────────────────────────────────────────────

    private class NoUrlMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"fake_token_abc123"}');
            } else {
                res.setStatusCode(201);
                res.setBody('{"id":123456789}'); // sin join_url
            }

            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER — inyectar ZoomConfig__mdt fake
    // ─────────────────────────────────────────────────────────────────────────

    private static void injectConfig() {
        ZoomCreateMeetingAction.testConfig = new ZoomConfig__mdt(
            AccountId__c    = 'fake_account_id',
            ClientId__c     = 'fake_client_id',
            ClientSecret__c = 'fake_client_secret'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1 — Happy path: devuelve joinUrl y success = true
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_Success() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
        req.topic    = 'Consultation - Johnson Turner Legal';
        req.duration = 45;

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Debe retornar exactamente un resultado');
        Assert.isTrue(results[0].success, 'success debe ser true');
        Assert.areEqual('https://zoom.us/j/123456789', results[0].joinUrl, 'joinUrl debe coincidir');
        Assert.isNull(results[0].errorMessage, 'errorMessage debe ser null en happy path');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2 — Duration por defecto: si no se pasa, usa 30 minutos
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_DefaultDuration() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
        req.topic = 'Meeting sin duration';

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success, 'Debe ser exitoso aunque no se pase duration');
        Assert.isNotNull(results[0].joinUrl, 'joinUrl no debe ser null');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3 — Bulk: 1 token + 3 meetings
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_Bulk() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        List<ZoomCreateMeetingAction.ActionRequest> reqs =
            new List<ZoomCreateMeetingAction.ActionRequest>();

        for (Integer i = 0; i < 3; i++) {
            ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
            req.topic    = 'Meeting ' + i;
            req.duration = 30;
            reqs.add(req);
        }

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(reqs);
        Test.stopTest();

        // SuccessMock: callout 1 = token, callouts 2-4 = meetings
        Assert.areEqual(3, results.size(), 'Debe retornar un resultado por cada request');
        for (ZoomCreateMeetingAction.ActionResult r : results) {
            Assert.isTrue(r.success, 'Todos deben ser exitosos');
            Assert.isNotNull(r.joinUrl, 'joinUrl no debe ser null');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4 — Lista vacía: retorna lista vacía sin hacer callouts
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_EmptyList() {
        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>()
            );
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Lista vacía debe retornar lista vacía');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5 — Topic en blanco: success = false, sin hacer callout a Zoom
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_BlankTopic() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
        req.topic = '';

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success, 'success debe ser false con topic vacío');
        Assert.isTrue(
            results[0].errorMessage.contains('Meeting Topic is required'),
            'errorMessage debe indicar que el topic es requerido'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6 — Token falla: todos los requests quedan como failed
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_TokenFailure() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new TokenFailMock());

        List<ZoomCreateMeetingAction.ActionRequest> reqs =
            new List<ZoomCreateMeetingAction.ActionRequest>();

        for (Integer i = 0; i < 2; i++) {
            ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
            req.topic = 'Meeting ' + i;
            reqs.add(req);
        }

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(reqs);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Debe retornar un resultado por cada request');
        for (ZoomCreateMeetingAction.ActionResult r : results) {
            Assert.isFalse(r.success, 'Todos deben ser false si el token falla');
            Assert.isTrue(
                r.errorMessage.contains('Failed to obtain Zoom access token'),
                'errorMessage debe indicar fallo en el token'
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7 — Meeting API devuelve 400: success = false
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_MeetingApiFailure() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new MeetingFailMock());

        ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
        req.topic = 'Test Meeting';

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success, 'success debe ser false con error 400');
        Assert.isTrue(
            results[0].errorMessage.contains('Zoom API error 400'),
            'errorMessage debe indicar el error 400'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8 — Meeting responde 201 pero sin join_url: success = false
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateMeeting_NoJoinUrl() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new NoUrlMock());

        ZoomCreateMeetingAction.ActionRequest req = new ZoomCreateMeetingAction.ActionRequest();
        req.topic = 'Test Meeting';

        Test.startTest();
        List<ZoomCreateMeetingAction.ActionResult> results =
            ZoomCreateMeetingAction.createMeeting(
                new List<ZoomCreateMeetingAction.ActionRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success, 'success debe ser false si no viene join_url');
        Assert.isTrue(
            results[0].errorMessage.contains('no join_url was returned'),
            'errorMessage debe indicar ausencia de join_url'
        );
    }
}