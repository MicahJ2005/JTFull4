///Batch job to create Zoom_Meeting_Individual__c records based on matching emails from the 
/// Zoom Meeting Participants callout response
/// Micah Johnson - Demand Chain 2025

public class GetMeetingRegistrantsBatch implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts {

    private String token;
    private List<Id> newTranscriptIds;
    private List<String> meetingIdList;

    public GetMeetingRegistrantsBatch(String token, Set<String> meetingIds, Set<Id> newTranscriptIds) {
        this.token = token;
        this.newTranscriptIds = new List<Id>(newTranscriptIds);
        this.meetingIdList = new List<String>(meetingIds);
    }

    public Iterable<String> start(Database.BatchableContext bc) {
        return meetingIdList ;
    }

    public void execute(Database.BatchableContext bc, List<String> meetingIdsBatch) {
        String ZOOM_MEETING_ENDPOINT = 'https://api.zoom.us/v2/past_meetings/';
        
        List<Meeting_Transcript__c> meets = [SELECT Id , Zoom_Meeting_Id__c FROM Meeting_Transcript__c WHERE Id IN :newTranscriptIds];
        System.debug('meets: '+meets);

        map<string, string> zoomIdToTranscriptSFIdMap = new map<string,string>();
        for(Meeting_Transcript__c m:meets){
            zoomIdToTranscriptSFIdMap.put(m.Zoom_Meeting_Id__c, m.Id);
        }

        Map<String, List<Participant>> meetingIdToParticipantMap = new Map<String, List<Participant>>();

        for (String meetingId : meetingIdsBatch) {
            if(!meetingIdToParticipantMap.containsKey(meetingId)){
                meetingIdToParticipantMap.put(meetingId, new List<Participant>());
            }
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(ZOOM_MEETING_ENDPOINT + meetingId + '/participants');
                req.setHeader('Authorization', 'Bearer ' + token);
                req.setMethod('GET');

                Http http = new Http();
                HttpResponse res = http.send(req);

                ParticipantWrapper participants = (ParticipantWrapper) JSON.deserialize(res.getBody(), ParticipantWrapper.class);

                for (Participant p : participants.participants) {
                    meetingIdToParticipantMap.get(meetingId).add(p);
                }

            } catch (Exception e) {
                System.debug('Error in execute for meetingId ' + meetingId + ': ' + e.getMessage());
            }
        }

        List<string> userInfo = new List<String>();
        for (string meetingId :meetingIdToParticipantMap.keySet()) {
            List<Participant> participants = meetingIdToParticipantMap.get(meetingId);
            for (Participant p : participants) {
                System.debug('Name: ' + p.name + ' | Email: ' + p.user_email);
                if(p.user_email != null){
                    userInfo.add(p.user_email);
                }
            }
        }

        List<Lead> LeadList = [SELECT Id, Name, Email
            FROM Lead
            Where Email in :userInfo AND email != null];

        map<string, string> leadEmailToSFID = new map<string, string>();
        if(LeadList.size() > 0){
            for(Lead l:LeadList){
                leadEmailToSFID.put(l.email, l.Id);
            }
        }

        List<Account> AccountList = [SELECT Id, Name, PersonEmail
            FROM Account
            Where PersonEmail in :userInfo AND PersonEmail != null];  

        map<string, string> accountEmailToSFID = new map<string, string>();

        if(AccountList.size() > 0){
            for(Account a:AccountList){
                accountEmailToSFID.put(a.PersonEmail, a.Id);
            }
        }

        List<User> UserList = [SELECT Id, Name, Email 
            FROM User
            Where Email in :userInfo AND email != null];  

        map<string, string> userEmailToSFID = new map<string, string>();
        if(UserList.size() > 0){
            for(User u:UserList){
                userEmailToSFID.put(u.Email, u.Id);
            }
        }

        list<Zoom_Meeting_Individual__c> zoomMeetingIndividualList = new list<Zoom_Meeting_Individual__c>();
        for (string meetingId :meetingIdToParticipantMap.keySet()) {
            List<Participant> participants = meetingIdToParticipantMap.get(meetingId);
            for (Participant p : participants) {
                if(p.user_email != null){
                    Zoom_Meeting_Individual__c individual = new Zoom_Meeting_Individual__c();
                    individual.Zoom_Meeting_Id__c = meetingId;
                    individual.Meeting_Transcript__c = zoomIdToTranscriptSFIdMap.get(meetingId);
                    if(leadEmailToSFID.containsKey(p.user_email)){
                        individual.Lead__c = leadEmailToSFID.get(p.user_email);
                        zoomMeetingIndividualList.add(individual);
                    }
                    if(accountEmailToSFID.containsKey(p.user_email)){
                        individual.Account__c = accountEmailToSFID.get(p.user_email);
                        zoomMeetingIndividualList.add(individual);
                    }
                    if(userEmailToSFID.containsKey(p.user_email)){
                        individual.User__c = userEmailToSFID.get(p.user_email);
                        zoomMeetingIndividualList.add(individual);
                    }
                    
                }
            }
        }


        if(zoomMeetingIndividualList.size() > 0){
            insert zoomMeetingIndividualList;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch job completed.');
    }

    // === Inner Classes for JSON Deserialization ===
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
}