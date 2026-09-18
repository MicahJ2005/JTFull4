/// Micah Johnson - Demand Chain 2025
/// Runs both pending-retry passes - ZoomPhoneIntegration.retryPendingTranscripts (attaching a
/// transcript to a VoiceCall that should already exist) and retryPendingVoiceCallCreations
/// (creating the VoiceCall itself, for calls where that failed outright) - but deliberately does
/// not also run runZoomDataSync (the call-history poll). Scheduled separately, on a tighter
/// cadence than the full poll would need, specifically to validate whether the
/// phone.recording_completed/phone.recording_transcript_completed webhooks are sufficient on
/// their own - if these two retry passes fully clear out Zoom_Integration_Error__c on their own,
/// that's evidence the full poll isn't needed as more than an occasional safety net.
public with sharing class ZoomPhoneTranscriptRetrySchedulable implements Schedulable {
    public void execute(SchedulableContext ctx) {
        ZoomPhoneIntegration.retryPendingTranscripts();
        ZoomPhoneIntegration.retryPendingVoiceCallCreations();
    }
}