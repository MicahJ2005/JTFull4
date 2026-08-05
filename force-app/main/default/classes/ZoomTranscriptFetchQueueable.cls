/// Micah Johnson - Demand Chain 2025
/// Fetches and inserts one Zoom recording transcript per transaction, chaining to the next
/// file when done. Each callout gets its own governor limits (the 120s cumulative callout
/// timeout and 12MB async heap are per-transaction), so a user with several large meetings
/// no longer has their transcript downloads compete against each other's timeout budget.
public with sharing class ZoomTranscriptFetchQueueable implements Queueable, Database.AllowsCallouts {

    private String token;
    private Id queueId;
    private Map<String, User> zoomUserIdsToUserMap;
    private Map<String, Event> zoomIdToUserMap;
    private List<TranscriptJob> jobs;

    public ZoomTranscriptFetchQueueable(
        String token,
        Id queueId,
        Map<String, User> zoomUserIdsToUserMap,
        Map<String, Event> zoomIdToUserMap,
        List<TranscriptJob> jobs
    ) {
        this.token = token;
        this.queueId = queueId;
        this.zoomUserIdsToUserMap = zoomUserIdsToUserMap;
        this.zoomIdToUserMap = zoomIdToUserMap;
        this.jobs = jobs;
    }

    public void execute(QueueableContext ctx) {
        if (jobs.isEmpty()) {
            return;
        }

        TranscriptJob job = jobs.remove(0);

        try {
            String transcript = ZoomMeetingTranscriptService.fetchTranscriptFromZoom(job.file.download_url, token);
            List<Meeting_Transcript__c> transcriptsToAdd = ZoomMeetingTranscriptService.processTranscript(
                transcript, job.file.meeting_id, zoomUserIdsToUserMap.get(job.zoomId).Id
            );

            Event matchedEvent = zoomIdToUserMap.get(job.zoomMeetingId);
            for (Meeting_Transcript__c meetingTranscript : transcriptsToAdd) {
                meetingTranscript.OwnerId = queueId;
                meetingTranscript.Zoom_Event_Id__c = job.zoomMeetingId;

                if (matchedEvent != null && matchedEvent.WhoId != null && String.valueOf(matchedEvent.WhoId).startsWith('00Q')) {
                    meetingTranscript.Lead__c = matchedEvent.WhoId;
                    meetingTranscript.OwnerId = matchedEvent.OwnerId;
                } else if (matchedEvent != null && matchedEvent.WhoId != null) {
                    if (String.valueOf(matchedEvent.WhoId).startsWith('003')) {
                        meetingTranscript.Contact__c = matchedEvent.WhoId;
                    }
                    meetingTranscript.OwnerId = matchedEvent.OwnerId;
                } else if (matchedEvent != null && matchedEvent.WhatId != null) {
                    if (String.valueOf(matchedEvent.WhatId).startsWith('001')) {
                        meetingTranscript.Account__c = matchedEvent.WhatId;
                    }
                    meetingTranscript.OwnerId = matchedEvent.OwnerId;
                }
            }

            if (!transcriptsToAdd.isEmpty()) {
                Database.insert(transcriptsToAdd);
            }
        } catch (Exception e) {
            // Log and move on to the next job rather than aborting the whole chain -
            // one meeting's callout timeout or governor limit hit shouldn't block the rest.
            ZoomIntegrationErrorLogger.log('ZoomTranscriptFetchQueueable', 'execute', job.zoomId, job.zoomMeetingId, e);
        }

        if (!jobs.isEmpty()) {
            System.enqueueJob(new ZoomTranscriptFetchQueueable(token, queueId, zoomUserIdsToUserMap, zoomIdToUserMap, jobs));
        }
    }

    public class TranscriptJob {
        public String zoomId;
        public String zoomMeetingId;
        public ZoomMeetingTranscriptService.RecordingFile file;

        public TranscriptJob(String zoomId, String zoomMeetingId, ZoomMeetingTranscriptService.RecordingFile file) {
            this.zoomId = zoomId;
            this.zoomMeetingId = zoomMeetingId;
            this.file = file;
        }
    }
}