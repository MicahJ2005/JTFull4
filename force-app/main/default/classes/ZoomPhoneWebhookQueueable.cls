/// Micah Johnson - Demand Chain 2025
/// Async body of a phone.recording_transcript_completed webhook: processes one recording
/// reference per transaction, chaining to the next when done, then hands off to the same
/// matching/build logic used by the polling retry path
/// (ZoomPhoneIntegration.processWebhookTranscriptReady). A single event has only ever been
/// observed carrying one recording, but the payload shape (payload.object.recordings) is a list,
/// so this chains through however many arrive rather than assuming exactly one. Kept out of
/// ZoomPhoneWebhookHandler's request thread so the inbound webhook gets a fast ack regardless of
/// Zoom API latency - the Zoom token itself is fetched here (not by the handler) for the same
/// reason: fetching it synchronously on the guest request would slow down Zoom's own delivery.
public with sharing class ZoomPhoneWebhookQueueable implements Queueable, Database.AllowsCallouts {

    private List<RecordingRef> refs;
    private Integer currentIndex;
    private String token;

    public ZoomPhoneWebhookQueueable(List<RecordingRef> refs, Integer currentIndex) {
        this(refs, currentIndex, null);
    }

    private ZoomPhoneWebhookQueueable(List<RecordingRef> refs, Integer currentIndex, String token) {
        this.refs = refs;
        this.currentIndex = currentIndex;
        this.token = token;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= refs.size()) {
            return;
        }

        if (token == null) {
            ZoomConfig__mdt cfg = [
                SELECT AccountId__c, ClientId__c, ClientSecret__c
                FROM   ZoomConfig__mdt
                WHERE  DeveloperName = 'Default'
                LIMIT  1
            ];
            token = ZoomPhoneIntegration.getZoomToken(cfg.ClientId__c, cfg.ClientSecret__c, cfg.AccountId__c);
        }

        RecordingRef ref = refs[currentIndex];
        ZoomPhoneIntegration.processWebhookTranscriptReady(ref.recordingId, ref.callId, token);

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < refs.size()) {
            System.enqueueJob(new ZoomPhoneWebhookQueueable(refs, nextIndex, token));
        }
    }

    public class RecordingRef {
        public String recordingId;
        public String callId;

        public RecordingRef(String recordingId, String callId) {
            this.recordingId = recordingId;
            this.callId = callId;
        }
    }
}