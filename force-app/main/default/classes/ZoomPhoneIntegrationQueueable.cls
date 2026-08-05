/// Micah Johnson - Demand Chain 2025
/// Entry point for the Zoom Phone sync (token, call history, metadata push, then per-recording
/// transcript processing). Runs as a plain Queueable, launched directly from
/// ZoomPhoneIntegration.sendZoomDataToSalesforce() rather than a @future method, so the
/// per-recording Queueable chain it kicks off in Step 5 is free to chain further - a Queueable
/// started from a @future or Batch context can't itself call System.enqueueJob.
public with sharing class ZoomPhoneIntegrationQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext ctx) {
        ZoomPhoneIntegration.runZoomDataSync();
    }
}