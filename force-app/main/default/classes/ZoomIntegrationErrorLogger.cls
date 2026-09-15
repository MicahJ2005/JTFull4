/// Micah Johnson - Demand Chain 2025
/// Logs callout failures (timeouts, governor limits, other callout errors) from the Zoom
/// transcript pipeline into Zoom_Integration_Error__c so failures are visible without having
/// to dig through debug logs. Insert is isolated in its own try/catch so a logging failure
/// (e.g. DML limit already exhausted) never masks or replaces the original error.
///
/// without sharing: also called from ZoomPhoneWebhookHandler's guest-user REST context, which has
/// no sharing-rule visibility by default - logging a failure shouldn't depend on the calling
/// user's record access.
public without sharing class ZoomIntegrationErrorLogger {

    public static void log(String className, String methodName, String zoomUserId, String zoomMeetingId, Exception e) {
        log(className, methodName, zoomUserId, zoomMeetingId, e, null, null);
    }

    // Error_Type__c categories that represent a transient condition worth retrying, rather than
    // a real failure - ZoomPhoneIntegration.retryPendingTranscripts picks these back up later
    // instead of the recording being silently dropped once its sync window moves on.
    private static final Set<String> RETRYABLE_ERROR_TYPES = new Set<String>{ 'Transcript Not Ready', 'Voice Call Not Found' };

    /// Overload used for callout failures tied to a specific recording. When the failure falls
    /// into a retryable category (see RETRYABLE_ERROR_TYPES) and a recordingId is supplied, the
    /// log record is also marked as a pending retry (Recording_Id__c/Voice_Call_Id__c/Next_Retry_At__c)
    /// so ZoomPhoneIntegration.retryPendingTranscripts can pick it back up later.
    public static void log(
        String className, String methodName, String zoomUserId, String zoomMeetingId, Exception e,
        String recordingId, String voiceCallId
    ) {
        Zoom_Integration_Error__c logRecord = new Zoom_Integration_Error__c();
        logRecord.Apex_Class__c = className;
        logRecord.Apex_Method__c = methodName;
        logRecord.Zoom_User_Id__c = zoomUserId;
        logRecord.Zoom_Meeting_Id__c = zoomMeetingId;
        logRecord.Error_Type__c = categorizeError(e);
        logRecord.Error_Message__c = e.getMessage();
        logRecord.Stack_Trace__c = e.getStackTraceString();

        if (recordingId != null && RETRYABLE_ERROR_TYPES.contains(logRecord.Error_Type__c)) {
            // Skip creating a second pending retry for the same recording/call - this happens
            // when Zoom redelivers the same webhook event (or, with polling also running, both
            // paths hit the same failure independently). The existing record's own retry cycle
            // already covers it; a duplicate here would just inflate the count of "stuck" records
            // without representing a second distinct problem.
            if (zoomMeetingId != null && ![
                SELECT Id FROM Zoom_Integration_Error__c
                WHERE Resolved__c = false AND Recording_Id__c = :recordingId AND Zoom_Meeting_Id__c = :zoomMeetingId
                LIMIT 1
            ].isEmpty()) {
                return;
            }

            logRecord.Recording_Id__c = recordingId;
            logRecord.Voice_Call_Id__c = voiceCallId;
            logRecord.Retry_Count__c = 0;
            logRecord.Next_Retry_At__c = Datetime.now().addMinutes(20);
            logRecord.Resolved__c = false;
        } else {
            logRecord.Resolved__c = true;
        }

        try {
            insert logRecord;
        } catch (Exception insertEx) {
            System.debug(LoggingLevel.ERROR, 'Failed to insert Zoom_Integration_Error__c for '
                + className + '.' + methodName + ': ' + insertEx.getMessage());
        }
    }

    private static String categorizeError(Exception e) {
        String msg = e.getMessage() != null ? e.getMessage() : '';

        // Zoom-specific transcript error codes, surfaced as their own categories so they're not
        // confused with real callout failures: 12002 is transient and retryable, 12000 means Zoom
        // itself could not produce a transcript for this recording (nothing to retry).
        if (msg.contains('"code":12002')) {
            return 'Transcript Not Ready';
        }
        if (msg.contains('"code":12000')) {
            return 'Zoom Cannot Transcribe';
        }
        // Thrown by the webhook handler when a recording/transcript-ready notification arrives
        // before the call metadata poll has created the matching VoiceCall yet - expected to
        // happen routinely, since that poll runs 60-90 minutes behind while Zoom usually finishes
        // transcribing within minutes.
        if (e instanceof ZoomPhoneIntegration.VoiceCallNotFoundException) {
            return 'Voice Call Not Found';
        }
        if (e instanceof System.LimitException) {
            return 'Governor Limit';
        }
        if (e instanceof System.CalloutException) {
            String lowerMsg = msg.toLowerCase();
            if (lowerMsg.contains('timeout') || lowerMsg.contains('timed out')) {
                return 'Callout Timeout';
            }
            return 'Callout Error';
        }
        return 'Other';
    }
}