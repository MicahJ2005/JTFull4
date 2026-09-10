// Backfill Zoom Phone call data for a single 1-hour window:
// 2026-07-25 17:00 - 18:00 UTC.
//
// Fully self-contained - run this file on its own via
// "SFDX: Execute Anonymous Apex with Editor Contents". Check the debug log
// for the "completed successfully" / "FAILED" line and the "LIMITS AFTER
// RUN" line before moving to the next hour file.

Datetime WINDOW_START_GMT = Datetime.newInstanceGmt(2026, 7, 25, 17, 0, 0);
Datetime WINDOW_END_GMT = WINDOW_START_GMT.addHours(1);

String fromDateTime = WINDOW_START_GMT.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
String toDateTime = WINDOW_END_GMT.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

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
