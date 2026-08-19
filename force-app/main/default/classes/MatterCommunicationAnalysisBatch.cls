global class MatterCommunicationAnalysisBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // Configuration loaded from Matter_Comm_Batch_Config__mdt (Custom Metadata).
    // To change values: Setup → Custom Metadata Types → Matter Comm Batch Config → Default.
    // Falls back to hardcoded defaults if the record is missing.
    private static Matter_Comm_Batch_Config__mdt getConfig() {
        Matter_Comm_Batch_Config__mdt c = Matter_Comm_Batch_Config__mdt.getInstance('Default');
        return c != null ? c : new Matter_Comm_Batch_Config__mdt(
            Prompt_Template_Name__c = 'Matter_Communication_Analysis',
            Max_Characters__c       = 400000,
            Query_Limit__c          = 200,
            Go_Live_Date__c         = Date.newInstance(2026, 6, 4)
        );
    }
    private static final Matter_Comm_Batch_Config__mdt CONFIG = getConfig();

    private static final String  PROMPT_TEMPLATE_DEV_NAME = CONFIG.Prompt_Template_Name__c;
    private static final Integer MAX_CHARS                 = CONFIG.Max_Characters__c.intValue();
    private static final Integer QUERY_LIMIT               = CONFIG.Query_Limit__c.intValue();
    private static final Date    GO_LIVE_DATE              = CONFIG.Go_Live_Date__c;

    private Set<Id> matterIdFilter;

    global MatterCommunicationAnalysisBatch() {}

    global MatterCommunicationAnalysisBatch(Set<Id> matterIdFilter) {
        this.matterIdFilter = matterIdFilter;
    }

    // ── Start ─────────────────────────────────────────────────────────────────

    global Database.QueryLocator start(Database.BatchableContext bc) {
        if (matterIdFilter != null && !matterIdFilter.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, Communication_Analysis__c, Communication_Log__c, Total_Email_Count__c, Comms_Error_Message__c,
                       Last_Substantive_Conversation__c, Last_Client_Inbound__c, Last_Attorney_Client_Conversation__c,
                       Unanswered_Client_Messages__c, Attorney_Callback_Requested__c, Client_Engagement_Status__c,
                       Communication_Log_Start__c, Last_Escalation_Date__c, Log_Character_Count__c, Last_Summarized__c,
                       Open_Promises__c, Completed_Promises__c, Broken_Promises__c
                FROM   AcctSeed__Project__c
                WHERE  AcctSeed__Status__c = 'Active'
                AND    Comms_Has_Error__c = false
                AND    Id IN :matterIdFilter
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id, Communication_Analysis__c, Communication_Log__c, Total_Email_Count__c, Comms_Error_Message__c,
                   Last_Substantive_Conversation__c, Last_Client_Inbound__c, Last_Attorney_Client_Conversation__c,
                   Unanswered_Client_Messages__c, Attorney_Callback_Requested__c, Client_Engagement_Status__c,
                   Communication_Log_Start__c, Last_Escalation_Date__c, Log_Character_Count__c, Last_Summarized__c,
                   Open_Promises__c, Completed_Promises__c, Broken_Promises__c
            FROM   AcctSeed__Project__c
            WHERE  AcctSeed__Status__c = 'Active'
            AND    Comms_Has_Error__c = false
        ]);
    }

    // ── Execute ───────────────────────────────────────────────────────────────

    global void execute(Database.BatchableContext bc, List<AcctSeed__Project__c> matters) {
        Id firstMatterId = matters.isEmpty() ? null : matters[0].Id;
        try {
            executeInner(matters);
        } catch (Exception outerEx) {
            System.debug('MatterCommunicationAnalysisBatch: Unexpected execute failure for Matter ' + firstMatterId + ' — ' + outerEx.getTypeName() + ': ' + outerEx.getMessage());
            if (firstMatterId != null) {
                try {
                    update new AcctSeed__Project__c(
                        Id                     = firstMatterId,
                        Comms_Has_Error__c     = true,
                        Comms_Error_Message__c = ('Execute: ' + outerEx.getTypeName() + ': ' + outerEx.getMessage()).left(1000)
                    );
                } catch (Exception flagEx) {
                    System.debug('Error flag update failed for ' + firstMatterId + ': ' + flagEx.getMessage());
                }
            }
        }
    }

    private void executeInner(List<AcctSeed__Project__c> matters) {
        Set<Id> matterIds = new Map<Id, AcctSeed__Project__c>(matters).keySet();

        // ── 1. Query all unreviewed junction records for these matters ─────────

        List<Related_Email_Message__c> emailJunctions = [
            SELECT Id, Email_Message_Id__c, Matter__c
            FROM   Related_Email_Message__c
            WHERE  Matter__c IN :matterIds
            AND    AI_Reviewed__c = false
            AND    CreatedDate >= :GO_LIVE_DATE
            ORDER BY CreatedDate ASC
            LIMIT  :QUERY_LIMIT
        ];

        Set<Id> emailMsgIds = new Set<Id>();
        for (Related_Email_Message__c j : emailJunctions) {
            if (String.isNotBlank(j.Email_Message_Id__c)) {
                try { emailMsgIds.add((Id) j.Email_Message_Id__c); } catch (Exception e) {}
            }
        }
        Map<Id, EmailMessage> emailsById = emailMsgIds.isEmpty()
            ? new Map<Id, EmailMessage>()
            : new Map<Id, EmailMessage>([SELECT Id, TextBody, CreatedDate, Incoming, FromAddress FROM EmailMessage WHERE Id IN :emailMsgIds]);

        List<Related_Call_Transcript__c> callJunctions = [
            SELECT Id, Call_Transcript__c, Matter__c
            FROM   Related_Call_Transcript__c
            WHERE  Matter__c IN :matterIds
            AND    AI_Reviewed__c = false
            AND    Call_Transcript__c != null
            AND    CreatedDate >= :GO_LIVE_DATE
            ORDER BY CreatedDate ASC
            LIMIT  :QUERY_LIMIT
        ];

        Set<Id> callTranscriptIds = new Set<Id>();
        for (Related_Call_Transcript__c j : callJunctions) callTranscriptIds.add(j.Call_Transcript__c);
        Map<Id, Call_Transcript__c> callTranscriptsById = callTranscriptIds.isEmpty()
            ? new Map<Id, Call_Transcript__c>()
            : new Map<Id, Call_Transcript__c>([SELECT Id, Transcript_Text__c, CreatedDate FROM Call_Transcript__c WHERE Id IN :callTranscriptIds]);

        List<Related_Text_Message__c> textJunctions = [
            SELECT Id, Text_Message_Session__c, Matter__c
            FROM   Related_Text_Message__c
            WHERE  Matter__c IN :matterIds
            AND    AI_Reviewed__c = false
            AND    Text_Message_Session__c != null
            AND    CreatedDate >= :GO_LIVE_DATE
            ORDER BY CreatedDate ASC
            LIMIT  :QUERY_LIMIT
        ];

        Set<Id> sessionIds = new Set<Id>();
        for (Related_Text_Message__c j : textJunctions) sessionIds.add(j.Text_Message_Session__c);
        Map<Id, SMS_Session__c> sessionsById = sessionIds.isEmpty()
            ? new Map<Id, SMS_Session__c>()
            : new Map<Id, SMS_Session__c>([SELECT Id, SMS_Session_Text__c, CreatedDate FROM SMS_Session__c WHERE Id IN :sessionIds]);

        List<Related_Meeting_Transcript__c> meetingJunctions = [
            SELECT Id, Meeting_Transcript__c, Matter__c
            FROM   Related_Meeting_Transcript__c
            WHERE  Matter__c IN :matterIds
            AND    AI_Reviewed__c = false
            AND    Meeting_Transcript__c != null
            AND    CreatedDate >= :GO_LIVE_DATE
            ORDER BY CreatedDate ASC
            LIMIT  :QUERY_LIMIT
        ];

        Set<Id> meetingTranscriptIds = new Set<Id>();
        for (Related_Meeting_Transcript__c j : meetingJunctions) meetingTranscriptIds.add(j.Meeting_Transcript__c);
        Map<Id, Meeting_Transcript__c> meetingTranscriptsById = meetingTranscriptIds.isEmpty()
            ? new Map<Id, Meeting_Transcript__c>()
            : new Map<Id, Meeting_Transcript__c>([SELECT Id, Transcript__c, CreatedDate FROM Meeting_Transcript__c WHERE Id IN :meetingTranscriptIds]);

        // ── 2. Total email count + total call minutes per matter ─────────────

        Map<Id, Integer> emailCountByMatter = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Matter__c, COUNT_DISTINCT(Email_Message_Id__c) cnt
            FROM   Related_Email_Message__c
            WHERE  Matter__c IN :matterIds
            GROUP BY Matter__c
        ]) {
            emailCountByMatter.put((Id) ar.get('Matter__c'), Integer.valueOf(ar.get('cnt')));
        }

        Map<Id, Integer> callMinutesByMatter = new Map<Id, Integer>();
        for (Related_Call_Transcript__c j : [
            SELECT Matter__c, Call_Transcript__r.Call_Duration_HH_MM_SS__c
            FROM   Related_Call_Transcript__c
            WHERE  Matter__c IN :matterIds
            AND    Call_Transcript__c != null
        ]) {
            Integer mins = parseDurationToMinutes(j.Call_Transcript__r.Call_Duration_HH_MM_SS__c);
            Integer current = callMinutesByMatter.containsKey(j.Matter__c) ? callMinutesByMatter.get(j.Matter__c) : 0;
            callMinutesByMatter.put(j.Matter__c, current + mins);
        }

        // ── 3. Bucket by matter ───────────────────────────────────────────────

        Map<Id, List<Related_Email_Message__c>>      emailsByMatter   = new Map<Id, List<Related_Email_Message__c>>();
        Map<Id, List<Related_Call_Transcript__c>>    callsByMatter    = new Map<Id, List<Related_Call_Transcript__c>>();
        Map<Id, List<Related_Text_Message__c>>       textsByMatter    = new Map<Id, List<Related_Text_Message__c>>();
        Map<Id, List<Related_Meeting_Transcript__c>> meetingsByMatter = new Map<Id, List<Related_Meeting_Transcript__c>>();

        for (Related_Email_Message__c j : emailJunctions) {
            if (!emailsByMatter.containsKey(j.Matter__c)) emailsByMatter.put(j.Matter__c, new List<Related_Email_Message__c>());
            emailsByMatter.get(j.Matter__c).add(j);
        }
        for (Related_Call_Transcript__c j : callJunctions) {
            if (!callsByMatter.containsKey(j.Matter__c)) callsByMatter.put(j.Matter__c, new List<Related_Call_Transcript__c>());
            callsByMatter.get(j.Matter__c).add(j);
        }
        for (Related_Text_Message__c j : textJunctions) {
            if (!textsByMatter.containsKey(j.Matter__c)) textsByMatter.put(j.Matter__c, new List<Related_Text_Message__c>());
            textsByMatter.get(j.Matter__c).add(j);
        }
        for (Related_Meeting_Transcript__c j : meetingJunctions) {
            if (!meetingsByMatter.containsKey(j.Matter__c)) meetingsByMatter.put(j.Matter__c, new List<Related_Meeting_Transcript__c>());
            meetingsByMatter.get(j.Matter__c).add(j);
        }

        // ── 4. Per-matter: assemble, call AI, collect DML ─────────────────────

        Map<Id, AcctSeed__Project__c>       matterUpdateMap = new Map<Id, AcctSeed__Project__c>();
        List<Related_Email_Message__c>      emailsToStamp   = new List<Related_Email_Message__c>();
        List<Related_Call_Transcript__c>    callsToStamp    = new List<Related_Call_Transcript__c>();
        List<Related_Text_Message__c>       textsToStamp    = new List<Related_Text_Message__c>();
        List<Related_Meeting_Transcript__c> meetingsToStamp = new List<Related_Meeting_Transcript__c>();

        for (AcctSeed__Project__c matter : matters) {
            Id mId = matter.Id;

            List<Related_Email_Message__c>      matterEmails   = emailsByMatter.containsKey(mId)   ? emailsByMatter.get(mId)   : new List<Related_Email_Message__c>();
            List<Related_Call_Transcript__c>    matterCalls    = callsByMatter.containsKey(mId)    ? callsByMatter.get(mId)    : new List<Related_Call_Transcript__c>();
            List<Related_Text_Message__c>       matterTexts    = textsByMatter.containsKey(mId)    ? textsByMatter.get(mId)    : new List<Related_Text_Message__c>();
            List<Related_Meeting_Transcript__c> matterMeetings = meetingsByMatter.containsKey(mId) ? meetingsByMatter.get(mId) : new List<Related_Meeting_Transcript__c>();

            // Always update email count and call minutes regardless of AI outcome
            AcctSeed__Project__c matterUpdate = new AcctSeed__Project__c(
                Id = mId,
                Total_Email_Count__c  = emailCountByMatter.containsKey(mId)  ? emailCountByMatter.get(mId)  : 0,
                Total_Call_Minutes__c = callMinutesByMatter.containsKey(mId) ? callMinutesByMatter.get(mId) : 0
            );
            matterUpdateMap.put(mId, matterUpdate);

            if (matterEmails.isEmpty() && matterCalls.isEmpty() && matterTexts.isEmpty() && matterMeetings.isEmpty()) continue;

            Integer existingLen = String.isBlank(matter.Communication_Analysis__c) ? 0 : matter.Communication_Analysis__c.length();
            Integer blockBudget = Math.max(50000, MAX_CHARS - existingLen);
            AssemblyResult assembled = assembleCommunicationBlocks(
                matterEmails, emailsById,
                matterCalls,  callTranscriptsById,
                matterTexts,  sessionsById,
                matterMeetings, meetingTranscriptsById,
                blockBudget
            );

            // Stamp records with no resolvable content immediately — no AI needed
            for (Related_Email_Message__c j      : assembled.emailsEmpty)   emailsToStamp.add(new Related_Email_Message__c(Id = j.Id, AI_Reviewed__c = true));
            for (Related_Call_Transcript__c j    : assembled.callsEmpty)    callsToStamp.add(new Related_Call_Transcript__c(Id = j.Id, AI_Reviewed__c = true));
            for (Related_Text_Message__c j       : assembled.textsEmpty)    textsToStamp.add(new Related_Text_Message__c(Id = j.Id, AI_Reviewed__c = true));
            for (Related_Meeting_Transcript__c j : assembled.meetingsEmpty) meetingsToStamp.add(new Related_Meeting_Transcript__c(Id = j.Id, AI_Reviewed__c = true));

            if (String.isBlank(assembled.blocks)) continue;

            if (matter.Communication_Log_Start__c == null) {
                DateTime earliest = findEarliestIncludedDate(assembled, emailsById, callTranscriptsById, sessionsById, meetingTranscriptsById);
                if (earliest != null) matterUpdateMap.get(mId).Communication_Log_Start__c = earliest.date();
            }

            try {
                String blocksWithContext = buildContextHeader(matter) + assembled.blocks;
                String rawResponse = invokePromptTemplate((String) mId, blocksWithContext);

                String analysisSection = extractSection(rawResponse, 'COMMUNICATION_ANALYSIS');
                String logSection      = extractSection(rawResponse, 'COMMUNICATION_LOG');

                if (String.isNotBlank(analysisSection)) {
                    String existing = String.isBlank(matter.Communication_Analysis__c) ? '' : matter.Communication_Analysis__c;
                    String merged   = mergeFactLines(existing, analysisSection);
                    if (merged.length() > 131000) merged = merged.left(131000);
                    matterUpdateMap.get(mId).Communication_Analysis__c = merged;
                }

                if (String.isNotBlank(logSection)) {
                    String existingLog = String.isBlank(matter.Communication_Log__c) ? '' : matter.Communication_Log__c;
                    String newLog      = String.isBlank(existingLog) ? logSection : existingLog + '\n\n' + logSection;
                    if (newLog.length() > 131000) {
                        String trimmed = newLog.right(131000);
                        Integer firstNewline = trimmed.indexOf('\n');
                        if (firstNewline >= 0) trimmed = trimmed.substring(firstNewline + 1);
                        newLog = trimmed;
                    }
                    matterUpdateMap.get(mId).Communication_Log__c = newLog;
                    matterUpdateMap.get(mId).Log_Character_Count__c = newLog.length();
                }

                stampScalarFields(matterUpdateMap.get(mId), matter, rawResponse);
                matterUpdateMap.get(mId).Last_Summarized__c = DateTime.now();

                List<String> historicalLogHeaders = extractLogHeaderLines(matter.Communication_Log__c);
                List<String> newLogHeaders        = extractLogHeaderLines(logSection);
                String overallTone = computeOverallTone(historicalLogHeaders, newLogHeaders);
                String toneTrend   = computeToneTrend(historicalLogHeaders, newLogHeaders);
                if (overallTone != null) matterUpdateMap.get(mId).Overall_Tone__c = overallTone;
                if (toneTrend   != null) matterUpdateMap.get(mId).Tone_Trend__c   = toneTrend;
                matterUpdateMap.get(mId).Communication_Load_Score__c = computeLoadScore(historicalLogHeaders, newLogHeaders, Date.today());

                // Stamp included records only after a successful AI response
                for (Related_Email_Message__c j      : assembled.emailsIncluded)   emailsToStamp.add(new Related_Email_Message__c(Id = j.Id, AI_Reviewed__c = true));
                for (Related_Call_Transcript__c j    : assembled.callsIncluded)    callsToStamp.add(new Related_Call_Transcript__c(Id = j.Id, AI_Reviewed__c = true));
                for (Related_Text_Message__c j       : assembled.textsIncluded)    textsToStamp.add(new Related_Text_Message__c(Id = j.Id, AI_Reviewed__c = true));
                for (Related_Meeting_Transcript__c j : assembled.meetingsIncluded) meetingsToStamp.add(new Related_Meeting_Transcript__c(Id = j.Id, AI_Reviewed__c = true));

            } catch (Exception e) {
                System.debug('MatterCommunicationAnalysisBatch: AI callout failed for Matter ' + mId + ' — ' + e.getTypeName() + ': ' + e.getMessage());
                matterUpdateMap.get(mId).Comms_Has_Error__c      = true;
                matterUpdateMap.get(mId).Comms_Error_Message__c  = (e.getTypeName() + ': ' + e.getMessage()).left(1000);
            }
        }

        // ── 5. DML — junctions first, matter update isolated ─────────────────
        // Batch size = 1, so there is always exactly one matter in scope.
        // If any junction stamp DML fails we flag that matter so self-chaining stops.
        Id singleMatterId = matterUpdateMap.isEmpty() ? null : matterUpdateMap.keySet().iterator().next();

        try {
            if (!emailsToStamp.isEmpty()) update emailsToStamp;
        } catch (Exception e) {
            System.debug('Email stamp failed: ' + e.getMessage());
            if (singleMatterId != null) {
                matterUpdateMap.get(singleMatterId).Comms_Has_Error__c     = true;
                matterUpdateMap.get(singleMatterId).Comms_Error_Message__c = ('Email stamp: ' + e.getTypeName() + ': ' + e.getMessage()).left(1000);
            }
        }
        try {
            if (!callsToStamp.isEmpty()) update callsToStamp;
        } catch (Exception e) {
            System.debug('Call stamp failed: ' + e.getMessage());
            if (singleMatterId != null) {
                matterUpdateMap.get(singleMatterId).Comms_Has_Error__c     = true;
                matterUpdateMap.get(singleMatterId).Comms_Error_Message__c = ('Call stamp: ' + e.getTypeName() + ': ' + e.getMessage()).left(1000);
            }
        }
        try {
            if (!textsToStamp.isEmpty()) update textsToStamp;
        } catch (Exception e) {
            System.debug('Text stamp failed: ' + e.getMessage());
            if (singleMatterId != null) {
                matterUpdateMap.get(singleMatterId).Comms_Has_Error__c     = true;
                matterUpdateMap.get(singleMatterId).Comms_Error_Message__c = ('Text stamp: ' + e.getTypeName() + ': ' + e.getMessage()).left(1000);
            }
        }
        try {
            if (!meetingsToStamp.isEmpty()) update meetingsToStamp;
        } catch (Exception e) {
            System.debug('Meeting stamp failed: ' + e.getMessage());
            if (singleMatterId != null) {
                matterUpdateMap.get(singleMatterId).Comms_Has_Error__c     = true;
                matterUpdateMap.get(singleMatterId).Comms_Error_Message__c = ('Meeting stamp: ' + e.getTypeName() + ': ' + e.getMessage()).left(1000);
            }
        }
        if (!matterUpdateMap.isEmpty()) {
            List<AcctSeed__Project__c> mattersToUpdate = matterUpdateMap.values();
            for (AcctSeed__Project__c m : mattersToUpdate) {
                try {
                    update m;
                } catch (Exception e) {
                    System.debug('Matter update failed for ' + m.Id + ': ' + e.getMessage());
                    try {
                        update new AcctSeed__Project__c(
                            Id                      = m.Id,
                            Comms_Has_Error__c      = true,
                            Comms_Error_Message__c  = (e.getTypeName() + ': ' + e.getMessage()).left(1000)
                        );
                    } catch (Exception flagEx) {
                        System.debug('Error flag update failed for ' + m.Id + ': ' + flagEx.getMessage());
                    }
                }
            }
        }
    }  // end executeInner

    // ── Finish ────────────────────────────────────────────────────────────────

    global void finish(Database.BatchableContext bc) {
        Integer remaining = countPending(matterIdFilter);
        System.debug('MatterCommunicationAnalysisBatch: finished. Remaining: ' + remaining);
        if (remaining > 0) {
            Integer alreadyRunning = [
                SELECT COUNT() FROM AsyncApexJob
                WHERE ApexClass.Name = 'MatterCommunicationAnalysisBatch'
                AND Status IN ('Processing', 'Preparing', 'Queued', 'Holding')
            ];
            if (alreadyRunning == 0) {
                Database.executeBatch(new MatterCommunicationAnalysisBatch(matterIdFilter), 1);
            }
        }
    }

    private static Integer countPending(Set<Id> filter) {
        // Only count junctions tied to Active, non-errored matters — mirrors start() criteria exactly.
        Set<Id> eligibleMatters = new Map<Id, AcctSeed__Project__c>([
            SELECT Id FROM AcctSeed__Project__c
            WHERE  AcctSeed__Status__c = 'Active'
            AND    Comms_Has_Error__c  = false
        ]).keySet();

        if (filter != null && !filter.isEmpty()) {
            Set<Id> scope = new Set<Id>();
            for (Id id : filter) { if (eligibleMatters.contains(id)) scope.add(id); }
            if (scope.isEmpty()) return 0;
            return [SELECT COUNT() FROM Related_Email_Message__c     WHERE Matter__c IN :scope AND AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE]
                 + [SELECT COUNT() FROM Related_Call_Transcript__c   WHERE Matter__c IN :scope AND AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE]
                 + [SELECT COUNT() FROM Related_Text_Message__c      WHERE Matter__c IN :scope AND AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE]
                 + [SELECT COUNT() FROM Related_Meeting_Transcript__c WHERE Matter__c IN :scope AND AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE];
        }
        return [SELECT COUNT() FROM Related_Email_Message__c     WHERE AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE AND Matter__c IN :eligibleMatters]
             + [SELECT COUNT() FROM Related_Call_Transcript__c   WHERE AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE AND Matter__c IN :eligibleMatters]
             + [SELECT COUNT() FROM Related_Text_Message__c      WHERE AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE AND Matter__c IN :eligibleMatters]
             + [SELECT COUNT() FROM Related_Meeting_Transcript__c WHERE AI_Reviewed__c = false AND CreatedDate >= :GO_LIVE_DATE AND Matter__c IN :eligibleMatters];
    }

    // ── AssemblyResult ────────────────────────────────────────────────────────

    private class AssemblyResult {
        String blocks = '';
        List<Related_Email_Message__c>      emailsIncluded   = new List<Related_Email_Message__c>();
        List<Related_Call_Transcript__c>    callsIncluded    = new List<Related_Call_Transcript__c>();
        List<Related_Text_Message__c>       textsIncluded    = new List<Related_Text_Message__c>();
        List<Related_Meeting_Transcript__c> meetingsIncluded = new List<Related_Meeting_Transcript__c>();
        List<Related_Email_Message__c>      emailsEmpty      = new List<Related_Email_Message__c>();
        List<Related_Call_Transcript__c>    callsEmpty       = new List<Related_Call_Transcript__c>();
        List<Related_Text_Message__c>       textsEmpty       = new List<Related_Text_Message__c>();
        List<Related_Meeting_Transcript__c> meetingsEmpty    = new List<Related_Meeting_Transcript__c>();
    }

    // ── assembleCommunicationBlocks ───────────────────────────────────────────
    // Fills blocks up to MAX_CHARS with full records — no truncation of individual records.
    // Records with no content → emailsEmpty (stamped immediately, no AI cost).
    // Records that don't fit in this run's budget → left unreviewed, picked up next run.

    private static AssemblyResult assembleCommunicationBlocks(
        List<Related_Email_Message__c>      emailJunctions,
        Map<Id, EmailMessage>               emailsById,
        List<Related_Call_Transcript__c>    callJunctions,
        Map<Id, Call_Transcript__c>         callTranscriptsById,
        List<Related_Text_Message__c>       textJunctions,
        Map<Id, SMS_Session__c>             sessionsById,
        List<Related_Meeting_Transcript__c> meetingJunctions,
        Map<Id, Meeting_Transcript__c>      meetingTranscriptsById,
        Integer budget
    ) {
        AssemblyResult result = new AssemblyResult();
        Integer charsUsed = 0;

        Set<Id> seenEmailIds = new Set<Id>();
        for (Related_Email_Message__c j : emailJunctions) {
            Id emailId;
            try { emailId = (Id) j.Email_Message_Id__c; } catch (Exception e) { result.emailsEmpty.add(j); continue; }
            if (seenEmailIds.contains(emailId)) { result.emailsEmpty.add(j); continue; }
            seenEmailIds.add(emailId);
            EmailMessage em = emailsById.get(emailId);
            if (em == null || String.isBlank(em.TextBody)) { result.emailsEmpty.add(j); continue; }
            if (charsUsed + em.TextBody.length() > budget) continue;
            String direction = em.Incoming == true ? 'Inbound' : 'Outbound';
            String block = '--- EMAIL | Id: ' + j.Id + ' | Date: ' + formatDateTime(em.CreatedDate) + ' | Direction: ' + direction + ' | From: ' + (String.isNotBlank(em.FromAddress) ? em.FromAddress : 'Unknown') + ' ---\n' + em.TextBody + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.emailsIncluded.add(j);
        }

        for (Related_Call_Transcript__c j : callJunctions) {
            Call_Transcript__c ct = callTranscriptsById.get(j.Call_Transcript__c);
            if (ct == null || String.isBlank(ct.Transcript_Text__c)) { result.callsEmpty.add(j); continue; }
            if (charsUsed + ct.Transcript_Text__c.length() > budget) continue;
            String block = '--- CALL TRANSCRIPT | Id: ' + j.Id + ' | Date: ' + formatDateTime(ct.CreatedDate) + ' ---\n' + ct.Transcript_Text__c + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.callsIncluded.add(j);
        }

        for (Related_Text_Message__c j : textJunctions) {
            SMS_Session__c sess = sessionsById.get(j.Text_Message_Session__c);
            if (sess == null || String.isBlank(sess.SMS_Session_Text__c)) { result.textsEmpty.add(j); continue; }
            if (charsUsed + sess.SMS_Session_Text__c.length() > budget) continue;
            String block = '--- SMS SESSION | Id: ' + j.Id + ' | Date: ' + formatDateTime(sess.CreatedDate) + ' ---\n' + sess.SMS_Session_Text__c + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.textsIncluded.add(j);
        }

        for (Related_Meeting_Transcript__c j : meetingJunctions) {
            Meeting_Transcript__c mt = meetingTranscriptsById.get(j.Meeting_Transcript__c);
            if (mt == null || String.isBlank(mt.Transcript__c)) { result.meetingsEmpty.add(j); continue; }
            if (charsUsed + mt.Transcript__c.length() > budget) continue;
            String block = '--- MEETING TRANSCRIPT | Id: ' + j.Id + ' | Date: ' + formatDateTime(mt.CreatedDate) + ' ---\n' + mt.Transcript__c + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.meetingsIncluded.add(j);
        }

        return result;
    }

    // ── extractSection ────────────────────────────────────────────────────────

    @TestVisible
    private static String extractSection(String response, String sectionName) {
        String marker = '==' + sectionName + '==';
        Integer markerIdx = response.indexOf(marker);
        if (markerIdx < 0) return '';
        Integer contentStart = markerIdx + marker.length();
        if (contentStart < response.length() && response.substring(contentStart, contentStart + 1) == '\n') {
            contentStart++;
        }
        String afterMarker   = response.substring(contentStart);
        Integer nextSection  = afterMarker.indexOf('\n==');
        return nextSection >= 0 ? afterMarker.substring(0, nextSection).trim() : afterMarker.trim();
    }

    // ── mergeFactLines ────────────────────────────────────────────────────────
    // Merges new AI structured fact output into existing field content.
    // New fact-lines are appended into matching [Issue] sections; new sections appended at end.
    // Duplicate fact-lines within the same section are not added twice.

    @TestVisible
    private static String mergeFactLines(String existing, String newFacts) {
        if (String.isBlank(existing)) return newFacts;
        if (String.isBlank(newFacts))  return existing;

        Map<String, List<String>> sectionMap   = new Map<String, List<String>>();
        List<String>              sectionOrder = new List<String>();
        String currentSection = null;

        for (String line : existing.split('\n')) {
            String trimmed = line.trim();
            if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
                currentSection = trimmed;
                if (!sectionMap.containsKey(currentSection)) {
                    sectionMap.put(currentSection, new List<String>());
                    sectionOrder.add(currentSection);
                }
            } else if (currentSection != null && String.isNotBlank(trimmed) && !trimmed.startsWith('<')) {
                sectionMap.get(currentSection).add(trimmed);
            }
        }

        currentSection = null;
        for (String line : newFacts.split('\n')) {
            String trimmed = line.trim();
            if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
                currentSection = trimmed;
                if (!sectionMap.containsKey(currentSection)) {
                    sectionMap.put(currentSection, new List<String>());
                    sectionOrder.add(currentSection);
                }
            } else if (currentSection != null && String.isNotBlank(trimmed) && !trimmed.startsWith('<')) {
                if (!sectionMap.get(currentSection).contains(trimmed)) {
                    sectionMap.get(currentSection).add(trimmed);
                }
            }
        }

        String result = '';
        for (String section : sectionOrder) {
            result += section + '\n';
            for (String factLine : sectionMap.get(section)) {
                result += factLine + '\n';
            }
            result += '\n\n';
        }
        return result.trim();
    }

    // ── formatDateTime ────────────────────────────────────────────────────────

    private static String formatDateTime(DateTime dt) {
        return dt == null ? 'Unknown' : dt.format('yyyy-MM-dd HH:mm:ss', 'GMT');
    }

    // ── buildContextHeader ────────────────────────────────────────────────────
    // Prepended to communicationBlocks so the AI knows today's date for the
    // CLIENT_ENGAGEMENT_STATUS 14-day rule.

    private static String buildContextHeader(AcctSeed__Project__c matter) {
        String header = 'Today: ' + String.valueOf(Date.today()) + '\n';
        if (matter.Attorney_Callback_Requested__c != null) {
            header += 'Pending Attorney Callback Request: ' + matter.Attorney_Callback_Requested__c.format('yyyy-MM-dd HH:mm:ss') + '\n';
        }
        header += 'Current Open Promises:\n';
        String openPromisesText = String.isNotBlank(matter.Open_Promises__c)
            ? matter.Open_Promises__c.replaceAll('<[^>]+>', '').trim()
            : 'None';
        header += openPromisesText;
        return header + '\n\n';
    }

    // ── extractScalarValue ────────────────────────────────────────────────────
    // Tries the ==SECTION_NAME== marker format first, then falls back to parsing
    // flat key-value lines (e.g. "SECTION_NAME value") that the AI sometimes outputs.

    @TestVisible
    private static String extractScalarValue(String rawResponse, String key) {
        String val = extractSection(rawResponse, key);
        if (String.isNotBlank(val)) return val;
        for (String line : rawResponse.split('\n')) {
            String trimmed = line.trim();
            if (trimmed.startsWithIgnoreCase(key + ' ') || trimmed.startsWithIgnoreCase(key + ':')) {
                String v = trimmed.substringAfter(key).trim();
                if (v.startsWith(':')) v = v.substringAfter(':').trim();
                return v;
            }
        }
        return '';
    }

    // ── stampScalarFields ─────────────────────────────────────────────────────
    // Parses the 6 scalar output sections from the AI response and stamps the
    // matter update record. Sections absent or returning NONE are not written,
    // preserving the existing field value.

    @TestVisible
    private static void stampScalarFields(AcctSeed__Project__c mUpdate, AcctSeed__Project__c matter, String rawResponse) {
        String lastSubVal    = extractScalarValue(rawResponse, 'LAST_SUBSTANTIVE_CONVERSATION');
        String lastInbVal    = extractScalarValue(rawResponse, 'LAST_CLIENT_INBOUND');
        String lastAttyVal   = extractScalarValue(rawResponse, 'LAST_ATTORNEY_CLIENT_CONVERSATION');
        String unansweredVal = extractScalarValue(rawResponse, 'UNANSWERED_CLIENT_MESSAGES');
        String callbackVal   = extractScalarValue(rawResponse, 'ATTORNEY_CALLBACK_REQUESTED');
        String statusVal     = extractScalarValue(rawResponse, 'CLIENT_ENGAGEMENT_STATUS');
        String escalationVal = extractScalarValue(rawResponse, 'LAST_ESCALATION_DATE');

        if (String.isNotBlank(lastSubVal) && lastSubVal != 'NONE') {
            try { mUpdate.Last_Substantive_Conversation__c = DateTime.valueOf(lastSubVal); } catch (Exception e) {}
        }
        if (String.isNotBlank(lastInbVal) && lastInbVal != 'NONE') {
            try { mUpdate.Last_Client_Inbound__c = DateTime.valueOf(lastInbVal); } catch (Exception e) {}
        }
        if (String.isNotBlank(lastAttyVal) && lastAttyVal != 'NONE') {
            try { mUpdate.Last_Attorney_Client_Conversation__c = DateTime.valueOf(lastAttyVal); } catch (Exception e) {}
        }
        if (String.isNotBlank(unansweredVal) && unansweredVal != 'NONE') {
            try {
                if (unansweredVal.startsWith('RESET|')) {
                    Integer n = Integer.valueOf(unansweredVal.substringAfter('RESET|'));
                    mUpdate.Unanswered_Client_Messages__c = Math.max(0, n);
                } else if (unansweredVal.startsWith('ADD|')) {
                    Integer n = Integer.valueOf(unansweredVal.substringAfter('ADD|'));
                    Integer current = matter.Unanswered_Client_Messages__c != null ? matter.Unanswered_Client_Messages__c.intValue() : 0;
                    mUpdate.Unanswered_Client_Messages__c = Math.max(0, current + n);
                }
            } catch (Exception e) {}
        }
        if (String.isNotBlank(callbackVal)) {
            if (callbackVal == 'CLEAR') {
                mUpdate.Attorney_Callback_Requested__c = null;
                mUpdate.Unanswered_Client_Messages__c  = 0;
            } else if (callbackVal != 'NONE') {
                try { mUpdate.Attorney_Callback_Requested__c = DateTime.valueOf(callbackVal); } catch (Exception e) {}
            }
        }
        if (String.isNotBlank(statusVal) && statusVal != 'NONE') {
            mUpdate.Client_Engagement_Status__c = statusVal;
        }
        if (String.isNotBlank(escalationVal) && escalationVal != 'NONE') {
            try { mUpdate.Last_Escalation_Date__c = Date.valueOf(escalationVal); } catch (Exception e) {}
        }

        String openPromisesVal      = extractScalarValue(rawResponse, 'OPEN_PROMISES');
        String completedPromisesVal = extractScalarValue(rawResponse, 'COMPLETED_PROMISES');
        String brokenPromisesVal    = extractScalarValue(rawResponse, 'BROKEN_PROMISES');

        if (String.isNotBlank(openPromisesVal)) {
            if (openPromisesVal == 'NONE') {
                mUpdate.Open_Promises__c = null;
            } else {
                String html = '';
                for (String line : openPromisesVal.split('\n')) {
                    if (String.isNotBlank(line.trim())) html += formatPromiseHtml(line.trim());
                }
                mUpdate.Open_Promises__c = html.left(32768);
            }
        }
        if (String.isNotBlank(completedPromisesVal) && completedPromisesVal != 'NONE') {
            String existing = String.isBlank(matter.Completed_Promises__c) ? '' : matter.Completed_Promises__c;
            String newHtml = '';
            for (String line : completedPromisesVal.split('\n')) {
                if (String.isNotBlank(line.trim())) newHtml += formatPromiseHtml(line.trim());
            }
            mUpdate.Completed_Promises__c = (existing + newHtml).left(32768);
        }
        if (String.isNotBlank(brokenPromisesVal) && brokenPromisesVal != 'NONE') {
            String existing = String.isBlank(matter.Broken_Promises__c) ? '' : matter.Broken_Promises__c;
            String newHtml = '';
            for (String line : brokenPromisesVal.split('\n')) {
                if (String.isNotBlank(line.trim())) newHtml += formatPromiseHtml(line.trim());
            }
            mUpdate.Broken_Promises__c = (existing + newHtml).left(32768);
        }
    }

    // ── formatPromiseHtml ─────────────────────────────────────────────────────
    // Converts a pipe-delimited promise line from the AI into an HTML paragraph
    // with a hyperlink to the referenced Salesforce communication record.
    // Format: date|party|description|due_date|recordId

    @TestVisible
    private static String formatPromiseHtml(String pipeLine) {
        if (String.isBlank(pipeLine)) return '';
        List<String> parts      = pipeLine.split('\\|', -1);
        String promiseDate  = parts.size() > 0 ? parts[0].trim() : '';
        String party        = parts.size() > 1 ? parts[1].trim() : '';
        String description  = parts.size() > 2 ? parts[2].trim() : '';
        String dueDate      = parts.size() > 3 ? parts[3].trim() : '';
        String recordId     = parts.size() > 4 ? parts[4].trim() : '';

        String line = promiseDate + ' | <strong>' + party + '</strong> | ' + description;
        if (String.isNotBlank(dueDate) && dueDate != 'NONE') line += ' | Due: ' + dueDate;
        if (String.isNotBlank(recordId)) line += ' | <a href="/' + recordId + '">View Record</a>';
        return '<p>' + line + '</p>';
    }

    // ── parseDurationToMinutes ────────────────────────────────────────────────

    @TestVisible
    private static Integer parseDurationToMinutes(String hhmmss) {
        if (String.isBlank(hhmmss)) return 0;
        try {
            List<String> parts = hhmmss.split(':');
            if (parts.size() == 3) {
                return (Integer.valueOf(parts[0]) * 60) + Integer.valueOf(parts[1]);
            } else if (parts.size() == 2) {
                return Integer.valueOf(parts[0]);
            }
        } catch (Exception e) {}
        return 0;
    }

    // ── Tone and Load Score computation ──────────────────────────────────────

    @TestVisible
    private static List<String> extractLogHeaderLines(String logContent) {
        List<String> headers = new List<String>();
        if (String.isBlank(logContent)) return headers;
        for (String line : logContent.split('\n')) {
            String trimmed = line.trim();
            if (String.isBlank(trimmed)) continue;
            if (trimmed.split('\\|', -1).size() >= 11) headers.add(trimmed);
        }
        return headers;
    }

    @TestVisible
    private static String getToneFromHeader(String header) {
        List<String> parts = header.split('\\|', -1);
        return parts.size() > 7 ? parts[7].trim() : 'Neutral';
    }

    @TestVisible
    private static Decimal toneToNumber(String tone) {
        if (tone == 'Cooperative')              return  2;
        if (tone == 'Neutral')                  return  1;
        if (tone == 'Tense')                    return -1;
        if (tone == 'Hostile')                  return -2;
        if (tone == 'Distressed' || tone == 'Crisis') return -2;
        return 0;
    }

    @TestVisible
    private static String mapToneToPicklist(String tone) {
        if (tone == 'Distressed') return 'Crisis';
        return tone;
    }

    @TestVisible
    private static Decimal toneListAverage(List<String> headers) {
        if (headers.isEmpty()) return 0;
        Decimal sum = 0;
        for (String h : headers) sum += toneToNumber(getToneFromHeader(h));
        return sum / headers.size();
    }

    @TestVisible
    private static String computeOverallTone(List<String> historicalHeaders, List<String> newHeaders) {
        List<String> combined = new List<String>(historicalHeaders);
        combined.addAll(newHeaders);
        if (combined.isEmpty()) return null;

        Integer startIdx = Math.max(0, combined.size() - 10);
        List<String> window = new List<String>();
        for (Integer i = startIdx; i < combined.size(); i++) window.add(combined[i]);

        if (window.size() < 3) return mapToneToPicklist(getToneFromHeader(window[window.size() - 1]));

        Decimal weightedSum = 0;
        Decimal totalWeight = 0;
        Boolean hasDistressed = false;
        Integer sz = window.size();

        for (Integer i = 0; i < sz; i++) {
            String tone = getToneFromHeader(window[sz - 1 - i]);
            if (tone == 'Distressed' || tone == 'Crisis') hasDistressed = true;
            Decimal weight = 1.0 - (Decimal.valueOf(i) * 0.1);
            weightedSum += toneToNumber(tone) * weight;
            totalWeight  += weight;
        }

        Decimal avg = totalWeight > 0 ? weightedSum / totalWeight : 0;
        if (hasDistressed && avg < 0) return 'Crisis';
        if (avg >= 1.5)  return 'Cooperative';
        if (avg >= -0.5) return 'Neutral';
        if (avg >= -1.5) return 'Tense';
        return 'Hostile';
    }

    @TestVisible
    private static String computeToneTrend(List<String> historicalHeaders, List<String> newHeaders) {
        List<String> combined = new List<String>(historicalHeaders);
        combined.addAll(newHeaders);
        if (combined.isEmpty()) return null;

        Integer startIdx = Math.max(0, combined.size() - 10);
        List<String> window = new List<String>();
        for (Integer i = startIdx; i < combined.size(); i++) window.add(combined[i]);

        if (window.size() < 4) return 'Stable';

        Integer half = window.size() / 2;
        List<String> priorHalf  = new List<String>();
        List<String> recentHalf = new List<String>();
        for (Integer i = 0; i < window.size(); i++) {
            if (i < half) priorHalf.add(window[i]);
            else          recentHalf.add(window[i]);
        }

        Decimal diff = toneListAverage(recentHalf) - toneListAverage(priorHalf);
        if (diff >=  0.6) return 'Improving';
        if (diff <= -0.6) return 'Deteriorating';
        return 'Stable';
    }

    @TestVisible
    private static Integer computeLoadScore(List<String> historicalHeaders, List<String> newHeaders, Date today) {
        List<String> combined = new List<String>(historicalHeaders);
        combined.addAll(newHeaders);

        Decimal weightedTotal = 0;
        for (String header : combined) {
            List<String> parts = header.split('\\|', -1);
            if (parts.size() <= 8) continue;
            String timestampStr = parts[0].trim();
            String loadStr      = parts[8].trim();
            if (String.isBlank(timestampStr) || String.isBlank(loadStr)) continue;

            Integer load;
            try { load = Integer.valueOf(loadStr); } catch (Exception e) { continue; }

            Date commDate;
            try {
                String dateStr = timestampStr.replace('T', ' ');
                if (dateStr.length() == 16) dateStr += ':00';
                commDate = DateTime.valueOf(dateStr).date();
            } catch (Exception e) { continue; }

            Integer age = commDate.daysBetween(today);
            if (age < 0 || age > 30) continue;

            Decimal weight = age <= 7 ? 1.0 : age <= 14 ? 0.6 : 0.3;
            weightedTotal += load * weight;
        }

        if (weightedTotal <= 5)  return Integer.valueOf((weightedTotal * 6).round());
        if (weightedTotal <= 15) return Integer.valueOf((30 + (weightedTotal - 5) * 4).round());
        return Math.min(100, Integer.valueOf((70 + (weightedTotal - 15) * 2).round()));
    }

    // ── findEarliestIncludedDate ──────────────────────────────────────────────

    private static DateTime findEarliestIncludedDate(
        AssemblyResult assembled,
        Map<Id, EmailMessage> emailsById,
        Map<Id, Call_Transcript__c> callTranscriptsById,
        Map<Id, SMS_Session__c> sessionsById,
        Map<Id, Meeting_Transcript__c> meetingTranscriptsById
    ) {
        DateTime earliest = null;
        for (Related_Email_Message__c j : assembled.emailsIncluded) {
            Id emailId;
            try { emailId = (Id) j.Email_Message_Id__c; } catch (Exception e) { continue; }
            EmailMessage em = emailsById.get(emailId);
            if (em != null && em.CreatedDate != null && (earliest == null || em.CreatedDate < earliest)) earliest = em.CreatedDate;
        }
        for (Related_Call_Transcript__c j : assembled.callsIncluded) {
            Call_Transcript__c ct = callTranscriptsById.get(j.Call_Transcript__c);
            if (ct != null && ct.CreatedDate != null && (earliest == null || ct.CreatedDate < earliest)) earliest = ct.CreatedDate;
        }
        for (Related_Text_Message__c j : assembled.textsIncluded) {
            SMS_Session__c sess = sessionsById.get(j.Text_Message_Session__c);
            if (sess != null && sess.CreatedDate != null && (earliest == null || sess.CreatedDate < earliest)) earliest = sess.CreatedDate;
        }
        for (Related_Meeting_Transcript__c j : assembled.meetingsIncluded) {
            Meeting_Transcript__c mt = meetingTranscriptsById.get(j.Meeting_Transcript__c);
            if (mt != null && mt.CreatedDate != null && (earliest == null || mt.CreatedDate < earliest)) earliest = mt.CreatedDate;
        }
        return earliest;
    }

    // ── invokePromptTemplate ──────────────────────────────────────────────────

    private static String invokePromptTemplate(String matterId, String communicationBlocks) {
        ConnectApi.WrappedValue matterIdVal = new ConnectApi.WrappedValue();
        matterIdVal.value = matterId;

        ConnectApi.WrappedValue blocksVal = new ConnectApi.WrappedValue();
        blocksVal.value = communicationBlocks;

        ConnectApi.WrappedValue existingFactsVal = new ConnectApi.WrappedValue();
        existingFactsVal.value = '';

        ConnectApi.EinsteinPromptTemplateGenerationsInput ptInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        ptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        ptInput.isPreview        = false;
        ptInput.inputParams      = new Map<String, ConnectApi.WrappedValue>{
            'Input:matterId'            => matterIdVal,
            'Input:communicationBlocks' => blocksVal,
            'Input:existingFacts'       => existingFactsVal
        };

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                PROMPT_TEMPLATE_DEV_NAME, ptInput
            );

        if (result == null || result.generations == null || result.generations.isEmpty()
            || String.isBlank(result.generations[0].text)) {
            throw new CalloutException('Empty or null response from prompt template: ' + PROMPT_TEMPLATE_DEV_NAME);
        }

        return result.generations[0].text;
    }
}