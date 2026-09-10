// One-off fetch of a single Zoom meeting transcript:
// Zoom user 8PZy6dKIRyOe75i7YJEjMg, target time ~2026-08-24 11:48 AM Central Time,
// widened to the whole week of 2026-08-24 (Mon) - 2026-08-30 (Sun) in case the
// actual meeting landed on a different day that week.
//
// ZoomMeetingTranscriptService.getRecentMeetings() only supports a relative
// "last few hours" window, so it can't be reused for a specific past range.
// This script calls the Zoom recordings endpoint directly for that week,
// picks whichever meeting's start_time is closest to the target, downloads
// its transcript, and inserts it as Meeting_Transcript__c - mirroring what
// ZoomTranscriptFetchQueueable does, minus the Event/Lead/Contact matching
// (there's no "today's Events" context to match against for a backfilled day).
//
// NOTE ON TIME ZONE: Central Time is UTC-5 (CDT) in August under daylight
// saving, not UTC-6 (CST). 11:48 AM Central on 2026-08-24 is being treated
// as 16:48 UTC below. If you specifically meant UTC-6, adjust TARGET_UTC.
//
// HOW TO USE: Run via "SFDX: Execute Anonymous Apex with Editor Contents"
// and check the debug log for the candidate meeting list and the
// "completed successfully" / "FAILED" line.

String ZOOM_USER_ID = '8PZy6dKIRyOe75i7YJEjMg';
Datetime TARGET_UTC = Datetime.newInstanceGmt(2026, 8, 24, 16, 48, 0);
String FROM_DAY = '2026-08-24';
String TO_DAY = '2026-08-30';

System.debug('=== Target meeting time (UTC): ' + TARGET_UTC.formatGMT('yyyy-MM-dd HH:mm:ss')
    + ', searching ' + FROM_DAY + ' to ' + TO_DAY + ' ===');

ZoomConfig__mdt cfg = [
    SELECT AccountId__c, ClientId__c, ClientSecret__c, DefaultUserId__c
    FROM   ZoomConfig__mdt
    WHERE  DeveloperName = 'Default'
    LIMIT  1
];

User sfUser = [
    SELECT Id, Name
    FROM   User
    WHERE  Zoom_User_Id__c = :ZOOM_USER_ID
    LIMIT  1
];
System.debug('Salesforce user for this Zoom account: ' + sfUser.Id + ' (' + sfUser.Name + ')');

QueueSobject queue = [
    SELECT Id, QueueId
    FROM   QueueSobject
    WHERE  Queue.name = 'CSR Meeting Transcript'
    LIMIT  1
];

try {
    String zoomToken = ZoomMeetingTranscriptService.getZoomToken(
        cfg.ClientId__c, cfg.ClientSecret__c, cfg.AccountId__c
    );

    String queryParams = 'from=' + EncodingUtil.urlEncode(FROM_DAY, 'UTF-8')
        + '&to=' + EncodingUtil.urlEncode(TO_DAY, 'UTF-8')
        + '&page_size=300';

    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://api.zoom.us/v2/users/' + ZOOM_USER_ID + '/recordings?' + queryParams);
    req.setHeader('Authorization', 'Bearer ' + zoomToken);
    req.setMethod('GET');
    req.setTimeout(120000);
    HttpResponse res = new Http().send(req);

    if (res.getStatusCode() != 200) {
        throw new CalloutException('Error listing recordings: ' + res.getStatusCode() + ' ' + res.getBody());
    }

    ZoomMeetingTranscriptService.RecordingWrapper wrapped = ZoomMeetingTranscriptService.parseJson(res.getBody());

    ZoomMeetingTranscriptService.Meeting closest = null;
    Long closestDiffSeconds = null;

    if (wrapped.meetings != null) {
        for (ZoomMeetingTranscriptService.Meeting m : wrapped.meetings) {
            Datetime startTime = (Datetime) JSON.deserialize('"' + m.start_time + '"', Datetime.class);
            Long diffSeconds = Math.abs(startTime.getTime() - TARGET_UTC.getTime()) / 1000;
            System.debug('Candidate meeting: id=' + m.id + ' uuid=' + m.uuid + ' topic=' + m.topic
                + ' start_time=' + m.start_time + ' diffSeconds=' + diffSeconds);

            if (closestDiffSeconds == null || diffSeconds < closestDiffSeconds) {
                closestDiffSeconds = diffSeconds;
                closest = m;
            }
        }
    }

    if (closest == null) {
        System.debug(LoggingLevel.ERROR, '=== No meetings found for ' + ZOOM_USER_ID + ' between ' + FROM_DAY + ' and ' + TO_DAY + ' ===');
    } else {
        System.debug('=== Closest match: id=' + closest.id + ' topic=' + closest.topic
            + ' start_time=' + closest.start_time + ' (off by ' + closestDiffSeconds + 's) ===');

        ZoomMeetingTranscriptService.RecordingFile transcriptFile = null;
        for (ZoomMeetingTranscriptService.RecordingFile f : closest.recording_files) {
            if (f.file_type == 'TRANSCRIPT') {
                transcriptFile = f;
                break;
            }
        }

        if (transcriptFile == null) {
            System.debug(LoggingLevel.ERROR, '=== Meeting ' + closest.id + ' has no TRANSCRIPT recording file ===');
        } else {
            List<Meeting_Transcript__c> existing = [
                SELECT Id FROM Meeting_Transcript__c
                WHERE Zoom_Meeting_Id__c = :String.valueOf(closest.id)
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                System.debug('=== Transcript for meeting ' + closest.id + ' already imported (' + existing[0].Id + '), skipping insert ===');
            } else {
                String transcript = ZoomMeetingTranscriptService.fetchTranscriptFromZoom(transcriptFile.download_url, zoomToken);
                System.debug('Transcript fetched (length): ' + (transcript != null ? transcript.length() : 0));

                List<Meeting_Transcript__c> transcriptsToAdd = ZoomMeetingTranscriptService.processTranscript(
                    transcript, String.valueOf(closest.id), sfUser.Id
                );

                Date meetingDate = ((Datetime) JSON.deserialize('"' + closest.start_time + '"', Datetime.class)).date();
                for (Meeting_Transcript__c mt : transcriptsToAdd) {
                    mt.OwnerId = queue.QueueId;
                    mt.Meeting_Date__c = meetingDate;
                }

                insert transcriptsToAdd;
                System.debug('=== Inserted ' + transcriptsToAdd.size() + ' Meeting_Transcript__c record(s) for meeting '
                    + closest.id + ' ===');
            }
        }
    }

    System.debug('=== Run completed successfully ===');
} catch (Exception ex) {
    System.debug(LoggingLevel.ERROR, '=== FAILED: ' + ex.getMessage() + ' ===');
    System.debug(LoggingLevel.ERROR, ex.getStackTraceString());
}

System.debug('LIMITS AFTER RUN -- '
    + 'SOQL queries: ' + Limits.getQueries() + '/' + Limits.getLimitQueries() + ', '
    + 'SOQL rows: ' + Limits.getQueryRows() + '/' + Limits.getLimitQueryRows() + ', '
    + 'Callouts: ' + Limits.getCallouts() + '/' + Limits.getLimitCallouts() + ', '
    + 'DML statements: ' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements() + ', '
    + 'DML rows: ' + Limits.getDmlRows() + '/' + Limits.getLimitDmlRows() + ', '
    + 'CPU time (ms): ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime());
