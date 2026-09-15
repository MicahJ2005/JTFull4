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

    // ── Helper: a syntactically valid Id for a real object in this org ────────
    // Key prefixes are assigned per org, so they are read from the describe rather than
    // hardcoded. Produces an Id that resolves to the right SObjectType but matches no row.

    private static Id fakeId(Schema.SObjectType t, Integer seq) {
        String suffix = String.valueOf(seq);
        while (suffix.length() < 12) suffix = '0' + suffix;
        return Id.valueOf(t.getDescribe().getKeyPrefix() + suffix);
    }

    private static Id fakeEmailId(Integer seq)    { return fakeId(EmailMessage.SObjectType, seq); }
    private static Id fakeCallId(Integer seq)     { return fakeId(Call_Transcript__c.SObjectType, seq); }
    private static Id fakeMatterId(Integer seq)   { return fakeId(AcctSeed__Project__c.SObjectType, seq); }

    // ── Helper: a ref map like assembleCommunicationBlocks builds ─────────────

    private static Map<String, MatterCommunicationAnalysisBatch.BlockRef> refMap() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs =
            new Map<String, MatterCommunicationAnalysisBatch.BlockRef>();
        refs.put('1', new MatterCommunicationAnalysisBatch.BlockRef(
            fakeEmailId(101), DateTime.newInstanceGmt(2026, 3, 31, 13, 38, 24)));
        refs.put('2', new MatterCommunicationAnalysisBatch.BlockRef(
            fakeEmailId(102), DateTime.newInstanceGmt(2026, 3, 31, 17, 15, 28)));
        refs.put('3', new MatterCommunicationAnalysisBatch.BlockRef(
            fakeEmailId(103), DateTime.newInstanceGmt(2026, 3, 31, 17, 18, 42)));
        refs.put('4', new MatterCommunicationAnalysisBatch.BlockRef(
            fakeCallId(104),  DateTime.newInstanceGmt(2026, 2,  2, 20, 53,  0)));
        return refs;
    }

    // ── Unit Tests: resolveRef ────────────────────────────────────────────────

    @isTest
    static void testResolveRef() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();

        System.assertEquals(fakeEmailId(103), MatterCommunicationAnalysisBatch.resolveRef('3', refs),
            'Bare ordinal resolves');
        System.assertEquals(fakeEmailId(103), MatterCommunicationAnalysisBatch.resolveRef(' Ref: 3 ', refs),
            'Ordinal with a Ref: prefix resolves');
        System.assertEquals(fakeEmailId(103), MatterCommunicationAnalysisBatch.resolveRef('[3]', refs),
            'Bracketed ordinal resolves');

        System.assertEquals(null, MatterCommunicationAnalysisBatch.resolveRef('99', refs),
            'Out-of-range ordinal resolves to nothing');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.resolveRef('View Record', refs),
            'Label text resolves to nothing');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.resolveRef('', refs),
            'Blank resolves to nothing');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.resolveRef('1',
            new Map<String, MatterCommunicationAnalysisBatch.BlockRef>()), 'Empty map resolves to nothing');
    }

    // ── Unit Tests: resolveLogRef (timestamp cross-check) ─────────────────────

    @isTest
    static void testResolveLogRef_TrustsMatchingRef() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();
        // Ref 3's block is 17:18:42; the entry says 17:19 — within tolerance, so ref 3 stands.
        System.assertEquals(fakeEmailId(103),
            MatterCommunicationAnalysisBatch.resolveLogRef('3', '2026-03-31T17:19', refs),
            'A ref whose block matches the timestamp is trusted');
    }

    @isTest
    static void testResolveLogRef_CorrectsWrongRef() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();
        // This is the live failure reproduced: the entry is dated 17:19 but the AI cited the
        // February block (ref 4). Exactly one block sits within tolerance of 17:19 — ref 3 —
        // so that wins.
        System.assertEquals(fakeEmailId(103),
            MatterCommunicationAnalysisBatch.resolveLogRef('4', '2026-03-31T17:19', refs),
            'A ref contradicted by the timestamp is corrected to the matching block');
    }

    @isTest
    static void testResolveLogRef_KeepsRefWhenNoBetterMatch() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();
        // The other live case: timestamp drifted two days, but the cited ref is right. No block
        // is near that timestamp, so nothing overrides it.
        System.assertEquals(fakeCallId(104),
            MatterCommunicationAnalysisBatch.resolveLogRef('4', '2025-11-03T14:35', refs),
            'An unmatched timestamp must not discard a valid ref');
    }

    @isTest
    static void testResolveLogRef_AmbiguousWindowKeepsRef() {
        // Two blocks sent in the same second — the AI is the only thing that can tell them
        // apart, so its choice must stand.
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs =
            new Map<String, MatterCommunicationAnalysisBatch.BlockRef>();
        refs.put('1', new MatterCommunicationAnalysisBatch.BlockRef(
            fakeEmailId(201), DateTime.newInstanceGmt(2025, 10, 1, 20, 35, 4)));
        refs.put('2', new MatterCommunicationAnalysisBatch.BlockRef(
            fakeEmailId(202), DateTime.newInstanceGmt(2025, 10, 1, 20, 35, 4)));

        System.assertEquals(fakeEmailId(202),
            MatterCommunicationAnalysisBatch.resolveLogRef('2', '2025-10-01T20:35', refs),
            'With two candidates in the window the cited ref is kept');
    }

    @isTest
    static void testParseLogTimestamp() {
        System.assertEquals(DateTime.newInstanceGmt(2026, 3, 31, 17, 19, 0),
            MatterCommunicationAnalysisBatch.parseLogTimestamp('2026-03-31T17:19'), 'Minute precision parsed');
        System.assertEquals(DateTime.newInstanceGmt(2026, 3, 31, 17, 19, 0),
            MatterCommunicationAnalysisBatch.parseLogTimestamp('2026-03-31T17:19:42'), 'Seconds ignored');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.parseLogTimestamp('not a date'), 'Garbage rejected');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.parseLogTimestamp(null), 'Null rejected');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.parseLogTimestamp(''), 'Blank rejected');
    }

    // ── Unit Tests: ref-driven linkification ──────────────────────────────────

    @isTest
    static void testLinkifyLogSection_WithRefs() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();
        Id expected = fakeEmailId(103);

        // The AI writes the ordinal; Apex substitutes the real Id.
        String line = '2026-03-31T17:19|Email|Out|Erica/Gage||Other|Promise|Neutral|2|Q|3';
        String out  = MatterCommunicationAnalysisBatch.linkifyLogSection(line, refs);

        System.assert(out.contains('/lightning/r/EmailMessage/' + expected + '/view'),
            'Ordinal is replaced by the real record link');
        System.assert(!out.endsWith('|3'), 'Raw ordinal is not left in the field');
        System.assertEquals(11, out.split('\\|', -1).size(), 'Field count preserved');
        System.assertEquals('Neutral', MatterCommunicationAnalysisBatch.getToneFromHeader(out),
            'Tone field still readable');

        // Wrong ordinal, right timestamp → corrected.
        String wrong = '2026-03-31T17:19|Email|Out|Erica/Gage||Other|Promise|Neutral|2|Q|4';
        System.assert(MatterCommunicationAnalysisBatch.linkifyLogSection(wrong, refs)
                .contains('/lightning/r/EmailMessage/' + expected + '/view'),
            'A contradicted ordinal is corrected before the link is written');

        // Junk ordinal with no timestamp match → no link, nothing invented.
        String junk = '2020-01-01T00:00|Email|Out|X/Y||Other||Neutral|1||99';
        String junkOut = MatterCommunicationAnalysisBatch.linkifyLogSection(junk, refs);
        System.assert(!junkOut.contains('href'), 'An unresolvable ordinal produces no link');
    }

    @isTest
    static void testLinkifyFactLines_WithRefs() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();
        String out = MatterCommunicationAnalysisBatch.linkifyFactLines(
            '[Custody]\nF|established|Parties agreed on schedule|1,3', refs);

        System.assert(out.contains('/lightning/r/EmailMessage/' + fakeEmailId(101) + '/view'), 'First ordinal resolved');
        System.assert(out.contains('/lightning/r/EmailMessage/' + fakeEmailId(103) + '/view'), 'Second ordinal resolved');
        System.assert(out.contains('[Custody]'), 'Section header preserved');
    }

    @isTest
    static void testFormatPromiseHtml_WithRefs() {
        Map<String, MatterCommunicationAnalysisBatch.BlockRef> refs = refMap();
        String html = MatterCommunicationAnalysisBatch.formatPromiseHtml(
            '2026-03-31|Attorney|Send the agreement|2026-04-05|2', refs);

        System.assert(html.contains('/lightning/r/EmailMessage/' + fakeEmailId(102) + '/view'),
            'Promise ordinal resolved to the real record');
        System.assert(html.contains('Send the agreement'), 'Promise text kept');

        // An ordinal that resolves to nothing must not produce a link.
        String bad = MatterCommunicationAnalysisBatch.formatPromiseHtml(
            '2026-03-31|Attorney|Send the agreement|2026-04-05|99', refs);
        System.assert(!bad.contains('href'), 'Unresolvable ordinal produces no link');
        System.assert(bad.contains('source record not identified'), 'Unresolved source is called out');
    }

    // ── Unit Tests: commRecordUrl ─────────────────────────────────────────────

    @isTest
    static void testCommRecordUrl_AcceptsCommunicationRecords() {
        Id emailId = fakeEmailId(1);
        System.assertEquals('/lightning/r/EmailMessage/' + emailId + '/view',
            MatterCommunicationAnalysisBatch.commRecordUrl(String.valueOf(emailId)),
            'EmailMessage Id should produce a Lightning link');

        Id callId = fakeCallId(1);
        System.assertEquals('/lightning/r/Call_Transcript__c/' + callId + '/view',
            MatterCommunicationAnalysisBatch.commRecordUrl(String.valueOf(callId)),
            'Call_Transcript__c Id should produce a Lightning link');

        // A 15-character Id is normalised to its 18-character form.
        String fifteen = String.valueOf(callId).substring(0, 15);
        System.assertEquals('/lightning/r/Call_Transcript__c/' + callId + '/view',
            MatterCommunicationAnalysisBatch.commRecordUrl(fifteen),
            '15-char Id should normalise to 18 in the link');

        // Surrounding whitespace is tolerated.
        System.assertEquals('/lightning/r/EmailMessage/' + emailId + '/view',
            MatterCommunicationAnalysisBatch.commRecordUrl('  ' + emailId + '  '),
            'Whitespace around the Id should be trimmed');
    }

    @isTest
    static void testCommRecordUrl_RejectsEverythingElse() {
        // The exact junk shapes observed in production output.
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl('Related Call Transcript'),
            'Label text is not a record Id');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl('View Record'),
            'Link label is not a record Id');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl('a035g00000ABCDE'),
            'Fabricated placeholder Id should be rejected');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl(String.valueOf(fakeMatterId(1))),
            'Matter Id is a real record but not a communication record');

        // Structural rejects.
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl(null),   'Null rejected');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl(''),     'Blank rejected');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl('abc'),  'Wrong length rejected');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.commRecordUrl('zzz000000000000'),
            'Unknown key prefix rejected');
    }

    // ── Unit Tests: linkifyLogSection ─────────────────────────────────────────

    @isTest
    static void testLinkifyLogSection() {
        Id callId = fakeCallId(2);
        String line = '2026-06-16T15:01|Call|In|Client/Firm|Nm|Custody|Promise|Neutral|3|Q|' + callId;

        String out = MatterCommunicationAnalysisBatch.linkifyLogSection(line);
        System.assert(out.contains('<a href="/lightning/r/Call_Transcript__c/' + callId + '/view">'),
            'Trailing record Id should become a link');

        // The 11-field layout and the tone at index 7 must survive untouched.
        List<String> parts = out.split('\\|', -1);
        System.assertEquals(11, parts.size(), 'Field count preserved');
        System.assertEquals('Neutral', MatterCommunicationAnalysisBatch.getToneFromHeader(out), 'Tone field still readable');
        System.assertEquals(1, MatterCommunicationAnalysisBatch.extractLogHeaderLines(out).size(),
            'Linked line still parses as a log header');

        // Idempotent — a second pass changes nothing.
        System.assertEquals(out, MatterCommunicationAnalysisBatch.linkifyLogSection(out), 'Re-linking is a no-op');

        // A bad trailing value is left exactly as-is.
        String bad = '2026-06-16T15:01|Call|In|Client/Firm|Nm|Custody|Promise|Neutral|3|Q|' + fakeMatterId(2);
        System.assertEquals(bad, MatterCommunicationAnalysisBatch.linkifyLogSection(bad), 'Matter Id left unlinked');

        // Non-log text and blanks pass through.
        System.assertEquals('just a sentence', MatterCommunicationAnalysisBatch.linkifyLogSection('just a sentence'),
            'Free text untouched');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.linkifyLogSection(null), 'Null passes through');
    }

    // ── Unit Tests: linkifyFactLines ──────────────────────────────────────────

    @isTest
    static void testLinkifyFactLines() {
        Id a = fakeEmailId(3);
        Id b = fakeEmailId(4);
        String section = '[Custody]\nF|established|Parties agreed on schedule|' + a + ',' + b;

        String out = MatterCommunicationAnalysisBatch.linkifyFactLines(section);
        System.assert(out.contains('<a href="/lightning/r/EmailMessage/' + a + '/view">'), 'First Id linked');
        System.assert(out.contains('<a href="/lightning/r/EmailMessage/' + b + '/view">'), 'Second Id linked');
        System.assert(out.contains('[Custody]'), 'Section header preserved');

        // Idempotent.
        System.assertEquals(out, MatterCommunicationAnalysisBatch.linkifyFactLines(out), 'Re-linking is a no-op');

        // Nothing linkable → line returned unchanged.
        String bad = 'F|established|Something happened|not-an-id';
        System.assertEquals(bad, MatterCommunicationAnalysisBatch.linkifyFactLines(bad), 'Unlinkable line unchanged');
        System.assertEquals(null, MatterCommunicationAnalysisBatch.linkifyFactLines(null), 'Null passes through');
    }

    @isTest
    static void testStripTags() {
        System.assertEquals('F|fact|text|abc',
            MatterCommunicationAnalysisBatch.stripTags('F|fact|text|<a href="/x">abc</a>'), 'Tags removed');
        System.assertEquals('', MatterCommunicationAnalysisBatch.stripTags(null),  'Null returns empty');
        System.assertEquals('', MatterCommunicationAnalysisBatch.stripTags('   '), 'Blank returns empty');
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

    @isTest
    static void testMergeFactLines_DedupesAcrossLinkMarkup() {
        // A previously stored line carries record hyperlinks; the AI returns the same fact
        // unlinked. Deduplication compares the markup-stripped text, so it must not double up.
        Id emailId = fakeEmailId(5);
        String storedLinked = '[Custody]\nF|established|Parties agreed|'
            + '<a href="/lightning/r/EmailMessage/' + emailId + '/view">' + emailId + '</a>';
        String returnedPlain = '[Custody]\nF|established|Parties agreed|' + emailId;

        String merged = MatterCommunicationAnalysisBatch.mergeFactLines(storedLinked, returnedPlain);

        System.assertEquals(1, merged.split('Parties agreed', -1).size() - 1,
            'Same fact must not be stored twice just because one copy is hyperlinked');
        System.assert(merged.contains('<a href='), 'The stored hyperlinked form is the one kept');
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
        Id emailId = fakeEmailId(10);

        // Full line with all fields
        String html = MatterCommunicationAnalysisBatch.formatPromiseHtml(
            '2025-01-10|attorney|Will file motion|2025-01-15|' + emailId);
        System.assert(html.contains('<p>'),               'Promise wrapped in paragraph tag');
        System.assert(html.contains('Will file motion'),  'Description included');
        System.assert(html.contains('Due: 2025-01-15'),   'Due date included');
        System.assert(html.contains('href="/lightning/r/EmailMessage/' + emailId + '/view"'),
            'Hyperlink points at the communication record');
        System.assert(html.contains('View Record'),       'Link label included');

        // Due date = NONE → omitted
        String noDue = MatterCommunicationAnalysisBatch.formatPromiseHtml(
            '2025-01-10|attorney|File motion|NONE|' + emailId);
        System.assert(!noDue.contains('Due:'), 'NONE due date omitted');

        // No record ID → no hyperlink, and no placeholder note either
        String noId = MatterCommunicationAnalysisBatch.formatPromiseHtml('2025-01-10|attorney|File motion|2025-01-15|');
        System.assert(!noId.contains('href'),                          'Blank record ID produces no hyperlink');
        System.assert(!noId.contains('source record not identified'),  'Blank Id is silent, not annotated');

        // Blank input → empty string
        System.assertEquals('', MatterCommunicationAnalysisBatch.formatPromiseHtml(''), 'Blank line returns empty string');
    }

    @isTest
    static void testFormatPromiseHtml_RejectsBadRecordIds() {
        // Every one of these was observed in live Open_Promises__c content and rendered as
        // a dead link. The promise text must survive; the link must not be produced.
        List<String> junk = new List<String>{
            'Related Call Transcript',
            'Related Meeting Transcript',
            'View Record',
            'a035g00000ABCDE',
            String.valueOf(fakeMatterId(10))
        };

        for (String bad : junk) {
            String html = MatterCommunicationAnalysisBatch.formatPromiseHtml(
                '2025-01-10|attorney|Will file motion|2025-01-15|' + bad);
            System.assert(html.contains('Will file motion'), 'Promise text kept for: ' + bad);
            System.assert(!html.contains('href'),            'No hyperlink produced for: ' + bad);
            System.assert(html.contains('source record not identified'),
                'Unresolved source is called out for: ' + bad);
        }
    }

    @isTest
    static void testStampScalarFields_Promises() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Completed_Promises__c = '<p>old promise entry</p>',
            Broken_Promises__c    = null
        );

        Id rec1 = fakeEmailId(20);
        Id rec2 = fakeCallId(20);

        // OPEN_PROMISES: set to a value — output should be HTML with hyperlink
        AcctSeed__Project__c mOpen = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mOpen, matter,
            '==OPEN_PROMISES==\n2025-01-10|attorney|Will file motion|2025-01-15|' + rec1);
        System.assert(mOpen.Open_Promises__c.contains('<p>'),              'Open promise wrapped in paragraph tag');
        System.assert(mOpen.Open_Promises__c.contains('Will file motion'), 'Description in open promise');
        System.assert(mOpen.Open_Promises__c.contains('href="/lightning/r/EmailMessage/' + rec1 + '/view"'),
            'Hyperlink to communication record in open promise');

        // OPEN_PROMISES = NONE → null
        AcctSeed__Project__c mNone = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mNone, matter, '==OPEN_PROMISES==\nNONE');
        System.assertEquals(null, mNone.Open_Promises__c, 'NONE should clear open promises to null');

        // COMPLETED_PROMISES appends HTML to existing content
        AcctSeed__Project__c mCompleted = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mCompleted, matter,
            '==COMPLETED_PROMISES==\n2025-01-15|attorney|Filed motion|completed|' + rec1);
        System.assert(mCompleted.Completed_Promises__c.contains('old promise entry'), 'Existing completed promises preserved on append');
        System.assert(mCompleted.Completed_Promises__c.contains('Filed motion'),      'New completed promise appended as HTML');
        System.assert(mCompleted.Completed_Promises__c.contains('href="/lightning/r/EmailMessage/' + rec1 + '/view"'),
            'Hyperlink in completed promise');

        // BROKEN_PROMISES: no existing → set as HTML
        AcctSeed__Project__c mBroken = new AcctSeed__Project__c();
        MatterCommunicationAnalysisBatch.stampScalarFields(mBroken, matter,
            '==BROKEN_PROMISES==\n2025-01-15|client|Never sent docs|broken|' + rec2);
        System.assert(mBroken.Broken_Promises__c.contains('Never sent docs'), 'Broken promise description recorded');
        System.assert(mBroken.Broken_Promises__c.contains('href="/lightning/r/Call_Transcript__c/' + rec2 + '/view"'),
            'Hyperlink in broken promise');

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