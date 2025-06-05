public class GetMeetingRegistrantsQueueable implements Queueable, Database.AllowsCallouts {

    private String token;
    private List<String> meetingIdList;
    private Set<Id> newTranscriptIds;

    public GetMeetingRegistrantsQueueable(String token, Set<String> meetingIds, Set<Id> newTranscriptIds) {
        this.token = token;
        this.meetingIdList = new List<String>(meetingIds);
        this.newTranscriptIds = newTranscriptIds;
    }

    public void execute(QueueableContext context) {
        String ZOOM_MEETING_ENDPOINT = 'https://api.zoom.us/v2/past_meetings/';

        List<Meeting_Transcript__c> meets = [
            SELECT Id , Zoom_Meeting_Id__c 
            FROM Meeting_Transcript__c 
            WHERE Id IN :newTranscriptIds
        ];

        Map<String, String> zoomIdToTranscriptSFIdMap = new Map<String, String>();
        for (Meeting_Transcript__c m : meets) {
            zoomIdToTranscriptSFIdMap.put(m.Zoom_Meeting_Id__c, m.Id);
        }

        Map<String, List<Participant>> meetingIdToParticipantMap = new Map<String, List<Participant>>();

        for (String meetingId : meetingIdList) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(ZOOM_MEETING_ENDPOINT + meetingId + '/participants');
                req.setHeader('Authorization', 'Bearer ' + token);
                req.setMethod('GET');

                Http http = new Http();
                HttpResponse res = http.send(req);

                ParticipantWrapper participants = (ParticipantWrapper) JSON.deserialize(res.getBody(), ParticipantWrapper.class);
                meetingIdToParticipantMap.put(meetingId, participants.participants);
            } catch (Exception e) {
                System.debug('Error fetching participants for meetingId ' + meetingId + ': ' + e.getMessage());
            }
        }

        Set<String> userEmails = new Set<String>();
        for (List<Participant> participants : meetingIdToParticipantMap.values()) {
            for (Participant p : participants) {
                if (p.user_email != null) {
                    userEmails.add(p.user_email);
                }
            }
        }

        Map<String, String> leadEmailToSFID = new Map<String, String>();
        for (Lead l : [SELECT Id, Email FROM Lead WHERE Email IN :userEmails AND Email != null]) {
            leadEmailToSFID.put(l.Email, l.Id);
        }

        Map<String, String> accountEmailToSFID = new Map<String, String>();
        for (Account a : [SELECT Id, PersonEmail FROM Account WHERE PersonEmail IN :userEmails AND PersonEmail != null]) {
            accountEmailToSFID.put(a.PersonEmail, a.Id);
        }

        Map<String, String> userEmailToSFID = new Map<String, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Email IN :userEmails AND Email != null]) {
            userEmailToSFID.put(u.Email, u.Id);
        }

        List<Zoom_Meeting_Individual__c> zoomMeetingIndividualList = new List<Zoom_Meeting_Individual__c>();
        for (String meetingId : meetingIdToParticipantMap.keySet()) {
            List<Participant> participants = meetingIdToParticipantMap.get(meetingId);
            for (Participant p : participants) {
                if (p.user_email != null) {
                    Zoom_Meeting_Individual__c individual = new Zoom_Meeting_Individual__c();
                    individual.Zoom_Meeting_Id__c = meetingId;
                    individual.Meeting_Transcript__c = zoomIdToTranscriptSFIdMap.get(meetingId);
                    if (leadEmailToSFID.containsKey(p.user_email)) {
                        individual.Lead__c = leadEmailToSFID.get(p.user_email);
                    }
                    if (accountEmailToSFID.containsKey(p.user_email)) {
                        individual.Account__c = accountEmailToSFID.get(p.user_email);
                    }
                    if (userEmailToSFID.containsKey(p.user_email)) {
                        individual.User__c = userEmailToSFID.get(p.user_email);
                    }
                    zoomMeetingIndividualList.add(individual);
                }
            }
        }

        if (!zoomMeetingIndividualList.isEmpty()) {
            insert zoomMeetingIndividualList;
        }
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