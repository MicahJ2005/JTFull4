@isTest
private class ZoomPhoneWebhookHandlerTest {

    private class ZoomTokenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token": "mockZoomToken123"}');
            return res;
        }
    }

    private static RestRequest buildRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/zoomPhoneWebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        return req;
    }

    @isTest
    static void testComputeAndValidateSignatureRoundTrip() {
        // Pure crypto check, independent of any org config - a valid signature computed with the
        // same secret should validate, and a tampered one (or the wrong secret) should not.
        String secret = 'unit-test-secret';
        String body = '{"event":"phone.recording_transcript_completed"}';
        String timestamp = '1700000000';

        String signature = ZoomPhoneWebhookHandler.computeSignature(body, timestamp, secret, true);

        System.assert(ZoomPhoneWebhookHandler.isValidSignature(body, timestamp, signature, secret));
        System.assert(!ZoomPhoneWebhookHandler.isValidSignature(body, timestamp, 'v0=wrong', secret));
        System.assert(!ZoomPhoneWebhookHandler.isValidSignature(body, timestamp, signature, 'different-secret'));
        System.assert(!ZoomPhoneWebhookHandler.isValidSignature(body, timestamp, signature, null));
    }

    @isTest
    static void testMalformedJsonBodyReturns400() {
        RestRequest req = buildRequest('not json');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testUrlValidationHandshake() {
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'endpoint.url_validation',
            'payload' => new Map<String, Object>{ 'plainToken' => 'abc123' }
        });

        RestRequest req = buildRequest(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals('abc123', responseBody.get('plainToken'));
        System.assertNotEquals(null, responseBody.get('encryptedToken'));
    }

    @isTest
    static void testUrlValidationFailsClosedWithoutSecretConfigured() {
        // testSecretTokenOverride left null here - falls through to the real (currently blank in
        // a freshly deployed org) ZoomConfig__mdt.Webhook_Secret_Token__c, which must fail closed
        // rather than validate against a blank key.
        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'endpoint.url_validation',
            'payload' => new Map<String, Object>{ 'plainToken' => 'abc123' }
        });

        RestRequest req = buildRequest(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testRejectsInvalidSignature() {
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_transcript_completed',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{ 'id' => 'rec1', 'call_id' => '12345' }
            }
        });

        RestRequest req = buildRequest(body);
        req.headers.put('x-zm-signature', 'v0=not-a-real-signature');
        req.headers.put('x-zm-request-timestamp', '1700000000');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'A rejected request should never reach any processing logic');
    }

    @isTest
    static void testAcceptsValidSignatureAndSchedulesRetryWhenVoiceCallMissing() {
        // No VoiceCall can be created via DML in a test (it's only populated by Salesforce's real
        // Voice API - see the note in ZoomPhoneIntegrationTest), so the "found, transcript
        // attached" path can't be exercised here. This instead verifies the routine case given the
        // 60-90 minute lag on the metadata poll: the webhook arrives before its VoiceCall exists
        // yet, and that should be scheduled as a retry rather than dropped.
        Test.setMock(HttpCalloutMock.class, new ZoomTokenMock());
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_transcript_completed',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{ 'id' => 'rec1', 'call_id' => '12345' }
            }
        });
        String timestamp = '1700000000';
        String signature = ZoomPhoneWebhookHandler.computeSignature(body, timestamp, 'unit-test-secret', true);

        RestRequest req = buildRequest(body);
        req.headers.put('x-zm-signature', signature);
        req.headers.put('x-zm-request-timestamp', timestamp);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        Zoom_Integration_Error__c logRecord = [
            SELECT Error_Type__c, Recording_Id__c, Zoom_Meeting_Id__c, Resolved__c, Retry_Count__c
            FROM Zoom_Integration_Error__c LIMIT 1
        ];
        System.assertEquals('Voice Call Not Found', logRecord.Error_Type__c);
        System.assertEquals('rec1', logRecord.Recording_Id__c);
        System.assertEquals('12345', logRecord.Zoom_Meeting_Id__c);
        System.assertEquals(false, logRecord.Resolved__c);
        System.assertEquals(0, logRecord.Retry_Count__c);
    }

    @isTest
    static void testIgnoresUnhandledEventType() {
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_completed',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{ 'id' => 'rec1', 'call_id' => '12345' }
            }
        });
        String timestamp = '1700000000';
        String signature = ZoomPhoneWebhookHandler.computeSignature(body, timestamp, 'unit-test-secret', true);

        RestRequest req = buildRequest(body);
        req.headers.put('x-zm-signature', signature);
        req.headers.put('x-zm-request-timestamp', timestamp);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c]);
    }

    @isTest
    static void testMissingPayloadObjectFieldsLogsError() {
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_transcript_completed',
            'payload' => new Map<String, Object>{ 'object' => new Map<String, Object>() }
        });
        String timestamp = '1700000000';
        String signature = ZoomPhoneWebhookHandler.computeSignature(body, timestamp, 'unit-test-secret', true);

        RestRequest req = buildRequest(body);
        req.headers.put('x-zm-signature', signature);
        req.headers.put('x-zm-request-timestamp', timestamp);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ZoomPhoneWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Method__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size());
        System.assertEquals('handlePost', errors[0].Apex_Method__c);
    }
}
