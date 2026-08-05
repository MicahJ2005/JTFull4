/**
 * MatterCommunicationsControllerTest.cls
 * Test coverage for MatterCommunicationsController.
 *
 * Test data: 5 emails + 1 text session (raw fallback format) + 1 meeting = 7 total records.
 * Call_Transcript__c requires Voice_Call__c (platform-managed, not test-insertable)
 * so call tests cover the controller routing and empty-junction code path instead.
 * extractCustomerName() is annotated @TestVisible and tested directly.
 */
@IsTest
private class MatterCommunicationsControllerTest {

    @TestSetup
    static void makeData() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(Name = 'Test Matter');
        insert matter;

        Account acct = new Account(Name = 'Test Account');
        insert acct;

        Case parentCase = new Case(Subject = 'Test', AccountId = acct.Id);
        insert parentCase;

        // ── Emails ────────────────────────────────────────────────────────────
        List<EmailMessage> emails = new List<EmailMessage>();
        for (Integer i = 0; i < 5; i++) {
            emails.add(new EmailMessage(
                ParentId    = parentCase.Id,
                Subject     = 'Test Subject ' + i,
                TextBody    = 'Body content ' + i,
                FromName    = 'Sender ' + i,
                FromAddress = 'sender' + i + '@test.com',
                ToAddress   = 'recipient@firm.com',
                Incoming    = Math.mod(i, 2) == 0,
                RelatedToId = matter.Id,
                MessageDate = Datetime.now().addDays(-i)
            ));
        }
        insert emails;

        List<Related_Email_Message__c> emailJunctions = new List<Related_Email_Message__c>();
        for (EmailMessage em : emails) {
            emailJunctions.add(new Related_Email_Message__c(
                Matter__c           = matter.Id,
                Email_Message_Id__c = em.Id,
                Email_Subject__c    = em.Subject,
                Email_Recipients__c = em.ToAddress,
                Account__c          = acct.Id
            ));
        }
        insert emailJunctions;

        // ── Calls ─────────────────────────────────────────────────────────────
        // Call_Transcript__c requires Voice_Call__c, and VoiceCall is a
        // platform-managed object that cannot be inserted in Apex tests.
        // Call filter tests cover the controller routing + empty-junction path.

        // ── Texts ─────────────────────────────────────────────────────────────
        SMS_Session__c sess = new SMS_Session__c(
            SMS_Session_Date__c    = Date.today().addDays(-1),
            SMS_Session_Text__c    = 'Client: Is the case ready?\nJT: Almost there.',
            SMS_Phone__c           = '+16125551234',
            Johnson_Turner_User__c = UserInfo.getUserId()
        );
        insert sess;

        // Type__c is a restricted picklist — omitted so the platform assigns
        // its default; the controller treats a blank/null Type as incoming.
        insert new SMS_Session_Individual__c(
            SMS_Session__c = sess.Id,
            JT_User__c     = UserInfo.getUserId()
        );

        insert new Related_Text_Message__c(
            Matter__c               = matter.Id,
            Text_Message_Session__c = sess.Id
        );

        // ── Meetings ──────────────────────────────────────────────────────────
        // Status__c is a restricted picklist — omitted to avoid invalid-value errors.
        Meeting_Transcript__c mt = new Meeting_Transcript__c(
            Transcript__c          = 'Atty: Welcome everyone\nClient: Thank you',
            Meeting_Date__c        = Date.today().addDays(-2),
            Johnson_Turner_User__c = UserInfo.getUserId()
        );
        insert mt;

