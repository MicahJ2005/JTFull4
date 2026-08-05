/// Micah Johnson - Demand Chain 2025
/// Logs callout failures (timeouts, governor limits, other callout errors) from the Zoom
/// transcript pipeline into Zoom_Integration_Error__c so failures are visible without having
/// to dig through debug logs. Insert is isolated in its own try/catch so a logging failure
/// (e.g. DML limit already exhausted) never masks or replaces the original error.
public with sharing class ZoomIntegrationErrorLogger {

    public static void log(String className, String methodName, String zoomUserId, String zoomMeetingId, Exception e) {
        Zoom_Integration_Error__c logRecord = new Zoom_Integration_Error__c();
        logRecord.Apex_Class__c = className;
        logRecord.Apex_Method__c = methodName;
        logRecord.Zoom_User_Id__c = zoomUserId;
        logRecord.Zoom_Meeting_Id__c = zoomMeetingId;
        logRecord.Error_Type__c = categorizeError(e);
        logRecord.Error_Message__c = e.getMessage();
        logRecord.Stack_Trace__c = e.getStackTraceString();

        try {
            insert logRecord;
        } catch (Exception insertEx) {
            System.debug(LoggingLevel.ERROR, 'Failed to insert Zoom_Integration_Error__c for '
                + className + '.' + methodName + ': ' + insertEx.getMessage());
        }
    }

    private static String categorizeError(Exception e) {
        if (e instanceof System.LimitException) {
            return 'Governor Limit';
        }
        if (e instanceof System.CalloutException) {
            String msg = e.getMessage() != null ? e.getMessage().toLowerCase() : '';
            if (msg.contains('timeout') || msg.contains('timed out')) {
                return 'Callout Timeout';
            }
            return 'Callout Error';
        }
        return 'Other';
    }
}