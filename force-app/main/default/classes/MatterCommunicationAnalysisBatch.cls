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
                    String merged   = mergeFactLines(existing, linkifyFactLines(analysisSection, assembled.refs));
                    if (merged.length() > 131000) merged = merged.left(131000);
                    matterUpdateMap.get(mId).Communication_Analysis__c = merged;
                }

                if (String.isNotBlank(logSection)) {
                    String linkedLog   = linkifyLogSection(logSection, assembled.refs);
                    String existingLog = String.isBlank(matter.Communication_Log__c) ? '' : matter.Communication_Log__c;
                    String newLog      = String.isBlank(existingLog) ? linkedLog : existingLog + '\n\n' + linkedLog;
                    if (newLog.length() > 131000) {
                        String trimmed = newLog.right(131000);
                        Integer firstNewline = trimmed.indexOf('\n');
                        if (firstNewline >= 0) trimmed = trimmed.substring(firstNewline + 1);
                        newLog = trimmed;
                    }
                    matterUpdateMap.get(mId).Communication_Log__c = newLog;
                    matterUpdateMap.get(mId).Log_Character_Count__c = newLog.length();
                }

                stampScalarFields(matterUpdateMap.get(mId), matter, rawResponse, assembled.refs);
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
        // ordinal (as a string) → the communication record that block was built from
        Map<String, BlockRef> refs = new Map<String, BlockRef>();
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
    // Each block header carries an ordinal ("Ref: 7"), never a record Id. result.refs maps
    // that ordinal to the UNDERLYING communication record (EmailMessage / Call_Transcript__c
    // / SMS_Session__c / Meeting_Transcript__c) so Apex, not the AI, writes every Id that
    // reaches a field. Junctions are still what gets stamped AI_Reviewed__c — that is tracked
    // through the *Included lists below and is unaffected by what the header shows.
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
        Integer refSeq    = 0;

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
            refSeq++;
            String refKey = String.valueOf(refSeq);
            result.refs.put(refKey, new BlockRef(em.Id, em.CreatedDate));
            String block = '--- EMAIL | Ref: ' + refKey + ' | Date: ' + formatDateTime(em.CreatedDate) + ' | Direction: ' + direction + ' | From: ' + (String.isNotBlank(em.FromAddress) ? em.FromAddress : 'Unknown') + ' ---\n' + em.TextBody + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.emailsIncluded.add(j);
        }

        for (Related_Call_Transcript__c j : callJunctions) {
            Call_Transcript__c ct = callTranscriptsById.get(j.Call_Transcript__c);
            if (ct == null || String.isBlank(ct.Transcript_Text__c)) { result.callsEmpty.add(j); continue; }
            if (charsUsed + ct.Transcript_Text__c.length() > budget) continue;
            refSeq++;
            String refKey = String.valueOf(refSeq);
            result.refs.put(refKey, new BlockRef(ct.Id, ct.CreatedDate));
            String block = '--- CALL TRANSCRIPT | Ref: ' + refKey + ' | Date: ' + formatDateTime(ct.CreatedDate) + ' ---\n' + ct.Transcript_Text__c + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.callsIncluded.add(j);
        }

        for (Related_Text_Message__c j : textJunctions) {
            SMS_Session__c sess = sessionsById.get(j.Text_Message_Session__c);
            if (sess == null || String.isBlank(sess.SMS_Session_Text__c)) { result.textsEmpty.add(j); continue; }
            if (charsUsed + sess.SMS_Session_Text__c.length() > budget) continue;
            refSeq++;
            String refKey = String.valueOf(refSeq);
            result.refs.put(refKey, new BlockRef(sess.Id, sess.CreatedDate));
            String block = '--- SMS SESSION | Ref: ' + refKey + ' | Date: ' + formatDateTime(sess.CreatedDate) + ' ---\n' + sess.SMS_Session_Text__c + '\n\n';
            result.blocks += block;
            charsUsed += block.length();
            result.textsIncluded.add(j);
        }

        for (Related_Meeting_Transcript__c j : meetingJunctions) {
            Meeting_Transcript__c mt = meetingTranscriptsById.get(j.Meeting_Transcript__c);
            if (mt == null || String.isBlank(mt.Transcript__c)) { result.meetingsEmpty.add(j); continue; }
            if (charsUsed + mt.Transcript__c.length() > budget) continue;
            refSeq++;
            String refKey = String.valueOf(refSeq);
            result.refs.put(refKey, new BlockRef(mt.Id, mt.CreatedDate));
            String block = '--- MEETING TRANSCRIPT | Ref: ' + refKey + ' | Date: ' + formatDateTime(mt.CreatedDate) + ' ---\n' + mt.Transcript__c + '\n\n';
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
        // Dedupe keys are the markup-stripped form of each fact line, so a stored line that
        // already carries record hyperlinks still matches the plain line the AI returns.
        Map<String, Set<String>>  sectionKeys  = new Map<String, Set<String>>();
        List<String>              sectionOrder = new List<String>();
        String currentSection = null;

        for (String line : existing.split('\n')) {
            String trimmed = line.trim();
            if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
                currentSection = trimmed;
                if (!sectionMap.containsKey(currentSection)) {
                    sectionMap.put(currentSection, new List<String>());
                    sectionKeys.put(currentSection, new Set<String>());
                    sectionOrder.add(currentSection);
                }
            } else if (currentSection != null && String.isNotBlank(trimmed) && !trimmed.startsWith('<')) {
                sectionMap.get(currentSection).add(trimmed);
                sectionKeys.get(currentSection).add(stripTags(trimmed));
            }
        }

        currentSection = null;
        for (String line : newFacts.split('\n')) {
            String trimmed = line.trim();
            if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
                currentSection = trimmed;
                if (!sectionMap.containsKey(currentSection)) {
                    sectionMap.put(currentSection, new List<String>());
                    sectionKeys.put(currentSection, new Set<String>());
                    sectionOrder.add(currentSection);
                }
            } else if (currentSection != null && String.isNotBlank(trimmed) && !trimmed.startsWith('<')) {
                String key = stripTags(trimmed);
                if (!sectionKeys.get(currentSection).contains(key)) {
                    sectionMap.get(currentSection).add(trimmed);
                    sectionKeys.get(currentSection).add(key);
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

    // ── Block references ──────────────────────────────────────────────────────
    // The AI is never shown a record Id. Each transcript block is labelled with a small
    // ordinal ("Ref: 7") and the AI echoes that ordinal back. Apex holds the ordinal →
    // record map and substitutes the real Id afterwards, so a malformed, fabricated or
    // mis-transcribed Id cannot reach the output: every Id written comes from this map.
    //
    // The one error left available to the AI is naming the wrong ordinal. That is caught
    // by comparing the entry's own timestamp against the referenced block's date — see
    // resolveLogRef.

    public class BlockRef {
        public Id       recordId;
        public DateTime blockDate;
        public BlockRef(Id recordId, DateTime blockDate) {
            this.recordId  = recordId;
            this.blockDate = blockDate;
        }
    }

    // Entry timestamps are rounded to the minute and drift by seconds, so a block within two
    // minutes is the same communication. The window has to stay tight: replies inside one
    // email thread land three or four minutes apart, and a wide window makes them
    // indistinguishable.
    private static final Long REF_MATCH_TOLERANCE_MS = 120L * 1000L;

    // Pulls the ordinal out of whatever the AI wrote — "7", "Ref: 7", "[7]" all resolve.
    @TestVisible
    private static Id resolveRef(String rawValue, Map<String, BlockRef> refs) {
        if (String.isBlank(rawValue) || refs == null || refs.isEmpty()) return null;
        String digits = rawValue.trim().replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) return null;
        BlockRef br = refs.get(digits);
        return br == null ? null : br.recordId;
    }

    // Resolves a log entry's ref, then sanity-checks it against the entry's timestamp.
    // If the referenced block is far from the timestamp AND exactly one other block sits
    // within tolerance, the AI named the wrong ordinal and the closer block wins.
    // Ambiguous or unmatched cases keep the AI's choice — only positive evidence overrides.
    @TestVisible
    private static Id resolveLogRef(String rawValue, String rawTimestamp, Map<String, BlockRef> refs) {
        if (refs == null || refs.isEmpty()) return null;

        String   digits = String.isBlank(rawValue) ? '' : rawValue.trim().replaceAll('[^0-9]', '');
        BlockRef cited  = String.isBlank(digits) ? null : refs.get(digits);
        DateTime stamp  = parseLogTimestamp(rawTimestamp);

        if (stamp == null) return cited == null ? null : cited.recordId;

        if (cited != null && cited.blockDate != null
            && Math.abs(stamp.getTime() - cited.blockDate.getTime()) <= REF_MATCH_TOLERANCE_MS) {
            return cited.recordId;   // cited block matches the timestamp — trust it
        }

        // Find the closest block and the runner-up. Overriding needs the closest to be inside
        // the window AND the runner-up to be outside it — otherwise two blocks both explain
        // the timestamp (same-second sends) and only the AI can tell them apart.
        BlockRef nearest    = null;
        Long     bestDist   = null;
        Long     secondDist = null;
        for (BlockRef br : refs.values()) {
            if (br.blockDate == null) continue;
            Long dist = Math.abs(stamp.getTime() - br.blockDate.getTime());
            if (bestDist == null || dist < bestDist) {
                secondDist = bestDist;
                bestDist   = dist;
                nearest    = br;
            } else if (secondDist == null || dist < secondDist) {
                secondDist = dist;
            }
        }

        if (nearest != null && bestDist <= REF_MATCH_TOLERANCE_MS
            && (secondDist == null || secondDist > REF_MATCH_TOLERANCE_MS)) {
            return nearest.recordId;
        }
        return cited == null ? null : cited.recordId;
    }

    @TestVisible
    private static DateTime parseLogTimestamp(String ts) {
        if (String.isBlank(ts)) return null;
        String v = ts.trim();
        if (v.length() < 16) return null;
        try {
            return DateTime.newInstanceGmt(
                Integer.valueOf(v.substring(0, 4)),
                Integer.valueOf(v.substring(5, 7)),
                Integer.valueOf(v.substring(8, 10)),
                Integer.valueOf(v.substring(11, 13)),
                Integer.valueOf(v.substring(14, 16)),
                0);
        } catch (Exception e) {
            return null;
        }
    }

    // ── Communication record linking ──────────────────────────────────────────
    // Each block header hands the AI the Id of the underlying communication record
    // (EmailMessage / Call_Transcript__c / SMS_Session__c / Meeting_Transcript__c) and
    // the AI echoes it back in log lines, fact lines and promise lines. What comes back
    // cannot be trusted: the model has been observed returning label text ("View Record"),
    // the Matter Id, and fabricated placeholder Ids. These helpers accept only Ids that
    // actually resolve to a communication object in this org, and link only those.

    private static final Set<String> LINKABLE_COMM_OBJECTS = new Set<String>{
        'EmailMessage',
        'Call_Transcript__c',
        'SMS_Session__c',
        'Meeting_Transcript__c',
        // Junction Ids — still accepted so entries written before this change keep linking.
        'Related_Email_Message__c',
        'Related_Call_Transcript__c',
        'Related_Text_Message__c',
        'Related_Meeting_Transcript__c'
    };

    // Key prefixes are assigned per org, so prefix → object name is resolved at runtime
    // and cached for the life of the transaction.
    private static Map<String, String> objectNameByPrefix = new Map<String, String>();

    // Returns the Lightning URL for a genuine communication record Id, or null when the
    // value is not an Id, does not resolve in this org, or points at some other object.
    @TestVisible
    private static String commRecordUrl(String rawValue) {
        if (String.isBlank(rawValue)) return null;
        String candidate = rawValue.trim();
        if (candidate.length() != 15 && candidate.length() != 18) return null;
        if (!Pattern.matches('[a-zA-Z0-9]+', candidate)) return null;

        String objName;
        try {
            Id recId  = Id.valueOf(candidate);
            candidate = String.valueOf(recId);          // normalise 15-char Ids to 18
            String pfx = candidate.substring(0, 3);
            if (!objectNameByPrefix.containsKey(pfx)) {
                Schema.SObjectType t = recId.getSObjectType();
                objectNameByPrefix.put(pfx, t == null ? null : t.getDescribe().getName());
            }
            objName = objectNameByPrefix.get(pfx);
        } catch (Exception e) {
            return null;   // malformed Id, or a checksum the AI mangled
        }

        if (objName == null || !LINKABLE_COMM_OBJECTS.contains(objName)) return null;
        return '/lightning/r/' + objName + '/' + candidate + '/view';
    }

    // ── linkifyLogSection ─────────────────────────────────────────────────────
    // Log header lines are pipe-delimited with the record Id in the last field. Only that
    // field is rewritten, so the 11-field layout and the tone value at index 7 that
    // extractLogHeaderLines / getToneFromHeader rely on are untouched. Idempotent: an
    // already-linked field no longer looks like an Id, so it is left alone.

    @TestVisible
    private static String linkifyLogSection(String logSection) {
        return linkifyLogSection(logSection, null);
    }

    @TestVisible
    private static String linkifyLogSection(String logSection, Map<String, BlockRef> refs) {
        if (String.isBlank(logSection)) return logSection;
        List<String> out = new List<String>();
        for (String line : logSection.split('\n')) {
            List<String> parts = line.split('\\|', -1);
            if (parts.size() >= 11) {
                String last  = parts[parts.size() - 1];
                Id     recId = resolveLogRef(last, parts[0], refs);
                String url   = recId != null ? commRecordUrl(String.valueOf(recId))
                                             : commRecordUrl(last);
                String label = recId != null ? String.valueOf(recId) : last.trim();
                if (url != null) {
                    parts[parts.size() - 1] = '<a href="' + url + '">' + label + '</a>';
                    out.add(String.join(parts, '|'));
                    continue;
                }
            }
            out.add(line);
        }
        return String.join(out, '\n');
    }

    // ── linkifyFactLines ──────────────────────────────────────────────────────
    // Fact lines are "type|status|text|id[,id...]" — the last field holds one or more
    // comma-separated source Ids. Section headers such as [Custody] contain no pipes and
    // pass through untouched.

    @TestVisible
    private static String linkifyFactLines(String factSection) {
        return linkifyFactLines(factSection, null);
    }

    @TestVisible
    private static String linkifyFactLines(String factSection, Map<String, BlockRef> refs) {
        if (String.isBlank(factSection)) return factSection;
        List<String> out = new List<String>();
        for (String line : factSection.split('\n')) {
            List<String> parts = line.split('\\|', -1);
            if (parts.size() >= 4) {
                List<String> rendered  = new List<String>();
                Boolean      linkedAny = false;
                for (String token : parts[parts.size() - 1].split(',')) {
                    Id     ref = resolveRef(token, refs);
                    String url = ref != null ? commRecordUrl(String.valueOf(ref)) : commRecordUrl(token);
                    if (ref != null) token = String.valueOf(ref);
                    if (url != null) {
                        rendered.add('<a href="' + url + '">' + token.trim() + '</a>');
                        linkedAny = true;
                    } else {
                        rendered.add(token.trim());
                    }
                }
                if (linkedAny) {
                    parts[parts.size() - 1] = String.join(rendered, ',');
                    out.add(String.join(parts, '|'));
                    continue;
                }
            }
            out.add(line);
        }
        return String.join(out, '\n');
    }

    // Strips markup so stored (linked) fact lines compare equal to freshly returned
    // (unlinked) ones during merge deduplication.
    @TestVisible
    private static String stripTags(String html) {
        return String.isBlank(html) ? '' : html.replaceAll('<[^>]+>', '').trim();
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
        stampScalarFields(mUpdate, matter, rawResponse, null);
    }

    @TestVisible
    private static void stampScalarFields(AcctSeed__Project__c mUpdate, AcctSeed__Project__c matter, String rawResponse, Map<String, BlockRef> refs) {
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
                    if (String.isNotBlank(line.trim())) html += formatPromiseHtml(line.trim(), refs);
                }
                mUpdate.Open_Promises__c = html.left(32768);
            }
        }
        if (String.isNotBlank(completedPromisesVal) && completedPromisesVal != 'NONE') {
            String existing = String.isBlank(matter.Completed_Promises__c) ? '' : matter.Completed_Promises__c;
            String newHtml = '';
            for (String line : completedPromisesVal.split('\n')) {
                if (String.isNotBlank(line.trim())) newHtml += formatPromiseHtml(line.trim(), refs);
            }
            mUpdate.Completed_Promises__c = (existing + newHtml).left(32768);
        }
        if (String.isNotBlank(brokenPromisesVal) && brokenPromisesVal != 'NONE') {
            String existing = String.isBlank(matter.Broken_Promises__c) ? '' : matter.Broken_Promises__c;
            String newHtml = '';
            for (String line : brokenPromisesVal.split('\n')) {
                if (String.isNotBlank(line.trim())) newHtml += formatPromiseHtml(line.trim(), refs);
            }
            mUpdate.Broken_Promises__c = (existing + newHtml).left(32768);
        }
    }

    // ── formatPromiseHtml ─────────────────────────────────────────────────────
    // Converts a pipe-delimited promise line from the AI into an HTML paragraph, with a
    // hyperlink to the referenced Salesforce communication record when — and only when —
    // the Id the AI supplied resolves to a real communication record.
    // Format: date|party|description|due_date|recordId

    @TestVisible
    private static String formatPromiseHtml(String pipeLine) {
        return formatPromiseHtml(pipeLine, null);
    }

    @TestVisible
    private static String formatPromiseHtml(String pipeLine, Map<String, BlockRef> refs) {
        if (String.isBlank(pipeLine)) return '';
        List<String> parts      = pipeLine.split('\\|', -1);
        String promiseDate  = parts.size() > 0 ? parts[0].trim() : '';
        String party        = parts.size() > 1 ? parts[1].trim() : '';
        String description  = parts.size() > 2 ? parts[2].trim() : '';
        String dueDate      = parts.size() > 3 ? parts[3].trim() : '';
        String recordId     = parts.size() > 4 ? parts[4].trim() : '';

        String line = promiseDate + ' | <strong>' + party + '</strong> | ' + description;
        if (String.isNotBlank(dueDate) && dueDate != 'NONE') line += ' | Due: ' + dueDate;

        Id     promiseRef = resolveRef(recordId, refs);
        if (promiseRef != null) recordId = String.valueOf(promiseRef);
        String recordUrl  = commRecordUrl(recordId);
        if (recordUrl != null) {
            line += ' | <a href="' + recordUrl + '">View Record</a>';
        } else if (String.isNotBlank(recordId)) {
            // Not a communication record Id. Observed values include label text
            // ("Related Call Transcript", "View Record"), the Matter Id, and fabricated
            // placeholders. Keep the promise, drop the dead link.
            line += ' | (source record not identified)';
        }
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
        matterIdVal.value = new Map<String, Object>{ 'id' => matterId };

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