        insert new Related_Meeting_Transcript__c(
            Matter__c             = matter.Id,
            Meeting_Transcript__c = mt.Id
        );
    }


    // ── Email tests ───────────────────────────────────────────────────────────

    @IsTest static void testEmailRetrieval() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,null,null,50,0);
        Test.stopTest();
        System.assertEquals(5, r.counts.EMAIL, 'Expected 5 emails');
        System.assertEquals(5, r.totalCount,   'Expected totalCount 5 on EMAIL filter');
        for (MatterCommunicationsController.CommItem item : r.items) {
            System.assertEquals('EMAIL', item.commType, 'EMAIL filter returned non-email item');
        }
    }

    @IsTest static void testEmailIsolation() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,null,null,50,0);
        Test.stopTest();
        for (MatterCommunicationsController.CommItem item : r.items) {
            System.assertNotEquals('CALL',    item.commType, 'EMAIL filter returned CALL');
            System.assertNotEquals('TEXT',    item.commType, 'EMAIL filter returned TEXT');
            System.assertNotEquals('MEETING', item.commType, 'EMAIL filter returned MEETING');
        }
    }

    @IsTest static void testSearchBySubject() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL','Subject 0',null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.items.size(), 'Search by subject should return 1 result');
    }

    @IsTest static void testSearchBySender() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL','sender1@test.com',null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.items.size(), 'Should find 1 result by fromAddress');
    }

    @IsTest static void testSearchByRecipient() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL','recipient@firm.com',null,null,50,0);
        Test.stopTest();
        System.assertEquals(5, r.items.size(), 'Should find all 5 by toAddress');
    }

    @IsTest static void testPagination() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult p1 =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,null,null,3,0);
        MatterCommunicationsController.CommunicationsResult p2 =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,null,null,3,3);
        Test.stopTest();
        System.assertEquals(3,     p1.items.size(), 'Page 1 should have 3 items');
        System.assertEquals(true,  p1.hasMore,      'Page 1 should have more');
        System.assertEquals(2,     p2.items.size(), 'Page 2 should have 2 items');
        System.assertEquals(false, p2.hasMore,      'Page 2 should have no more');
    }

    @IsTest static void testGetEmailBody() {
        EmailMessage em = [SELECT Id FROM EmailMessage LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommItem item =
            MatterCommunicationsController.getEmailBody(em.Id);
        Test.stopTest();
        System.assertEquals('EMAIL', item.commType);
        System.assertEquals(em.Id,   item.recordId);
    }

    @IsTest static void testGetEmailBodyNullThrows() {
        Boolean threw = false;
        Test.startTest();
        try { MatterCommunicationsController.getEmailBody(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();
        System.assert(threw, 'Should throw for null emailMessageId');
    }


    // ── Call tests ────────────────────────────────────────────────────────────

    @IsTest static void testFilterCallEmptyPath() {
        // Verifies the CALL filter routes correctly through getCommunications
        // and returns an empty result when no Related_Call_Transcript__c junctions
        // exist (VoiceCall is platform-managed and cannot be inserted in tests).
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'CALL',null,null,null,50,0);
        Test.stopTest();
        System.assertEquals(0, r.totalCount,  'No call junctions exist — should return 0');
        System.assertEquals(0, r.counts.CALL, 'counts.CALL should be 0');
        System.assertEquals(0, r.items.size(), 'No items expected');
    }

    @IsTest static void testCallIsolation() {
        // CALL filter must never return EMAIL, TEXT, or MEETING items
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'CALL',null,null,null,50,0);
        Test.stopTest();
        for (MatterCommunicationsController.CommItem item : r.items) {
            System.assertNotEquals('EMAIL',   item.commType, 'CALL filter returned EMAIL');
            System.assertNotEquals('TEXT',    item.commType, 'CALL filter returned TEXT');
            System.assertNotEquals('MEETING', item.commType, 'CALL filter returned MEETING');
        }
    }

    @IsTest static void testSearchCallEmptyPath() {
        // Search with CALL filter exercises the search-term branch of getCalls
        // even when no junctions exist — confirms no exception is thrown
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'CALL','Speaker A',null,null,50,0);
        Test.stopTest();
        System.assertEquals(0, r.items.size(), 'No calls — empty result expected');
    }


    // ── Email date filter tests ───────────────────────────────────────────────

    @IsTest static void testEmailDateFromFilter() {
        // Covers getEmails() dfrom branch (lines 220-221)
        // dateFrom = today → only email 0 (MessageDate = now) qualifies
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        String today = String.valueOf(Date.today());
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,today,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.totalCount, 'dfrom=today should return only today\'s email');
    }

    @IsTest static void testEmailDateToFilter() {
        // Covers getEmails() dto branch (lines 224-225)
        // dateTo = yesterday → emails 1-4 (MessageDate yesterday and older) qualify
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        String yesterday = String.valueOf(Date.today().addDays(-1));
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,null,yesterday,50,0);
        Test.stopTest();
        System.assertEquals(4, r.totalCount, 'dto=yesterday should return 4 emails');
    }

    @IsTest static void testGetEmailBodyNotFound() {
        // Covers line 178 — getEmailBody throws when no EmailMessage matches the ID
        // Passing the Matter ID (valid format, wrong object) returns empty from SOQL
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Boolean threw = false;
        Test.startTest();
        try { MatterCommunicationsController.getEmailBody(m.Id); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException when EmailMessage not found');
    }

    @IsTest static void testMalformedEmailMessageId() {
        // Covers line 204 — catch block skips junctions whose Email_Message_Id__c
        // cannot be cast to Id (non-null text value that is not a valid SF ID)
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        insert new Related_Email_Message__c(
            Matter__c           = m.Id,
            Email_Message_Id__c = 'INVALID'
        );
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'EMAIL',null,null,null,50,0);
        Test.stopTest();
        // Malformed junction is silently skipped — only the 5 valid emails count
        System.assertEquals(5, r.totalCount, 'Malformed junction should be skipped, returning 5 valid emails');
    }

    // ── Text tests ────────────────────────────────────────────────────────────

    @IsTest static void testFilterText() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT',null,null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.totalCount,         'Should return 1 text session');
        System.assertEquals(1, r.counts.TEXT,        'counts.TEXT should be 1');
        System.assertEquals('TEXT', r.items[0].commType);
    }

    @IsTest static void testTextIsolation() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT',null,null,null,50,0);
        Test.stopTest();
        for (MatterCommunicationsController.CommItem item : r.items) {
            System.assertNotEquals('EMAIL',   item.commType, 'TEXT filter returned EMAIL');
            System.assertNotEquals('CALL',    item.commType, 'TEXT filter returned CALL');
            System.assertNotEquals('MEETING', item.commType, 'TEXT filter returned MEETING');
        }
    }

    @IsTest static void testTextHasBubbles() {
        // The makeData session uses raw text (not Zoom block format), so the parser
        // finds no double-newline-delimited blocks and fires the raw-content fallback,
        // which surfaces the entire session text as a single incoming bubble.
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT',null,null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.items.size());
        System.assert(
            r.items[0].textMessages != null && r.items[0].textMessages.size() >= 1,
            'TEXT item should have at least one bubble (raw-content fallback)'
        );
    }

    @IsTest static void testSearchByPhone() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT','+16125551234',null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.items.size(), 'Should find text session by phone number');
    }


    @IsTest static void testTextBubbleZoomFormat() {
        // Verifies the Zoom block-format parser (Date/Time / Sender / Message blocks
        // separated by \n\n) creates one bubble per block with the correct body text
        // and a parsed sentTime.  A unique phone number isolates this session from
        // the raw-format session inserted in makeData.
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];

        String zoomText =
            'Date/Time: 2025-11-07T16:29:43Z\nSender: Test Client, \nTo: JT User, \nMessage: Is the case ready?\n\n' +
            'Date/Time: 2025-11-07T16:30:00Z\nSender: JT User, \nTo: Test Client, \nMessage: Almost there.';

        SMS_Session__c sess = new SMS_Session__c(
            SMS_Session_Date__c    = Date.today().addDays(-1),
            SMS_Session_Text__c    = zoomText,
            SMS_Phone__c           = '+16125559999',
            Johnson_Turner_User__c = UserInfo.getUserId()
        );
        insert sess;
        insert new Related_Text_Message__c(Matter__c = m.Id, Text_Message_Session__c = sess.Id);

        Test.startTest();
        // Search by unique phone to isolate this session from the makeData session
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT','+16125559999',null,null,50,0);
        Test.stopTest();

        System.assertEquals(1, r.items.size(), 'Should return 1 Zoom-format text session');
        MatterCommunicationsController.CommItem item = r.items[0];
        System.assertNotEquals(null, item.textMessages, 'textMessages should not be null');
        System.assertEquals(2, item.textMessages.size(), 'Zoom block format should produce 2 bubbles');
        System.assertEquals('Is the case ready?', item.textMessages[0].body, 'First bubble body mismatch');
        System.assertEquals('Almost there.',       item.textMessages[1].body, 'Second bubble body mismatch');
        System.assertEquals('Test Client',         item.textMessages[0].fromName, 'Sender should be stripped of trailing comma');
        System.assertNotEquals('', item.textMessages[0].sentTime, 'sentTime should be parsed from ISO timestamp');
        System.assertEquals('Is the case ready?',  item.bodyPreview, 'bodyPreview should use first bubble body');
    }

    @IsTest static void testTextDateFilter() {
        // Covers getTexts() dfrom and dto date filter branches (lines 407-411)
        // SMS session is from yesterday — dfrom=today excludes it, dto=2daysago also excludes it
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        String today      = String.valueOf(Date.today());
        String twoDaysAgo = String.valueOf(Date.today().addDays(-2));
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r1 =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT',null,today,null,50,0);
        MatterCommunicationsController.CommunicationsResult r2 =
            MatterCommunicationsController.getCommunications(m.Id,'TEXT',null,null,twoDaysAgo,50,0);
        Test.stopTest();
        System.assertEquals(0, r1.totalCount, 'dfrom=today should exclude yesterday\'s text session');
        System.assertEquals(0, r2.totalCount, 'dto=2daysago should exclude yesterday\'s text session');
    }

    // ── Meeting tests ─────────────────────────────────────────────────────────

    @IsTest static void testFilterMeeting() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'MEETING',null,null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.totalCount,            'Should return 1 meeting');
        System.assertEquals(1, r.counts.MEETING,        'counts.MEETING should be 1');
        System.assertEquals('MEETING', r.items[0].commType);
    }

    @IsTest static void testMeetingIsolation() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'MEETING',null,null,null,50,0);
        Test.stopTest();
        for (MatterCommunicationsController.CommItem item : r.items) {
            System.assertNotEquals('EMAIL', item.commType, 'MEETING filter returned EMAIL');
            System.assertNotEquals('CALL',  item.commType, 'MEETING filter returned CALL');
            System.assertNotEquals('TEXT',  item.commType, 'MEETING filter returned TEXT');
        }
    }

    @IsTest static void testSearchByMeetingTranscript() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'MEETING','Welcome everyone',null,null,50,0);
        Test.stopTest();
        System.assertEquals(1, r.items.size(), 'Should find meeting by transcript text');
    }


    @IsTest static void testMeetingDateFilter() {
        // Covers getMeetings() dfrom and dto date filter branches (lines 506-510)
        // Meeting is from 2 days ago — dfrom=yesterday excludes it, dto=3daysago also excludes it
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        String yesterday    = String.valueOf(Date.today().addDays(-1));
        String threeDaysAgo = String.valueOf(Date.today().addDays(-3));
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r1 =
            MatterCommunicationsController.getCommunications(m.Id,'MEETING',null,yesterday,null,50,0);
        MatterCommunicationsController.CommunicationsResult r2 =
            MatterCommunicationsController.getCommunications(m.Id,'MEETING',null,null,threeDaysAgo,50,0);
        Test.stopTest();
        System.assertEquals(0, r1.totalCount, 'dfrom=yesterday should exclude 2-days-ago meeting');
        System.assertEquals(0, r2.totalCount, 'dto=3daysago should exclude 2-days-ago meeting');
    }

    // ── ALL filter / cross-type tests ─────────────────────────────────────────

    @IsTest static void testAllFilterIncludesAllTypes() {
        // ALL filter must surface EMAIL, TEXT, and MEETING from test data.
        // CALL is excluded here because VoiceCall records are not test-insertable.
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'ALL',null,null,null,50,0);
        Test.stopTest();
        Set<String> types = new Set<String>();
        for (MatterCommunicationsController.CommItem item : r.items) {
            types.add(item.commType);
        }
        System.assert(types.contains('EMAIL'),   'ALL should include EMAIL');
        System.assert(types.contains('TEXT'),    'ALL should include TEXT');
        System.assert(types.contains('MEETING'), 'ALL should include MEETING');
    }

    @IsTest static void testCountsAllTypes() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'ALL',null,null,null,50,0);
        Test.stopTest();
        System.assertEquals(5, r.counts.EMAIL,   'Expected 5 emails');
        System.assertEquals(0, r.counts.CALL,    'Expected 0 calls (VoiceCall not test-insertable)');
        System.assertEquals(1, r.counts.TEXT,    'Expected 1 text');
        System.assertEquals(1, r.counts.MEETING, 'Expected 1 meeting');
        System.assertEquals(7, r.counts.total,   'Expected 7 total');
    }

    @IsTest static void testSortedDescending() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        MatterCommunicationsController.CommunicationsResult r =
            MatterCommunicationsController.getCommunications(m.Id,'ALL',null,null,null,50,0);
        Test.stopTest();
        Datetime prev = null;
        for (MatterCommunicationsController.CommItem item : r.items) {
            if (prev != null && item.messageDate != null) {
                System.assert(item.messageDate <= prev, 'Items not sorted descending by messageDate');
            }
            if (item.messageDate != null) prev = item.messageDate;
        }
    }

    @IsTest static void testPaginationAllTypes() {
        AcctSeed__Project__c m = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        Test.startTest();
        // 7 total records (5 email + 1 text + 1 meeting) — page 1 of 5 leaves 2 on page 2
        MatterCommunicationsController.CommunicationsResult p1 =
            MatterCommunicationsController.getCommunications(m.Id,'ALL',null,null,null,5,0);
        MatterCommunicationsController.CommunicationsResult p2 =
            MatterCommunicationsController.getCommunications(m.Id,'ALL',null,null,null,5,5);
        Test.stopTest();
        System.assertEquals(5,     p1.items.size(), 'Page 1 should have 5 items');
        System.assertEquals(true,  p1.hasMore,      'Page 1 should have more');
        System.assertEquals(2,     p2.items.size(), 'Page 2 should have 2 items');
        System.assertEquals(false, p2.hasMore,      'Page 2 should have no more');
    }

    @IsTest static void testNullMatterIdThrows() {
        Boolean threw = false;
        Test.startTest();
        try { MatterCommunicationsController.getCommunications(null,'ALL',null,null,null,50,0); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for null matterId');
    }


    // ── extractCustomerName unit tests ────────────────────────────────────────
    // extractCustomerName() is @TestVisible so it can be called directly without
    // needing an insertable Call_Transcript__c (which requires the platform-managed
    // VoiceCall object and cannot be created in Apex tests).

    @IsTest static void testExtractCustomerNameFormat1() {
        // Format 1 — "Speaker: spoken text" per line.
        // JT attorney speaks first; customer should be returned as the non-JT speaker.
        String transcript =
            'Amanda Johnson: Hello, how can I help you today?\n' +
            'Deanna Zimmer: Hi, I had a question about my case.\n' +
            'Amanda Johnson: Of course, go ahead.';
        Test.startTest();
        String result = MatterCommunicationsController.extractCustomerName(transcript, 'Amanda Johnson');
        Test.stopTest();
        System.assertEquals('Deanna Zimmer', result, 'Format 1: should return non-JT speaker as customer name');
    }

    @IsTest static void testExtractCustomerNameFormat2() {
        // Format 2 — "User: Name\ntext: body" pairs (Zimmer/Patricia-style transcripts).
        // Customer appears first; JT attorney's name is excluded.
        String transcript =
            'User: Patricia Jean Pawlitschek\n' +
            'text: Hello there, I have a question.\n' +
            'User: Amanda Johnson\n' +
            'text: Hi Patricia, happy to help.';
        Test.startTest();
        String result = MatterCommunicationsController.extractCustomerName(transcript, 'Amanda Johnson');
        Test.stopTest();
        System.assertEquals('Patricia Jean Pawlitschek', result,
            'Format 2: should return the non-JT User: value as customer name');
    }

    @IsTest static void testExtractCustomerNameBlankTranscript() {
        // A null or blank transcript has no speakers to parse — should return null.
        Test.startTest();
        String nullResult  = MatterCommunicationsController.extractCustomerName(null, 'Amanda Johnson');
        String blankResult = MatterCommunicationsController.extractCustomerName('',   'Amanda Johnson');
        Test.stopTest();
        System.assertEquals(null, nullResult,  'Null transcript should return null');
        System.assertEquals(null, blankResult, 'Blank transcript should return null');
    }

    @IsTest static void testExtractCustomerNameBlankJtUser() {
        // When Call_Owner_Name__c is blank (e.g. no VoiceCall linked), the method
        // cannot exclude the JT attorney and falls back to the first candidate.
        String transcript =
            'Amanda Johnson: Hello\n' +
            'Deanna Zimmer: Hi there';
        Test.startTest();
        String result = MatterCommunicationsController.extractCustomerName(transcript, null);
        Test.stopTest();
        System.assertEquals('Amanda Johnson', result,
            'Blank jtUserName: should return first speaker (no exclusion applied)');
    }

    @IsTest static void testExtractCustomerNameFallbackSingleSpeaker() {
        // Edge case: transcript contains only the JT attorney speaking.
        // No other candidate can be excluded, so the method returns the only candidate.
        String transcript =
            'Amanda Johnson: Hello\n' +
            'Amanda Johnson: Is anyone there?';
        Test.startTest();
        String result = MatterCommunicationsController.extractCustomerName(transcript, 'Amanda Johnson');
        Test.stopTest();
        System.assertEquals('Amanda Johnson', result,
            'Single-speaker transcript: should return the only candidate as fallback');
    }
}