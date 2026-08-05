/**
 * MatterCommunicationAnalysisScheduler.cls
 *
 * Schedulable wrapper that fires MatterCommunicationAnalysisBatch nightly.
 * Processes active Matter records, assembles unreviewed communication
 * transcripts, and invokes AI analysis via the Matter_Communication_Analysis
 * Flex Prompt Template.
 *
 * To register the nightly schedule, run this anonymous Apex once in your org:
 *   MatterCommunicationAnalysisScheduler.scheduleNightly();
 *
 * @org Johnson Turner Legal
 */
global class MatterCommunicationAnalysisScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MatterCommunicationAnalysisBatch(), 1);
    }

    /**
     * Registers a daily 1:00 AM CST schedule for this job.
     * Run once via anonymous Apex to activate the schedule.
     */
    public static void scheduleNightly() {
        // Cron expression: seconds minutes hours day-of-month month day-of-week
        // '0 0 1 * * ?' fires at 1:00:00 AM every day (org time zone = CST)
        String cronExpr = '0 0 1 * * ?';
        System.schedule(
            'Matter Communication Analysis — Nightly',
            cronExpr,
            new MatterCommunicationAnalysisScheduler()
        );
    }
}