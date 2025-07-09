public with sharing class ZoomPhoneIntegration implements Schedulable {

    public void execute(SchedulableContext ctx) {
        sendZoomDataToSalesforce();
    }

    @future(callout=true)
    public static void sendZoomDataToSalesforce() {
        String clientId = 'OlTvfeKSCuXyENCswlexQ';
        String clientSecret = 'mJQ2SXpsBABlord50hHQVj7l40tLg3n9';
        String accountId = 'Af5TohNeQKiIODcnyFCOyQ';

        // Step 1: Get Zoom OAuth Token
        String zoomToken = getZoomToken(clientId, clientSecret, accountId);
        System.debug('Zoom Token: ' + zoomToken);
        
        // Step 2: Fetch Call Logs
        Datetime now = Datetime.now(); // Current datetime
        String toDateTime = now.addHours(-1).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 1 hour ago
        String fromDateTime = now.addHours(-1).addMinutes(-30).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 1.5 hours ago
        String zoomJson = fetchZoomCallHistory(zoomToken, fromDateTime, toDateTime);
        System.debug('Zoom JSON: ' + zoomJson);

        // Step 3: Transform Zoom Data
        String salesforceJson = transformZoomData(zoomJson);
        System.debug('Salesforce JSON: ' + salesforceJson);

        // Step 4: Send Call Metadata to Salesforce
        List<CallResponse> responses = sendCallMetadataToECI(salesforceJson);
        System.debug('Call Metadata Responses: ' + responses);

        // Step 5: Fetch and Upload Recordings
        processRecordings(zoomToken, responses, fromDateTime, toDateTime);
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
    
    public static String transformZoomData(String zoomJson) {
        // Step 1: Build a Map of Salesforce User IDs
        Map<String, User> userNameToIdMap = buildUserMap();
        
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
            System.debug('log transformZoomData '+ log);
            Map<String, Object> call = (Map<String, Object>) log;
            System.debug('call transformZoomData '+ call);
    
            // Map Zoom user to Contact user ID
            String userName = null;
            string contactName = null;
    
            if (call.containsKey('caller_name') && call.get('caller_name') != null && String.valueOf(call.get('direction')).toLowerCase() == 'outbound') {
                contactName = String.valueOf(call.get('caller_name'));
                contactNameToContactMap.put(contactName, new List<string>());
            } else if (call.containsKey('direction') && String.valueOf(call.get('direction')).toLowerCase() == 'inbound' &&
                       call.containsKey('callee_name') && call.get('callee_name') != null) {
                contactName = String.valueOf(call.get('callee_name'));
                contactNameToContactMap.put(contactName, new List<string>());
            }

            for(Account a: [SELECT Id, Phone, PersonMobilePhone, Name FROM Account WHERE Phone != null AND Name IN: contactNameToContactMap.keySet() ]){
                system.debug('ACCOUNT IN LOOP: '+ a);
                if(a.Phone != null){
                    contactNameToContactMap.get(a.name).add(a.phone);
                }
                else if(a.PersonMobilePhone != null){
                    contactNameToContactMap.get(a.name).add(a.PersonMobilePhone);
                }
            }

            for(Lead a: [SELECT Id, Phone, Name FROM Lead WHERE Phone != null AND Name IN: contactNameToContactMap.keySet() ]){
                system.debug('Lead IN LOOP: '+ a);
                contactNameToContactMap.get(a.name).add(a.phone);
            }

            for(Contact a: [SELECT Id, Phone, MobilePhone, Name FROM Contact WHERE Phone != null AND Name IN: contactNameToContactMap.keySet() ]){
                system.debug('Contact IN LOOP: '+ a);
                if(a.phone != null){
                    contactNameToContactMap.get(a.name).add(a.phone);
                }
                else if(a.MobilePhone != null){
                    contactNameToContactMap.get(a.name).add(a.MobilePhone);
                }
            }
        }
    /////////////
        for (Object log : callLogs) {
            System.debug('log transformZoomData '+ log);
            Map<String, Object> call = (Map<String, Object>) log;
            System.debug('call transformZoomData '+ call);
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
            string contactName = null;
    
            if (call.containsKey('caller_name') && call.get('caller_name') != null && String.valueOf(call.get('direction')).toLowerCase() == 'outbound') {
                userName = String.valueOf(call.get('caller_name'));
                contactName = String.valueOf(call.get('caller_name'));
            } else if (call.containsKey('direction') && String.valueOf(call.get('direction')).toLowerCase() == 'inbound' &&
                       call.containsKey('callee_name') && call.get('callee_name') != null) {
                userName = String.valueOf(call.get('callee_name'));
                contactName = String.valueOf(call.get('caller_name'));
            }
    
            if (userName != null) {
                if(userNameToIdMap.containsKey(userName)){
                    String salesforceUserId = userNameToIdMap.get(userName).Id;
                    System.debug('userName: '+ userName + ' in map: '+ userNameToIdMap.get(userName).Id);
                    if (salesforceUserId != null) {
                        formattedCall.put('userId', salesforceUserId);
                    } else {
                        System.debug('Skipping record due to missing Salesforce user for Zoom user: ' + userName);
                        continue; // Skip this record
                    }
                }
                
            } else {
                System.debug('Skipping record due to missing external ID (caller_ext_id or callee_ext_id): ' + call);
                continue; // Skip this record
            }
            
            System.debug('toPhoneNumber callee_did_number: '+ call.get('callee_did_number'));
            System.debug('callee_name callee_name: '+ call.get('callee_name'));
            System.debug('fromPhoneNumber caller_did_number: '+ call.get('caller_did_number'));
            System.debug('caller_name caller_name: '+ call.get('caller_name'));
            System.debug('direction direction: '+ call.get('direction'));

            
            string toPhoneNumber = String.valueOf(call.get('callee_did_number'));
            System.debug('toPhoneNumber BEFORE: '+ toPhoneNumber);
            
            string fromPhoneNumber = String.valueOf(call.get('caller_did_number'));
            System.debug('fromPhoneNumber BEFORE: '+ fromPhoneNumber);

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

            System.debug('toPhoneNumber AFTER: '+ toPhoneNumber);
            System.debug('fromPhoneNumber AFTER: '+ fromPhoneNumber);
            // Map other fields
            // formattedCall.put('toPhoneNumber', call.get('callee_did_number'));
            // formattedCall.put('fromPhoneNumber', call.get('caller_did_number'));
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
    
            // Reconstruct the filtered JSON payload
            Map<String, Object> filteredInputMap = new Map<String, Object>();
            filteredInputMap.put('calls', filteredCalls);
            String filteredJsonInput = JSON.serialize(filteredInputMap);
    
            // Construct the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/voicecalls');
            req.setMethod('POST');
            req.setTimeout(120000); // Set timeout to 120 seconds
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setHeader('Content-Type', 'application/json');
            req.setBody(filteredJsonInput);
    
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

        return responseList;
    }
    
    public static void processRecordings(String token, List<CallResponse> responses, String fromDateTime, String toDateTime) {
        // Fetch recordings for the specified timeframe
        List<Map<String, Object>> recordings = fetchRecordings(token, fromDateTime, toDateTime);
        List<Call_Transcript__c> transcripts = new List<Call_Transcript__c>();
    
        if (recordings == null || recordings.isEmpty()) {
            System.debug('No recordings found in the specified timeframe.');
            return;
        }
    
        // Map CallResponse objects by their externalId for faster lookups
        Map<String, CallResponse> responseMap = new Map<String, CallResponse>();

        for (CallResponse response : responses) {
            if (response.externalId != null && response.isSuccess && response.uploadUrl != null) {
                responseMap.put(response.externalId, response);
            }
        }
        
        Map<String, Account> phoneToAccountIdMap = new Map<String, Account>();
        Map<String, Lead> phoneToLeadIdMap = new Map<String, Lead>();
        Map<String, User> phoneToUserIdMap = new Map<String, User>();
        
        Set<string> setPhoneFormats = new Set<String>();
        Set<string> setPhoneExtensions = new Set<String>();
        //Set<string> setAllNames = new Set<String>();

        /// get maps of Users based on phone number
        for (Map<String, Object> recording : recordings) {
            try {
                if (recording == null || !recording.containsKey('download_url')) continue;
    
                String callId = (String) recording.get('call_id');
                String fileUrl = (String) recording.get('download_url');
                System.debug('Processing recording with callId: ' + callId + ', fileUrl: ' + fileUrl);
    
                if (callId == null || fileUrl == null) continue;
    
                String transcriptBody = '';
                // Match the recording to a CallResponse using callId
                if (responseMap.containsKey(callId)) {
                    CallResponse matchedResponse = responseMap.get(callId);
                    System.debug('Matched response for callId: ' + callId);
    
                    // uploadRecording(matchedResponse.uploadUrl, fileUrl);
                    String transcript = fetchTranscriptFromZoom((String) recording.get('id'), token);
                    System.debug('transcript: ' + transcript);
                    // get the body of the transcript
                    Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(transcript);
                    system.debug('parsedData'+ parsedData.get('timeline'));
                    List<Object> timelineEntries = (List<Object>) parsedData.get('timeline');
                    for(Object data: timelineEntries){

                        system.debug('data text'+ data);
                        Map<String, Object> transcriptEntry = (Map<String, Object>) data;
                        String userId = (String) transcriptEntry.get('userId');
                        system.debug('userId:'+ userId);
                        string userName = userId;
                        if(userId.length() > 5){
                            List<String> phoneFormats = ZoomSMSIntegration.generatePhoneFormats(userId);
                            system.debug('phoneFormats'+ phoneFormats);
                            for(string phone: phoneFormats){
                                setPhoneFormats.add(phone);
                            }
                        }
                        if(userId.length() == 4){
                            setPhoneExtensions.add(userId);
                        }
                    }
                } else {
                    System.debug('No matching CallResponse found for callId: ' + callId);
                }
            } catch (Exception ex) {
                System.debug('Error processing recording: ' + ex.getMessage());
            }
        }

        List<Account> returnedAccount = ZoomSMSIntegration.getRelatedPersonAccountByPhoneNumber(setPhoneFormats) != null 
            ? ZoomSMSIntegration.getRelatedPersonAccountByPhoneNumber(setPhoneFormats) 
            : new List<Account>();

        List<Lead> returnedLead = ZoomSMSIntegration.getRelatedLeadByPhoneNumber(setPhoneFormats) != null 
            ? ZoomSMSIntegration.getRelatedLeadByPhoneNumber(setPhoneFormats) 
            : new List<Lead>();

        List<User> returnedUser = ZoomSMSIntegration.getRelatedUsersByPhoneNumber(setPhoneFormats) != null 
            ? ZoomSMSIntegration.getRelatedUsersByPhoneNumber(setPhoneFormats) 
            : new List<User>();

        List<User> returnedUserExtension = getRelatedUsersByExtension(setPhoneExtensions) != null 
            ? getRelatedUsersByExtension(setPhoneExtensions) 
            : new List<User>();

        system.debug('returnedAccount'+ returnedAccount.size());
        system.debug('returnedLead'+ returnedLead.size());
        system.debug('returnedUser'+ returnedUser.size());
        if(returnedAccount.size() > 0){
            for(Account a: returnedAccount){
                if(a != null){
                    phoneToAccountIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(a.phone), a);
                }
            }
        }
        
        if(returnedLead.size() > 0){
            for(Lead l: returnedLead){
                if(l != null ){
                    phoneToLeadIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(l.phone), l);
                }
            }
        }

        if(returnedUser.size() > 0){
            for(User u: returnedUser){
                if(u != null){
                    phoneToUserIdMap.put(ZoomSMSIntegration.removePhoneNumberFormat(u.phone), u);
                }
            }
        }

         if(returnedUserExtension.size() > 0){
            for(User u: returnedUserExtension){
                if(u.extension != null){
                    system.debug('Extension: '+ u.extension + 'for user:'+ u.name);
                    phoneToUserIdMap.put(u.Extension, u);
                }
            }
        }

        // Process each recording
        for (Map<String, Object> recording : recordings) {
            try {
                if (recording == null || !recording.containsKey('download_url')) continue;
    
                String callId = (String) recording.get('call_id');
                String fileUrl = (String) recording.get('download_url');
                String transcriptUrl = (String) recording.get('transcript_download_url');
                System.debug('transcriptUrl: ' + transcriptUrl);
                System.debug('Processing recording with callId: ' + callId + ', fileUrl: ' + fileUrl);
    
                if (callId == null || fileUrl == null) continue;
    
                String transcriptBody = '';
                // Match the recording to a CallResponse using callId
                if (responseMap.containsKey(callId)) {
                    CallResponse matchedResponse = responseMap.get(callId);
                    System.debug('Matched response for callId: ' + callId);
    
                    uploadRecording(matchedResponse.uploadUrl, fileUrl);
                    System.debug('(String) recording.get(\'id\'): ' + recording.get('id'));
                    String transcript = fetchTranscriptFromZoom((String) recording.get('id'), token);
                    System.debug('transcript: ' + transcript);
                    // get the body of the transcript
                    Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(transcript);
                    system.debug('parsedData'+ parsedData.get('timeline'));
                    List<Object> timelineEntries = (List<Object>) parsedData.get('timeline');
                    for(Object data: timelineEntries){

                        system.debug('data text'+ data);
                        Map<String, Object> transcriptEntry = (Map<String, Object>) data;
                        String text = (String) transcriptEntry.get('text');
                        system.debug('transcriptEntry:'+ transcriptEntry);
                        // // String rawText = (String) transcriptEntry.get('raw_text');
                        // // String ts = (String) transcriptEntry.get('ts');
                        // // String endTs = (String) transcriptEntry.get('end_ts');
                        String userId = (String) transcriptEntry.get('userId');
                        system.debug('userId:'+ userId);
                        // // String channelMark = (String) transcriptEntry.get('channelMark');
                        string userName = userId;
                        if(phoneToAccountIdMap.containsKey(userId)){
                            userName = phoneToAccountIdMap.get(userId).Name;
                        }
                        else if(phoneToLeadIdMap.containsKey(userId)){
                            userName = phoneToLeadIdMap.get(userId).Name;
                        }else if(phoneToUserIdMap.containsKey(userId)){
                            userName = phoneToUserIdMap.get(userId).Name;
                            system.debug('userName: '+ userName + 'for number:' + userId);
                        }
                        else{
                            userName = userId+', ';
                        }
                        system.debug('userName'+ userName);
                        system.debug('test'+ text);
                        transcriptBody += 'User: ' + userName + '\r\n' + 'text: '+ text + '\r\n' + '\r\n';
                    }

                    System.debug('transcriptBody: ' + transcriptBody);
                    System.debug('transcriptBody Length: ' + transcriptBody.length());
                    List<Call_Transcript__c> CTList = processTranscript(transcriptBody, matchedResponse.voiceCallId);
                    for(Call_Transcript__c ctranscript: CTList){
                        transcripts.add(ctranscript);
                    }
                    
                } else {
                    System.debug('No matching CallResponse found for callId: ' + callId);
                }
            } catch (Exception ex) {
                System.debug('Error processing recording: ' + ex.getMessage());
            }
        }

        // Update the VoicepCall records with the transcript
        if(transcripts.size() > 0){
            upsert transcripts;
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
    
            // Set up HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(uploadUrl); // The Salesforce upload endpoint
            req.setMethod('POST');
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId()); // Authenticate to Salesforce
            req.setBody(body);

            // Send HTTP request
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('Response: ' + res.getStatusCode());
    
            // Handle the response
            if (res.getStatusCode() == 204) {
                return 'Audio uploaded successfully';
            } else {
                throw new CalloutException('Failed to upload audio. Status: ' + res.getStatusCode() + ', Response: ' + res.getBody());
            }
        } catch (Exception ex) {
            throw new CalloutException('Error during audio upload: ' + ex.getMessage());
        }
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
            WHERE IsActive = true
        ];
    
        for (User user : users) {
            userMap.put(user.Name, user);
        }
    
        return userMap;
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