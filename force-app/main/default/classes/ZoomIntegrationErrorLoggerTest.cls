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
}