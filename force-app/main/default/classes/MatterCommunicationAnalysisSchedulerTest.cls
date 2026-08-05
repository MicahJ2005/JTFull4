@isTest
private class MatterCommunicationAnalysisSchedulerTest {

    @isTest
    static void testScheduleNightly() {
        Test.startTest();
        MatterCommunicationAnalysisScheduler.scheduleNightly();
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, State
            FROM   CronTrigger
            WHERE  CronJobDetail.Name = 'Matter Communication Analysis — Nightly'
            LIMIT  1
        ];
        System.assertEquals('0 0 1 * * ?', ct.CronExpression, 'Cron expression should fire at 1:00 AM daily');
        System.assertEquals('WAITING', ct.State, 'Job should be in WAITING state after scheduling');
    }

    @isTest
    static void testExecute() {
        MatterCommunicationAnalysisScheduler scheduler = new MatterCommunicationAnalysisScheduler();
        Test.startTest();
        System.schedule('Test Scheduler', '0 0 1 * * ?', scheduler);
        Test.stopTest();
    }
}