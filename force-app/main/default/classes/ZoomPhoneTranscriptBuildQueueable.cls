/// Micah Johnson - Demand Chain 2025
/// Uploads the recording and fetches the transcript for one Zoom Phone recording per
/// transaction, chaining to the next recording when done. Isolating each recording's callouts
/// into its own transaction keeps a slow or timed-out upload/transcript fetch for one
/// recording from eating into the 120s cumulative callout budget shared by the rest. Once
/// every recording has been processed, upserts the accumulated Call_Transcript__c records.
public with sharing class ZoomPhoneTranscriptBuildQueueable implements Queueable, Database.AllowsCallouts {

    private String token;
    private List<Map<String, Object>> recordings;
    private Integer currentIndex;
    private Map<String, ZoomPhoneIntegration.CallResponse> responseMap;
    private Map<String, Account> phoneToAccountIdMap;
    private Map<String, Lead> phoneToLeadIdMap;
    private Map<String, User> phoneToUserIdMap;
    private List<Call_Transcript__c> transcripts;
    private Boolean agentPromptActive;

    public ZoomPhoneTranscriptBuildQueueable(
        String token,
        List<Map<String, Object>> recordings,
        Integer currentIndex,
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap,
        Map<String, Account> phoneToAccountIdMap,
        Map<String, Lead> phoneToLeadIdMap,
        Map<String, User> phoneToUserIdMap,
        List<Call_Transcript__c> transcripts,
        Boolean agentPromptActive
    ) {
        this.token = token;
        this.recordings = recordings;
        this.currentIndex = currentIndex;
        this.responseMap = responseMap;
        this.phoneToAccountIdMap = phoneToAccountIdMap;
        this.phoneToLeadIdMap = phoneToLeadIdMap;
        this.phoneToUserIdMap = phoneToUserIdMap;
        this.transcripts = transcripts;
        this.agentPromptActive = agentPromptActive;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= recordings.size()) {
            ZoomPhoneIntegration.upsertCallTranscripts(transcripts, agentPromptActive);
            return;
        }

        Map<String, Object> recording = recordings[currentIndex];
        String callId = recording != null ? (String) recording.get('call_id') : null;
        String recordingId = recording != null ? (String) recording.get('id') : null;
        ZoomPhoneIntegration.CallResponse matchedResponse = callId != null ? responseMap.get(callId) : null;

        try {
            transcripts.addAll(ZoomPhoneIntegration.buildTranscriptForRecording(
                recording, token, responseMap, phoneToAccountIdMap, phoneToLeadIdMap, phoneToUserIdMap
            ));
        } catch (Exception e) {
            // Passing recordingId/voiceCallId lets the logger schedule an automatic retry when
            // this is Zoom error 12002 ("still being transcribed") instead of losing the
            // transcript once the sync window's fromDateTime/toDateTime moves past it.
            ZoomIntegrationErrorLogger.log(
                'ZoomPhoneTranscriptBuildQueueable', 'execute', null, callId, e,
                recordingId, matchedResponse != null ? matchedResponse.voiceCallId : null
            );
        }

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < recordings.size()) {
            System.enqueueJob(new ZoomPhoneTranscriptBuildQueueable(
                token, recordings, nextIndex, responseMap, phoneToAccountIdMap, phoneToLeadIdMap, phoneToUserIdMap,
                transcripts, agentPromptActive
            ));
        } else {
            ZoomPhoneIntegration.upsertCallTranscripts(transcripts, agentPromptActive);
        }
    }
}