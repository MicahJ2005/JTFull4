@isTest
private class ZoomPhoneTranscriptRetrySchedulableTest {

    @isTest
    static void testExecuteRunsBothRetryPasses() {
        // No due retries of either kind exist in a fresh test org, so this just proves execute()
        // calls both retryPendingTranscripts() and retryPendingVoiceCallCreations() without error
        // and without also touching the call-history poll (no callout mock is configured for
        // oauth/token or call_history - if runZoomDataSync were called too, this test would fail
        // with a callout exception).
        Test.startTest();
        new ZoomPhoneTranscriptRetrySchedulable().execute(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Zoom_Integration_Error__c], 'Nothing should be logged when there are no due retries');
    }
}
