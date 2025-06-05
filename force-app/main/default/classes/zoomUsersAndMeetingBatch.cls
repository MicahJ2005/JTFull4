public with sharing class zoomUsersAndMeetingBatch implements Database.Batchable<SObject>, Database.AllowsCallouts{
    private String token;
    private String queueId;
    public map<String, User> zoomUserIdsToUserMap;
    public Map<String,List<ZoomMeetingTranscriptService.RecordingFile>> userToTranscriptFileMap;
    
    public zoomUsersAndMeetingBatch(String token, string queueId) {
            this.token = token;
            this.queueId = queueId;
            this.userToTranscriptFileMap = userToTranscriptFileMap;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {

        if(Test.isRunningTest()){
            return Database.getQueryLocator([SELECT Id, Name, Zoom_User_Id__c
            FROM User
            WHERE IsActive = true
            AND Zoom_User_Id__c != null LIMIT 1]);
        }
        // Get Zoom User Id's in SF
        return Database.getQueryLocator([SELECT Id, Name, Zoom_User_Id__c
        FROM User
        WHERE IsActive = true
        AND Zoom_User_Id__c != null]);
    }
    public void execute(Database.BatchableContext bc, List<SObject> scope) {

        map<String, User> zoomUserIdsToUserMap = new map<String, User>();
        // build zoomUserIdsToUserMap
        for(SObject u : scope){
            System.debug('scope: '+u);
            User uu = (User)u;
            System.debug('uu.Zoom_User_Id__c: '+uu.Zoom_User_Id__c);
            if(!zoomUserIdsToUserMap.containsKey(uu.Zoom_User_Id__c)){
                zoomUserIdsToUserMap.put(uu.Zoom_User_Id__c,uu);
            }
        }
        System.debug('zoomUserIdsToUserMap: '+zoomUserIdsToUserMap);
        
        // Fetch Recent Zoom Meetings
        // Map<String,List<ZoomMeetingTranscriptService.RecordingFile>> 
        userToTranscriptFileMap = ZoomMeetingTranscriptService.getRecentMeetings(token, zoomUserIdsToUserMap);
        System.debug('userToTranscriptFileMap: '+userToTranscriptFileMap);


        List<Meeting_Transcript__c> meetingTranscriptsToInsert = new List<Meeting_Transcript__c>();

        set<String> meetingIds = new set<String>();

        for(string zoomId: userToTranscriptFileMap.keySet()){
            for(ZoomMeetingTranscriptService.RecordingFile url: userToTranscriptFileMap.get(zoomId)){
                meetingIds.add(url.meeting_id);
                // Get Transcripts from Zoom
                string transcript = ZoomMeetingTranscriptService.fetchTranscriptFromZoom(url.download_url, token);
                List<Meeting_Transcript__c> transcriptsToAdd =  ZoomMeetingTranscriptService.processTranscript(transcript, url.meeting_id, zoomUserIdsToUserMap.get(zoomId).Id);
                for(Meeting_Transcript__c meetingTranscript : transcriptsToAdd){
                    // meetingTranscript.OwnerId = queueId;
                    meetingTranscriptsToInsert.add(meetingTranscript);
                }
            }
        }

        set<Id> newTranscriptIds = new set<Id>();
        if(!meetingTranscriptsToInsert.isEmpty()){
            if(!Test.isRunningTest()){
                List<Database.SaveResult> newMeetingTranscripts = Database.insert(meetingTranscriptsToInsert);
                for(Database.SaveResult sr : newMeetingTranscripts){
                    if(sr.isSuccess()){
                        newTranscriptIds.add(sr.getId());
                    }
                }
            ///Start a batch Class to create related Zoom Meeting Participant Records
            // GetMeetingRegistrantsBatch batch = new GetMeetingRegistrantsBatch(token, meetingIds, newTranscriptIds);
            // Database.executeBatch(batch, 200); // 200 is the batch size — can be adjusted
            
                // GetMeetingRegistrantsQueueable job = new GetMeetingRegistrantsQueueable(token, meetingIds, newTranscriptIds);
                // System.enqueueJob(job);
            }
        }
    }
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch job completed.');
        System.debug('FINISH userToTranscriptFileMap: '+userToTranscriptFileMap);
        System.debug('FINISH token: '+token);
        // Database.executeBatch(new ProcessZoomTranscriptsBatch(token, userToTranscriptFileMap), 1);
    }

}