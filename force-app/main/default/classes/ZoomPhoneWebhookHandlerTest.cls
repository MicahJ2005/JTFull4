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
        // Force the blank-secret path deterministically via the override (empty, not null - null
        // would fall through to the real org record, which is expected to hold a real secret once
        // the webhook is actually configured, not blank) rather than relying on
        // ZoomConfig__mdt.Webhook_Secret_Token__c happening to be unset in whatever org this runs in.
        ZoomPhoneWebhookHandler.testSecretTokenOverride = '';

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
                'object' => new Map<String, Object>{
                    'recordings' => new List<Object>{
                        new Map<String, Object>{ 'id' => 'rec1', 'call_id' => '12345' }
                    }
                }
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
                'object' => new Map<String, Object>{
                    'recordings' => new List<Object>{
                        new Map<String, Object>{ 'id' => 'rec1', 'call_id' => '12345' }
                    }
                }
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
    static void testProcessesMultipleRecordingsInOneEvent() {
        // payload.object.recordings is a list - a single event has only ever been observed
        // carrying one entry, but this proves every entry present gets processed, not just the
        // first one. Exercises the queueable's chaining directly (rather than through
        // handlePost's own enqueueJob) since Apex test context only allows one real
        // System.enqueueJob to be drained by Test.stopTest() per test method - see the identical
        // note on the scan/build queueable tests in ZoomPhoneIntegrationTest.
        Test.setMock(HttpCalloutMock.class, new ZoomTokenMock());

        List<ZoomPhoneWebhookQueueable.RecordingRef> refs = new List<ZoomPhoneWebhookQueueable.RecordingRef>{
            new ZoomPhoneWebhookQueueable.RecordingRef('rec1', '12345'),
            new ZoomPhoneWebhookQueueable.RecordingRef('rec2', '67890')
        };

        Test.startTest();
        new ZoomPhoneWebhookQueueable(refs, 0).execute(null);
        Test.stopTest();

        List<Zoom_Integration_Error__c> logRecords = [
            SELECT Recording_Id__c, Zoom_Meeting_Id__c FROM Zoom_Integration_Error__c ORDER BY Recording_Id__c
        ];
        System.assertEquals(2, logRecords.size(), 'Both recordings in the event should have been processed');
        System.assertEquals('rec1', logRecords[0].Recording_Id__c);
        System.assertEquals('12345', logRecords[0].Zoom_Meeting_Id__c);
        System.assertEquals('rec2', logRecords[1].Recording_Id__c);
        System.assertEquals('67890', logRecords[1].Zoom_Meeting_Id__c);
    }

    private class RecordingCompletedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains('/voicecalls')) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(201);
                ZoomPhoneIntegration.CallResponse mockCall = new ZoomPhoneIntegration.CallResponse();
                mockCall.externalId = '12345';
                mockCall.voiceCallId = '67890';
                mockCall.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
                mockCall.isSuccess = true;
                res.setBody(JSON.serialize(new Map<String, Object>{ 'calls' => new List<Object>{ mockCall } }));
                return res;
            }
            if (endpoint.contains('upload')) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(204);
                return res;
            }
            HttpResponse fallback = new HttpResponse(); fallback.setStatusCode(404); fallback.setBody('Unknown endpoint');
            return fallback;
        }
    }

    @isTest
    static void testHandlePostEnqueuesRecordingCompletedEvent() {
        Test.setMock(HttpCalloutMock.class, new RecordingCompletedMock());
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_completed',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'recordings' => new List<Object>{
                        new Map<String, Object>{
                            'call_id' => '12345',
                            'date_time' => '2026-09-14T16:51:51Z',
                            'end_time' => '2026-09-14T16:54:05Z',
                            'direction' => 'outbound',
                            'caller_number' => '8984',
                            'callee_number' => '+16127241972',
                            'download_url' => 'https://zoom.us/v2/phone/recording/download/rec1'
                        }
                    }
                }
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
        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'A fully successful recording_completed should log nothing');
    }

    @isTest
    static void testHandlePostLogsRecordingCompletedMissingCallId() {
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_completed',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'recordings' => new List<Object>{ new Map<String, Object>{ 'date_time' => '2026-09-14T16:51:51Z' } }
                }
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
        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Method__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size());
        System.assertEquals('handlePost', errors[0].Apex_Method__c);
    }

    @isTest
    static void testRecordingCompletedQueueableProcessesMultipleRecordings() {
        Test.setMock(HttpCalloutMock.class, new RecordingCompletedMock());

        List<ZoomPhoneRecordingWebhookQueueable.RecordingCompletedRef> refs =
            new List<ZoomPhoneRecordingWebhookQueueable.RecordingCompletedRef>{
                new ZoomPhoneRecordingWebhookQueueable.RecordingCompletedRef(
                    new Map<String, Object>{
                        'call_id' => '111', 'date_time' => '2026-09-14T16:51:51Z', 'end_time' => '2026-09-14T16:54:05Z',
                        'direction' => 'outbound', 'caller_number' => '8984', 'callee_number' => '+16127241972',
                        'download_url' => 'https://zoom.us/v2/phone/recording/download/rec1'
                    }, '111'
                ),
                new ZoomPhoneRecordingWebhookQueueable.RecordingCompletedRef(
                    new Map<String, Object>{
                        'call_id' => '222', 'date_time' => '2026-09-14T16:51:51Z', 'end_time' => '2026-09-14T16:54:05Z',
                        'direction' => 'inbound', 'caller_number' => '+16127241972', 'callee_number' => '8984',
                        'download_url' => 'https://zoom.us/v2/phone/recording/download/rec2'
                    }, '222'
                )
            };

        Test.startTest();
        new ZoomPhoneRecordingWebhookQueueable(refs, 0).execute(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'Both recordings should have processed successfully');
    }

    @isTest
    static void testIgnoresUnhandledEventType() {
        ZoomPhoneWebhookHandler.testSecretTokenOverride = 'unit-test-secret';

        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_something_else_unhandled',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'recordings' => new List<Object>{
                        new Map<String, Object>{ 'id' => 'rec1', 'call_id' => '12345' }
                    }
                }
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

        // No recordings array at all, and an entry missing call_id - neither should produce a
        // usable RecordingRef.
        String body = JSON.serialize(new Map<String, Object>{
            'event' => 'phone.recording_transcript_completed',
            'payload' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'recordings' => new List<Object>{
                        new Map<String, Object>{ 'id' => 'rec1' }
                    }
                }
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
        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Method__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size());
        System.assertEquals('handlePost', errors[0].Apex_Method__c);
    }
}