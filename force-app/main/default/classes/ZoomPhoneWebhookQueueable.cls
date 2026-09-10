/// Micah Johnson - Demand Chain 2025
/// Async body of a phone.recording_transcript_completed webhook: fetches a fresh Zoom token and
/// hands off to the same matching/build logic used by the polling retry path
/// (ZoomPhoneIntegration.processWebhookTranscriptReady). Kept out of ZoomPhoneWebhookHandler's
/// request thread so the inbound webhook gets a fast ack regardless of Zoom API latency.
public with sharing class ZoomPhoneWebhookQueueable implements Queueable, Database.AllowsCallouts {

    private String recordingId;
    private String callId;

    public ZoomPhoneWebhookQueueable(String recordingId, String callId) {
        this.recordingId = recordingId;
        this.callId = callId;
    }

    public void execute(QueueableContext ctx) {
        ZoomConfig__mdt cfg = [
            SELECT AccountId__c, ClientId__c, ClientSecret__c
            FROM   ZoomConfig__mdt
            WHERE  DeveloperName = 'Default'
            LIMIT  1
        ];
        String token = ZoomPhoneIntegration.getZoomToken(cfg.ClientId__c, cfg.ClientSecret__c, cfg.AccountId__c);
        ZoomPhoneIntegration.processWebhookTranscriptReady(recordingId, callId, token);
    }
}
