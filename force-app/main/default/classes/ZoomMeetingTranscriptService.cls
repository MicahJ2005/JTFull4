/// Micah Johnson - Demand Chain 2025

public with sharing class ZoomMeetingTranscriptService implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext ctx) {
        sendZoomDataToSalesforce();
    }

    public static void sendZoomDataToSalesforce() {
        String clientId = 'OlTvfeKSCuXyENCswlexQ';
        String clientSecret = 'mJQ2SXpsBABlord50hHQVj7l40tLg3n9';
        String accountId = 'Af5TohNeQKiIODcnyFCOyQ';

        QueueSobject queue =[SELECT Id, QueueId, Queue.name, SobjectType FROM QueueSobject WHERE Queue.name = 'CSR Meeting Transcript' LIMIT 1];
        // Step 1: Get Zoom OAuth Token
        String zoomToken = getZoomToken(clientId, clientSecret, accountId);
        zoomUsersAndMeetingBatch job = new zoomUsersAndMeetingBatch(zoomToken, queue.QueueId);
        Database.executeBatch(job, 1);
    }

    private static final Integer MAX_LENGTH = 131071;

    /////// processTranscript is a method to seperate out transcripts that are too long for one text area
    public static List<Meeting_Transcript__c> processTranscript(String transcriptBody, string zoomId, string sfUser) {
        List<Meeting_Transcript__c> transcripts = new List<Meeting_Transcript__c>();
        Integer totalLength = transcriptBody.length();
        Integer startIndex = 0;
        Integer sequenceNumber = 1;
        
        while (startIndex < totalLength) {
            Integer endIndex = Math.min(startIndex + MAX_LENGTH, totalLength);
            String text = transcriptBody.substring(startIndex, endIndex);
            
            Meeting_Transcript__c transcriptToAdd = new Meeting_Transcript__c();
                transcriptToAdd.Transcript__c = text;
                transcriptToAdd.Johnson_Turner_User__c = sfUser;
                transcriptToAdd.OwnerId = sfUser;
                transcriptToAdd.Meeting_Date__c = Date.today();
                transcriptToAdd.Zoom_Meeting_Id__c = zoomId;
                transcriptToAdd.Transcript_Sequence__c = sequenceNumber;
            transcripts.add(transcriptToAdd);
            startIndex = endIndex;
            sequenceNumber++;
        }
        return transcripts;
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
    
    /// Get meeting records for a 3 hours window. Starting one hour ago
    public static Map<String,List<RecordingFile>> getRecentMeetings(string token, map<String, User> zoomUserIdsToUserMap){
        ///these Date/time parameters will give us Zoom Meetings that are within a 3hr window, starting 1 hr ago
        Datetime now = Datetime.now(); // Current datetime
        String toDateTime = now.addDays(-1).formatGMT('yyyy-MM-dd'); // 1 hour ago
        String fromDateTime = now.addHours(-4).formatGMT('yyyy-MM-dd'); // 4 hours ago
        String ZOOM_MEETING_ENDPOINT = 'https://api.zoom.us/v2/users/';
        String queryParams = 'from=' + EncodingUtil.urlEncode(fromDateTime, 'UTF-8') +
                                 '&to=' + EncodingUtil.urlEncode(toDateTime, 'UTF-8') +
                                 '&page_size=300';
       
        Map<String,List<RecordingFile>> userToTranscriptFileMap = new Map<String,List<RecordingFile>>();
        set<string> zoomMeetingIdsAlreadyImported = new set<string>();
       for(Meeting_Transcript__c mt: [SELECT Id, 
                                            Johnson_Turner_User__c, 
                                            Johnson_Turner_User__r.Zoom_User_Id__c,
                                            Zoom_Meeting_Id__c 
                                            FROM Meeting_Transcript__c 
                                            WHERE createdDate >= Yesterday AND Johnson_Turner_User__r.Zoom_User_Id__c IN: zoomUserIdsToUserMap.keySet()]){
                                                zoomMeetingIdsAlreadyImported.add(mt.Zoom_Meeting_Id__c);            
                                            }
    
 System.debug('zoomMeetingIdsAlreadyImported: '+ zoomMeetingIdsAlreadyImported);
        for(String zoomId: zoomUserIdsToUserMap.keySet()){
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ZOOM_MEETING_ENDPOINT + zoomId + '/recordings?'+queryParams);
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req);
            system.debug('res: '+ res.getBody());
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            RecordingWrapper wrappedData = parseJson(res.getBody());
            for(Meeting meeting : wrappedData.meetings) {
                if(!zoomMeetingIdsAlreadyImported.contains(meeting.uuid)){
                    system.debug('This is a new Transcript ' + meeting.uuid + ' Keep it...');
                    system.debug('This is the Zoom Event Id ' + meeting.id + ' YEAH!!');
                    for (RecordingFile file : meeting.recording_files) {
                        if(file.file_type == 'TRANSCRIPT'){
                            if(userToTranscriptFileMap.containsKey(zoomId+'#'+meeting.id)){
                                userToTranscriptFileMap.get(zoomId+'#'+meeting.id).add(file);
                            }
                            else{
                                userToTranscriptFileMap.put(zoomId+'#'+meeting.id, new List<RecordingFile>());
                                userToTranscriptFileMap.get(zoomId+'#'+meeting.id).add(file);
                            }
                            
                        }
                    }
                }
                else{
                    system.debug('Transcript Already Exists for ' + meeting.uuid + ' skipping...');
                }
            }
        }
        return userToTranscriptFileMap;
    }

    /// Retreive VTT transcript file from the download url
    public static String fetchTranscriptFromZoom(String recordingURL, String token) {
        String transcriptUrl = recordingURL;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(transcriptUrl);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setMethod('GET'); 
        Http http = new Http();
        HttpResponse res = http.send(req);
        system.debug('response 1 Header: '+ res);
        System.debug('res1: '+ res.getHeader('location'));
        if (res.getStatusCode() == 302) {
            req.setEndpoint(res.getHeader('location'));
            res = http.send(req);
            System.debug('res2: '+ res.getBody());
            if (res.getStatusCode() == 200) {
                string vttContent = extractPlainTextFromVTT(res.getBody());
                return vttContent;
            } else {
                throw new CalloutException('Error fetching transcript: ' + res.getBody());
            }
        } else {
            throw new CalloutException('Error fetching transcript: ' + res.getBody());
        }
    }

    public static String extractPlainTextFromVTT(String vttContent) {
        List<String> lines = vttContent.split('\n');
        String plainText;
    
        for (String line : lines) {
            if (!line.contains('-->') && !line.startsWith('WEBVTT') 
                && String.isNotBlank(line) && line != 'null'
                && !Pattern.matches('^[\\d\\s]+$', line)) {
                    plainText += line + ' '+'\n';
            }
        }
    
        return plainText;
    }

   

    public class RecordingWrapper {
        // public String from;
        public String to;
        public String next_page_token;
        public Integer page_count;
        public Integer page_size;
        public Integer total_records;
        public List<Meeting> meetings;
    }

    public class Meeting {
        public String account_id;
        public Integer duration;
        public String host_id;
        public Long id;
        public Integer recording_count;
        public String start_time;
        public String topic;
        public Integer total_size;
        public String type;
        public String uuid;
        public String recording_play_passcode;
        public Boolean auto_delete;
        public String auto_delete_date;
        public List<RecordingFile> recording_files;
    }
    
    public class RecordingFile {
        public String deleted_time;
        public String download_url;
        public String file_path;
        public Integer file_size;
        public String file_type;
        public String file_extension;
        public String id;
        public String meeting_id;
        public String play_url;
        public String recording_end;
        public String recording_start;
        public String recording_type;
        public String status;
    }

    public class RecordingResponse {
        public List<RecordingFile> recording_files;
    }

    public class ParticipantWrapper {
        public String next_page_token;
        public Integer page_count;
        public Integer page_size;
        public Integer total_records;
        public List<Participant> participants;
    }

    public class Participant {
        public String id;
        public String name;
        public String user_id;
        public String registrant_id;
        public String user_email;
        public String join_time;
        public String leave_time;
        public Integer duration;
        public Boolean failover;
        public String status;
        public Boolean internal_user;
    }
    
    // Sample method to parse and access the recording_files
   
    public static RecordingWrapper parseJson(String jsonString) {
        RecordingWrapper data = (RecordingWrapper) JSON.deserialize(jsonString, RecordingWrapper.class);
        return data;
    }
}