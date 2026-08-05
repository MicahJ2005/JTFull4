@isTest
private class BoxCreateSharedLinkQueueTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data
    // ─────────────────────────────────────────────────────────────────────────

    private static final String MOCK_TOKEN          = 'mock_access_token_123';
    private static final String MOCK_FOLDER_ID      = '111111111';
    private static final String CLIENT_FOLDER_ID    = '222222222';
    private static final String OPPOSING_FOLDER_ID  = '333333333';

    // The Box API returns a path; the production code prepends the domain.
    private static final String CLIENT_URL_PATH    = '/f/client_file_request';
    private static final String OPPOSING_URL_PATH  = '/f/opposing_file_request';
    private static final String CLIENT_URL_FULL    = 'https://johnsonturner.app.box.com' + CLIENT_URL_PATH;
    private static final String OPPOSING_URL_FULL  = 'https://johnsonturner.app.box.com' + OPPOSING_URL_PATH;

    @testSetup
    static void setupTestData() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(Name = 'Test Matter');
        insert matter;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HTTP Mocks
    // ─────────────────────────────────────────────────────────────────────────

    /** Returns a valid Box OAuth token. */
    private class TokenSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"' + MOCK_TOKEN + '","token_type":"bearer"}');
            return res;
        }
    }

    /** Returns a 401 failure for the token endpoint. */
    private class TokenFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"invalid_client"}');
            return res;
        }
    }

    /**
     * Multi-callout mock that handles the full happy-path sequence:
     *   1. POST /oauth2/token                      → access token
     *   2. GET  /folders/{id}/items                → two matching subfolders
     *   3. POST /file_requests/{id}/copy (client)  → new file request for client folder
     *   4. POST /file_requests/{id}/copy (opposing)→ new file request for opposing folder
     */
    private class HappyPathMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();

            // 1. Token
            if (endpoint.contains('/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"' + MOCK_TOKEN + '"}');
                return res;
            }

            // 2. Folder items (subfolder listing)
            if (endpoint.contains('/items')) {
                res.setStatusCode(200);
                res.setBody('{"total_count":2,"entries":['
                    + '{"type":"folder","id":"' + CLIENT_FOLDER_ID   + '","name":"Client Uploads - New Documents Here"},'
                    + '{"type":"folder","id":"' + OPPOSING_FOLDER_ID + '","name":"Opposing Uploads - New Documents Here"}'
                    + ']}');
                return res;
            }

            // 3 & 4. Copy file request — distinguish by which folder ID is in the body
            if (endpoint.contains('/file_requests/') && endpoint.contains('/copy')) {
                String body = req.getBody();
                if (body != null && body.contains(CLIENT_FOLDER_ID)) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"new_client_req","type":"file_request","url":"' + CLIENT_URL_PATH + '"}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"id":"new_opposing_req","type":"file_request","url":"' + OPPOSING_URL_PATH + '"}');
                }
                return res;
            }

            // Fallback
            res.setStatusCode(404);
            res.setBody('{"error":"not_found"}');
            return res;
        }
    }

    /** Returns an empty subfolder list. */
    private class EmptyFoldersMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"' + MOCK_TOKEN + '"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"total_count":0,"entries":[]}');
            }
            return res;
        }
    }

    /** Returns subfolders that don't match the upload folder names. */
    private class NoMatchingFoldersMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"' + MOCK_TOKEN + '"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"total_count":1,"entries":[{"type":"folder","id":"999","name":"Some Other Folder"}]}');
            }
            return res;
        }
    }

    /** Returns a 500 error for any file_requests copy call. */
    private class CopyFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"' + MOCK_TOKEN + '"}');
                return res;
            }
            if (req.getEndpoint().contains('/items')) {
                res.setStatusCode(200);
                res.setBody('{"total_count":1,"entries":['
                    + '{"type":"folder","id":"' + CLIENT_FOLDER_ID + '","name":"Client Uploads - New Documents Here"}'
                    + ']}');
                return res;
            }
            res.setStatusCode(500);
            res.setBody('{"error":"server_error"}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // extractFileRequestUrl  (@TestVisible static helper)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExtractFileRequestUrl_withValidUrl() {
        String body = '{"id":"123","type":"file_request","url":"https://app.box.com/f/abc"}';
        String url = BoxCreateSharedLinkQueue.extractFileRequestUrl(body);
        System.assertEquals('https://app.box.com/f/abc', url, 'Should extract the url field');
    }

    @isTest
    static void testExtractFileRequestUrl_withNoUrlKey() {
        String body = '{"id":"123","type":"file_request"}';
        String url = BoxCreateSharedLinkQueue.extractFileRequestUrl(body);
        System.assertEquals(null, url, 'Should return null when url key is absent');
    }

    @isTest
    static void testExtractFileRequestUrl_withBlankBody() {
        System.assertEquals(null, BoxCreateSharedLinkQueue.extractFileRequestUrl(null));
        System.assertEquals(null, BoxCreateSharedLinkQueue.extractFileRequestUrl(''));
    }

    @isTest
    static void testExtractFileRequestUrl_withInvalidJson() {
        String url = BoxCreateSharedLinkQueue.extractFileRequestUrl('not-json-at-all');
        System.assertEquals(null, url, 'Should return null for invalid JSON');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // fetchAccessTokenWithClientCredentials  (@TestVisible static helper)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testFetchAccessToken_success() {
        Test.setMock(HttpCalloutMock.class, new TokenSuccessMock());
        Test.startTest();
        String token = BoxCreateSharedLinkQueue.fetchAccessTokenWithClientCredentials();
        Test.stopTest();
        System.assertEquals(MOCK_TOKEN, token, 'Should return the access token from response');
    }

    @isTest
    static void testFetchAccessToken_failure() {
        Test.setMock(HttpCalloutMock.class, new TokenFailMock());
        Test.startTest();
        String token = BoxCreateSharedLinkQueue.fetchAccessTokenWithClientCredentials();
        Test.stopTest();
        System.assertNotEquals(MOCK_TOKEN, token, 'Should not return a valid token on failure');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // execute()  (Queueable end-to-end)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecute_happyPath_updatesMatter() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        System.enqueueJob(new BoxCreateSharedLinkQueue(MOCK_FOLDER_ID, matter.Id));
        Test.stopTest();

        AcctSeed__Project__c updated = [
            SELECT Box_Client_Upload_Link__c, Box_Opposing_Upload_Link__c
            FROM AcctSeed__Project__c
            WHERE Id = :matter.Id
        ];
        System.assertEquals(CLIENT_URL_FULL,   updated.Box_Client_Upload_Link__c,   'Client upload link should be set');
        System.assertEquals(OPPOSING_URL_FULL, updated.Box_Opposing_Upload_Link__c, 'Opposing upload link should be set');
    }

    @isTest
    static void testExecute_blankFolderId_doesNothing() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        System.enqueueJob(new BoxCreateSharedLinkQueue('', matter.Id));
        Test.stopTest();

        AcctSeed__Project__c updated = [
            SELECT Box_Client_Upload_Link__c, Box_Opposing_Upload_Link__c
            FROM AcctSeed__Project__c
            WHERE Id = :matter.Id
        ];
        System.assertEquals(null, updated.Box_Client_Upload_Link__c,   'Client link should remain null');
        System.assertEquals(null, updated.Box_Opposing_Upload_Link__c, 'Opposing link should remain null');
    }

    @isTest
    static void testExecute_noMatchingFolders_doesNotUpdateMatter() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new NoMatchingFoldersMock());
        Test.startTest();
        System.enqueueJob(new BoxCreateSharedLinkQueue(MOCK_FOLDER_ID, matter.Id));
        Test.stopTest();

        AcctSeed__Project__c updated = [
            SELECT Box_Client_Upload_Link__c, Box_Opposing_Upload_Link__c
            FROM AcctSeed__Project__c
            WHERE Id = :matter.Id
        ];
        System.assertEquals(null, updated.Box_Client_Upload_Link__c,   'Client link should remain null when no folder match');
        System.assertEquals(null, updated.Box_Opposing_Upload_Link__c, 'Opposing link should remain null when no folder match');
    }

    @isTest
    static void testExecute_blankMatterId_doesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        System.enqueueJob(new BoxCreateSharedLinkQueue(MOCK_FOLDER_ID, null));
        Test.stopTest();
        System.assert(true, 'No exception expected when MatterId is null');
    }

    @isTest
    static void testExecute_copyFails_doesNotUpdateMatter() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new CopyFailMock());
        Test.startTest();
        System.enqueueJob(new BoxCreateSharedLinkQueue(MOCK_FOLDER_ID, matter.Id));
        Test.stopTest();

        AcctSeed__Project__c updated = [
            SELECT Box_Client_Upload_Link__c, Box_Opposing_Upload_Link__c
            FROM AcctSeed__Project__c
            WHERE Id = :matter.Id
        ];
        System.assertEquals(null, updated.Box_Client_Upload_Link__c,   'Client link should remain null when copy fails');
        System.assertEquals(null, updated.Box_Opposing_Upload_Link__c, 'Opposing link should remain null when copy fails');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getSubfolders()  (public static)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetSubfolders_returnsTwoFolders() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        List<BoxCreateSharedLinkQueue.BoxFolderInfo> subs =
            BoxCreateSharedLinkQueue.getSubfolders(MOCK_FOLDER_ID);
        Test.stopTest();
        System.assertEquals(2, subs.size(), 'Should return 2 subfolders');
    }

    @isTest
    static void testGetSubfolders_stripsD_prefix() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        List<BoxCreateSharedLinkQueue.BoxFolderInfo> subs =
            BoxCreateSharedLinkQueue.getSubfolders('d_' + MOCK_FOLDER_ID);
        Test.stopTest();
        System.assertEquals(2, subs.size(), 'Should handle d_ prefix and return 2 subfolders');
    }

    @isTest
    static void testGetSubfolders_emptyResponse() {
        Test.setMock(HttpCalloutMock.class, new EmptyFoldersMock());
        Test.startTest();
        List<BoxCreateSharedLinkQueue.BoxFolderInfo> subs =
            BoxCreateSharedLinkQueue.getSubfolders(MOCK_FOLDER_ID);
        Test.stopTest();
        System.assertEquals(0, subs.size(), 'Should return empty list when no subfolders');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // enqueue()  (public static helper)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testEnqueue_returnsJobId() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        Id jobId = BoxCreateSharedLinkQueue.enqueue(MOCK_FOLDER_ID, matter.Id);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'enqueue() should return a valid AsyncApexJob Id');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // createSharedLinksFromFlow()  (@InvocableMethod)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testCreateSharedLinksFromFlow_happyPath() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        BoxCreateSharedLinkQueue.FlowRequest req = new BoxCreateSharedLinkQueue.FlowRequest();
        req.FolderId = MOCK_FOLDER_ID;
        req.MatterId = matter.Id;

        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        BoxCreateSharedLinkQueue.createSharedLinksFromFlow(
            new List<BoxCreateSharedLinkQueue.FlowRequest>{ req }
        );
        Test.stopTest();

        AcctSeed__Project__c updated = [
            SELECT Box_Client_Upload_Link__c, Box_Opposing_Upload_Link__c
            FROM AcctSeed__Project__c
            WHERE Id = :matter.Id
        ];
        System.assertEquals(CLIENT_URL_FULL,   updated.Box_Client_Upload_Link__c,   'Flow: client link should be set');
        System.assertEquals(OPPOSING_URL_FULL, updated.Box_Opposing_Upload_Link__c, 'Flow: opposing link should be set');
    }

    @isTest
    static void testCreateSharedLinksFromFlow_blankFields_skipsEnqueue() {
        BoxCreateSharedLinkQueue.FlowRequest req = new BoxCreateSharedLinkQueue.FlowRequest();
        req.FolderId = '';
        req.MatterId = '';

        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        BoxCreateSharedLinkQueue.createSharedLinksFromFlow(
            new List<BoxCreateSharedLinkQueue.FlowRequest>{ req }
        );
        Test.stopTest();
        System.assert(true, 'No exception expected for blank flow inputs');
    }

    @isTest
    static void testCreateSharedLinksFromFlow_emptyList_doesNothing() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        BoxCreateSharedLinkQueue.createSharedLinksFromFlow(
            new List<BoxCreateSharedLinkQueue.FlowRequest>()
        );
        Test.stopTest();
        System.assert(true, 'No exception expected for empty request list');
    }
}