/// Micah Johnson - Demand Chain 2025
/// Async body of a phone.recording_completed webhook: processes one recording reference per
/// transaction, chaining to the next when done. Creates the VoiceCall directly from the webhook
/// payload and uploads the audio (ZoomPhoneIntegration.processWebhookRecordingCompleted) - no
/// Zoom API token needed, since both steps call Salesforce's own REST API. Kept out of
/// ZoomPhoneWebhookHandler's request thread so the inbound webhook gets a fast ack regardless of
/// callout latency.
public with sharing class ZoomPhoneRecordingWebhookQueueable implements Queueable, Database.AllowsCallouts {

    private List<RecordingCompletedRef> refs;
    private Integer currentIndex;

    public ZoomPhoneRecordingWebhookQueueable(List<RecordingCompletedRef> refs, Integer currentIndex) {
        this.refs = refs;
        this.currentIndex = currentIndex;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= refs.size()) {
            return;
        }

        RecordingCompletedRef ref = refs[currentIndex];
        try {
            ZoomPhoneIntegration.processWebhookRecordingCompleted(ref.recording, ref.callId);
        } catch (Exception e) {
            // processWebhookRecordingCompleted logs its own specific failures (call map parsing,
            // audio upload); this only guards against sendCallBatchToECI's rethrow (already logged
            // there too) so one recording's failure doesn't stop the rest of the chain.
            System.debug('ZoomPhoneRecordingWebhookQueueable: recording for call_id ' + ref.callId + ' failed: ' + e.getMessage());
        }

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < refs.size()) {
            System.enqueueJob(new ZoomPhoneRecordingWebhookQueueable(refs, nextIndex));
        }
    }

    public class RecordingCompletedRef {
        public Map<String, Object> recording;
        public String callId;

        public RecordingCompletedRef(Map<String, Object> recording, String callId) {
            this.recording = recording;
            this.callId = callId;
        }
    }
}