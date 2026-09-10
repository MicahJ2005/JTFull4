/// Micah Johnson - Demand Chain 2025
/// Retries one previously "not ready" (Zoom error 12002) recording per transaction, chaining to
/// the next pending retry when done. Kicked off from ZoomPhoneIntegration.retryPendingTranscripts,
/// which runs from the Schedulable's execute() rather than the main sync's Queueable chain so it
/// isn't subject to the main sync's per-window recording count.
public with sharing class ZoomPhoneTranscriptRetryQueueable implements Queueable, Database.AllowsCallouts {

    private String token;
    private List<Zoom_Integration_Error__c> retries;
    private Integer currentIndex;

    public ZoomPhoneTranscriptRetryQueueable(String token, List<Zoom_Integration_Error__c> retries, Integer currentIndex) {
        this.token = token;
        this.retries = retries;
        this.currentIndex = currentIndex;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= retries.size()) {
            return;
        }

        ZoomPhoneIntegration.processTranscriptRetry(retries[currentIndex], token);

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < retries.size()) {
            System.enqueueJob(new ZoomPhoneTranscriptRetryQueueable(token, retries, nextIndex));
        }
    }
}
