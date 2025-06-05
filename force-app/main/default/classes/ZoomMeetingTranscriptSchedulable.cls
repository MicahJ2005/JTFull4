public with sharing class ZoomMeetingTranscriptSchedulable implements Schedulable, Database.AllowsCallouts {
    public void execute(SchedulableContext sc) {
        System.enqueueJob(new ZoomMeetingTranscriptService());
    }
}