/// Micah Johnson - Demand Chain 2025
/// Retries one previously "not ready" (Zoom error 12002) recording per transaction, chaining to
/// the next pending retry when done. Kicked off from ZoomPhoneIntegration.retryPendingTranscripts,
/// which runs from a Schedulable's execute() (either ZoomPhoneIntegration's own, or
/// ZoomPhoneTranscriptRetrySchedulable's) rather than the main sync's Queueable chain, so it isn't
/// subject to the main sync's per-window recording count. The Zoom token is fetched here, lazily,
/// rather than by the caller - Scheduled Apex's execute() doesn't allow synchronous callouts
/// ("Callout from scheduled Apex not supported"), so retryPendingTranscripts can't fetch it itself.
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

        if (token == null) {
            ZoomConfig__mdt cfg = [
                SELECT AccountId__c, ClientId__c, ClientSecret__c
                FROM   ZoomConfig__mdt
                WHERE  DeveloperName = 'Default'
                LIMIT  1
            ];
            token = ZoomPhoneIntegration.getZoomToken(cfg.ClientId__c, cfg.ClientSecret__c, cfg.AccountId__c);
        }

        ZoomPhoneIntegration.processTranscriptRetry(retries[currentIndex], token);

        Integer nextIndex = currentIndex + 1;
        if (nextIndex < retries.size()) {
            System.enqueueJob(new ZoomPhoneTranscriptRetryQueueable(token, retries, nextIndex));
        }
    }
}
