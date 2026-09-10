/// Micah Johnson - Demand Chain 2025
/// Inbound REST endpoint for Zoom Phone webhooks - the event-driven alternative to polling for
/// recording/transcript readiness. Currently handles phone.recording_transcript_completed only;
/// phone.recording_completed (the audio) is intentionally not wired up yet - re-uploading audio
/// to an already-created VoiceCall needs its own upload URL, and it isn't yet confirmed whether
/// Salesforce exposes a way to request one outside the original VoiceCall-creation response
/// (see ZoomPhoneIntegration.buildTranscriptForRecording/sendCallMetadataToECI). Unhandled events
/// are acknowledged (200) and ignored rather than rejected, per Zoom's guidance for a shared
/// endpoint that isn't subscribed to every event type it might receive.
///
/// NOTE: the payload.object field names below (id, call_id) are assumed to mirror the same shape
/// already used by the polling /v2/phone/recordings endpoint elsewhere in this codebase (see
/// ZoomPhoneIntegration.fetchRecordings). Confirm against a real captured delivery from Zoom
/// before relying on this in production, and adjust the two lines in handlePost if they differ.
@RestResource(urlMapping='/zoomPhoneWebhook/*')
global with sharing class ZoomPhoneWebhookHandler {

    private static final Set<String> HANDLED_EVENTS = new Set<String>{
        'phone.recording_transcript_completed'
    };

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String rawBody = req.requestBody != null ? req.requestBody.toString() : '';
        Map<String, Object> payload;
        try {
            payload = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
        } catch (Exception e) {
            res.statusCode = 400;
            return;
        }

        String eventName = (String) payload.get('event');

        // One-time handshake Zoom sends when the endpoint URL is first registered on the app's
        // Event Subscriptions feature. It isn't signed the way real events are - responding
        // correctly using the shared Secret Token is itself how Zoom confirms endpoint ownership.
        if (eventName == 'endpoint.url_validation') {
            handleUrlValidation(payload, res);
            return;
        }

        String secretToken = getWebhookSecretToken();
        String timestamp = req.headers.get('x-zm-request-timestamp');
        String signature = req.headers.get('x-zm-signature');

        if (!isValidSignature(rawBody, timestamp, signature, secretToken)) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('Invalid signature');
            return;
        }

        // Ack immediately - Zoom expects a fast response and retries/backs off otherwise. The
        // actual Zoom API + Salesforce work happens async in ZoomPhoneWebhookQueueable so it isn't
        // done on the inbound request's own budget.
        res.statusCode = 200;

        if (!HANDLED_EVENTS.contains(eventName)) {
            System.debug('ZoomPhoneWebhookHandler: ignoring unhandled event ' + eventName);
            return;
        }

        Map<String, Object> payloadInner = (Map<String, Object>) payload.get('payload');
        Map<String, Object> objectData = payloadInner != null ? (Map<String, Object>) payloadInner.get('object') : null;
        String recordingId = objectData != null ? (String) objectData.get('id') : null;
        String callId = objectData != null ? (String) objectData.get('call_id') : null;

        if (recordingId == null || callId == null) {
            ZoomIntegrationErrorLogger.log('ZoomPhoneWebhookHandler', 'handlePost', null, callId,
                new WebhookPayloadException('Missing payload.object.id/call_id for event ' + eventName));
            return;
        }

        System.enqueueJob(new ZoomPhoneWebhookQueueable(recordingId, callId));
    }

    private static void handleUrlValidation(Map<String, Object> payload, RestResponse res) {
        Map<String, Object> payloadInner = (Map<String, Object>) payload.get('payload');
        String plainToken = payloadInner != null ? (String) payloadInner.get('plainToken') : null;
        String secretToken = getWebhookSecretToken();

        if (plainToken == null || String.isBlank(secretToken)) {
            res.statusCode = 400;
            return;
        }

        Map<String, String> body = new Map<String, String>{
            'plainToken' => plainToken,
            'encryptedToken' => computeSignature(plainToken, null, secretToken, false)
        };
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    @TestVisible
    private static Boolean isValidSignature(String rawBody, String timestamp, String signatureHeader, String secretToken) {
        if (String.isBlank(timestamp) || String.isBlank(signatureHeader) || String.isBlank(secretToken)) {
            return false;
        }
        return computeSignature(rawBody, timestamp, secretToken, true) == signatureHeader;
    }

    /// Shared HMAC-SHA256 helper for both the per-event signature (message "v0:{timestamp}:{body}",
    /// result prefixed "v0=") and the url_validation handshake (message is just the plainToken,
    /// result is a bare hex digest with no prefix) - Zoom uses the same Secret Token for both but
    /// formats the two differently.
    @TestVisible
    private static String computeSignature(String message, String timestamp, String secretToken, Boolean prefixedEventFormat) {
        String toSign = prefixedEventFormat ? ('v0:' + timestamp + ':' + message) : message;
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(toSign), Blob.valueOf(secretToken));
        String hex = EncodingUtil.convertToHex(mac);
        return prefixedEventFormat ? ('v0=' + hex) : hex;
    }

    // Test-only override so signature validation can be tested deterministically without reading
    // or writing the real ZoomConfig__mdt.Default record - that record already holds the live
    // Zoom Client Secret, which a test has no business touching.
    @TestVisible
    private static String testSecretTokenOverride = null;

    private static String getWebhookSecretToken() {
        if (Test.isRunningTest() && testSecretTokenOverride != null) {
            return testSecretTokenOverride;
        }
        ZoomConfig__mdt cfg = [
            SELECT Webhook_Secret_Token__c
            FROM   ZoomConfig__mdt
            WHERE  DeveloperName = 'Default'
            LIMIT  1
        ];
        return cfg.Webhook_Secret_Token__c;
    }

    public class WebhookPayloadException extends Exception {}
}
