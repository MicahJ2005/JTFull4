/// Micah Johnson - Demand Chain 2025
/// Retries one previously-failed VoiceCall creation per transaction, chaining to the next pending
/// retry when done. Kicked off from ZoomPhoneIntegration.retryPendingVoiceCallCreations. No Zoom
/// API token is needed - VoiceCall creation and the audio upload both call Salesforce's own REST
/// API, same as the original webhook attempt (see ZoomPhoneIntegration.createVoiceCallAndUploadAudio).
public with sharing class ZoomPhoneVoiceCallRetryQueueable implements Queueable, Database.AllowsCallouts {

    private List<Zoom_Integration_Error__c> retries;
    private Integer currentIndex;

    public ZoomPhoneVoiceCallRetryQueueable(List<Zoom_Integration_Error__c> retries, Integer currentIndex) {
        this.retries = retries;
        this.currentIndex = currentIndex;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= retries.size()) {
            return;
        }

        ZoomPhoneIntegration.processVoiceCallCreationRetry(retries[currentIndex]);

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < retries.size()) {
            System.enqueueJob(new ZoomPhoneVoiceCallRetryQueueable(retries, nextIndex));
        }
    }
}