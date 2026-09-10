@isTest
private class ZoomIntegrationErrorLoggerTest {

    @isTest
    static void testLogCategorizesCalloutTimeout() {
        Test.startTest();
        ZoomIntegrationErrorLogger.log('SomeClass', 'someMethod', 'zoomUser1', 'meeting1',
            new CalloutException('Read timed out'));
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [
            SELECT Error_Type__c, Apex_Class__c, Apex_Method__c, Zoom_User_Id__c, Zoom_Meeting_Id__c, Error_Message__c
            FROM Zoom_Integration_Error__c LIMIT 1
        ];
        System.assertEquals('Callout Timeout', logRecord.Error_Type__c);
        System.assertEquals('SomeClass', logRecord.Apex_Class__c);
        System.assertEquals('someMethod', logRecord.Apex_Method__c);
        System.assertEquals('zoomUser1', logRecord.Zoom_User_Id__c);
        System.assertEquals('meeting1', logRecord.Zoom_Meeting_Id__c);
        System.assertEquals('Read timed out', logRecord.Error_Message__c);
    }

    @isTest
    static void testLogCategorizesGovernorLimit() {
        Test.startTest();
        ZoomIntegrationErrorLogger.log('SomeClass', 'someMethod', null, null,
            new LimitException('Too many callouts: 101'));
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [SELECT Error_Type__c FROM Zoom_Integration_Error__c LIMIT 1];
        System.assertEquals('Governor Limit', logRecord.Error_Type__c);
    }

    @isTest
    static void testLogCategorizesCalloutError() {
        Test.startTest();
        ZoomIntegrationErrorLogger.log('SomeClass', 'someMethod', null, null,
            new CalloutException('Unauthorized endpoint'));
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [SELECT Error_Type__c FROM Zoom_Integration_Error__c LIMIT 1];
        System.assertEquals('Callout Error', logRecord.Error_Type__c);
    }

    @isTest
    static void testLogCategorizesOtherException() {
        Test.startTest();
        ZoomIntegrationErrorLogger.log('SomeClass', 'someMethod', null, null,
            new JSONException('Malformed JSON'));
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [SELECT Error_Type__c FROM Zoom_Integration_Error__c LIMIT 1];
        System.assertEquals('Other', logRecord.Error_Type__c);
    }

    @isTest
    static void testLogSchedulesRetryForTranscriptNotReady() {
        Test.startTest();
        ZoomIntegrationErrorLogger.log('SomeClass', 'someMethod', null, 'meeting1',
            new CalloutException('Error fetching transcript: {"code":12002,"message":"This recording is still in the process of being transcribed. Reopen this recording in a few minutes."}'),
            'rec123', '0Aa000000000001');
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [
            SELECT Error_Type__c, Recording_Id__c, Voice_Call_Id__c, Retry_Count__c, Next_Retry_At__c, Resolved__c
            FROM Zoom_Integration_Error__c LIMIT 1
        ];
        System.assertEquals('Transcript Not Ready', logRecord.Error_Type__c);
        System.assertEquals('rec123', logRecord.Recording_Id__c);
        System.assertEquals('0Aa000000000001', logRecord.Voice_Call_Id__c);
        System.assertEquals(0, logRecord.Retry_Count__c);
        System.assertEquals(false, logRecord.Resolved__c);
        System.assertNotEquals(null, logRecord.Next_Retry_At__c);
    }

    @isTest
    static void testLogMarksZoomCannotTranscribeAsResolved() {
        Test.startTest();
        ZoomIntegrationErrorLogger.log('SomeClass', 'someMethod', null, 'meeting2',
            new CalloutException('Error fetching transcript: {"code":12000,"message":"Unable to transcribe this recording."}'),
            'rec456', '0Aa000000000002');
        Test.stopTest();

        Zoom_Integration_Error__c logRecord = [
            SELECT Error_Type__c, Recording_Id__c, Resolved__c
            FROM Zoom_Integration_Error__c LIMIT 1
        ];
        System.assertEquals('Zoom Cannot Transcribe', logRecord.Error_Type__c);
        System.assertEquals(null, logRecord.Recording_Id__c, 'Not retryable, so no retry fields should be set even though a recordingId was passed in');
        System.assertEquals(true, logRecord.Resolved__c);
    }
}