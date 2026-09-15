// without sharing: this class's SOQL/DML (VoiceCall, Call_Transcript__c, Zoom_Integration_Error__c,
// etc.) also runs from ZoomPhoneWebhookHandler's guest-user REST context, which has essentially no
// sharing-rule visibility by default. Access here is gated by the webhook's HMAC signature check
// and the scheduled sync's own trusted execution context, not by record sharing - the existing
// internal callers (Schedulable, Queueable chains) are already broadly-permissioned users this
// doesn't restrict either way.
public without sharing class ZoomPhoneIntegration implements Schedulable {

    public void execute(SchedulableContext ctx) {
        sendZoomDataToSalesforce();
        retryPendingTranscripts();
    }

    // Kicks off ZoomPhoneIntegrationQueueable rather than doing the work in a @future method.
    // A Queueable job started from a @future (or Batch) context can't itself enqueue further
    // jobs ("Maximum stack depth has been reached"), and Step 5 below needs to chain a
    // Queueable per recording so each one gets its own callout/governor-limit budget. Starting
    // that chain from a plain Queueable (launched synchronously here, not from @future) avoids
    // the restriction.
    public static void sendZoomDataToSalesforce() {
        System.enqueueJob(new ZoomPhoneIntegrationQueueable());
    }

    /// Body of the Zoom Phone sync, run from ZoomPhoneIntegrationQueueable.execute().
    public static void runZoomDataSync() {
        ZoomConfig__mdt cfg = [
            SELECT AccountId__c, ClientId__c, ClientSecret__c, DefaultUserId__c
            FROM   ZoomConfig__mdt
            WHERE  DeveloperName = 'Default'
            LIMIT  1
        ];

        String clientId = cfg.ClientId__c;
        String clientSecret = cfg.ClientSecret__c;
        String accountId = cfg.AccountId__c;
        String defaultUserId = cfg.DefaultUserId__c;

        // Step 1: Get Zoom OAuth Token
        String zoomToken = getZoomToken(clientId, clientSecret, accountId);
        System.debug('Zoom Token: ' + zoomToken);

        // Step 2: Fetch Call Logs
        Datetime now = Datetime.now(); // Current datetime
        String toDateTime = now.addHours(-1).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 1 hour ago
        String fromDateTime = now.addHours(-1).addMinutes(-30).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 1.5 hours ago
        // String toDateTime   = DateTime.newInstanceGmt(2026, 8, 19, 14, 0, 0).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 9:00am CDT
        // String fromDateTime = DateTime.newInstanceGmt(2026, 8, 19, 13, 0, 0).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 8:00am CDT

        String zoomJson;
        try {
            zoomJson = fetchZoomCallHistory(zoomToken, fromDateTime, toDateTime);
        } catch (Exception e) {
            ZoomIntegrationErrorLogger.log('ZoomPhoneIntegration', 'fetchZoomCallHistory', null, null, e);
            throw e;
        }
        System.debug('Zoom JSON: ' + zoomJson);

        // Step 3: Transform Zoom Data
        String salesforceJson = transformZoomData(zoomJson, defaultUserId);
        System.debug('Salesforce JSON: ' + salesforceJson);

        // if(salesforceJson != null){
            // Step 4: Send Call Metadata to Salesforce
            List<CallResponse> responses = sendCallMetadataToECI(salesforceJson);
            System.debug('Call Metadata Responses: ' + responses);

            // Step 5: Fetch and Upload Recordings
            processRecordings(zoomToken, responses, fromDateTime, toDateTime);
        // }
    }

    // Method to fetch OAuth token from Zoom
    public static String getZoomToken(String clientId, String clientSecret, String accountId) {
        String authUrl = 'https://zoom.us/oauth/token';

        try {
            // Create the authorization header value
            String credentials = clientId + ':' + clientSecret;
            String encodedCredentials = EncodingUtil.base64Encode(Blob.valueOf(credentials));

            // Create the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(authUrl);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + encodedCredentials);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            // Add required body parameters
            req.setBody('grant_type=account_credentials&account_id=' + accountId);

            // Make the HTTP callout
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Parse the response to get the token
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) responseMap.get('access_token');
            } else {
                System.debug('Failed to get token. Status Code: ' + res.getStatusCode());
                System.debug('Response Body: ' + res.getBody());
                throw new CalloutException('Failed to get Zoom token: ' + res.getBody());
            }
        } catch (Exception e) {
            ZoomIntegrationErrorLogger.log('ZoomPhoneIntegration', 'getZoomToken', null, null, e);
            throw new CalloutException('Error during Zoom token request: ' + e.getMessage());
        }
    }

    public static String fetchZoomCallHistory(String token, String fromDateTime, String toDateTime, String nextPageToken, List<Map<String, Object>> aggregatedLogs) {
        try {
            // Build the query parameters
            String endpoint = 'https://api.zoom.us/v2/phone/call_history';
            String queryParams = 'from=' + EncodingUtil.urlEncode(fromDateTime, 'UTF-8') +
                                 '&to=' + EncodingUtil.urlEncode(toDateTime, 'UTF-8') +
                                 '&page_size=300';
            
            if (nextPageToken != null) {
                queryParams += '&next_page_token=' + EncodingUtil.urlEncode(nextPageToken, 'UTF-8');
            }
    
            // Setup the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint + '?' + queryParams);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + token);
    
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
    
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    
                // Extract and aggregate call logs
                List<Object> currentPageLogs = new List<Object>();
                if (responseMap.containsKey('call_logs') && responseMap.get('call_logs') != null) {
                    currentPageLogs = (List<Object>) responseMap.get('call_logs');
                    for (Object rawLog : currentPageLogs) {
                        if (rawLog instanceof Map<String, Object>) {
                            aggregatedLogs.add((Map<String, Object>) rawLog);
                        }
                    }
                }
    
                // Debugging
                System.debug('Current Page Logs: ' + currentPageLogs.size());
                System.debug('next_page_token: ' + responseMap.get('next_page_token'));
    
                // Get next page token if available
                String newNextPageToken = responseMap.containsKey('next_page_token') ? (String) responseMap.get('next_page_token') : null;
    
                // Exit condition: If fewer than 300 records and no next page token, stop recursion
                if (currentPageLogs.size() < 300) {
                    System.debug('Last page reached with ' + currentPageLogs.size() + ' records.');
                    return JSON.serialize(aggregatedLogs);
                }
    
                // Continue fetching if there's more data
                return fetchZoomCallHistory(token, fromDateTime, toDateTime, newNextPageToken, aggregatedLogs);
            } else {
                throw new CalloutException('Error fetching call history: ' + res.getBody());
            }
        } catch (Exception ex) {
            System.debug('Exception while fetching Zoom call history: ' + ex.getMessage());
            throw ex;
        }
    }
    
    // Overloaded method to initialize the recursive call
    public static String fetchZoomCallHistory(String token, String fromDateTime, String toDateTime) {
        return fetchZoomCallHistory(token, fromDateTime, toDateTime, null, new List<Map<String, Object>>());
    }    
    
    public static String transformZoomData(String zoomJson, String defaultUserId) {
        // Step 1: Build a Map of Salesforce User IDs
        Map<String, User> userNameToIdMap = buildUserMap();
        // Extension is a more reliable match than Name against Zoom's caller_name/callee_name,
        // which can silently fail to match on any display-name spelling difference.
        Map<String, User> userExtensionToIdMap = buildUserExtensionMap();

        set<string> internalUserPhoneSet = new set<string>();
        set<string> internalUserNameSet = new set<string>();
        // List<String> phoneFormats = new List<String>();
        String phoneFormats;
        for(User u: ([SELECT Id, Name, MobilePhone, phone, profile.name FROM User WHERE isActive = true AND profile.name != 'Fairwell Customer Community Plus Login User' AND profile.name != 'Kapsten Customer Community Login User'])){
            
            if(u.phone != null){
                phoneFormats = ZoomSMSIntegration.removePhoneNumberFormat(u.phone);
                            // system.debug('phoneFormats +'+ phoneFormats);
                // for(string phone: phoneFormats){
                    internalUserPhoneSet.add('+'+phoneFormats);
                    internalUserNameSet.add(u.Name);
                // }
            }
            if(u.MobilePhone != null){
                phoneFormats = ZoomSMSIntegration.removePhoneNumberFormat(u.MobilePhone);
                            // system.debug('phoneFormats +'+ phoneFormats);
                // for(string phone: phoneFormats){
                    internalUserPhoneSet.add('+'+phoneFormats);
                    internalUserNameSet.add(u.Name);
                // }
            }
            
        }
        
        String mediaProviderId = '123';
        if(!Test.isRunningTest()){
            CallCoachingMediaProvider mediaProvider = [SELECT Id, ProviderName FROM CallCoachingMediaProvider WHERE ProviderName = 'Zoom Phone' LIMIT 1];
            mediaProviderId = mediaProvider.Id;
        }
    
        // Deserialize the input JSON
        List<Object> callLogs = (List<Object>) JSON.deserializeUntyped(zoomJson);
    
        // List to hold transformed call data
        List<Map<String, Object>> formattedCalls = new List<Map<String, Object>>();

        map<string, List<string>> contactNameToContactMap = new map<string, List<string>>();
        for (Object log : callLogs) {
            // System.debug('log transformZoomData '+ log);
            Map<String, Object> call = (Map<String, Object>) log;
            // System.debug('call transformZoomData '+ call);
    
            // Map Zoom user to Contact user ID
            String userName = null;
            string contactName = null;
            string callerName = null;
            string calleeName = null;
    
            if (call.containsKey('caller_name') && call.get('caller_name') != null && String.valueOf(call.get('direction')).toLowerCase() == 'outbound') {
                contactName = String.valueOf(call.get('caller_name'));
                callerName = String.valueOf(call.get('caller_name'));
                contactNameToContactMap.put(contactName, new List<string>());
                // System.debug('CALLER NUMBER: '+ call.get('caller_did_number'));
            } else if (call.containsKey('direction') && String.valueOf(call.get('direction')).toLowerCase() == 'inbound' &&
                       call.containsKey('callee_name') && call.get('callee_name') != null) {
                contactName = String.valueOf(call.get('callee_name'));
                calleeName = String.valueOf(call.get('callee_name'));
                contactNameToContactMap.put(contactName, new List<string>());
                // System.debug('CALLEE NUMBER: '+ call.get('callee_did_number'));
            }
        }

        // Resolve phone numbers for every collected contact name in one query per object type,
        // instead of re-querying inside the loop above for every call log entry - with a month's
        // worth of call logs that per-entry querying blows the 100-SOQL-query governor limit.
        for(Account a: [SELECT Id, Phone, PersonMobilePhone, Name FROM Account WHERE Phone != null AND Name IN: contactNameToContactMap.keySet() ]){
            // system.debug('ACCOUNT IN LOOP: '+ a);
            if(a.Phone != null){
                contactNameToContactMap.get(a.name).add(a.phone);
            }
            else if(a.PersonMobilePhone != null){
                contactNameToContactMap.get(a.name).add(a.PersonMobilePhone);
            }
        }

        for(Lead a: [SELECT Id, Phone, Name FROM Lead WHERE Phone != null AND Name IN: contactNameToContactMap.keySet() ]){
            // system.debug('Lead IN LOOP: '+ a);
            contactNameToContactMap.get(a.name).add(a.phone);
        }

        for(Contact a: [SELECT Id, Phone, MobilePhone, Name FROM Contact WHERE Phone != null AND Name IN: contactNameToContactMap.keySet() ]){
            // system.debug('Contact IN LOOP: '+ a);
            if(a.phone != null){
                contactNameToContactMap.get(a.name).add(a.phone);
            }
            else if(a.MobilePhone != null){
                contactNameToContactMap.get(a.name).add(a.MobilePhone);
            }
        }
    /////////////
        for (Object log : callLogs) {
            // System.debug('log transformZoomData '+ log);
            Map<String, Object> call = (Map<String, Object>) log;
            // System.debug('call transformZoomData '+ call);
            Map<String, Object> formattedCall = new Map<String, Object>();
            // Skip calls under 10 seconds
            if (call.containsKey('duration') && call.get('duration') != null) {
                Integer durationInSeconds = Integer.valueOf(call.get('duration'));
                if (durationInSeconds < 10) {
                    System.debug('Skipping call with duration less than 10 seconds: ' + call);
                    continue; // Skip this record
                }
            } else {
                System.debug('Skipping record due to missing duration: ' + call);
                continue; // Skip record
            }
    
            // Map startDateTime
            if (call.containsKey('start_time') && call.get('start_time') != null) {
                String startDateTimeRaw = String.valueOf(call.get('start_time'));
                formattedCall.put('startDateTime', startDateTimeRaw);
    
                // Calculate endDateTime using duration
                try {
                    Datetime startDatetimeObj = Datetime.valueOfGmt(startDateTimeRaw.replace('T', ' ').replace('Z', ''));
                    Datetime endDatetimeObj = startDatetimeObj.addSeconds(Integer.valueOf(call.get('duration')));
                    formattedCall.put('endDateTime', endDatetimeObj.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
                } catch (Exception ex) {
                    System.debug('Error parsing startDateTime or calculating endDateTime: ' + ex.getMessage());
                    continue; // Skip record
                }
            } else {
                System.debug('Skipping record due to missing start_time: ' + call);
                continue; // Skip record
            }
    
            // Map callType based on direction
            if (call.containsKey('direction') && call.get('direction') != null) {
                String direction = String.valueOf(call.get('direction')).toLowerCase();
                formattedCall.put('callType', direction == 'inbound' ? 'Inbound' : direction == 'outbound' ? 'Outbound' : 'Unknown');
            } else {
                System.debug('Skipping record due to missing direction: ' + call);
                continue; // Skip record
            }
    
            // Map Zoom user to Salesforce user ID
            String userName = null;
            String userExtension = null;
            string contactName = null;

            if (call.containsKey('caller_name') && call.get('caller_name') != null && String.valueOf(call.get('direction')).toLowerCase() == 'outbound') {
                userName = String.valueOf(call.get('caller_name'));
                userExtension = call.get('caller_ext_number') != null ? String.valueOf(call.get('caller_ext_number')) : null;
                contactName = String.valueOf(call.get('caller_name'));
            } else if (call.containsKey('direction') && String.valueOf(call.get('direction')).toLowerCase() == 'inbound' &&
                       call.containsKey('callee_name') && call.get('callee_name') != null) {
                userName = String.valueOf(call.get('callee_name'));
                userExtension = call.get('callee_ext_number') != null ? String.valueOf(call.get('callee_ext_number')) : null;
                contactName = String.valueOf(call.get('caller_name'));
            }

            // Prefer matching the internal Zoom user by extension - it's a stable identifier,
            // unlike caller_name/callee_name which can silently fail to match a User.Name that
            // differs in spelling. Fall back to the name match, then the default user.
            if (userExtension != null && userExtensionToIdMap.containsKey(userExtension)) {
                formattedCall.put('userId', userExtensionToIdMap.get(userExtension).Id);
                System.debug('userExtension: '+ userExtension + ' in map: '+ userExtensionToIdMap.get(userExtension).Id);
            } else if (userName != null && userNameToIdMap.containsKey(userName)) {
                formattedCall.put('userId', userNameToIdMap.get(userName).Id);
                System.debug('userName: '+ userName + ' in map: '+ userNameToIdMap.get(userName).Id);
            } else {
                formattedCall.put('userId', defaultUserId);
            }
            
            // System.debug('toPhoneNumber callee_did_number: '+ call.get('callee_did_number'));
            System.debug('callee_name callee_name: '+ call.get('callee_name'));
            // System.debug('fromPhoneNumber caller_did_number: '+ call.get('caller_did_number'));
            System.debug('caller_name caller_name: '+ call.get('caller_name'));
            // System.debug('direction direction: '+ call.get('direction'));
            // Boolean skipThis = false;
            /// removed this filter on internal calls- MJ Demand Chain 6.2.2026
            // if(internalUserNameSet.contains(String.valueOf(call.get('callee_name'))) && internalUserNameSet.contains(String.valueOf(call.get('caller_name')))){
            //     System.debug('THIS IS AN INTERNAL CALL BETWEEN '+ call.get('caller_name') +' AND '+ call.get('callee_name') +'... Skipping this record!!!');
            // }else{
            
                string toPhoneNumber = String.valueOf(call.get('callee_did_number'));
                if(toPhoneNumber == null){
                    toPhoneNumber = String.valueOf(call.get('callee_ext_number'));
                }
                // System.debug('toPhoneNumber BEFORE: '+ toPhoneNumber);

                string fromPhoneNumber = String.valueOf(call.get('caller_did_number'));
                if(fromPhoneNumber == null){
                    fromPhoneNumber = String.valueOf(call.get('caller_ext_number'));
                }
                // System.debug('fromPhoneNumber BEFORE: '+ fromPhoneNumber);

                if(toPhoneNumber == null){
                    if(contactNameToContactMap.containsKey(String.valueOf(call.get('callee_name')))){
                        for(string s: contactNameToContactMap.get(String.valueOf(call.get('callee_name')))){
                            toPhoneNumber = s;
                        }
                        
                    }
                    else if(userNameToIdMap.containsKey(String.valueOf(call.get('callee_name')))){
                        if(userNameToIdMap.get(String.valueOf(call.get('callee_name'))).phone != null){
                            toPhoneNumber = userNameToIdMap.get(String.valueOf(call.get('callee_name'))).phone;
                        }
                        else{
                            toPhoneNumber = userNameToIdMap.get(String.valueOf(call.get('callee_name'))).MobilePhone;
                        }
                        
                    }
                
                }
                if(fromPhoneNumber == null){
                    if(contactNameToContactMap.containsKey(String.valueOf(call.get('caller_name')))){
                        // toPhoneNumber = contactNameToContactMap.get(String.valueOf(call.get('caller_name'))[0]);
                        for(string s: contactNameToContactMap.get(String.valueOf(call.get('caller_name')))){
                            fromPhoneNumber = s;
                        }
                    }
                    else if(userNameToIdMap.containsKey(String.valueOf(call.get('caller_name')))){
                        if(userNameToIdMap.get(String.valueOf(call.get('caller_name'))).phone != null){
                            fromPhoneNumber = userNameToIdMap.get(String.valueOf(call.get('caller_name'))).phone;
                        }
                        else{
                            fromPhoneNumber = userNameToIdMap.get(String.valueOf(call.get('caller_name'))).MobilePhone;
                        }
                    }
                }

                
                System.debug('internalUserPhoneSet: '+ internalUserPhoneSet);
                // if( toPhoneNumber != null && fromPhoneNumber != null){
                //     System.debug('toPhoneNumber AFTER: '+ toPhoneNumber);
                //     System.debug('fromPhoneNumber AFTER: '+ fromPhoneNumber);
                //     System.debug('toPhoneNumber LENGTH AFTER: '+ toPhoneNumber.length());
                //     System.debug('fromPhoneNumber LENGTH AFTER: '+ fromPhoneNumber.length());
                //     if((internalUserPhoneSet.contains(toPhoneNumber) || toPhoneNumber.length() == 4) && 
                //         (internalUserPhoneSet.contains(fromPhoneNumber) || fromPhoneNumber.length() == 4)){
                //         system.debug('To: ' +toPhoneNumber+' and FROM: ' +fromPhoneNumber +' are both internal... WE CAN SKIP THS CONVO');
                //     }
                // }
                
                
                // Map other fields
                // formattedCall.put('toPhoneNumber', call.get('callee_did_number'));
                // formattedCall.put('fromPhoneNumber', call.get('caller_did_number'));
                system.debug('toPhoneNumber: '+ toPhoneNumber);
                system.debug('fromPhoneNumber: '+ fromPhoneNumber);
                system.debug('Call Id: '+ call.get('call_id'));
                if(toPhoneNumber != null && toPhoneNumber != '' && fromPhoneNumber != null && fromPhoneNumber != ''){
                    formattedCall.put('toPhoneNumber', toPhoneNumber);
                    formattedCall.put('fromPhoneNumber', fromPhoneNumber);
                    formattedCall.put('recordingDuration', call.get('duration'));
                    formattedCall.put('externalId', call.get('call_id'));
                    formattedCall.put('recordingFormat', 'mp3'); // Assume recordings are in mp3 format
                    formattedCall.put('mediaProviderId', mediaProviderId); 
            
                    // Add transformed call to the list
                    formattedCalls.add(formattedCall);
                }
            // }
        }
    
        // Create output map
        Map<String, Object> output = new Map<String, Object>();
        output.put('calls', formattedCalls);
    
        System.debug('Number of calls transformed: ' + formattedCalls.size());
        return JSON.serialize(output);
    }
     
    // Method to send call metadata to the VoiceCalls endpoint
    public static List<CallResponse> sendCallMetadataToECI(String jsonInput) {
        List<CallResponse> responseList = new List<CallResponse>();

            // Parse the JSON input into a Map structure
            Map<String, Object> inputMap = (Map<String, Object>) JSON.deserializeUntyped(jsonInput);
    
            // Get the list of calls
            List<Object> calls = (List<Object>) inputMap.get('calls');
    
            // Filter out calls where recordingDuration == 0
            List<Object> filteredCalls = new List<Object>();
            for (Object callObj : calls) {
                Map<String, Object> call = (Map<String, Object>) callObj;
                if (call.containsKey('recordingDuration') && Integer.valueOf(call.get('recordingDuration')) > 0) {
                    filteredCalls.add(call);
                } else {
                    System.debug('Skipping call with recordingDuration == 0: ' + call);
                }
            }

            // Skip calls that already have a VoiceCall, so re-fetching an overlapping call-history
            // window (the normal sync's own window, a manual backfill run, or any future webhook
            // re-check) never creates a second VoiceCall for the same call.
            filteredCalls = excludeCallsWithExistingVoiceCall(filteredCalls);

            // The VoiceCalls bulk-create endpoint rejects requests over 200 records
            // (EXCEEDED_MAX_SIZE_REQUEST: "The number of calls cannot exceed 200."), so send
            // the filtered calls in batches of 200 instead of one request per call.
            Integer batchSize = 200;
            for (Integer batchStart = 0; batchStart < filteredCalls.size(); batchStart += batchSize) {
                Integer batchEnd = Math.min(batchStart + batchSize, filteredCalls.size());
                List<Object> callBatch = new List<Object>();
                for (Integer i = batchStart; i < batchEnd; i++) {
                    callBatch.add(filteredCalls[i]);
                }
                responseList.addAll(sendCallBatchToECI(callBatch));
            }

        return responseList;
    }

    private static List<Object> excludeCallsWithExistingVoiceCall(List<Object> calls) {
        Set<String> externalIds = new Set<String>();
        for (Object callObj : calls) {
            Map<String, Object> call = (Map<String, Object>) callObj;
            String externalId = (String) call.get('externalId');
            if (externalId != null) {
                externalIds.add(externalId);
            }
        }
        if (externalIds.isEmpty()) {
            return calls;
        }

        Set<String> existingExternalIds = new Set<String>();
        for (VoiceCall vc : [SELECT VendorCallKey FROM VoiceCall WHERE VendorCallKey IN :externalIds]) {
            existingExternalIds.add(vc.VendorCallKey);
        }
        if (existingExternalIds.isEmpty()) {
            return calls;
        }

        List<Object> newCalls = new List<Object>();
        for (Object callObj : calls) {
            Map<String, Object> call = (Map<String, Object>) callObj;
            String externalId = (String) call.get('externalId');
            if (externalId == null || !existingExternalIds.contains(externalId)) {
                newCalls.add(callObj);
            } else {
                System.debug('Skipping call with externalId ' + externalId + ' - VoiceCall already exists');
            }
        }
        return newCalls;
    }

    public static List<CallResponse> sendCallBatchToECI(List<Object> callBatch) {
        List<CallResponse> responseList = new List<CallResponse>();

        // Reconstruct the filtered JSON payload
        Map<String, Object> filteredInputMap = new Map<String, Object>();
        filteredInputMap.put('calls', callBatch);
        String filteredJsonInput = JSON.serialize(filteredInputMap);

        // Construct the HTTP request - routed through the ZoomWebhooksNamedCredentials Named
        // Credential (OAuth 2.0 Client Credentials Flow, a dedicated integration user) rather than
        // UserInfo.getSessionId(): a guest user's session (ZoomPhoneWebhookHandler's REST context)
        // can't authenticate against Salesforce's own REST API, so a session-id header only ever
        // worked for the polling pipeline's real logged-in session. Using the same Named Credential
        // for both callers means they now share one consistent, minimally-scoped identity instead
        // of one path depending on whatever user happened to be running the scheduled job.
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ZoomWebhooksNamedCredentials/services/data/v62.0/voicecalls');
        req.setMethod('POST');
        req.setTimeout(120000); // Set timeout to 120 seconds
        req.setHeader('Content-Type', 'application/json');
        req.setBody(filteredJsonInput);

        try {
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            system.debug('res BODY HERE: ' + res.getBody());
            // Handle response
            if (res.getStatusCode() == 201) {
                // Parse the response and return success for individual calls
                 // Parse response into a Map
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    system.debug('responseMap HERE: ' + responseMap);
                // Extract the "calls" array
                if (responseMap.containsKey('calls')) {
                    List<Object> callObjects = (List<Object>) responseMap.get('calls');
                    system.debug('callObjects HERE: ' + callObjects);
                    // Map each call object to CallResponse
                    for (Object obj : callObjects) {
                        CallResponse response = (CallResponse) JSON.deserialize(JSON.serialize(obj), CallResponse.class);
                        system.debug('Response object: ' + obj);
                        responseList.add(response);
                    }
                } else {
                    throw new CalloutException('Malformed response: Missing "calls" key');
                }
            } else {
                // Log or throw error for unexpected status codes
                System.debug('Error: ' + res.getBody());
                throw new CalloutException('Error sending call metadata to ECI: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ZoomIntegrationErrorLogger.log('ZoomPhoneIntegration', 'sendCallMetadataToECI', null, null, e);
            throw e;
        }

        return responseList;
    }

    /// Entry point for ZoomPhoneWebhookHandler's phone.recording_completed events. Creates the
    /// VoiceCall directly from the webhook payload instead of waiting on the call-history poll
    /// (runZoomDataSync's 60-90 minute window) - the same fields the poll extracts from
    /// /v2/phone/call_history are present on the recording's own webhook payload. Uploading the
    /// audio right here (rather than later, from the poll's per-recording processing) is what
    /// makes this possible without a separate "how do we get an upload URL for an already-created
    /// VoiceCall" mechanism: we get a fresh uploadUrl back from creating the VoiceCall right now.
    /// No Zoom API token is needed - VoiceCall creation and the audio upload both call Salesforce's
    /// own REST API (session id auth / the Zoom_Phone Named Credential respectively).
    public static void processWebhookRecordingCompleted(Map<String, Object> recording, String callId) {
        List<VoiceCall> existing = [SELECT Id FROM VoiceCall WHERE VendorCallKey = :callId LIMIT 1];
        if (!existing.isEmpty()) {
            System.debug('VoiceCall already exists for call_id ' + callId + ' - skipping duplicate creation');
            return;
        }

        try {
            createVoiceCallAndUploadAudio(recording, callId);
        } catch (Exception e) {
            // Retryable, unlike a plain ZoomIntegrationErrorLogger.log call - this failure mode
            // has no simpler identifier to re-fetch the original call data from later (unlike a
            // transcript retry, which just needs a recording id), so the raw payload itself is
            // captured to rebuild the same request on retry.
            logRetryableVoiceCallCreationFailure(recording, callId, e);
        }
    }

    /// Core VoiceCall-creation + audio-upload logic, shared between the first webhook attempt
    /// (processWebhookRecordingCompleted) and processVoiceCallCreationRetry. Throws on any real
    /// failure (including a per-call failure the VoiceCalls bulk-create API can report even when
    /// the overall HTTP request succeeds) - callers decide how to log/retry it. Returns normally,
    /// without creating anything, for a legitimate skip (a short call under 10 seconds).
    private static void createVoiceCallAndUploadAudio(Map<String, Object> recording, String callId) {
        Map<String, Object> callMap = buildCallMapFromWebhookRecording(recording, callId);
        if (callMap == null) {
            return; // short call (<10s) - not a failure, just skip
        }

        List<CallResponse> responses = sendCallBatchToECI(new List<Object>{ callMap });
        if (responses.isEmpty()) {
            throw new CalloutException('sendCallBatchToECI returned no CallResponse for call_id ' + callId);
        }
        if (!responses[0].isSuccess || responses[0].uploadUrl == null) {
            throw new CalloutException('VoiceCall creation reported failure for call_id ' + callId
                + '. isSuccess=' + responses[0].isSuccess + ' errorMsg=' + responses[0].errorMsg);
        }

        String downloadUrl = (String) recording.get('download_url');
        if (downloadUrl != null) {
            try {
                uploadRecording(responses[0].uploadUrl, downloadUrl);
            } catch (Exception e) {
                ZoomIntegrationErrorLogger.log('ZoomPhoneIntegration', 'uploadRecording', null, callId, e);
            }
        }
    }

    private static void logRetryableVoiceCallCreationFailure(Map<String, Object> recording, String callId, Exception e) {
        Zoom_Integration_Error__c logRecord = new Zoom_Integration_Error__c();
        logRecord.Apex_Class__c = 'ZoomPhoneIntegration';
        logRecord.Apex_Method__c = 'processWebhookRecordingCompleted';
        logRecord.Zoom_Meeting_Id__c = callId;
        logRecord.Recording_Id__c = recording.get('id') != null ? String.valueOf(recording.get('id')) : null;
        logRecord.Error_Type__c = 'Voice Call Creation Failed';
        logRecord.Error_Message__c = e.getMessage();
        logRecord.Stack_Trace__c = e.getStackTraceString();
        logRecord.Raw_Payload__c = JSON.serialize(recording);
        logRecord.Retry_Count__c = 0;
        logRecord.Next_Retry_At__c = Datetime.now().addMinutes(RETRY_DELAY_MINUTES);
        logRecord.Resolved__c = false;

        try {
            insert logRecord;
        } catch (Exception insertEx) {
            System.debug(LoggingLevel.ERROR, 'Failed to insert Zoom_Integration_Error__c for processWebhookRecordingCompleted: ' + insertEx.getMessage());
        }
    }

    /// Picks up recordings whose VoiceCall creation previously failed and are now due for another
    /// attempt, per Zoom_Integration_Error__c's Next_Retry_At__c. Mirrors retryPendingTranscripts,
    /// but for the earlier failure point (creating the VoiceCall itself) rather than attaching a
    /// transcript to one that should already exist - a call whose recording_completed processing
    /// failed outright has no VoiceCall for a transcript retry to find no matter how many times
    /// it's attempted, so this is a separate retry pass keyed off Error_Type__c instead of
    /// Recording_Id__c.
    public static void retryPendingVoiceCallCreations() {
        List<Zoom_Integration_Error__c> dueRetries = [
            SELECT Id, Zoom_Meeting_Id__c, Raw_Payload__c, Retry_Count__c
            FROM Zoom_Integration_Error__c
            WHERE Resolved__c = false AND Error_Type__c = 'Voice Call Creation Failed' AND Next_Retry_At__c <= :Datetime.now()
            ORDER BY Next_Retry_At__c ASC
            LIMIT 50
        ];

        if (dueRetries.isEmpty()) {
            return;
        }

        System.enqueueJob(new ZoomPhoneVoiceCallRetryQueueable(dueRetries, 0));
    }

    /// Per-record body of the VoiceCall-creation retry pass: rebuilds the original request from
    /// the raw payload captured on the failed attempt and retries it. On success (or finding a
    /// VoiceCall already exists - e.g. a later duplicate webhook succeeded independently in the
    /// meantime) marks the retry resolved; on failure, reschedules up to
    /// MAX_TRANSCRIPT_RETRY_ATTEMPTS times before giving up. Called once per pending retry from
    /// ZoomPhoneVoiceCallRetryQueueable, each in its own transaction.
    public static void processVoiceCallCreationRetry(Zoom_Integration_Error__c retryRecord) {
        String callId = retryRecord.Zoom_Meeting_Id__c;
        try {
            List<VoiceCall> existing = [SELECT Id FROM VoiceCall WHERE VendorCallKey = :callId LIMIT 1];
            if (existing.isEmpty()) {
                Map<String, Object> recording = (Map<String, Object>) JSON.deserializeUntyped(retryRecord.Raw_Payload__c);
                createVoiceCallAndUploadAudio(recording, callId);
            }
            retryRecord.Resolved__c = true;
            update retryRecord;
        } catch (Exception e) {
            Integer attempts = (retryRecord.Retry_Count__c != null ? retryRecord.Retry_Count__c.intValue() : 0) + 1;
            retryRecord.Retry_Count__c = attempts;
            retryRecord.Error_Message__c = e.getMessage();
            retryRecord.Stack_Trace__c = e.getStackTraceString();
            if (attempts < MAX_TRANSCRIPT_RETRY_ATTEMPTS) {
                retryRecord.Next_Retry_At__c = Datetime.now().addMinutes(RETRY_DELAY_MINUTES);
            } else {
                retryRecord.Resolved__c = true;
            }
            update retryRecord;
        }
    }

    /// NOTE: field names (date_time, end_time, caller_number, callee_number, direction,
    /// owner.extension_number, download_url) are assumed to mirror the same shape already
    /// confirmed for phone.recording_transcript_completed's payload.object.recordings[] entries.
    /// Confirm against a real captured phone.recording_completed delivery and adjust here if they
    /// differ, the same way the transcript-completed payload shape needed correcting.
    private static Map<String, Object> buildCallMapFromWebhookRecording(Map<String, Object> recording, String callId) {
        String startDateTime = (String) recording.get('date_time');
        String endDateTime = (String) recording.get('end_time');
        String direction = (String) recording.get('direction');
        String toPhoneNumber = (String) recording.get('callee_number');
        String fromPhoneNumber = (String) recording.get('caller_number');

        if (startDateTime == null || endDateTime == null || direction == null
            || toPhoneNumber == null || fromPhoneNumber == null) {
            // Throws (rather than silently returning null, as this used to) so
            // processWebhookRecordingCompleted's existing catch block logs it - this used to be a
            // completely silent failure with no trace anywhere, which is exactly how a
            // phone.recording_completed payload shape mismatch would produce a VoiceCall that
            // never gets created and no error to explain why. Includes the raw recording object so
            // the actual payload shape is visible on the logged record, the same way
            // recording_transcript_completed's shape needed correcting once already.
            throw new CalloutException('Missing required field(s) on phone.recording_completed payload for call_id '
                + callId + '. Raw recording object: ' + JSON.serialize(recording));
        }

        Integer durationInSeconds;
        try {
            Datetime startDt = Datetime.valueOfGmt(startDateTime.replace('T', ' ').replace('Z', ''));
            Datetime endDt = Datetime.valueOfGmt(endDateTime.replace('T', ' ').replace('Z', ''));
            durationInSeconds = (Integer) ((endDt.getTime() - startDt.getTime()) / 1000);
        } catch (Exception e) {
            throw new CalloutException('Could not parse date_time/end_time on phone.recording_completed payload for call_id '
                + callId + '. Raw recording object: ' + JSON.serialize(recording));
        }
        if (durationInSeconds < 10) {
            return null; // legitimate skip (short call) - not a bug, nothing to log
        }

        ZoomConfig__mdt cfg = [SELECT DefaultUserId__c FROM ZoomConfig__mdt WHERE DeveloperName = 'Default' LIMIT 1];
        String userId = cfg.DefaultUserId__c;
        Map<String, Object> owner = (Map<String, Object>) recording.get('owner');
        String extension = owner != null && owner.get('extension_number') != null
            ? String.valueOf(owner.get('extension_number')) : null;
        if (extension != null) {
            Map<String, User> extensionMap = buildUserExtensionMap();
            if (extensionMap.containsKey(extension)) {
                userId = extensionMap.get(extension).Id;
            }
        }

        String mediaProviderId = '123';
        if (!Test.isRunningTest()) {
            CallCoachingMediaProvider mediaProvider = [
                SELECT Id FROM CallCoachingMediaProvider WHERE ProviderName = 'Zoom Phone' LIMIT 1
            ];
            mediaProviderId = mediaProvider.Id;
        }

        Map<String, Object> callMap = new Map<String, Object>();
        callMap.put('startDateTime', startDateTime);
        callMap.put('endDateTime', endDateTime);
        callMap.put('callType', direction.toLowerCase() == 'inbound' ? 'Inbound' : direction.toLowerCase() == 'outbound' ? 'Outbound' : 'Unknown');
        callMap.put('userId', userId);
        callMap.put('toPhoneNumber', toPhoneNumber);
        callMap.put('fromPhoneNumber', fromPhoneNumber);
        callMap.put('recordingDuration', durationInSeconds);
        callMap.put('externalId', callId);
        callMap.put('recordingFormat', 'mp3');
        callMap.put('mediaProviderId', mediaProviderId);
        return callMap;
    }

    public static void processRecordings(String token, List<CallResponse> responses, String fromDateTime, String toDateTime) {
        Agent_Prompt_Trigger__mdt setting = [
            SELECT IsActive__c
            FROM Agent_Prompt_Trigger__mdt
            WHERE DeveloperName = 'ApexAgentActive'
            LIMIT 1
        ];
        // Fetch recordings for the specified timeframe
        List<Map<String, Object>> recordings;
        try {
            recordings = fetchRecordings(token, fromDateTime, toDateTime);
        } catch (Exception e) {
            ZoomIntegrationErrorLogger.log('ZoomPhoneIntegration', 'fetchRecordings', null, null, e);
            throw e;
        }

        if (recordings == null || recordings.isEmpty()) {
            System.debug('No recordings found in the specified timeframe.');
            return;
        }

        // Zoom can return the same physical recording once per call leg (e.g. both legs of an
        // internal-to-internal call share one call_id), so dedupe by call_id before processing -
        // otherwise the transcript gets uploaded and inserted twice against the same VoiceCall.
        Set<String> seenCallIds = new Set<String>();
        List<Map<String, Object>> dedupedRecordings = new List<Map<String, Object>>();
        for (Map<String, Object> recording : recordings) {
            String callId = recording != null ? (String) recording.get('call_id') : null;
            if (callId == null || !seenCallIds.contains(callId)) {
                if (callId != null) {
                    seenCallIds.add(callId);
                }
                dedupedRecordings.add(recording);
            } else {
                System.debug('Skipping duplicate recording for callId: ' + callId);
            }
        }
        recordings = dedupedRecordings;

        // Map CallResponse objects by their externalId for faster lookups
        Map<String, CallResponse> responseMap = new Map<String, CallResponse>();

        for (CallResponse response : responses) {
            if (response.externalId != null && response.isSuccess && response.uploadUrl != null) {
                responseMap.put(response.externalId, response);
            }
        }

        // Each recording's transcript/upload callouts are processed one at a time in chained
        // Queueables (scan phase, then transcript-build phase) instead of in a loop here, so a
        // slow or timed-out callout for one recording gets its own fresh transaction budget
        // instead of sharing the 120s cumulative callout budget with every other recording.
        System.enqueueJob(new ZoomPhoneRecordingScanQueueable(
            token, recordings, 0, responseMap, new Set<String>(), new Set<String>(), setting.IsActive__c
        ));
    }

    /// Per-recording body of the scan phase: fetches the transcript for one recording and
    /// collects the phone numbers/extensions mentioned in it. Called once per recording from
    /// ZoomPhoneRecordingScanQueueable, each in its own transaction.
    public static void scanRecordingForPhoneNumbers(
        Map<String, Object> recording, String token, Map<String, CallResponse> responseMap,
        Set<String> setPhoneFormats, Set<String> setPhoneExtensions
    ) {
        if (recording == null || !recording.containsKey('download_url')) return;

        String callId = (String) recording.get('call_id');
        String fileUrl = (String) recording.get('download_url');
        System.debug('Processing recording with callId: ' + callId + ', fileUrl: ' + fileUrl);

        if (callId == null || fileUrl == null) return;

        if (!responseMap.containsKey(callId)) {
            System.debug('No matching CallResponse found for callId: ' + callId);
            return;
        }

        CallResponse matchedResponse = responseMap.get(callId);
        System.debug('Matched response for callId: ' + callId);

        String transcript = fetchTranscriptFromZoom((String) recording.get('id'), token);
        System.debug('transcript: ' + transcript);
        Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(transcript);
        List<Object> timelineEntries = (List<Object>) parsedData.get('timeline');
        for (Object data : timelineEntries) {
            Map<String, Object> transcriptEntry = (Map<String, Object>) data;
            String userId = (String) transcriptEntry.get('userId');
            if (userId.length() > 5) {
                List<String> phoneFormats = ZoomSMSIntegration.generatePhoneFormats(userId);
                for (String phone : phoneFormats) {
                    setPhoneFormats.add(phone);
                }
            }
            if (userId.length() == 4) {
                setPhoneExtensions.add(userId);
            }
        }
    }

    /// Called by ZoomPhoneRecordingScanQueueable once every recording has been scanned. Builds
    /// the phone/extension lookup maps (SOQL only, no callouts) and kicks off the transcript
    /// build phase.
    public static void finishScanAndStartTranscriptBuild(
        String token, List<Map<String, Object>> recordings, Map<String, CallResponse> responseMap,
        Set<String> setPhoneFormats, Set<String> setPhoneExtensions, Boolean agentPromptActive
    ) {
        Map<String, Account> phoneToAccountIdMap = new Map<String, Account>();
        Map<String, Lead> phoneToLeadIdMap = new Map<String, Lead>();
        Map<String, User> phoneToUserIdMap = new Map<String, User>();

        List<Account> returnedAccount = ZoomSMSIntegration.getRelatedPersonAccountByPhoneNumber(setPhoneFormats);
        List<Lead> returnedLead = ZoomSMSIntegration.getRelatedLeadByPhoneNumber(setPhoneFormats);
        List<User> returnedUser = ZoomSMSIntegration.getRelatedUsersByPhoneNumber(setPhoneFormats);
        List<User> returnedUserExtension = getRelatedUsersByExtension(setPhoneExtensions);

        if (returnedAccount != null) {
            for (Account a : returnedAccount) {
                if (a != null) {
                    phoneToAccountIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(a.phone), a);
                }
            }
        }

        if (returnedLead != null) {
            for (Lead l : returnedLead) {
                if (l != null) {
                    phoneToLeadIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(l.phone), l);
                }
            }
        }

        if (returnedUser != null) {
            for (User u : returnedUser) {
                if (u != null) {
                    phoneToUserIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(u.phone), u);
                }
            }
        }

        if (returnedUserExtension != null) {
            for (User u : returnedUserExtension) {
                if (u.extension != null) {
                    system.debug('Extension: ' + u.extension + 'for user:' + u.name);
                    phoneToUserIdMap.put(u.Extension, u);
                }
            }
        }

        System.enqueueJob(new ZoomPhoneTranscriptBuildQueueable(
            token, recordings, 0, responseMap, phoneToAccountIdMap, phoneToLeadIdMap, phoneToUserIdMap,
            new List<Call_Transcript__c>(), agentPromptActive
        ));
    }

    /// Per-recording body of the transcript-build phase: uploads the audio, fetches the
    /// transcript for one recording, and builds its Call_Transcript__c record(s). Called once
    /// per recording from ZoomPhoneTranscriptBuildQueueable, each in its own transaction.
    public static List<Call_Transcript__c> buildTranscriptForRecording(
        Map<String, Object> recording, String token, Map<String, CallResponse> responseMap,
        Map<String, Account> phoneToAccountIdMap, Map<String, Lead> phoneToLeadIdMap, Map<String, User> phoneToUserIdMap
    ) {
        List<Call_Transcript__c> result = new List<Call_Transcript__c>();
        if (recording == null || !recording.containsKey('download_url')) return result;

        String callId = (String) recording.get('call_id');
        String fileUrl = (String) recording.get('download_url');
        System.debug('Processing recording with callId: ' + callId + ', fileUrl: ' + fileUrl);

        if (callId == null || fileUrl == null) return result;

        if (!responseMap.containsKey(callId)) {
            System.debug('No matching CallResponse found for callId: ' + callId);
            return result;
        }

        CallResponse matchedResponse = responseMap.get(callId);
        System.debug('Matched response for callId: ' + callId);

        if (transcriptAlreadyExistsForVoiceCall(matchedResponse.voiceCallId)) {
            System.debug('Transcript already exists for VoiceCall ' + matchedResponse.voiceCallId + ' - skipping duplicate');
            return result;
        }

        // Upload and transcript are independent Zoom operations - a failure uploading the audio
        // (e.g. FILE_SIZE_LIMIT_EXCEEDED, or Salesforce being unable to fetch it from Zoom) used to
        // throw here and abort the whole method, losing a transcript that would otherwise have
        // fetched fine. Isolate it so it can't block the transcript fetch below - but logging it
        // has to wait until after that callout too (DML immediately followed by a callout in the
        // same transaction throws "You have uncommitted work pending").
        Exception uploadError;
        try {
            uploadRecording(matchedResponse.uploadUrl, fileUrl);
        } catch (Exception e) {
            uploadError = e;
        }

        String transcript;
        try {
            transcript = fetchTranscriptFromZoom((String) recording.get('id'), token);
        } finally {
            if (uploadError != null) {
                ZoomIntegrationErrorLogger.log('ZoomPhoneIntegration', 'uploadRecording', null, callId, uploadError);
            }
        }
        System.debug('transcript: ' + transcript);
        Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(transcript);
        List<Object> timelineEntries = (List<Object>) parsedData.get('timeline');
        String transcriptBody = formatTranscriptBody(timelineEntries, phoneToAccountIdMap, phoneToLeadIdMap, phoneToUserIdMap);

        System.debug('transcriptBody Length: ' + transcriptBody.length());
        result.addAll(processTranscript(transcriptBody, matchedResponse.voiceCallId));
        return result;
    }

    private static String formatTranscriptBody(
        List<Object> timelineEntries, Map<String, Account> phoneToAccountIdMap,
        Map<String, Lead> phoneToLeadIdMap, Map<String, User> phoneToUserIdMap
    ) {
        String transcriptBody = '';
        for (Object data : timelineEntries) {
            Map<String, Object> transcriptEntry = (Map<String, Object>) data;
            String text = (String) transcriptEntry.get('text');
            String userId = (String) transcriptEntry.get('userId');
            String userName = userId;
            if (phoneToAccountIdMap.containsKey(userId)) {
                userName = phoneToAccountIdMap.get(userId).Name;
            } else if (phoneToLeadIdMap.containsKey(userId)) {
                userName = phoneToLeadIdMap.get(userId).Name;
            } else if (phoneToUserIdMap.containsKey(userId)) {
                userName = phoneToUserIdMap.get(userId).Name;
            } else {
                userName = userId + ', ';
            }
            transcriptBody += 'User: ' + userName + '\r\n' + 'text: ' + text + '\r\n' + '\r\n';
        }
        return transcriptBody;
    }

    private static final Integer MAX_TRANSCRIPT_RETRY_ATTEMPTS = 5;
    private static final Integer RETRY_DELAY_MINUTES = 20;

    /// Picks up recordings that previously failed with Zoom error 12002 ("still being
    /// transcribed") and are now due for another attempt, per Zoom_Integration_Error__c's
    /// Next_Retry_At__c. Called from the Schedulable's execute() (not from within the main sync's
    /// Queueable chain) so it always gets its own System.enqueueJob call regardless of how many
    /// recordings the main sync is processing.
    public static void retryPendingTranscripts() {
        List<Zoom_Integration_Error__c> dueRetries = [
            SELECT Id, Recording_Id__c, Voice_Call_Id__c, Retry_Count__c, Zoom_Meeting_Id__c
            FROM Zoom_Integration_Error__c
            WHERE Resolved__c = false AND Recording_Id__c != null AND Next_Retry_At__c <= :Datetime.now()
            ORDER BY Next_Retry_At__c ASC
            LIMIT 50
        ];

        if (dueRetries.isEmpty()) {
            return;
        }

        // Token fetch is deferred to the Queueable itself, not done here - Scheduled Apex's
        // execute() doesn't allow synchronous callouts ("Callout from scheduled Apex not
        // supported"), and this method is called directly from a Schedulable's execute()
        // (both ZoomPhoneIntegration's own and ZoomPhoneTranscriptRetrySchedulable's).
        System.enqueueJob(new ZoomPhoneTranscriptRetryQueueable(null, dueRetries, 0));
    }

    /// Per-recording body of the retry pass: re-fetches the transcript for one previously
    /// "not ready" recording, or one whose VoiceCall didn't exist yet when a webhook first
    /// reported the transcript ready (resolved here from Zoom_Meeting_Id__c, the call id, since
    /// Voice_Call_Id__c may still be blank in that case). On another 12002 or a still-missing
    /// VoiceCall, reschedules Next_Retry_At__c up to MAX_TRANSCRIPT_RETRY_ATTEMPTS times; on
    /// success or any other error, marks the retry resolved. Called once per pending retry from
    /// ZoomPhoneTranscriptRetryQueueable, each in its own transaction.
    public static void processTranscriptRetry(Zoom_Integration_Error__c retryRecord, String token) {
        try {
            String voiceCallId = String.isNotBlank(retryRecord.Voice_Call_Id__c)
                ? retryRecord.Voice_Call_Id__c
                : resolveVoiceCallId(retryRecord.Zoom_Meeting_Id__c);

            if (transcriptAlreadyExistsForVoiceCall(voiceCallId)) {
                retryRecord.Resolved__c = true;
                update retryRecord;
                return;
            }

            String transcript = fetchTranscriptFromZoom(retryRecord.Recording_Id__c, token);
            List<Call_Transcript__c> transcripts = buildTranscriptFromTimeline(transcript, voiceCallId);
            upsertCallTranscripts(transcripts, false);

            retryRecord.Resolved__c = true;
            update retryRecord;
        } catch (Exception e) {
            Integer attempts = (retryRecord.Retry_Count__c != null ? retryRecord.Retry_Count__c.intValue() : 0) + 1;
            Boolean stillRetryable = (e.getMessage() != null && e.getMessage().contains('"code":12002'))
                || e instanceof VoiceCallNotFoundException;

            // Update the same tracked row rather than also calling ZoomIntegrationErrorLogger.log
            // here - that used to insert a brand new Zoom_Integration_Error__c record on every
            // failed attempt (not just the final give-up), so one stuck call retried several times
            // produced several extra rows on top of the one real tracking row.
            retryRecord.Retry_Count__c = attempts;
            retryRecord.Error_Message__c = e.getMessage();
            retryRecord.Stack_Trace__c = e.getStackTraceString();
            if (stillRetryable && attempts < MAX_TRANSCRIPT_RETRY_ATTEMPTS) {
                retryRecord.Next_Retry_At__c = Datetime.now().addMinutes(RETRY_DELAY_MINUTES);
            } else {
                retryRecord.Resolved__c = true;
            }
            update retryRecord;
        }
    }

    /// Entry point for ZoomPhoneWebhookHandler's phone.recording_transcript_completed events.
    /// Zoom typically finishes transcribing within minutes of a call ending, but the call-metadata
    /// poll (runZoomDataSync) that creates each call's VoiceCall only looks 60-90 minutes back - so
    /// this webhook will routinely fire before that VoiceCall exists yet, not just on rare races.
    /// When that happens, resolveVoiceCallId throws VoiceCallNotFoundException, which
    /// ZoomIntegrationErrorLogger treats as retryable so retryPendingTranscripts picks it back up
    /// once the metadata poll has caught up. Called from ZoomPhoneWebhookQueueable, not directly
    /// from the REST handler, so the inbound webhook request itself doesn't wait on this callout.
    public static void processWebhookTranscriptReady(String recordingId, String callId, String token) {
        try {
            String voiceCallId = resolveVoiceCallId(callId);

            if (transcriptAlreadyExistsForVoiceCall(voiceCallId)) {
                System.debug('Transcript already exists for VoiceCall ' + voiceCallId + ' (call ' + callId + ') - skipping duplicate');
                return;
            }

            String transcript = fetchTranscriptFromZoom(recordingId, token);
            List<Call_Transcript__c> transcripts = buildTranscriptFromTimeline(transcript, voiceCallId);
            upsertCallTranscripts(transcripts, false);
        } catch (Exception e) {
            ZoomIntegrationErrorLogger.log(
                'ZoomPhoneIntegration', 'processWebhookTranscriptReady', null, callId, e, recordingId, null
            );
        }
    }

    private static String resolveVoiceCallId(String callId) {
        List<VoiceCall> matches = callId != null
            ? [SELECT Id FROM VoiceCall WHERE VendorCallKey = :callId LIMIT 1]
            : new List<VoiceCall>();
        if (matches.isEmpty()) {
            throw new VoiceCallNotFoundException('No VoiceCall found yet for call_id ' + callId);
        }
        return matches[0].Id;
    }

    /// Guards every transcript-build entry point (poll, retry, webhook) against creating a second
    /// Call_Transcript__c for the same VoiceCall - all three can independently end up processing
    /// the same recording (an overlapping poll window, a retry racing a later poll, or a webhook
    /// firing for a call the poll already handled).
    private static Boolean transcriptAlreadyExistsForVoiceCall(String voiceCallId) {
        return voiceCallId != null
            && ![SELECT Id FROM Call_Transcript__c WHERE Voice_Call__c = :voiceCallId LIMIT 1].isEmpty();
    }

    public class VoiceCallNotFoundException extends Exception {}

    /// Builds Call_Transcript__c record(s) for one recording's transcript outside the normal
    /// batch-sync flow, resolving phone-to-name lookups just for this recording rather than reusing
    /// the whole batch's pre-built maps (finishScanAndStartTranscriptBuild). Used by the retry path,
    /// where a single recording is processed on its own.
    private static List<Call_Transcript__c> buildTranscriptFromTimeline(String transcript, String voiceCallId) {
        Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(transcript);
        List<Object> timelineEntries = (List<Object>) parsedData.get('timeline');

        Set<String> setPhoneFormats = new Set<String>();
        Set<String> setPhoneExtensions = new Set<String>();
        for (Object data : timelineEntries) {
            Map<String, Object> entry = (Map<String, Object>) data;
            String userId = (String) entry.get('userId');
            if (userId == null) continue;
            if (userId.length() > 5) {
                setPhoneFormats.addAll(ZoomSMSIntegration.generatePhoneFormats(userId));
            } else if (userId.length() == 4) {
                setPhoneExtensions.add(userId);
            }
        }

        Map<String, Account> phoneToAccountIdMap = new Map<String, Account>();
        Map<String, Lead> phoneToLeadIdMap = new Map<String, Lead>();
        Map<String, User> phoneToUserIdMap = new Map<String, User>();

        List<Account> returnedAccount = ZoomSMSIntegration.getRelatedPersonAccountByPhoneNumber(setPhoneFormats);
        List<Lead> returnedLead = ZoomSMSIntegration.getRelatedLeadByPhoneNumber(setPhoneFormats);
        List<User> returnedUser = ZoomSMSIntegration.getRelatedUsersByPhoneNumber(setPhoneFormats);
        List<User> returnedUserExtension = getRelatedUsersByExtension(setPhoneExtensions);

        if (returnedAccount != null) {
            for (Account a : returnedAccount) {
                if (a != null) {
                    phoneToAccountIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(a.phone), a);
                }
            }
        }
        if (returnedLead != null) {
            for (Lead l : returnedLead) {
                if (l != null) {
                    phoneToLeadIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(l.phone), l);
                }
            }
        }
        if (returnedUser != null) {
            for (User u : returnedUser) {
                if (u != null) {
                    phoneToUserIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(u.phone), u);
                }
            }
        }
        if (returnedUserExtension != null) {
            for (User u : returnedUserExtension) {
                if (u.extension != null) {
                    phoneToUserIdMap.put(u.Extension, u);
                }
            }
        }

        String transcriptBody = formatTranscriptBody(timelineEntries, phoneToAccountIdMap, phoneToLeadIdMap, phoneToUserIdMap);
        return processTranscript(transcriptBody, voiceCallId);
    }

    /// Called by ZoomPhoneTranscriptBuildQueueable once every recording has been processed.
    /// Upserts the accumulated Call_Transcript__c records and, when the agent prompt trigger is
    /// active, hands the successfully saved ones off for evaluation.
    public static void upsertCallTranscripts(List<Call_Transcript__c> transcripts, Boolean agentPromptActive) {
        if (transcripts.isEmpty()) return;

        Database.UpsertResult[] saveResults = Database.upsert(transcripts, false);

        List<Call_Transcript__c> successfullySaved = new List<Call_Transcript__c>();

        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.UpsertResult sr = saveResults[i];
            Call_Transcript__c t = transcripts[i];

            if (sr.isSuccess()) {
                if (t.Id == null) {
                    t.Id = sr.getId();
                }
                successfullySaved.add(t);
            } else {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('❌ Upsert failed for transcript ' + t.Name + ': ' + err.getMessage());
                }
            }
        }

        if (agentPromptActive) {
            if (!successfullySaved.isEmpty()) {
                for (Call_Transcript__c ctranscript : successfullySaved) {
                    //String promptResponse = CallTranscriptEvaluatorService.evaluateTranscript(ctranscript.Id);
                    //System.debug('✅ Evaluated transcript ' + ctranscript.Id + ': ' + promptResponse);
                }
            } else {
                System.debug('⚠️ No transcripts were successfully saved. Skipping evaluation.');
            }
        }
    }

    private static final Integer MAX_LENGTH = 131071;

    public static List<Call_Transcript__c> processTranscript(String transcriptBody, string callId) {
        List<Call_Transcript__c> transcripts = new List<Call_Transcript__c>();
        Integer totalLength = transcriptBody.length();
        Integer startIndex = 0;
        Integer sequenceNumber = 1;
        
        while (startIndex < totalLength) {
            Integer endIndex = Math.min(startIndex + MAX_LENGTH, totalLength);
            String text = transcriptBody.substring(startIndex, endIndex);
            
            Call_Transcript__c transcriptRecord = new Call_Transcript__c();
            transcriptRecord.Voice_Call__c = callId;
            transcriptRecord.Transcript_Text__c = text;
            transcriptRecord.Transcript_Sequence__c = sequenceNumber;
            transcripts.add(transcriptRecord);
            
            startIndex = endIndex;
            sequenceNumber++;
        }
        
        // if (!transcripts.isEmpty()) {
            return transcripts;
        // }
    }

    public static User getSMSInternalUser(String userName){
        system.debug('userName'+ userName);
        return [SELECT Id, Name, Username FROM User WHERE Name =: userName];
    }

    public static List<Account> getRelatedPersonAccountByPhoneNumber(Set<String> phoneFormats){
        List<Account> accounts = [SELECT Id, Name, Phone FROM Account WHERE Phone IN: phoneFormats];
        return (accounts.isEmpty()) ? null : accounts; // Returns first matching accounts or null
    }

    public static List<Lead> getRelatedLeadByPhoneNumber(Set<String> phoneFormats){
        List<Lead> leads = [SELECT Id, Name, Phone FROM lead WHERE Phone IN: phoneFormats];
        return (leads.isEmpty()) ? null : leads; // Returns first matching leads or null
    }

    public static List<User> getRelatedUsersByPhoneNumber(Set<String> phoneFormats){
        List<User> Users = [SELECT Id, Name, Phone FROM User WHERE Phone IN: phoneFormats];
        return (Users.isEmpty()) ? null : Users; // Returns first matching users or null
    }

    public static List<User> getRelatedUsersByName(Set<String> names){
        List<User> Users = [SELECT Id, Name, Phone FROM User WHERE Name IN: names];
        return (Users.isEmpty()) ? null : Users; // Returns first matching users or null
    }

    public static String fetchTranscriptFromZoom(String recordingId, String token) {
        // recordingId = 'vMOoZ2xwQU6rxV93NT5veA';
        System.debug('recordingId in fetchTranscriptFromZoom: ' + recordingId);
        String transcriptUrl = 'https://api.zoom.us/v2/phone/recording_transcript/download/' + recordingId;
        System.debug('transcriptUrl fetchTranscriptFromZoom: ' + transcriptUrl);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(transcriptUrl);
        req.setTimeout(120000); // Set timeout to 120 seconds
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setMethod('GET'); 
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('res1: '+ res.getHeader('location'));
        if (res.getStatusCode() == 302) {
            req.setEndpoint(res.getHeader('location'));
            res = http.send(req);
            System.debug('res2: '+ res.getBody());
            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                throw new CalloutException('Error fetching transcript: ' + res.getBody());
            }
        } else {
            throw new CalloutException('Error fetching transcript: ' + res.getBody());
        }
    }

    public static List<Map<String, Object>> fetchRecordings(String token, String fromDateTime, String toDateTime, String nextPageToken, List<Map<String, Object>> aggregatedRecordings) {
        try {
            // Build the query parameters
            String endpoint = 'https://api.zoom.us/v2/phone/recordings';
            String queryParams = 'page_size=300';
            queryParams += '&from=' + EncodingUtil.urlEncode(fromDateTime, 'UTF-8');
            queryParams += '&to=' + EncodingUtil.urlEncode(toDateTime, 'UTF-8');
            
            if (nextPageToken != null) {
                queryParams += '&next_page_token=' + EncodingUtil.urlEncode(nextPageToken, 'UTF-8');
            }
    
            // Setup the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint + '?' + queryParams);
            req.setTimeout(120000); // Set timeout to 120 seconds
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + token);
    
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
    
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    
                // Extract and aggregate recordings
                List<Object> currentPageRecordings = new List<Object>();
                if (responseMap.containsKey('recordings') && responseMap.get('recordings') != null) {
                    currentPageRecordings = (List<Object>) responseMap.get('recordings');
                    for (Object rawRecording : currentPageRecordings) {
                        if (rawRecording instanceof Map<String, Object>) {
                            aggregatedRecordings.add((Map<String, Object>) rawRecording);
                        }
                    }
                }
    
                // Debugging
                System.debug('Current Page Recordings: ' + currentPageRecordings.size());
                System.debug('next_page_token: ' + responseMap.get('next_page_token'));
    
                // Get next page token if available
                String newNextPageToken = responseMap.containsKey('next_page_token') ? (String) responseMap.get('next_page_token') : null;
    
                // Exit condition: If fewer than 300 records and no next page token, stop recursion
                if (currentPageRecordings.size() < 300) {
                    System.debug('Last page reached with ' + currentPageRecordings.size() + ' records.');
                    return aggregatedRecordings;
                }
    
                // Continue fetching if there's more data
                return fetchRecordings(token, fromDateTime, toDateTime, newNextPageToken, aggregatedRecordings);
            } else {
                throw new CalloutException('Error fetching recordings: ' + res.getBody());
            }
        } catch (Exception ex) {
            System.debug('Exception while fetching recordings: ' + ex.getMessage());
            throw ex;
        }
    }
    
    // Overloaded method to initialize the recursive call
    public static List<Map<String, Object>> fetchRecordings(String token, String fromDateTime, String toDateTime) {
        return fetchRecordings(token, fromDateTime, toDateTime, null, new List<Map<String, Object>>());
    }      

    public static String uploadRecording(String uploadUrl, String recordingUrl) {
        try {
            // Boundary definition for multipart/form-data
            String boundary = '---------------------------audioBoundary';
            String lineBreak = '\r\n';
            recordingUrl = '/' + stripBaseUrl(recordingUrl, 'https://zoom.us');
    
            // Prepare the form-data body
            String body = '--' + boundary + lineBreak +
                          'Content-Disposition: form-data; name="recordingURL"' + lineBreak + lineBreak +
                          recordingUrl + lineBreak + // Pass the recording URL or relative path
                          '--' + boundary + lineBreak +
                          'Content-Disposition: form-data; name="name"' + lineBreak + lineBreak +
                          'Zoom_Phone' + lineBreak + // Pass the literal string "namedCredential"
                          '--' + boundary + '--' + lineBreak;
    
            // Set up HTTP request - uploadUrl comes back as an absolute URL (its domain isn't
            // guaranteed to match URL.getOrgDomainUrl()'s exact form - Salesforce can hand back a
            // different canonical form for the same org), so route it through
            // ZoomWebhooksNamedCredentials by path alone rather than trying to strip a specific
            // domain prefix. See the note on sendCallBatchToECI for why this replaces
            // UserInfo.getSessionId().
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:ZoomWebhooksNamedCredentials' + extractServicesPath(uploadUrl));
            req.setMethod('POST');
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            req.setTimeout(120000);
            req.setBody(body);

            // Send HTTP request
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('Response: ' + res.getStatusCode());

            // Handle the response
            if (res.getStatusCode() == 204) {
                return 'Audio uploaded successfully';
            } else {
                throw new CalloutException('Failed to upload audio. Status: ' + res.getStatusCode() + ', Response: ' + res.getBody() + '. uploadUrl was: ' + uploadUrl);
            }
        } catch (Exception ex) {
            throw new CalloutException('Error during audio upload: ' + ex.getMessage());
        }
    }

    /// Extracts the "/services/..." path (and anything after it) from an absolute URL, so it can
    /// be appended straight to a "callout:NamedCredentialName" prefix regardless of exactly which
    /// domain form Salesforce used for the absolute URL it handed back.
    private static String extractServicesPath(String absoluteUrl) {
        Integer servicesIndex = absoluteUrl.indexOf('/services/');
        if (servicesIndex == -1) {
            throw new CalloutException('Could not find /services/ path in URL: ' + absoluteUrl);
        }
        return absoluteUrl.substring(servicesIndex);
    }

    public static String stripBaseUrl(String fullUrl, String baseUrl) {
        // Ensure baseUrl has a trailing slash for consistency
        if (!baseUrl.endsWith('/')) {
            baseUrl += '/';
        }
    
        // Remove the baseUrl if fullUrl starts with it
        if (fullUrl.startsWith(baseUrl)) {
            return fullUrl.substring(baseUrl.length());
        } else {
            // Return fullUrl unmodified if baseUrl is not a match
            return fullUrl;
        }
    }
    

    private static Map<String, User> buildUserMap() {
        Map<String, User> userMap = new Map<String, User>();
        
        // Query Salesforce User object for Zoom User IDs
        List<User> users = [
            SELECT Id, Name, Phone, MobilePhone
            FROM User
            WHERE IsActive = true AND ContactId = null
        ];
    
        for (User user : users) {
            userMap.put(user.Name, user);
        }
    
        return userMap;
    }

    private static Map<String, User> buildUserExtensionMap() {
        Map<String, User> extensionMap = new Map<String, User>();

        List<User> users = [
            SELECT Id, Name, Phone, MobilePhone, Extension
            FROM User
            WHERE IsActive = true AND ContactId = null AND Extension != null
        ];

        for (User user : users) {
            extensionMap.put(user.Extension, user);
        }

        return extensionMap;
    }

    public static List<User> getRelatedUsersByExtension(Set<String> extension){
        List<User> Users = [SELECT Id, Name, Phone, Extension FROM User WHERE Extension IN: extension];
        return (Users.isEmpty()) ? null : Users; // Returns first matching users or null
    }
    
    // Response class to handle individual call results
    public class CallResponse {
        public String externalId;   // External ID of the call
        public String voiceCallId;  // VoiceCall ID created in Salesforce
        public String uploadUrl;    // Upload URL for the audio file
        public Boolean isSuccess;   // Success status
        public String errorMsg;     // Error message if any
    }

    public class ZoomTranscript {
        // public String type;
        // public Integer ver;
        // public String recording_id;
        // public String meeting_id;
        // public String account_id;
        // public String host_id;
        // public Datetime recording_start;
        // public Datetime recording_end;
        public List<Timeline> timeline;
    }
    // Inner class to represent the "timeline" array
    public class Timeline {
        public String text;
    //     public String raw_text;
    //     public Time ts;
    //     public Time end_ts;
        // public List<String> users; // Assuming users is an array of user IDs or strings
        public String userId;
        // public List<String> userIds; // Assuming userIds is a list of strings (user phone extensions)
    //     public String channelMark;
    }
    
}