/// Micah Johnson - Demand Chain 2025
/// Scans one Zoom Phone recording per transaction to collect the phone numbers/extensions
/// mentioned in its transcript, chaining to the next recording when done. Isolating each
/// recording's callout into its own transaction keeps a slow or timed-out transcript fetch
/// for one recording from eating into the 120s cumulative callout budget shared by the rest.
/// Once every recording has been scanned, kicks off ZoomPhoneTranscriptBuildQueueable.
public with sharing class ZoomPhoneRecordingScanQueueable implements Queueable, Database.AllowsCallouts {

    private String token;
    private List<Map<String, Object>> recordings;
    private Integer currentIndex;
    private Map<String, ZoomPhoneIntegration.CallResponse> responseMap;
    private Set<String> setPhoneFormats;
    private Set<String> setPhoneExtensions;
    private Boolean agentPromptActive;

    public ZoomPhoneRecordingScanQueueable(
        String token,
        List<Map<String, Object>> recordings,
        Integer currentIndex,
        Map<String, ZoomPhoneIntegration.CallResponse> responseMap,
        Set<String> setPhoneFormats,
        Set<String> setPhoneExtensions,
        Boolean agentPromptActive
    ) {
        this.token = token;
        this.recordings = recordings;
        this.currentIndex = currentIndex;
        this.responseMap = responseMap;
        this.setPhoneFormats = setPhoneFormats;
        this.setPhoneExtensions = setPhoneExtensions;
        this.agentPromptActive = agentPromptActive;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= recordings.size()) {
            return;
        }

        Map<String, Object> recording = recordings[currentIndex];
        String callId = recording != null ? (String) recording.get('call_id') : null;

        try {
            ZoomPhoneIntegration.scanRecordingForPhoneNumbers(recording, token, responseMap, setPhoneFormats, setPhoneExtensions);
        } catch (Exception e) {
            ZoomIntegrationErrorLogger.log('ZoomPhoneRecordingScanQueueable', 'execute', null, callId, e);
        }

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < recordings.size()) {
            System.enqueueJob(new ZoomPhoneRecordingScanQueueable(
                token, recordings, nextIndex, responseMap, setPhoneFormats, setPhoneExtensions, agentPromptActive
            ));
        } else {
            ZoomPhoneIntegration.finishScanAndStartTranscriptBuild(
                token, recordings, responseMap, setPhoneFormats, setPhoneExtensions, agentPromptActive
            );
        }
    }
}