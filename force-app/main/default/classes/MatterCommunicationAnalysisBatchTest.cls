@isTest
private class MatterCommunicationAnalysisBatchTest {

    // ── Test Data Setup ───────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name               = 'Test Matter',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        // Email junctions with no Email_Message_Id__c — go to empty path, stamped without AI call
        List<Related_Email_Message__c> emails = new List<Related_Email_Message__c>();
        for (Integer i = 0; i < 3; i++) {
            emails.add(new Related_Email_Message__c(
                Matter__c      = matter.Id,
                AI_Reviewed__c = false
            ));
        }
        insert emails;
    }

    static AcctSeed__Project__c getMatter() {
        return [
            SELECT Id, Communication_Analysis__c, Communication_Log__c, Total_Email_Count__c,
                   Comms_Has_Error__c, Comms_Error_Message__c
            FROM   AcctSeed__Project__c
            WHERE  Name = 'Test Matter'
            LIMIT  1
        ];
    }

    // Returns a log header string with 11 pipe-delimited fields and the given tone at index 7
    private static String h(String tone) {
        return '2025-01-15 10:00:00|EMAIL|Inbound|client@x.com|f4|f5|f6|' + tone + '|3|f9|f10';
    }

    // Returns a log header with a controllable timestamp and load value
    private static String hLoad(String timestamp, String tone, String load) {
        return timestamp + '|EMAIL|Inbound|client@x.com|f4|f5|f6|' + tone + '|' + load + '|f9|f10';
    }

    // ── Batch Integration Tests ───────────────────────────────────────────────

    @isTest
    static void testEmptyRecordsStampedWithoutAiCall() {
        AcctSeed__Project__c matter = getMatter();

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ matter.Id }), 1);
        Test.stopTest();

        Integer unreviewed = [
            SELECT COUNT() FROM Related_Email_Message__c
            WHERE  Matter__c = :matter.Id AND AI_Reviewed__c = false
        ];
        System.assertEquals(0, unreviewed, 'All empty junction records should be stamped as reviewed');
    }

    @isTest
    static void testEmailCountUpdatedOnMatter() {
        AcctSeed__Project__c matter = getMatter();

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ matter.Id }), 1);
        Test.stopTest();

        matter = getMatter();
        // Junctions have no Email_Message_Id__c set; COUNT_DISTINCT ignores null values → 0
        System.assertEquals(0, matter.Total_Email_Count__c, 'COUNT_DISTINCT on null email IDs should return 0');
    }

    @isTest
    static void testBatchWithoutFilterRunsOnActiveMatters() {
        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(), 1);
        Test.stopTest();

        AcctSeed__Project__c matter = getMatter();
        System.assertNotEquals(null, matter.Total_Email_Count__c, 'Email count should be updated on all active matters');
    }

    @isTest
    static void testInactiveMatterNotProcessed() {
        // Comms_Has_Error__c = true excludes inactive matter from countPending, preventing runaway self-chaining
        AcctSeed__Project__c inactive = new AcctSeed__Project__c(
            Name                = 'Inactive Matter',
            AcctSeed__Status__c = 'Inactive',
            Comms_Has_Error__c  = true
        );
        insert inactive;

        Related_Email_Message__c junction = new Related_Email_Message__c(
            Matter__c      = inactive.Id,
            AI_Reviewed__c = false
        );
        insert junction;

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(), 1);
        Test.stopTest();

        junction = [SELECT AI_Reviewed__c FROM Related_Email_Message__c WHERE Id = :junction.Id];
        System.assertEquals(false, junction.AI_Reviewed__c, 'Inactive matter records should not be processed');
    }

    @isTest
    static void testMatterWithNoJunctionsUpdatesCountOnly() {
        AcctSeed__Project__c emptyMatter = new AcctSeed__Project__c(
            Name                = 'Empty Matter',
            AcctSeed__Status__c = 'Active'
        );
        insert emptyMatter;

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ emptyMatter.Id }), 1);
        Test.stopTest();

        emptyMatter = [
            SELECT Total_Email_Count__c, Communication_Analysis__c
            FROM   AcctSeed__Project__c
            WHERE  Id = :emptyMatter.Id
        ];
        System.assertEquals(0, emptyMatter.Total_Email_Count__c, 'Email count should be 0');
        System.assert(String.isBlank(emptyMatter.Communication_Analysis__c), 'Analysis should remain blank with no junctions');
    }

    @isTest
    static void testFinishDoesNotSelfChainWhenNoneRemaining() {
        // Mark all records reviewed before running so finish() sees 0 remaining
        List<Related_Email_Message__c> emails = [SELECT Id FROM Related_Email_Message__c];
        for (Related_Email_Message__c e : emails) e.AI_Reviewed__c = true;
        update emails;

        AcctSeed__Project__c matter = getMatter();

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ matter.Id }), 1);
        Test.stopTest();

        Integer queued = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE  ApexClass.Name = 'MatterCommunicationAnalysisBatch'
            AND    Status IN ('Processing', 'Preparing', 'Queued', 'Holding')
        ];
        System.assertEquals(0, queued, 'No self-chain should fire when no records remain');
    }

    @isTest
    static void testAllFourJunctionTypesStamped() {
        AcctSeed__Project__c matter = getMatter();

        // Call_Transcript__c requires a Voice_Call__c lookup (org-required field); tested separately if needed.
        // SMS_Session__c and Meeting_Transcript__c insert with no required fields — blank transcript text
        // routes them to the empty path so they are stamped without an AI call.
        SMS_Session__c sess = new SMS_Session__c();
        insert sess;
        Meeting_Transcript__c mt = new Meeting_Transcript__c();
        insert mt;

        insert new Related_Text_Message__c(Matter__c = matter.Id, AI_Reviewed__c = false, Text_Message_Session__c = sess.Id);
        insert new Related_Meeting_Transcript__c(Matter__c = matter.Id, AI_Reviewed__c = false, Meeting_Transcript__c = mt.Id);

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ matter.Id }), 1);
        Test.stopTest();

        Integer unreviewedTexts    = [SELECT COUNT() FROM Related_Text_Message__c       WHERE Matter__c = :matter.Id AND AI_Reviewed__c = false];
        Integer unreviewedMeetings = [SELECT COUNT() FROM Related_Meeting_Transcript__c WHERE Matter__c = :matter.Id AND AI_Reviewed__c = false];

        System.assertEquals(0, unreviewedTexts,    'Text junctions with no SMS body should be stamped');
        System.assertEquals(0, unreviewedMeetings, 'Meeting junctions with no transcript should be stamped');
    }

    @isTest
    static void testDuplicateEmailJunctionsDeduped() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name                = 'Dedup Matter',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        // Two junctions pointing to the same (fake) email ID — second is caught by seenEmailIds
        String fakeEmailId = String.valueOf(matter.Id);
        insert new List<Related_Email_Message__c>{
            new Related_Email_Message__c(Matter__c = matter.Id, Email_Message_Id__c = fakeEmailId, AI_Reviewed__c = false),
            new Related_Email_Message__c(Matter__c = matter.Id, Email_Message_Id__c = fakeEmailId, AI_Reviewed__c = false)
        };

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ matter.Id }), 1);
        Test.stopTest();

        Integer unreviewed = [SELECT COUNT() FROM Related_Email_Message__c WHERE Matter__c = :matter.Id AND AI_Reviewed__c = false];
        System.assertEquals(0, unreviewed, 'Both duplicate junctions should be stamped as reviewed');

        matter = [SELECT Total_Email_Count__c FROM AcctSeed__Project__c WHERE Id = :matter.Id];
        System.assertEquals(1, matter.Total_Email_Count__c, 'COUNT_DISTINCT should count one unique email ID despite two junctions');
    }

    @isTest
    static void testCommsErrorSetOnCalloutFailure() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name                = 'Callout Matter',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        Case c = new Case(Subject = 'Test Case');
        insert c;
        EmailMessage em = new EmailMessage(
            ParentId    = c.Id,
            Subject     = 'Case Update',
            TextBody    = 'Client asks about the status of their case.',
            FromAddress = 'client@example.com',
            ToAddress   = 'attorney@example.com',
            Incoming    = true
        );
        insert em;

        insert new Related_Email_Message__c(
            Matter__c           = matter.Id,
            Email_Message_Id__c = em.Id,
            AI_Reviewed__c      = false
        );

        Test.startTest();
        Database.executeBatch(new MatterCommunicationAnalysisBatch(new Set<Id>{ matter.Id }), 1);
        Test.stopTest();

        matter = [SELECT Comms_Has_Error__c, Comms_Error_Message__c FROM AcctSeed__Project__c WHERE Id = :matter.Id];
        System.assertEquals(true, matter.Comms_Has_Error__c, 'Error flag should be set when AI callout fails in test context');
        System.assert(String.isNotBlank(matter.Comms_Error_Message__c), 'Error message should be populated when callout fails');
    }

    // ── Unit Tests: extractSection ────────────────────────────────────────────

    @isTest
    static void testExtractSection() {
        String resp = '==COMMUNICATION_ANALYSIS==\nfact one\nfact two\n==COMMUNICATION_LOG==\nlog entry';

        System.assertEquals('fact one\nfact two', MatterCommunicationAnalysisBatch.extractSection(resp, 'COMMUNICATION_ANALYSIS'), 'First section with following section');
        System.assertEquals('log entry',           MatterCommunicationAnalysisBatch.extractSection(resp, 'COMMUNICATION_LOG'),      'Last section with no following section');
        System.assertEquals('',                    MatterCommunicationAnalysisBatch.extractSection(resp, 'MISSING'),                'Absent marker returns empty string');

        // No trailing section — returns everything after the marker
        String noTrailing = '==LAST==\nfinal content';
        System.assertEquals('final content', MatterCommunicationAnalysisBatch.extractSection(noTrailing, 'LAST'), 'Trailing section returns all remaining content');
    }

    // ── Unit Tests: mergeFactLines ────────────────────────────────────────────

    @isTest
    static void testMergeFactLines() {
        // Blank existing → returns newFacts
        System.assertEquals('[A]\nfact', MatterCommunicationAnalysisBatch.mergeFactLines('', '[A]\nfact'), 'Blank existing returns newFacts');

        // Blank new → returns existing
        System.assertEquals('[A]\nfact', MatterCommunicationAnalysisBatch.mergeFactLines('[A]\nfact', ''), 'Blank new returns existing');

        // Merge: existing fact preserved, new fact added, duplicate excluded, new section appended
        String existing = '[Issues]\nfact one';
        String newFacts = '[Issues]\nfact one\nfact two\n[Billing]\nbill item';
        String merged   = MatterCommunicationAnalysisBatch.mergeFactLines(existing, newFacts);

        System.assert(merged.contains('fact one'),  'Existing fact preserved');
        System.assert(merged.contains('fact two'),  'New fact added to existing section');
        System.assert(merged.contains('[Billing]'), 'New section appended');
        System.assert(merged.contains('bill item'), 'New section fact included');

        // Duplicate fact appears exactly once
        System.assertEquals(1, merged.split('fact one', -1).size() - 1, 'Duplicate fact should appear only once');

        // Lines starting with < are excluded from both parse passes
        String withTag = '[Issues]\n<deprecated>skip me</deprecated>\ngood fact';
        String mergedTag = MatterCommunicationAnalysisBatch.mergeFactLines('[Issues]\nexisting', withTag);
        System.assert(!mergedTag.contains('<deprecated>'), 'HTML-like tags excluded from facts');
        System.assert(mergedTag.contains('good fact'),     'Normal facts after a tag-line are retained');
    }

    // ── Unit Tests: extractScalarValue ───────────────────────────────────────

    @isTest
    static void testExtractScalarValue() {
        // Marker format
        String markerResp = '==STATUS==\nActive - Engaged\n==OTHER==\nval';
        System.assertEquals('Active - Engaged', MatterCommunicationAnalysisBatch.extractScalarValue(markerResp, 'STATUS'), 'Marker format extraction');

        // Fallback: flat space-separated
        System.assertEquals('Active - Engaged', MatterCommunicationAnalysisBatch.extractScalarValue('STATUS Active - Engaged', 'STATUS'), 'Flat space fallback');

        // Fallback: colon-separated
        System.assertEquals('Active - Engaged', MatterCommunicationAnalysisBatch.extractScalarValue('STATUS: Active - Engaged', 'STATUS'), 'Colon fallback');

        // Key not present → empty string
        System.assertEquals('', MatterCommunicationAnalysisBatch.extractScalarValue('nothing here', 'STATUS'), 'Missing key returns empty');
    }

    // ── Unit Tests: stampScalarFields ────────────────────────────────────────

    @isTest
    static void testStampScalarFields_DateTimeAndStatus() {
        AcctSeed__Project__c mUpdate = new AcctSeed__Project__c();
        AcctSeed__Project__c matter  = new AcctSeed__Project__c();

        String raw = '==LAST_SUBSTANTIVE_CONVERSATION==\n2025-01-15 10:00:00\n'
                   + '==LAST_CLIENT_INBOUND==\n2025-01-14 09:00:00\n'
                   + '==LAST_ATTORNEY_CLIENT_CONVERSATION==\n2025-01-13 08:00:00\n'
                   + '==LAST_ESCALATION_DATE==\n2025-01-10\n'
                   + '==CLIENT_ENGAGEMENT_STATUS==\nActive - Engaged\n'
                   + '==ATTORNEY_CALLBACK_REQUESTED==\nNONE\n'
                   + '==UNANSWERED_CLIENT_MESSAGES==\nNONE\n'
                   + '==OPEN_PROMISES==\nNONE\n'
                   + '==COMPLETED_PROMISES==\nNONE\n'
                   + '==BROKEN_PROMISES==\nNONE';

        MatterCommunicationAnalysisBatch.stampScalarFields(mUpdate, matter, raw);

        System.assertEquals(DateTime.valueOf('2025-01-15 10:00:00'), mUpdate.Last_Substantive_Conversation__c,       'Last substantive conversation set');
        System.assertEquals(DateTime.valueOf('2025-01-14 09:00:00'), mUpdate.Last_Client_Inbound__c,                 'Last client inbound set');
        System.assertEquals(DateTime.valueOf('2025-01-13 08:00:00'), mUpdate.Last_Attorney_Client_Conversation__c,   'Last attorney-client conversation set');
        System.assertEquals(Date.valueOf('2025-01-10'),              mUpdate.Last_Escalation_Date__c,                'Last escalation date set');
        System.assertEquals('Active - Engaged',                      mUpdate.Client_Engagement_Status__c,            'Client engagement status set');

        // Invalid date value → field stays null (caught silently)
        AcctSeed__Project__c mInvalid = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mInvalid, matter, '==LAST_SUBSTANTIVE_CONVERSATION==\nINVALID_DATE');
        System.assertEquals(null, mInvalid.Last_Substantive_Conversation__c, 'Invalid date leaves field null');
    }

    @isTest
    static void testStampScalarFields_CallbackAndUnanswered() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(Unanswered_Client_Messages__c = 7);

        // CLEAR resets both callback and unanswered count
        AcctSeed__Project__c mClear = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mClear, matter, '==ATTORNEY_CALLBACK_REQUESTED==\nCLEAR');
        System.assertEquals(null, mClear.Attorney_Callback_Requested__c, 'CLEAR should null out callback datetime');
        System.assertEquals(0,    mClear.Unanswered_Client_Messages__c,  'CLEAR should reset unanswered count to 0');

        // Setting callback to a specific datetime
        AcctSeed__Project__c mSet = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mSet, matter, '==ATTORNEY_CALLBACK_REQUESTED==\n2025-02-01 14:00:00');
        System.assertEquals(DateTime.valueOf('2025-02-01 14:00:00'), mSet.Attorney_Callback_Requested__c, 'Callback datetime set from response');

        // RESET|n sets absolute count
        AcctSeed__Project__c mReset = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mReset, matter, '==UNANSWERED_CLIENT_MESSAGES==\nRESET|3');
        System.assertEquals(3, mReset.Unanswered_Client_Messages__c, 'RESET should set absolute count regardless of existing');

        // ADD|n increments existing count (existing = 7)
        AcctSeed__Project__c mAdd = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mAdd, matter, '==UNANSWERED_CLIENT_MESSAGES==\nADD|2');
        System.assertEquals(9, mAdd.Unanswered_Client_Messages__c, 'ADD should increment existing count');

        // ADD|n with null existing → treated as 0
        AcctSeed__Project__c mNull = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mNull, new AcctSeed__Project__c(), '==UNANSWERED_CLIENT_MESSAGES==\nADD|4');
        System.assertEquals(4, mNull.Unanswered_Client_Messages__c, 'ADD with null existing should default to 0 + n');
    }

    @isTest
    static void testFormatPromiseHtml() {
        // Full line with all fields
        String html = MatterCommunicationAnalysisBatch.formatPromiseHtml('2025-01-10|attorney|Will file motion|2025-01-15|a0X123');
        System.assert(html.contains('<p>'),                  'Promise wrapped in paragraph tag');
        System.assert(html.contains('Will file motion'),     'Description included');
        System.assert(html.contains('Due: 2025-01-15'),      'Due date included');
        System.assert(html.contains('href="/a0X123"'),       'Hyperlink to record included');
        System.assert(html.contains('View Record'),          'Link label included');

        // Due date = NONE → omitted
        String noDue = MatterCommunicationAnalysisBatch.formatPromiseHtml('2025-01-10|attorney|File motion|NONE|a0X123');
        System.assert(!noDue.contains('Due:'), 'NONE due date omitted');

        // No record ID → no hyperlink
        String noId = MatterCommunicationAnalysisBatch.formatPromiseHtml('2025-01-10|attorney|File motion|2025-01-15|');
        System.assert(!noId.contains('href'), 'Blank record ID produces no hyperlink');

        // Blank input → empty string
        System.assertEquals('', MatterCommunicationAnalysisBatch.formatPromiseHtml(''), 'Blank line returns empty string');
    }

    @isTest
    static void testStampScalarFields_Promises() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Completed_Promises__c = '<p>old promise entry</p>',
            Broken_Promises__c    = null
        );

        // OPEN_PROMISES: set to a value — output should be HTML with hyperlink
        AcctSeed__Project__c mOpen = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mOpen, matter,
            '==OPEN_PROMISES==\n2025-01-10|attorney|Will file motion|2025-01-15|rec1');
        System.assert(mOpen.Open_Promises__c.contains('<p>'),              'Open promise wrapped in paragraph tag');
        System.assert(mOpen.Open_Promises__c.contains('Will file motion'), 'Description in open promise');
        System.assert(mOpen.Open_Promises__c.contains('href="/rec1"'),     'Hyperlink to record in open promise');

        // OPEN_PROMISES = NONE → null
        AcctSeed__Project__c mNone = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mNone, matter, '==OPEN_PROMISES==\nNONE');
        System.assertEquals(null, mNone.Open_Promises__c, 'NONE should clear open promises to null');

        // COMPLETED_PROMISES appends HTML to existing content
        AcctSeed__Project__c mCompleted = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mCompleted, matter,
            '==COMPLETED_PROMISES==\n2025-01-15|attorney|Filed motion|completed|rec1');
        System.assert(mCompleted.Completed_Promises__c.contains('old promise entry'), 'Existing completed promises preserved on append');
        System.assert(mCompleted.Completed_Promises__c.contains('Filed motion'),      'New completed promise appended as HTML');
        System.assert(mCompleted.Completed_Promises__c.contains('href="/rec1"'),      'Hyperlink in completed promise');

        // BROKEN_PROMISES: no existing → set as HTML
        AcctSeed__Project__c mBroken = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mBroken, matter,
            '==BROKEN_PROMISES==\n2025-01-15|client|Never sent docs|broken|rec2');
        System.assert(mBroken.Broken_Promises__c.contains('Never sent docs'), 'Broken promise description recorded');
        System.assert(mBroken.Broken_Promises__c.contains('href="/rec2"'),    'Hyperlink in broken promise');

        // COMPLETED_PROMISES = NONE → not written
        AcctSeed__Project__c mCompNone = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mCompNone, matter, '==COMPLETED_PROMISES==\nNONE');
        System.assertEquals(null, mCompNone.Completed_Promises__c, 'NONE completed promises should not write to mUpdate');
    }

    // ── Unit Tests: parseDurationToMinutes ────────────────────────────────────

    @isTest
    static void testParseDurationToMinutes() {
        System.assertEquals(0,  MatterCommunicationAnalysisBatch.parseDurationToMinutes(null),      'Null → 0');
        System.assertEquals(0,  MatterCommunicationAnalysisBatch.parseDurationToMinutes(''),         'Blank → 0');
        System.assertEquals(90, MatterCommunicationAnalysisBatch.parseDurationToMinutes('01:30:00'), 'HH:MM:SS → total minutes');
        System.assertEquals(0,  MatterCommunicationAnalysisBatch.parseDurationToMinutes('00:00:00'), 'Zero duration → 0');
        System.assertEquals(1,  MatterCommunicationAnalysisBatch.parseDurationToMinutes('01:30'),    'Two-part format → first segment as integer');
        System.assertEquals(0,  MatterCommunicationAnalysisBatch.parseDurationToMinutes('notatime'), 'Unparseable string → 0');
    }

    // ── Unit Tests: extractLogHeaderLines ─────────────────────────────────────

    @isTest
    static void testExtractLogHeaderLines() {
        // Empty and null inputs
        System.assertEquals(0, MatterCommunicationAnalysisBatch.extractLogHeaderLines('').size(),   'Empty string → empty list');
        System.assertEquals(0, MatterCommunicationAnalysisBatch.extractLogHeaderLines(null).size(), 'Null → empty list');

        // Valid header requires at least 11 pipe-delimited fields
        String validHeader = '2025-01-15 10:00:00|EMAIL|Inbound|client@x.com|f4|f5|f6|Cooperative|3|f9|f10';
        String logContent  = validHeader + '\nplain text line\ntoo|few|fields\n' + validHeader;

        List<String> headers = MatterCommunicationAnalysisBatch.extractLogHeaderLines(logContent);
        System.assertEquals(2, headers.size(), 'Only lines with 11+ pipe fields are returned as headers');
        System.assertEquals(validHeader, headers[0], 'First valid header correct');
        System.assertEquals(validHeader, headers[1], 'Second valid header correct');
    }

    // ── Unit Tests: tone helpers ──────────────────────────────────────────────

    @isTest
    static void testToneHelpers() {
        // getToneFromHeader extracts field at index 7
        System.assertEquals('Cooperative', MatterCommunicationAnalysisBatch.getToneFromHeader(h('Cooperative')), 'Cooperative tone extracted');
        System.assertEquals('Hostile',     MatterCommunicationAnalysisBatch.getToneFromHeader(h('Hostile')),     'Hostile tone extracted');

        // toneToNumber maps all defined tones
        System.assertEquals(2,  MatterCommunicationAnalysisBatch.toneToNumber('Cooperative'), 'Cooperative = 2');
        System.assertEquals(1,  MatterCommunicationAnalysisBatch.toneToNumber('Neutral'),     'Neutral = 1');
        System.assertEquals(-1, MatterCommunicationAnalysisBatch.toneToNumber('Tense'),       'Tense = -1');
        System.assertEquals(-2, MatterCommunicationAnalysisBatch.toneToNumber('Hostile'),     'Hostile = -2');
        System.assertEquals(-2, MatterCommunicationAnalysisBatch.toneToNumber('Distressed'),  'Distressed = -2');
        System.assertEquals(-2, MatterCommunicationAnalysisBatch.toneToNumber('Crisis'),      'Crisis = -2');
        System.assertEquals(0,  MatterCommunicationAnalysisBatch.toneToNumber('Unknown'),     'Unknown tone = 0');

        // mapToneToPicklist maps Distressed → Crisis, others pass through
        System.assertEquals('Crisis',      MatterCommunicationAnalysisBatch.mapToneToPicklist('Distressed'),  'Distressed maps to Crisis picklist');
        System.assertEquals('Cooperative', MatterCommunicationAnalysisBatch.mapToneToPicklist('Cooperative'), 'Cooperative passes through');
        System.assertEquals('Tense',       MatterCommunicationAnalysisBatch.mapToneToPicklist('Tense'),       'Tense passes through');

        // toneListAverage
        System.assertEquals(0, MatterCommunicationAnalysisBatch.toneListAverage(new List<String>()),       'Empty list → 0');
        System.assertEquals(2, MatterCommunicationAnalysisBatch.toneListAverage(new List<String>{ h('Cooperative') }), 'Single Cooperative → 2');
        // Average of Cooperative (2) + Hostile (-2) = 0
        List<String> mixed = new List<String>{ h('Cooperative'), h('Hostile') };
        System.assertEquals(0, MatterCommunicationAnalysisBatch.toneListAverage(mixed), 'Cooperative + Hostile average = 0');
    }

    // ── Unit Tests: computeOverallTone ───────────────────────────────────────

    @isTest
    static void testComputeOverallTone() {
        // Empty → null
        System.assertEquals(null, MatterCommunicationAnalysisBatch.computeOverallTone(new List<String>(), new List<String>()), 'Empty → null');

        // < 3 in window → mapToneToPicklist of most recent
        System.assertEquals('Cooperative', MatterCommunicationAnalysisBatch.computeOverallTone(new List<String>{ h('Cooperative') }, new List<String>()), '1 header → Cooperative');
        System.assertEquals('Crisis',      MatterCommunicationAnalysisBatch.computeOverallTone(new List<String>{ h('Distressed')  }, new List<String>()), '1 Distressed header → Crisis via mapToneToPicklist');

        // 3 Cooperative → high avg → 'Cooperative'
        List<String> coop3 = new List<String>{ h('Cooperative'), h('Cooperative'), h('Cooperative') };
        System.assertEquals('Cooperative', MatterCommunicationAnalysisBatch.computeOverallTone(coop3, new List<String>()), '3 Cooperative → Cooperative');

        // 3 Hostile → low avg → 'Hostile'
        List<String> hostile3 = new List<String>{ h('Hostile'), h('Hostile'), h('Hostile') };
        System.assertEquals('Hostile', MatterCommunicationAnalysisBatch.computeOverallTone(hostile3, new List<String>()), '3 Hostile → Hostile');

        // Distressed present + avg < 0 → 'Crisis'
        List<String> crisis = new List<String>{ h('Hostile'), h('Hostile'), h('Distressed') };
        System.assertEquals('Crisis', MatterCommunicationAnalysisBatch.computeOverallTone(crisis, new List<String>()), 'Distressed + negative avg → Crisis');

        // Tense-heavy → 'Tense' (-0.5 to -1.5 range)
        List<String> tense3 = new List<String>{ h('Tense'), h('Tense'), h('Tense') };
        System.assertEquals('Tense', MatterCommunicationAnalysisBatch.computeOverallTone(tense3, new List<String>()), '3 Tense → Tense');

        // Split across historical and new parameters
        List<String> hist = new List<String>{ h('Neutral') };
        List<String> newH = new List<String>{ h('Neutral'), h('Neutral') };
        System.assertEquals('Neutral', MatterCommunicationAnalysisBatch.computeOverallTone(hist, newH), 'Neutral split across params → Neutral');
    }

    // ── Unit Tests: computeToneTrend ─────────────────────────────────────────

    @isTest
    static void testComputeToneTrend() {
        // Empty → null
        System.assertEquals(null, MatterCommunicationAnalysisBatch.computeToneTrend(new List<String>(), new List<String>()), 'Empty → null');

        // < 4 headers in window → 'Stable'
        List<String> three = new List<String>{ h('Neutral'), h('Neutral'), h('Neutral') };
        System.assertEquals('Stable', MatterCommunicationAnalysisBatch.computeToneTrend(three, new List<String>()), 'Fewer than 4 headers → Stable');

        // Improving: prior half Hostile, recent half Cooperative
        List<String> improving = new List<String>{ h('Hostile'), h('Hostile'), h('Cooperative'), h('Cooperative') };
        System.assertEquals('Improving', MatterCommunicationAnalysisBatch.computeToneTrend(improving, new List<String>()), 'Tone moving positive → Improving');

        // Deteriorating: prior half Cooperative, recent half Hostile
        List<String> deteriorating = new List<String>{ h('Cooperative'), h('Cooperative'), h('Hostile'), h('Hostile') };
        System.assertEquals('Deteriorating', MatterCommunicationAnalysisBatch.computeToneTrend(deteriorating, new List<String>()), 'Tone moving negative → Deteriorating');

        // Stable: all Neutral
        List<String> stable = new List<String>{ h('Neutral'), h('Neutral'), h('Neutral'), h('Neutral') };
        System.assertEquals('Stable', MatterCommunicationAnalysisBatch.computeToneTrend(stable, new List<String>()), 'No change → Stable');
    }

    // ── Unit Tests: computeLoadScore ─────────────────────────────────────────

    @isTest
    static void testComputeLoadScore() {
        Date today = Date.today();

        // No headers → 0
        System.assertEquals(0, MatterCommunicationAnalysisBatch.computeLoadScore(new List<String>(), new List<String>(), today), 'No headers → 0');

        // Recent (age 0, weight 1.0): load=5 → weightedTotal=5 → score=(5*6)=30
        String ts0 = String.valueOf(today) + ' 10:00:00';
        System.assertEquals(30, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts0, 'Neutral', '5') }, new List<String>(), today), 'Age 0, load 5 → score 30');

        // Middle band: load=10, age=0 → weightedTotal=10 → score=30+(10-5)*4=50
        System.assertEquals(50, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts0, 'Neutral', '10') }, new List<String>(), today), 'Age 0, load 10 → score 50');

        // Upper band: load=20, age=0 → weightedTotal=20 → score=min(100, 70+(20-15)*2)=80
        System.assertEquals(80, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts0, 'Neutral', '20') }, new List<String>(), today), 'Age 0, load 20 → score 80');

        // Age 10 days (weight 0.6): load=10 → weightedTotal=6 → score=30+(6-5)*4=34
        String ts10 = String.valueOf(today.addDays(-10)) + ' 10:00:00';
        System.assertEquals(34, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts10, 'Neutral', '10') }, new List<String>(), today), 'Age 10, load 10 → score 34 (weight 0.6)');

        // Age 20 days (weight 0.3): load=10 → weightedTotal=3 → score=(3*6)=18
        String ts20 = String.valueOf(today.addDays(-20)) + ' 10:00:00';
        System.assertEquals(18, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts20, 'Neutral', '10') }, new List<String>(), today), 'Age 20, load 10 → score 18 (weight 0.3)');

        // Age > 30 days → skipped → score 0
        String ts40 = String.valueOf(today.addDays(-40)) + ' 10:00:00';
        System.assertEquals(0, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts40, 'Neutral', '10') }, new List<String>(), today), 'Age >30 → skipped, score 0');

        // Score capped at 100
        System.assertEquals(100, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts0, 'Neutral', '100') }, new List<String>(), today), 'Very high load → capped at 100');

        // Invalid load string → skipped → score 0
        System.assertEquals(0, MatterCommunicationAnalysisBatch.computeLoadScore(
            new List<String>{ hLoad(ts0, 'Neutral', 'notanumber') }, new List<String>(), today), 'Invalid load string → skipped, score 0');

        // Headers split across historicalHeaders and newHeaders are combined
        List<String> hist = new List<String>{ hLoad(ts0, 'Neutral', '3') };
        List<String> newH = new List<String>{ hLoad(ts0, 'Neutral', '2') };
        // weightedTotal = 3 + 2 = 5 → score = (5*6) = 30
        System.assertEquals(30, MatterCommunicationAnalysisBatch.computeLoadScore(hist, newH, today), 'Historical + new headers combined correctly');
    }
}