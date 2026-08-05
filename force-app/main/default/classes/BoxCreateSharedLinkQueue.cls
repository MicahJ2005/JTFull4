public with sharing class BoxCreateSharedLinkQueue implements Queueable, Database.AllowsCallouts {
    /**
     * Queueable to create Box File Requests for the Client and Opposing upload subfolders
     * by copying a template file request, then saving the resulting URLs to the Matter record.
     *
     * CAUTION: Credentials are hardcoded per the request. Move these to a secure store
     * (Named Credential / Custom Metadata / Protected Custom Setting) before production use.
     */
    private String FolderId;
    private String MatterId;

    // Template file request to copy when creating new upload requests.
    // ID sourced from: https://johnsonturner.app.box.com/filerequest/22084449398
    private static final String TEMPLATE_FILE_REQUEST_ID = '22084449398';

    // TODO: Move these to a secure source (e.g., Named Credential or Custom Metadata)
    private static final String BOX_BASE_URL  = 'https://api.box.com/2.0';
    private static final String BOX_TOKEN_URL = 'https://api.box.com/oauth2/token';

    private static String CLIENT_ID {
        get {
            if (CLIENT_ID == null) {
                BoxConnectedAppCreds__mdt creds = BoxConnectedAppCreds__mdt.getInstance('BoxConnectedApp');
                CLIENT_ID = creds != null ? creds.Client_Id__c : null;
            }
            return CLIENT_ID;
        }
        set;
    }
    private static String CLIENT_SECRET {
        get {
            if (CLIENT_SECRET == null) {
                BoxConnectedAppCreds__mdt creds = BoxConnectedAppCreds__mdt.getInstance('BoxConnectedApp');
                CLIENT_SECRET = creds != null ? creds.Client_Secret__c : null;
            }
            return CLIENT_SECRET;
        }
        set;
    }

    // Required for Client Credentials grant.
    // BOX_SUBJECT_ID should be your Box Enterprise ID (found in Box Admin Console > Account & Billing).
    private static final String BOX_SUBJECT_TYPE = 'user';
    private static final String BOX_SUBJECT_ID   = '45809534179';

    private static final Set<String> UPLOAD_FOLDER_NAMES = new Set<String>{
        'Client Uploads - New Documents Here',
        'Opposing Uploads - New Documents Here'
    };

    public BoxCreateSharedLinkQueue(String FolderId, String MatterId) {
        this.FolderId = FolderId;
        this.MatterId = MatterId;
    }

    public void execute(QueueableContext qc) {
        if (String.isBlank(FolderId)) {
            System.debug('BoxCreateSharedLinkQueue: FolderId is required.');
            return;
        }

        // Step 1: Get access token
        String accessToken;
        try {
            accessToken = fetchAccessTokenWithClientCredentials();
            System.debug('BoxCreateSharedLinkQueue: Obtained access token successfully.');
        } catch (Exception tokenEx) {
            System.debug('BoxCreateSharedLinkQueue: Failed to obtain access token - ' + tokenEx.getMessage());
            return;
        }
        if (String.isBlank(accessToken)) {
            System.debug('BoxCreateSharedLinkQueue: Access token is empty.');
            return;
        }

        // Step 2: Get subfolders of the parent folder
        List<BoxFolderInfo> subfolders = getSubfoldersWithToken(FolderId, accessToken);
        System.debug('BoxCreateSharedLinkQueue: Found ' + subfolders.size() + ' subfolders under ' + FolderId);

        // Step 3: Filter to only those whose names match UPLOAD_FOLDER_NAMES
        List<BoxFolderInfo> targets = new List<BoxFolderInfo>();
        for (BoxFolderInfo f : subfolders) {
            if (UPLOAD_FOLDER_NAMES.contains(f.name)) {
                targets.add(f);
            }
        }

        if (targets.isEmpty()) {
            System.debug('BoxCreateSharedLinkQueue: No matching upload folders found under ' + FolderId);
            return;
        }

        // Step 4: Copy the template file request into each matching subfolder
        String clientUploadUrl   = null;
        String opposingUploadUrl = null;
        for (BoxFolderInfo f : targets) {
            String url = copyFileRequestToFolder(TEMPLATE_FILE_REQUEST_ID, f.id, accessToken);
            System.debug('BoxCreateSharedLinkQueue: ' + f.name + ' → ' + url);
            if (f.name == 'Client Uploads - New Documents Here') {
                clientUploadUrl = url;
            } else if (f.name == 'Opposing Uploads - New Documents Here') {
                opposingUploadUrl = url;
            }
        }

        // Step 5: Update the related Matter (AcctSeed__Project__c) with the file request URLs
        if (String.isNotBlank(MatterId) && (String.isNotBlank(clientUploadUrl) || String.isNotBlank(opposingUploadUrl))) {
            try {
                AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = MatterId);
                if (String.isNotBlank(clientUploadUrl)) {
                    matter.Box_Client_Upload_Link__c = 'https://johnsonturner.app.box.com'+clientUploadUrl;
                }
                if (String.isNotBlank(opposingUploadUrl)) {
                    matter.Box_Opposing_Upload_Link__c = 'https://johnsonturner.app.box.com'+opposingUploadUrl;
                }
                update matter;
                System.debug('BoxCreateSharedLinkQueue: Updated Matter ' + MatterId + ' with Box file request links.');
            } catch (Exception ex) {
                System.debug('BoxCreateSharedLinkQueue: Failed to update Matter - ' + ex.getMessage());
            }
        }
    }

    /**
     * POST https://api.box.com/2.0/file_requests/{file_request_id}/copy
     * Creates a new file request targeting the given folder by copying the template.
     * Returns the public URL of the newly created file request.
     */
    private static String copyFileRequestToFolder(String fileRequestId, String folderId, String accessToken) {
        String cleanFolderId = folderId.startsWith('d_') ? folderId.substring(2) : folderId;
        String endpoint = BOX_BASE_URL + '/file_requests/' + fileRequestId + '/copy';

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endpoint);
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> folder  = new Map<String, Object>{ 'id' => cleanFolderId, 'type' => 'folder' };
        Map<String, Object> payload = new Map<String, Object>{ 'folder' => folder };
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);
        System.debug('copyFileRequestToFolder POST status=' + res.getStatusCode() + ', body=' + res.getBody());

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return extractFileRequestUrl(res.getBody());
        }

        System.debug('copyFileRequestToFolder: Failed to copy file request ' + fileRequestId + ' to folder ' + folderId);
        return null;
    }

    @TestVisible
    private static String extractFileRequestUrl(String body) {
        if (String.isBlank(body)) {
            return null;
        }
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (parsed == null) {
                return null;
            }
            Object urlVal = parsed.get('url');
            System.debug('fileRequestUrl: ' + urlVal);
            if (urlVal != null) {
                return String.valueOf(urlVal);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'BoxCreateSharedLinkQueue: Failed to parse file request response JSON - ' + e.getMessage());
        }
        return null;
    }

    /**
     * Fetches an access token from Box using the OAuth2 Client Credentials grant.
     */
    @TestVisible
    private static String fetchAccessTokenWithClientCredentials() {
        if (String.isBlank(CLIENT_ID) || String.isBlank(CLIENT_SECRET)) {
            System.debug('BoxCreateSharedLinkQueue: CLIENT_ID/CLIENT_SECRET could not be loaded from BoxConnectedAppCreds__mdt.');
        }
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(BOX_TOKEN_URL);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body =
            'grant_type='       + EncodingUtil.urlEncode('client_credentials', 'UTF-8') +
            '&client_id='       + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8') +
            '&client_secret='   + EncodingUtil.urlEncode(CLIENT_SECRET, 'UTF-8') +
            '&box_subject_type=' + EncodingUtil.urlEncode(BOX_SUBJECT_TYPE, 'UTF-8') +
            '&box_subject_id='  + EncodingUtil.urlEncode(BOX_SUBJECT_ID, 'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        Integer status  = res.getStatusCode();
        String resBody  = res.getBody();
        System.debug('Box OAuth Token Response Status=' + status);
        System.debug('Box OAuth Token Response Body=' + resBody);
        String returnString = '';
        if (status >= 200 && status < 303) {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resBody);
            System.debug('Parsed token response: ' + parsed);
            if (parsed != null) {
                Object token = parsed.get('access_token');
                System.debug('Extracted access_token: ' + token);
                if (token != null) {
                    return String.valueOf(token);
                }
            }
            returnString = 'Token response missing access_token.';
            System.debug('Token response missing access_token.');
        }
        returnString = 'Token request failed. Status=' + status + ', Body=' + resBody;
        return returnString;
    }

    /**
     * Helper to enqueue the job.
     * Example:
     *   BoxCreateSharedLinkQueue.enqueue('123456789', 'a0X000...');
     */
    public static Id enqueue(String FolderId, String MatterId) {
        return System.enqueueJob(new BoxCreateSharedLinkQueue(FolderId, MatterId));
    }

    /**
     * Invocable method so this can be called from a Flow.
     * Input variables: FolderId (Box parent folder ID), MatterId (AcctSeed__Project__c record ID).
     */
    public class FlowRequest {
        @InvocableVariable(label='Box Folder Id' description='The Box parent folder ID containing the upload subfolders' required=true)
        public String FolderId;

        @InvocableVariable(label='Matter Id' description='The AcctSeed__Project__c record ID to update with file request URLs' required=true)
        public String MatterId;
    }

    @InvocableMethod(label='Create Box File Request Links for Matter' description='Copies the template Box file request into the Client and Opposing upload folders and saves the resulting URLs to the Matter record.')
    public static void createSharedLinksFromFlow(List<FlowRequest> requests) {
        for (FlowRequest req : requests) {
            if (String.isNotBlank(req.FolderId) && String.isNotBlank(req.MatterId)) {
                System.enqueueJob(new BoxCreateSharedLinkQueue(req.FolderId, req.MatterId));
            }
        }
    }

    public class BoxFolderInfo {
        public String id;
        public String name;
        public BoxFolderInfo(String id, String name) {
            this.id   = id;
            this.name = name;
        }
    }

    /**
     * Returns all immediate subfolders of the given Box parent folder ID.
     * Handles up to 1000 items per page; paginates automatically if more exist.
     */
    public static List<BoxFolderInfo> getSubfolders(String parentFolderId) {
        List<BoxFolderInfo> results = new List<BoxFolderInfo>();
        String cleanId = parentFolderId.startsWith('d_') ? parentFolderId.substring(2) : parentFolderId;

        String accessToken = fetchAccessTokenWithClientCredentials();
        if (String.isBlank(accessToken)) {
            System.debug('BoxCreateSharedLinkQueue.getSubfolders: Could not obtain access token.');
            return results;
        }

        Integer offset          = 0;
        final Integer PAGE_SIZE = 1000;
        Boolean hasMore         = true;

        while (hasMore) {
            String endpoint = BOX_BASE_URL + '/folders/' + cleanId + '/items'
                + '?fields=id,name,type&limit=' + PAGE_SIZE + '&offset=' + offset;

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            HttpResponse res        = new Http().send(req);
            Integer statusCode      = res.getStatusCode();
            String body             = res.getBody();
            System.debug('BoxCreateSharedLinkQueue.getSubfolders: status=' + statusCode + ', body=' + body);

            if (statusCode < 200 || statusCode >= 300) {
                System.debug('BoxCreateSharedLinkQueue.getSubfolders: Non-2xx response. Stopping.');
                break;
            }

            Map<String, Object> parsed  = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> entries        = (List<Object>) parsed.get('entries');

            if (entries == null || entries.isEmpty()) { break; }

            for (Object entry : entries) {
                Map<String, Object> item = (Map<String, Object>) entry;
                if ('folder'.equals(String.valueOf(item.get('type')))) {
                    results.add(new BoxFolderInfo(
                        String.valueOf(item.get('id')),
                        String.valueOf(item.get('name'))
                    ));
                }
            }

            Integer totalCount = (Integer) parsed.get('total_count');
            offset += PAGE_SIZE;
            hasMore = (totalCount != null && offset < totalCount);
        }

        System.debug('BoxCreateSharedLinkQueue.getSubfolders: found ' + results.size() + ' subfolders.');
        return results;
    }

    // Internal overload that reuses an existing token
    private static List<BoxFolderInfo> getSubfoldersWithToken(String parentFolderId, String accessToken) {
        List<BoxFolderInfo> results = new List<BoxFolderInfo>();
        String cleanId = parentFolderId.startsWith('d_') ? parentFolderId.substring(2) : parentFolderId;

        Integer offset          = 0;
        final Integer PAGE_SIZE = 1000;
        Boolean hasMore         = true;

        while (hasMore) {
            String endpoint = BOX_BASE_URL + '/folders/' + cleanId + '/items'
                + '?fields=id,name,type&limit=' + PAGE_SIZE + '&offset=' + offset;

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            HttpResponse res   = new Http().send(req);
            Integer statusCode = res.getStatusCode();
            String body        = res.getBody();
            System.debug('getSubfoldersWithToken: status=' + statusCode);

            if (statusCode < 200 || statusCode >= 300) { break; }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> entries       = (List<Object>) parsed.get('entries');
            if (entries == null || entries.isEmpty()) { break; }

            for (Object entry : entries) {
                Map<String, Object> item = (Map<String, Object>) entry;
                if ('folder'.equals(String.valueOf(item.get('type')))) {
                    results.add(new BoxFolderInfo(
                        String.valueOf(item.get('id')),
                        String.valueOf(item.get('name'))
                    ));
                }
            }

            Integer totalCount = (Integer) parsed.get('total_count');
            offset += PAGE_SIZE;
            hasMore = (totalCount != null && offset < totalCount);
        }
        return results;
    }
}