@isTest
private class ZoomPhoneIntegrationTest {
	
    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Email = 'testuser@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            Phone = '1234567890'
        );
        insert testUser;

        insert new Account(Name='Mock Account', Phone='1234567890');
        insert new Lead(LastName='Mock Lead', Phone='1234567890');
    }
	
    // Mock class for the Zoom OAuth token request
    private class ZoomTokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token": "mockZoomToken123"}');
            return res;
        }
    }
	
    // Mock class for the Zoom call history API
    private class ZoomCallHistoryMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"call_logs": [{"start_time": "2024-02-12T12:00:00Z", "duration": 300, "direction": "inbound", "callee_ext_id" : "1234", "callee_name" : "Test User"}]}');
            return res;
        }
    }
    
    // Mock class for the Salesforce API call
     private class SalesforceApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            
            // Correctly structured JSON response with "calls" array
            List<ZoomPhoneIntegration.CallResponse> mockResponses = new List<ZoomPhoneIntegration.CallResponse>();
            
            // Create a sample CallResponse object
            ZoomPhoneIntegration.CallResponse mockCall = new ZoomPhoneIntegration.CallResponse();
            mockCall.externalId = '12345';
            mockCall.voiceCallId = '67890';
            mockCall.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
            mockCall.isSuccess = true;
            mockCall.errorMsg = null;
            
            mockResponses.add(mockCall);

            // Construct JSON response
            Map<String, Object> jsonResponse = new Map<String, Object>();
            jsonResponse.put('calls', mockResponses);
            
            // Convert to JSON
            res.setBody(JSON.serialize(jsonResponse));
            return res;
        }
    }
    
    private class FetchRecordingsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            List<Map<String, Object>> recordings = new List<Map<String, Object>>{
                new Map<String, Object>{
                    'id' => 'rec1',
                    'call_id' => '12345',
                    'Transcript_Text__c' => 'Testing text',
                    'Transcript_Sequence__c' => '1',
                    'download_url' => 'https://zoom.us/recordings/abc123'
                }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'recordings' => recordings }));
            return res;
        }
    }

    private class UploadRecordingsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(204);
            return res;
        }
    }

    private class UploadRecordingsFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('Upload failed');
            return res;
        }
    }

    private class FetchTranscriptMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('recording_transcript/download/')) {
                res.setStatusCode(302);
                res.setHeader('location', 'https://zoom-redirected-transcript.com/mock-transcript.txt');
            } else if (req.getEndpoint().contains('zoom-redirected-transcript.com')) {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'timeline' => new List<Object>{
                        new Map<String, Object>{ 'userId' => '1234567890', 'text' => 'Hello there!' }
                    }
                }));
            } else {
                res.setStatusCode(404);
                res.setBody('Endpoint not recognized in mock.');
            }
            return res;
        }
    }

    // Same shape as FetchTranscriptMock's redirect, but the final hop returns Zoom error 12002
    // ("still being transcribed") instead of a transcript, so the audio upload path is left
    // untouched (returns 204) and only the transcript fetch fails.
    private class TranscriptStillProcessingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            if (endpoint.contains('recording_transcript/download/')) {
                res.setStatusCode(302);
                res.setHeader('location', 'https://zoom-redirected-transcript.com/mock-transcript.txt');
            } else if (endpoint.contains('zoom-redirected-transcript.com')) {
                res.setStatusCode(400);
                res.setBody('{"code":12002,"message":"This recording is still in the process of being transcribed. Reopen this recording in a few minutes."}');
            } else if (endpoint.contains('upload')) {
                res.setStatusCode(204);
            } else {
                res.setStatusCode(404);
                res.setBody('Endpoint not recognized in mock.');
            }
            return res;
        }
    }

    private class MultiCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains('oauth/token')) return new ZoomTokenMock().respond(req);
            if (endpoint.contains('call_history')) return new ZoomCallHistoryMock().respond(req);
            if (endpoint.contains('/voicecalls')) return new SalesforceApiMock().respond(req);
            if (endpoint.contains('/recordings')) return new FetchRecordingsMock().respond(req);
            if (endpoint.contains('upload')) return new UploadRecordingsMock().respond(req);
            if (endpoint.contains('recording_transcript/download') || endpoint.contains('zoom-redirected-transcript.com')) return new FetchTranscriptMock().respond(req);
            HttpResponse fallback = new HttpResponse(); fallback.setStatusCode(404); fallback.setBody('Unknown endpoint');
            return fallback;
        }
    }

    // Same as MultiCalloutMock but with zero recordings, so processRecordings() returns before
    // ever calling System.enqueueJob - used to exercise steps 1-4 of the sync without touching
    // the per-recording chain at all.
    private class MultiCalloutMockNoRecordings implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains('oauth/token')) return new ZoomTokenMock().respond(req);
            if (endpoint.contains('call_history')) return new ZoomCallHistoryMock().respond(req);
            if (endpoint.contains('/voicecalls')) return new SalesforceApiMock().respond(req);
            if (endpoint.contains('/recordings')) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{ 'recordings' => new List<Object>() }));
                return res;
            }
            HttpResponse fallback = new HttpResponse(); fallback.setStatusCode(404); fallback.setBody('Unknown endpoint');
            return fallback;
        }
    }

    // Apex tests only allow one real System.enqueueJob call to be drained by Test.stopTest()
    // per test method - a second one (even nested inside the first job's execute()) throws
    // "Maximum stack depth has been reached". So the full future/queueable/queueable/queueable
    // chain can't be exercised end-to-end in one test; instead each hop is tested by calling
    // execute() directly as a plain method (which doesn't touch that budget) and only letting
    // stopTest() drain the one real chain transition that remains within a given test.

    @isTest
    static void testSchedulableExecuteRunsSyncAndRetryPass() {
        // Exercises the Schedulable entry point itself (execute -> sendZoomDataToSalesforce +
        // retryPendingTranscripts), which the other tests below bypass by calling the static
        // sync/retry methods directly.
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMockNoRecordings());
        Test.startTest();
        new ZoomPhoneIntegration().execute(null);
        Test.stopTest();
    }

    @isTest
    static void testZoomPhoneIntegrationQueueableExecute() {
        // Exercises steps 1-4 (token, call history, transform, metadata push) with real callouts.
        // The mock returns zero recordings so processRecordings() returns before calling
        // System.enqueueJob, keeping this test isolated from the per-recording chain (which is
        // covered separately below).
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMockNoRecordings());
        new ZoomPhoneIntegrationQueueable().execute(null);
    }

    // Call_Transcript__c.Voice_Call__c is a required lookup to the standard VoiceCall object,
    // which isn't createable via DML (it's only populated by Salesforce's real Voice API) - so
    // there's no way to build a real VoiceCall in a test and no way to assert that the final
    // upsert actually persists a row. Instead, the per-recording logic is verified directly
    // against its in-memory return value below, and the queueable wrappers are smoke-tested for
    // exceptions rather than DB side effects.

    @isTest
    static void testScanRecordingForPhoneNumbersCollectsPhoneData() {
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };
        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.isSuccess = true;
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{ '12345' => resp };

        Set<String> setPhoneFormats = new Set<String>();
        Set<String> setPhoneExtensions = new Set<String>();

        ZoomPhoneIntegration.scanRecordingForPhoneNumbers(recording, 'mockToken', responseMap, setPhoneFormats, setPhoneExtensions);

        System.assert(!setPhoneFormats.isEmpty(), 'Expected the 10-digit userId from the mocked timeline to produce phone formats');
    }

    @isTest
    static void testBuildTranscriptForRecordingReturnsTranscriptText() {
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };
        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.isSuccess = true;
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{ '12345' => resp };

        List<Call_Transcript__c> result = ZoomPhoneIntegration.buildTranscriptForRecording(
            recording, 'mockToken', responseMap, new Map<String, Account>(), new Map<String, Lead>(), new Map<String, User>()
        );

        System.assertEquals(1, result.size(), 'Expected one transcript chunk built from the mocked timeline');
        System.assert(result[0].Transcript_Text__c.contains('Hello there!'), 'Transcript text should come from the mocked timeline');
    }

    @isTest
    static void testZoomPhoneRecordingScanQueueableExecute() {
        // Scans one recording directly, then calling execute() a second time (rather than
        // relying on Test.stopTest() to drain the chained enqueueJob) exercises the build phase
        // without depending on Apex's test-only async chaining budget.
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };
        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.isSuccess = true;
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{ '12345' => resp };

        ZoomPhoneRecordingScanQueueable scanJob = new ZoomPhoneRecordingScanQueueable(
            'mockToken', new List<Map<String, Object>>{ recording }, 0,
            responseMap, new Set<String>(), new Set<String>(), false
        );

        scanJob.execute(null);

        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Class__c, Apex_Method__c, Error_Message__c FROM Zoom_Integration_Error__c];
        System.assertEquals(0, errors.size(), 'Scan phase should complete without logging any errors for a successful callout');
    }

    @isTest
    static void testZoomPhoneTranscriptBuildQueueableExecute() {
        // A single recording never needs to chain to another build job, so calling execute()
        // directly here never touches System.enqueueJob at all.
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };
        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.isSuccess = true;
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{ '12345' => resp };

        ZoomPhoneTranscriptBuildQueueable buildJob = new ZoomPhoneTranscriptBuildQueueable(
            'mockToken', new List<Map<String, Object>>{ recording }, 0,
            responseMap, new Map<String, Account>(), new Map<String, Lead>(), new Map<String, User>(),
            new List<Call_Transcript__c>(), false
        );

        buildJob.execute(null);

        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Class__c, Apex_Method__c, Error_Message__c FROM Zoom_Integration_Error__c];
        System.assertEquals(0, errors.size(), 'Build phase should complete without logging any errors for a successful callout');
    }

    @isTest
    static void testZoomPhoneRecordingScanQueueableLogsErrorAndContinues() {
        // A transcript-fetch failure during the scan phase should be logged, not thrown, and
        // the scan should still hand off to the build phase for the rest of the batch.
        Test.setMock(HttpCalloutMock.class, new FailTranscriptMock());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };

        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.isSuccess = true;

        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{
            '12345' => resp
        };

        ZoomPhoneRecordingScanQueueable scanJob = new ZoomPhoneRecordingScanQueueable(
            'mockToken', new List<Map<String, Object>>{ recording }, 0,
            responseMap, new Set<String>(), new Set<String>(), false
        );

        scanJob.execute(null);

        List<Zoom_Integration_Error__c> errors = [SELECT Error_Type__c, Zoom_Meeting_Id__c, Apex_Method__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size(), 'Expected the transcript fetch failure to be logged');
        System.assertEquals('12345', errors[0].Zoom_Meeting_Id__c);
        System.assertEquals('execute', errors[0].Apex_Method__c);
    }

    private class MultiCalloutMockUploadFails implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains('oauth/token')) return new ZoomTokenMock().respond(req);
            if (endpoint.contains('call_history')) return new ZoomCallHistoryMock().respond(req);
            if (endpoint.contains('/voicecalls')) return new SalesforceApiMock().respond(req);
            if (endpoint.contains('/recordings')) return new FetchRecordingsMock().respond(req);
            if (endpoint.contains('upload')) return new UploadRecordingsFailMock().respond(req);
            if (endpoint.contains('recording_transcript/download') || endpoint.contains('zoom-redirected-transcript.com')) return new FetchTranscriptMock().respond(req);
            HttpResponse fallback = new HttpResponse(); fallback.setStatusCode(404); fallback.setBody('Unknown endpoint');
            return fallback;
        }
    }

    @isTest
    static void testBuildTranscriptForRecordingSucceedsWhenUploadFails() {
        // A failed audio upload used to abort buildTranscriptForRecording entirely, losing a
        // transcript that would otherwise have fetched fine. Upload and transcript are
        // independent Zoom operations, so this asserts they're now handled independently too.
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMockUploadFails());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };
        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.isSuccess = true;
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{ '12345' => resp };

        Test.startTest();
        List<Call_Transcript__c> result = ZoomPhoneIntegration.buildTranscriptForRecording(
            recording, 'mockToken', responseMap, new Map<String, Account>(), new Map<String, Lead>(), new Map<String, User>()
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Transcript should still be built even though the audio upload failed');
        System.assert(result[0].Transcript_Text__c.contains('Hello there!'));

        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Method__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size(), 'Only the upload failure should be logged');
        System.assertEquals('uploadRecording', errors[0].Apex_Method__c);
    }

    @isTest
    static void testZoomPhoneTranscriptBuildQueueableLogsRetryableError() {
        // A 12002 failure surfacing through the build queueable's catch block should carry the
        // recording id and VoiceCall id needed for ZoomPhoneIntegration.retryPendingTranscripts
        // to pick it back up later, instead of being logged as a plain, unretryable failure.
        Test.setMock(HttpCalloutMock.class, new TranscriptStillProcessingMock());

        Map<String, Object> recording = new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'download_url' => 'https://zoom.us/recordings/abc123'
        };
        ZoomPhoneIntegration.CallResponse resp = new ZoomPhoneIntegration.CallResponse();
        resp.externalId = '12345';
        resp.uploadUrl = 'https://example.com/services/upload/VoiceCallRecording/123';
        resp.voiceCallId = '0Aa000000000001';
        resp.isSuccess = true;
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap = new Map<String, ZoomPhoneIntegration.CallResponse>{ '12345' => resp };

        ZoomPhoneTranscriptBuildQueueable buildJob = new ZoomPhoneTranscriptBuildQueueable(
            'mockToken', new List<Map<String, Object>>{ recording }, 0,
            responseMap, new Map<String, Account>(), new Map<String, Lead>(), new Map<String, User>(),
            new List<Call_Transcript__c>(), false
        );

        buildJob.execute(null);

        Zoom_Integration_Error__c error = [
            SELECT Error_Type__c, Recording_Id__c, Voice_Call_Id__c, Resolved__c
            FROM Zoom_Integration_Error__c LIMIT 1
        ];
        System.assertEquals('Transcript Not Ready', error.Error_Type__c);
        System.assertEquals('rec1', error.Recording_Id__c);
        System.assertEquals('0Aa000000000001', error.Voice_Call_Id__c);
        System.assertEquals(false, error.Resolved__c);
    }

    @isTest
    static void testProcessTranscriptRetrySucceeds() {
        Test.setMock(HttpCalloutMock.class, new FetchTranscriptMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'Test', Apex_Method__c = 'execute', Error_Type__c = 'Transcript Not Ready',
            Recording_Id__c = 'rec1', Voice_Call_Id__c = '0Aa000000000001',
            Retry_Count__c = 1, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processTranscriptRetry(retryRecord, 'mockToken');
        Test.stopTest();

        Zoom_Integration_Error__c updated = [SELECT Resolved__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id];
        System.assertEquals(true, updated.Resolved__c, 'A successful retry should mark the record resolved');
    }

    @isTest
    static void testProcessTranscriptRetryReschedulesOnStillProcessing() {
        Test.setMock(HttpCalloutMock.class, new TranscriptStillProcessingMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'Test', Apex_Method__c = 'execute', Error_Type__c = 'Transcript Not Ready',
            Recording_Id__c = 'rec1', Voice_Call_Id__c = '0Aa000000000001',
            Retry_Count__c = 0, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processTranscriptRetry(retryRecord, 'mockToken');
        Test.stopTest();

        Zoom_Integration_Error__c updated = [
            SELECT Resolved__c, Retry_Count__c, Next_Retry_At__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id
        ];
        System.assertEquals(false, updated.Resolved__c, 'Still processing should keep the retry pending');
        System.assertEquals(1, updated.Retry_Count__c);
        System.assert(updated.Next_Retry_At__c > Datetime.now(), 'Next attempt should be rescheduled into the future');

        // A failed retry attempt should update the same row, not also insert a second one - it
        // used to insert an extra plain error record on every failed attempt via
        // ZoomIntegrationErrorLogger.log, inflating the apparent number of distinct stuck calls.
        System.assertEquals(1, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'A failed retry should not create a second record');
    }

    @isTest
    static void testProcessTranscriptRetryGivesUpAfterMaxAttempts() {
        Test.setMock(HttpCalloutMock.class, new TranscriptStillProcessingMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'Test', Apex_Method__c = 'execute', Error_Type__c = 'Transcript Not Ready',
            Recording_Id__c = 'rec1', Voice_Call_Id__c = '0Aa000000000001',
            Retry_Count__c = 4, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processTranscriptRetry(retryRecord, 'mockToken');
        Test.stopTest();

        Zoom_Integration_Error__c updated = [SELECT Resolved__c, Retry_Count__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id];
        System.assertEquals(true, updated.Resolved__c, 'Should give up once MAX_TRANSCRIPT_RETRY_ATTEMPTS is reached');
        System.assertEquals(5, updated.Retry_Count__c);
    }

    @isTest
    static void testSendCallMetadataToECISkipsCallsWithNoExistingVoiceCall() {
        // No VoiceCall exists in test data (it can't be created via DML in a test - see the note
        // on testBuildTranscriptForRecordingReturnsTranscriptText), so this exercises the "nothing
        // to skip" branch of the new dedupe filter - a regression guard that it doesn't
        // accidentally drop calls that are genuinely new.
        Test.setMock(HttpCalloutMock.class, new SalesforceApiMock());

        Map<String, Object> call = new Map<String, Object>{
            'externalId' => '12345',
            'recordingDuration' => 300,
            'startDateTime' => '2024-02-12T12:00:00Z',
            'endDateTime' => '2024-02-12T12:05:00Z',
            'callType' => 'Inbound',
            'userId' => UserInfo.getUserId(),
            'toPhoneNumber' => '1234567890',
            'fromPhoneNumber' => '0987654321',
            'recordingFormat' => 'mp3',
            'mediaProviderId' => '123'
        };
        String jsonInput = JSON.serialize(new Map<String, Object>{ 'calls' => new List<Object>{ call } });

        Test.startTest();
        List<ZoomPhoneIntegration.CallResponse> responses = ZoomPhoneIntegration.sendCallMetadataToECI(jsonInput);
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'The call has no existing VoiceCall, so it should still be sent to the create endpoint');
    }

    private class RecordingCompletedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains('/voicecalls')) return new SalesforceApiMock().respond(req);
            if (endpoint.contains('upload')) return new UploadRecordingsMock().respond(req);
            HttpResponse fallback = new HttpResponse(); fallback.setStatusCode(404); fallback.setBody('Unknown endpoint');
            return fallback;
        }
    }

    private class RecordingCompletedUploadFailsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint.contains('/voicecalls')) return new SalesforceApiMock().respond(req);
            if (endpoint.contains('upload')) return new UploadRecordingsFailMock().respond(req);
            HttpResponse fallback = new HttpResponse(); fallback.setStatusCode(404); fallback.setBody('Unknown endpoint');
            return fallback;
        }
    }

    // Simulates the VoiceCalls bulk-create endpoint returning 201 overall (so sendCallBatchToECI
    // doesn't throw) while the individual call within the batch reports its own failure -
    // previously discarded silently with no logging anywhere.
    private class PerCallFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            ZoomPhoneIntegration.CallResponse mockCall = new ZoomPhoneIntegration.CallResponse();
            mockCall.externalId = '12345';
            mockCall.isSuccess = false;
            mockCall.errorMsg = 'DUPLICATE_EXTERNAL_ID';
            res.setBody(JSON.serialize(new Map<String, Object>{ 'calls' => new List<Object>{ mockCall } }));
            return res;
        }
    }

    private static Map<String, Object> buildRecordingCompletedPayload() {
        return new Map<String, Object>{
            'id' => 'rec1',
            'call_id' => '12345',
            'date_time' => '2026-09-14T16:51:51Z',
            'end_time' => '2026-09-14T16:54:05Z',
            'direction' => 'outbound',
            'caller_number' => '8984',
            'callee_number' => '+16127241972',
            'download_url' => 'https://zoom.us/v2/phone/recording/download/rec1',
            'owner' => new Map<String, Object>{ 'extension_number' => '8984' }
        };
    }

    @isTest
    static void testProcessWebhookRecordingCompletedCreatesVoiceCallAndUploadsAudio() {
        Test.setMock(HttpCalloutMock.class, new RecordingCompletedMock());

        Test.startTest();
        ZoomPhoneIntegration.processWebhookRecordingCompleted(buildRecordingCompletedPayload(), '12345');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'A fully successful recording_completed should log nothing');
    }

    @isTest
    static void testProcessWebhookRecordingCompletedLogsUploadFailureButStillSucceedsCreatingVoiceCall() {
        // Upload and VoiceCall creation are independent - a failed upload shouldn't be treated as
        // if the whole recording_completed event failed, matching the same decoupling already
        // applied to the polling path (buildTranscriptForRecording).
        Test.setMock(HttpCalloutMock.class, new RecordingCompletedUploadFailsMock());

        Test.startTest();
        ZoomPhoneIntegration.processWebhookRecordingCompleted(buildRecordingCompletedPayload(), '12345');
        Test.stopTest();

        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Method__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size());
        System.assertEquals('uploadRecording', errors[0].Apex_Method__c);
    }

    @isTest
    static void testProcessWebhookRecordingCompletedLogsPerCallCreationFailure() {
        // The VoiceCalls bulk-create endpoint can return 201 overall while an individual call in
        // the batch reports its own failure (isSuccess: false) - this used to be silently
        // discarded with no logging anywhere, which is exactly how a VoiceCall could fail to be
        // created with zero trace of why.
        Test.setMock(HttpCalloutMock.class, new PerCallFailureMock());

        Test.startTest();
        ZoomPhoneIntegration.processWebhookRecordingCompleted(buildRecordingCompletedPayload(), '12345');
        Test.stopTest();

        List<Zoom_Integration_Error__c> errors = [SELECT Apex_Method__c, Error_Message__c FROM Zoom_Integration_Error__c];
        System.assertEquals(1, errors.size(), 'A per-call creation failure should be logged, not silently discarded');
        System.assertEquals('processWebhookRecordingCompleted', errors[0].Apex_Method__c);
        System.assert(errors[0].Error_Message__c.contains('DUPLICATE_EXTERNAL_ID'), 'The per-call errorMsg should be captured for diagnosis');
    }

    @isTest
    static void testProcessWebhookRecordingCompletedSkipsShortCalls() {
        Map<String, Object> shortCall = buildRecordingCompletedPayload();
        shortCall.put('end_time', '2026-09-14T16:51:55Z'); // 4 seconds after date_time - under the 10s floor

        Test.startTest();
        ZoomPhoneIntegration.processWebhookRecordingCompleted(shortCall, '12345');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'Skipping a short call is not an error');
    }

    @isTest
    static void testProcessWebhookRecordingCompletedLogsMissingRequiredFields() {
        // A silent, unlogged skip here is exactly how a phone.recording_completed payload shape
        // mismatch would produce a VoiceCall that never gets created with no trace anywhere - this
        // must be logged (with the raw payload) rather than silently ignored.
        Map<String, Object> incomplete = new Map<String, Object>{ 'call_id' => '12345' };

        Test.startTest();
        ZoomPhoneIntegration.processWebhookRecordingCompleted(incomplete, '12345');
        Test.stopTest();

        List<Zoom_Integration_Error__c> errors = [
            SELECT Apex_Method__c, Error_Message__c, Error_Type__c, Resolved__c, Raw_Payload__c, Retry_Count__c
            FROM Zoom_Integration_Error__c
        ];
        System.assertEquals(1, errors.size(), 'Missing required fields should be logged, not silently skipped');
        System.assertEquals('processWebhookRecordingCompleted', errors[0].Apex_Method__c);
        System.assert(errors[0].Error_Message__c.contains('Missing required field'));

        // Retryable, unlike a generic ZoomIntegrationErrorLogger.log call - there's no VoiceCall
        // for a transcript retry to eventually find here, since creation itself never succeeded.
        System.assertEquals('Voice Call Creation Failed', errors[0].Error_Type__c);
        System.assertEquals(false, errors[0].Resolved__c);
        System.assertEquals(0, errors[0].Retry_Count__c);
        System.assertNotEquals(null, errors[0].Raw_Payload__c, 'The raw payload should be captured so a retry can rebuild the request');
    }

    @isTest
    static void testProcessVoiceCallCreationRetrySucceeds() {
        Test.setMock(HttpCalloutMock.class, new RecordingCompletedMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'ZoomPhoneIntegration', Apex_Method__c = 'processWebhookRecordingCompleted',
            Error_Type__c = 'Voice Call Creation Failed', Zoom_Meeting_Id__c = '12345',
            Raw_Payload__c = JSON.serialize(buildRecordingCompletedPayload()),
            Retry_Count__c = 1, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processVoiceCallCreationRetry(retryRecord);
        Test.stopTest();

        Zoom_Integration_Error__c updated = [SELECT Resolved__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id];
        System.assertEquals(true, updated.Resolved__c, 'A successful retry should mark the record resolved');
    }

    @isTest
    static void testProcessVoiceCallCreationRetryReschedulesOnFailure() {
        Test.setMock(HttpCalloutMock.class, new PerCallFailureMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'ZoomPhoneIntegration', Apex_Method__c = 'processWebhookRecordingCompleted',
            Error_Type__c = 'Voice Call Creation Failed', Zoom_Meeting_Id__c = '12345',
            Raw_Payload__c = JSON.serialize(buildRecordingCompletedPayload()),
            Retry_Count__c = 1, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processVoiceCallCreationRetry(retryRecord);
        Test.stopTest();

        Zoom_Integration_Error__c updated = [
            SELECT Resolved__c, Retry_Count__c, Next_Retry_At__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id
        ];
        System.assertEquals(false, updated.Resolved__c, 'A still-failing retry should stay pending until max attempts');
        System.assertEquals(2, updated.Retry_Count__c);
        System.assert(updated.Next_Retry_At__c > Datetime.now(), 'Next attempt should be rescheduled into the future');
    }

    @isTest
    static void testProcessVoiceCallCreationRetryGivesUpAfterMaxAttempts() {
        Test.setMock(HttpCalloutMock.class, new PerCallFailureMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'ZoomPhoneIntegration', Apex_Method__c = 'processWebhookRecordingCompleted',
            Error_Type__c = 'Voice Call Creation Failed', Zoom_Meeting_Id__c = '12345',
            Raw_Payload__c = JSON.serialize(buildRecordingCompletedPayload()),
            Retry_Count__c = 4, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processVoiceCallCreationRetry(retryRecord);
        Test.stopTest();

        Zoom_Integration_Error__c updated = [SELECT Resolved__c, Retry_Count__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id];
        System.assertEquals(true, updated.Resolved__c, 'Should give up once MAX_TRANSCRIPT_RETRY_ATTEMPTS is reached');
        System.assertEquals(5, updated.Retry_Count__c);
    }

    @isTest
    static void testRetryPendingVoiceCallCreationsProcessesDueRetries() {
        Test.setMock(HttpCalloutMock.class, new RecordingCompletedMock());

        Zoom_Integration_Error__c dueRetry = new Zoom_Integration_Error__c(
            Apex_Class__c = 'ZoomPhoneIntegration', Apex_Method__c = 'processWebhookRecordingCompleted',
            Error_Type__c = 'Voice Call Creation Failed', Zoom_Meeting_Id__c = '12345',
            Raw_Payload__c = JSON.serialize(buildRecordingCompletedPayload()),
            Retry_Count__c = 0, Next_Retry_At__c = Datetime.now().addMinutes(-5), Resolved__c = false
        );
        insert dueRetry;

        Test.startTest();
        ZoomPhoneIntegration.retryPendingVoiceCallCreations();
        Test.stopTest();

        Zoom_Integration_Error__c updated = [SELECT Resolved__c FROM Zoom_Integration_Error__c WHERE Id = :dueRetry.Id];
        System.assertEquals(true, updated.Resolved__c, 'The due retry should have been processed and resolved via the enqueued job');
    }

    @isTest
    static void testRetryPendingVoiceCallCreationsNoOpWhenNoneDue() {
        Test.startTest();
        ZoomPhoneIntegration.retryPendingVoiceCallCreations();
        Test.stopTest();
        // Nothing due, so no callout/job should be attempted - just asserting no exception here.
    }

    @isTest
    static void testProcessWebhookTranscriptReadyLogsRetryWhenVoiceCallMissing() {
        // No VoiceCall can be created via DML in a test, and this call id was never created by
        // the metadata poll either - so resolveVoiceCallId's lookup finds nothing, which is
        // exactly the routine case the webhook path has to handle given the 60-90 minute lag on
        // that poll versus Zoom usually finishing transcription within minutes.
        Test.startTest();
        ZoomPhoneIntegration.processWebhookTranscriptReady('rec1', '99999', 'mockToken');
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [
            SELECT Error_Type__c, Recording_Id__c, Zoom_Meeting_Id__c, Resolved__c, Retry_Count__c
            FROM Zoom_Integration_Error__c LIMIT 1
        ];
        System.assertEquals('Voice Call Not Found', logRecord.Error_Type__c);
        System.assertEquals('rec1', logRecord.Recording_Id__c);
        System.assertEquals('99999', logRecord.Zoom_Meeting_Id__c);
        System.assertEquals(false, logRecord.Resolved__c);
        System.assertEquals(0, logRecord.Retry_Count__c);
    }

    @isTest
    static void testProcessTranscriptRetryResolvesVoiceCallFromCallIdWhenBlank() {
        // Voice_Call_Id__c is blank here (as it would be for a retry row created by the webhook
        // path, which never had a VoiceCall to record in the first place) - processTranscriptRetry
        // should fall back to resolving it from Zoom_Meeting_Id__c (the call id) instead of
        // erroring on a missing id.
        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'Test', Apex_Method__c = 'execute', Error_Type__c = 'Voice Call Not Found',
            Recording_Id__c = 'rec1', Voice_Call_Id__c = null, Zoom_Meeting_Id__c = '12345',
            Retry_Count__c = 0, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        Test.startTest();
        ZoomPhoneIntegration.processTranscriptRetry(retryRecord, 'mockToken');
        Test.stopTest();

        Zoom_Integration_Error__c updated = [
            SELECT Resolved__c, Retry_Count__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id
        ];
        System.assertEquals(false, updated.Resolved__c, 'Should keep retrying while the VoiceCall still cannot be resolved');
        System.assertEquals(1, updated.Retry_Count__c);
    }

    @isTest
    static void testRetryPendingTranscriptsProcessesDueRetries() {
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());

        Zoom_Integration_Error__c dueRetry = new Zoom_Integration_Error__c(
            Apex_Class__c = 'Test', Apex_Method__c = 'execute', Error_Type__c = 'Transcript Not Ready',
            Recording_Id__c = 'rec1', Voice_Call_Id__c = '0Aa000000000001',
            Retry_Count__c = 0, Next_Retry_At__c = Datetime.now().addMinutes(-5), Resolved__c = false
        );
        insert dueRetry;

        Test.startTest();
        ZoomPhoneIntegration.retryPendingTranscripts();
        Test.stopTest();

        Zoom_Integration_Error__c updated = [SELECT Resolved__c FROM Zoom_Integration_Error__c WHERE Id = :dueRetry.Id];
        System.assertEquals(true, updated.Resolved__c, 'The due retry should have been processed and resolved via the enqueued job');
    }

    @isTest
    static void testRetryPendingTranscriptsNoOpWhenNoneDue() {
        Test.startTest();
        ZoomPhoneIntegration.retryPendingTranscripts();
        Test.stopTest();
        // Nothing due, so no callout/job should be attempted - just asserting no exception here.
    }

    @isTest
    static void testZoomPhoneTranscriptRetryQueueableExecute() {
        Test.setMock(HttpCalloutMock.class, new FetchTranscriptMock());

        Zoom_Integration_Error__c retryRecord = new Zoom_Integration_Error__c(
            Apex_Class__c = 'Test', Apex_Method__c = 'execute', Error_Type__c = 'Transcript Not Ready',
            Recording_Id__c = 'rec1', Voice_Call_Id__c = '0Aa000000000001',
            Retry_Count__c = 0, Next_Retry_At__c = Datetime.now(), Resolved__c = false
        );
        insert retryRecord;

        ZoomPhoneTranscriptRetryQueueable retryJob = new ZoomPhoneTranscriptRetryQueueable(
            'mockToken', new List<Zoom_Integration_Error__c>{ retryRecord }, 0
        );
        retryJob.execute(null);

        Zoom_Integration_Error__c updated = [SELECT Resolved__c FROM Zoom_Integration_Error__c WHERE Id = :retryRecord.Id];
        System.assertEquals(true, updated.Resolved__c);
    }

    @isTest
    static void testUpsertCallTranscriptsWithAgentPromptActiveAndNoSuccessfulSaves() {
        // Call_Transcript__c.Voice_Call__c is a required lookup to the standard VoiceCall object,
        // which isn't createable via DML in a test - so this upsert always fails, exercising the
        // agentPromptActive branch's "nothing to evaluate" path rather than the success path.
        Call_Transcript__c t = new Call_Transcript__c(
            Voice_Call__c = '0Aa000000000001', Transcript_Text__c = 'test', Transcript_Sequence__c = 1
        );

        Test.startTest();
        ZoomPhoneIntegration.upsertCallTranscripts(new List<Call_Transcript__c>{ t }, true);
        Test.stopTest();
        // No exception thrown is the assertion here - the record itself can't be verified saved.
    }

    @isTest
    static void testUploadRecordingFailure() {
        Test.setMock(HttpCalloutMock.class, new UploadRecordingsFailMock());
        Test.startTest();
        try {
            ZoomPhoneIntegration.uploadRecording('https://example.com/services/upload/VoiceCallRecording/123', 'https://zoom.us/recordings/fail');
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('upload'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUploadRecordingThrowsWhenUploadUrlHasNoServicesPath() {
        // uploadUrl's domain isn't guaranteed to match URL.getOrgDomainUrl()'s exact form, so the
        // rewrite anchors on "/services/" appearing somewhere in the URL rather than a specific
        // domain prefix - this proves a URL missing that anchor fails loudly instead of silently
        // sending a malformed request.
        Test.startTest();
        try {
            ZoomPhoneIntegration.uploadRecording('https://example.com/upload', 'https://zoom.us/recordings/fail');
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('/services/'), 'Expected the missing /services/ path to be called out: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    private class FailTranscriptMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('Transcript fetch failed');
            return res;
        }
    }

    @isTest
    static void testFetchTranscriptFailure() {
        Test.setMock(HttpCalloutMock.class, new FailTranscriptMock());
    
        Test.startTest();
        try {
            ZoomPhoneIntegration.fetchTranscriptFromZoom('failId', 'mockToken');
            System.assert(false, 'Expected exception not thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('fetching transcript'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testUtilityMethods() {
        // Get a valid profile for creating a User (Standard User exists in all orgs)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create a unique timestamp suffix to avoid username collisions across test runs
        String ts = String.valueOf(Datetime.now().getTime());

        // Create test data
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User' + ts, // make name unique
            Alias = 'tusr' + ts.substring(ts.length()-3),
            Email = 'testuser' + ts + '@example.com',
            Username = 'testuser' + ts + '@example.com',
            CommunityNickname = 'testuser' + ts,
            TimeZoneSidKey = 'America/Chicago',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Phone = '1234567890',
            ProfileId = p.Id
        );
        insert testUser;

        // User activeUser = [SELECT Id, name FROM User WHERE IsActive = true LIMIT 1];

        Account acc = new Account(Name = 'Test Account', Phone = '1234567890');
        insert acc;

        Lead lead = new Lead(LastName = 'Test Lead', Company = 'Test Company', Phone = '1234567890');
        insert lead;

        // === Test getSMSInternalUser ===
        // Test.startTest();
        // User resultUser = ZoomPhoneIntegration.getSMSInternalUser(activeUser.Name);
        // System.assertNotEquals(null, resultUser, 'Expected a User to be returned');
        // System.assertEquals(activeUser.Id, resultUser.Id);
        // Test.stopTest();

        // === Test getRelatedPersonAccountByPhoneNumber ===
        Set<String> phoneFormats = new Set<String>{'1234567890'};
        List<Account> relatedAccounts = ZoomPhoneIntegration.getRelatedPersonAccountByPhoneNumber(phoneFormats);
        //System.assertNotEquals(null, relatedAccounts, 'Expected non-null list for accounts');
        // System.assertEquals(1, relatedAccounts.size());

        // === Test getRelatedLeadByPhoneNumber ===
        List<Lead> relatedLeads = ZoomPhoneIntegration.getRelatedLeadByPhoneNumber(phoneFormats);
        //System.assertNotEquals(null, relatedLeads, 'Expected non-null list for leads');
        // System.assertEquals(1, relatedLeads.size());

        // === Test getRelatedUsersByPhoneNumber ===
        List<User> relatedUsers = ZoomPhoneIntegration.getRelatedUsersByPhoneNumber(phoneFormats);
        //System.assertNotEquals(null, relatedUsers, 'Expected non-null list for users');
        // System.assertEquals(1, relatedUsers.size());

        // === Test getRelatedUsersByName ===
        Set<String> names = new Set<String>{testUser.Name};
        List<User> relatedUsersByName = ZoomPhoneIntegration.getRelatedUsersByName(names);
        //System.assertNotEquals(null, relatedUsersByName, 'Expected non-null list for users by name');
        // System.assertEquals(1, relatedUsersByName.size());

        // === Test when no match is found ===
        Set<String> invalidPhones = new Set<String>{'0000000000'};
        List<Account> emptyAccounts = ZoomPhoneIntegration.getRelatedPersonAccountByPhoneNumber(invalidPhones);
        //System.assertEquals(null, emptyAccounts, 'Expected null when no Account matches');

        List<Lead> emptyLeads = ZoomPhoneIntegration.getRelatedLeadByPhoneNumber(invalidPhones);
        //System.assertEquals(null, emptyLeads, 'Expected null when no Lead matches');

        List<User> emptyUsers = ZoomPhoneIntegration.getRelatedUsersByPhoneNumber(invalidPhones);
       // System.assertEquals(null, emptyUsers, 'Expected null when no User matches');
    }
}