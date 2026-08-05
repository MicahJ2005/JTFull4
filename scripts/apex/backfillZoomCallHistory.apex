// Backfill Zoom Phone call data for a single 30-minute window.
//
// ZoomPhoneIntegration.sendZoomDataToSalesforce() always computes its own
// "1hr to 1.5hr ago" window, so it can't be reused for a backfill. This
// script calls the same underlying methods directly with an explicit
// window instead.
//
// HOW TO USE:
//   1. Edit WINDOW_END_GMT below to the END of the 30-minute window you
//      want to process (in GMT). WINDOW_START_GMT is computed as 30
//      minutes before it.
//   2. Run this file via "SFDx: Execute Anonymous Apex with Editor Contents".
//   3. Check the debug log for the "LIMITS AFTER RUN" line. If usage on
//      any line is close to its limit, stop and process smaller windows
//      (e.g. 15 minutes) rather than continuing as-is.
//   4. Move WINDOW_END_GMT back by 30 minutes and repeat until you've
//      covered the full 24-hour range (~48 runs).
//
// Example: to cover the last 24 hours ending now, start with
// WINDOW_END_GMT = Datetime.now() and decrement by 30 minutes each run
// until WINDOW_END_GMT is 24 hours before that starting point.

Datetime WINDOW_END_GMT = Datetime.newInstanceGmt(2026, 6, 25, 0, 0, 0); // <-- EDIT EACH RUN
Datetime WINDOW_START_GMT = WINDOW_END_GMT.addMinutes(-30);

String toDateTime = WINDOW_END_GMT.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
String fromDateTime = WINDOW_START_GMT.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

System.debug('=== Backfill window: ' + fromDateTime + ' to ' + toDateTime + ' ===');

ZoomConfig__mdt cfg = [
    SELECT AccountId__c, ClientId__c, ClientSecret__c, DefaultUserId__c
    FROM   ZoomConfig__mdt
    WHERE  DeveloperName = 'Default'
    LIMIT  1
];

try {
    String zoomToken = ZoomPhoneIntegration.getZoomToken(
        cfg.ClientId__c, cfg.ClientSecret__c, cfg.AccountId__c
    );

    String zoomJson = ZoomPhoneIntegration.fetchZoomCallHistory(zoomToken, fromDateTime, toDateTime);
    System.debug('Call logs fetched (raw length): ' + (zoomJson != null ? zoomJson.length() : 0));

    String salesforceJson = ZoomPhoneIntegration.transformZoomData(zoomJson, cfg.DefaultUserId__c);

    List<ZoomPhoneIntegration.CallResponse> responses =
        ZoomPhoneIntegration.sendCallMetadataToECI(salesforceJson);
    System.debug('VoiceCalls created/updated: ' + responses.size());

    ZoomPhoneIntegration.processRecordings(zoomToken, responses, fromDateTime, toDateTime);

    System.debug('=== Window ' + fromDateTime + ' to ' + toDateTime + ' completed successfully ===');
} catch (Exception ex) {
    System.debug(LoggingLevel.ERROR, '=== Window ' + fromDateTime + ' to ' + toDateTime
        + ' FAILED: ' + ex.getMessage() + ' ===');
    System.debug(LoggingLevel.ERROR, ex.getStackTraceString());
}

System.debug('LIMITS AFTER RUN -- '
    + 'SOQL queries: ' + Limits.getQueries() + '/' + Limits.getLimitQueries() + ', '
    + 'SOQL rows: ' + Limits.getQueryRows() + '/' + Limits.getLimitQueryRows() + ', '
    + 'Callouts: ' + Limits.getCallouts() + '/' + Limits.getLimitCallouts() + ', '
    + 'DML statements: ' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements() + ', '
    + 'DML rows: ' + Limits.getDmlRows() + '/' + Limits.getLimitDmlRows() + ', '
    + 'CPU time (ms): ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime());
