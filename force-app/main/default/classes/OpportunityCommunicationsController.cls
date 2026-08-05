/**
 * OpportunityCommunicationsController.cls
 *
 * Apex controller for the opportunityCommunicationsHub LWC.
 * Returns unified, paginated communications for an Opportunity record.
 *
 * Search covers: Subject, TextBody, FromName, FromAddress,
 *                ToAddress, CcAddress — matching the Lovable prototype.
 *
 * @org  Johnson Turner Legal
 */
public with sharing class OpportunityCommunicationsController {

    private static final Integer DEFAULT_PAGE_SIZE = 50;

    // ── Result wrappers ───────────────────────────────────────────────────────

    public class CommunicationsResult {
        @AuraEnabled public List<CommItem> items      { get; set; }
        @AuraEnabled public Integer        totalCount { get; set; }
        @AuraEnabled public Integer        pageSize   { get; set; }
        @AuraEnabled public Integer        pageOffset { get; set; }
        @AuraEnabled public Boolean        hasMore    { get; set; }
        @AuraEnabled public CommCounts     counts     { get; set; }
        public CommunicationsResult() {
            items      = new List<CommItem>();
            totalCount = 0;
            pageSize   = DEFAULT_PAGE_SIZE;
            pageOffset = 0;
            hasMore    = false;
            counts     = new CommCounts();
        }
    }

    public class CommCounts {
        @AuraEnabled public Integer total   { get; set; }
        @AuraEnabled public Integer EMAIL   { get; set; }
        @AuraEnabled public Integer CALL    { get; set; }
        @AuraEnabled public Integer TEXT    { get; set; }
        @AuraEnabled public Integer MEETING { get; set; }
        public CommCounts() { total = 0; EMAIL = 0; CALL = 0; TEXT = 0; MEETING = 0; }
    }

    public class CommItem {
        @AuraEnabled public String          commType        { get; set; } // EMAIL | CALL | TEXT | MEETING
        @AuraEnabled public String          recordId        { get; set; }
        @AuraEnabled public String          junctionId      { get; set; }
        @AuraEnabled public String          subject         { get; set; }
        @AuraEnabled public String          bodyPreview     { get; set; }
        @AuraEnabled public String          htmlBody        { get; set; } // null in list — loaded on demand
        @AuraEnabled public String          textBody        { get; set; }
        @AuraEnabled public String          fromName        { get; set; }
        @AuraEnabled public String          fromAddress     { get; set; }
        @AuraEnabled public String          toAddress       { get; set; }
        @AuraEnabled public String          ccAddress       { get; set; }
        @AuraEnabled public String          threadId        { get; set; }
        @AuraEnabled public Datetime        messageDate     { get; set; }
        @AuraEnabled public Boolean         isIncoming      { get; set; }
        @AuraEnabled public Boolean         hasAttachment   { get; set; }
        @AuraEnabled public Integer         durationSeconds { get; set; }
        @AuraEnabled public String          transcriptBody  { get; set; }
        @AuraEnabled public List<TextMsgItem> textMessages  { get; set; }
    }

    public class TextMsgItem {
        @AuraEnabled public String  id       { get; set; }
        @AuraEnabled public String  fromName { get; set; }
        @AuraEnabled public String  sentTime { get; set; }
        @AuraEnabled public String  body     { get; set; }
        @AuraEnabled public Boolean incoming { get; set; }
    }


    // ── Primary method ────────────────────────────────────────────────────────

    /**
     * getCommunications
     *
     * Called by the LWC on every filter/search/page change.
     *
     * @param opportunityId  Opportunity Id
     * @param filterType     ALL | EMAIL | CALL | TEXT | MEETING
     * @param searchTerm     Free-text — searches subject, body, fromName,
     *                       fromAddress, toAddress, ccAddress
     * @param dateFrom       Optional ISO date string (yyyy-MM-dd)
     * @param dateTo         Optional ISO date string (yyyy-MM-dd)
     * @param pageSize       Records per page (default 50)
     * @param pageOffset     0-based offset for pagination
     */
    @AuraEnabled(cacheable=false)
    public static CommunicationsResult getCommunications(
        Id      opportunityId,
        String  filterType,
        String  searchTerm,
        String  dateFrom,
        String  dateTo,
        Integer pageSize,
        Integer pageOffset
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('opportunityId is required.');
        }

        if (String.isBlank(filterType)) filterType = 'ALL';
        if (pageSize   == null || pageSize   <= 0) pageSize   = DEFAULT_PAGE_SIZE;
        if (pageOffset == null || pageOffset <  0) pageOffset = 0;

        // Parse optional date strings
        Date dfrom = String.isBlank(dateFrom) ? null : Date.valueOf(dateFrom);
        Date dto   = String.isBlank(dateTo)   ? null : Date.valueOf(dateTo);

        Boolean all     = filterType == 'ALL';
        List<CommItem> allItems = new List<CommItem>();

        if (all || filterType == 'EMAIL')   allItems.addAll(getEmails(opportunityId, searchTerm, dfrom, dto));
        if (all || filterType == 'CALL')    allItems.addAll(getCalls(opportunityId, searchTerm, dfrom, dto));
        if (all || filterType == 'TEXT')    allItems.addAll(getTexts(opportunityId, searchTerm, dfrom, dto));
        if (all || filterType == 'MEETING') allItems.addAll(getMeetings(opportunityId, searchTerm, dfrom, dto));

        // Count by type
        CommCounts counts = new CommCounts();
        for (CommItem item : allItems) {
            counts.total++;
            if      (item.commType == 'EMAIL')   counts.EMAIL++;
            else if (item.commType == 'CALL')    counts.CALL++;
            else if (item.commType == 'TEXT')    counts.TEXT++;
            else if (item.commType == 'MEETING') counts.MEETING++;
        }

        // Sort descending by messageDate
        allItems.sort(new DateComparator());

        // Paginate
        Integer total  = allItems.size();
        Integer from_i = Math.min(pageOffset, total);
        Integer to_i   = Math.min(pageOffset + pageSize, total);
        List<CommItem> page = new List<CommItem>();
        for (Integer i = from_i; i < to_i; i++) {
            page.add(allItems[i]);
        }

        CommunicationsResult result = new CommunicationsResult();
        result.items      = page;
        result.totalCount = total;
        result.pageSize   = pageSize;
        result.pageOffset = pageOffset;
        result.hasMore    = to_i < total;
        result.counts     = counts;
        return result;
    }


    /**
     * getEmailBody
     *
     * Loads full HtmlBody/TextBody for a single EmailMessage.
     * Called on demand when the user opens an email in the reading pane.
     * Keeping this separate keeps the list query lightweight.
     */
    @AuraEnabled(cacheable=true)
    public static CommItem getEmailBody(String emailMessageId) {
        if (String.isBlank(emailMessageId)) {
            throw new AuraHandledException('emailMessageId is required.');
        }
        List<EmailMessage> emails = [
            SELECT Id, Subject, HtmlBody, TextBody,
                   FromName, FromAddress, ToAddress, CcAddress,
                   MessageDate, Incoming, HasAttachment, ThreadIdentifier
            FROM   EmailMessage
            WHERE  Id = :emailMessageId
            LIMIT  1
        ];
        if (emails.isEmpty()) {
            throw new AuraHandledException('EmailMessage not found: ' + emailMessageId);
        }
        return toEmailItem(emails[0], null);
    }


    // ── Email fetch ───────────────────────────────────────────────────────────

    private static List<CommItem> getEmails(
        Id opportunityId, String searchTerm, Date dfrom, Date dto
    ) {
        // Step 1 — junction records for this Opportunity
        List<Related_Email_Message__c> junctions = [
            SELECT Id, Email_Message_Id__c
            FROM   Related_Email_Message__c
            WHERE  Opportunity__c = :opportunityId
            AND    Email_Message_Id__c != null
        ];
        if (junctions.isEmpty()) return new List<CommItem>();

        // Map EmailMessage Id → junction
        Map<Id, Related_Email_Message__c> byEmailId = new Map<Id, Related_Email_Message__c>();
        for (Related_Email_Message__c j : junctions) {
            try { byEmailId.put((Id) j.Email_Message_Id__c, j); }
            catch (Exception e) { /* skip malformed */ }
        }
        if (byEmailId.isEmpty()) return new List<CommItem>();

        // Step 2 — query EmailMessage
        // HtmlBody intentionally excluded for list performance — loaded via getEmailBody()
        // Dynamic SOQL bind vars don't support Map keySets directly — extract to a Set<Id>
        Set<Id> emailIds = byEmailId.keySet();
        String q =
            'SELECT Id, Subject, TextBody, FromName, FromAddress, ' +
            '       ToAddress, CcAddress, MessageDate, Incoming, ' +
            '       HasAttachment, ThreadIdentifier ' +
            'FROM   EmailMessage ' +
            'WHERE  Id IN :emailIds ';

        if (dfrom != null) {
            Datetime start = Datetime.newInstance(dfrom, Time.newInstance(0,0,0,0));
            q += 'AND MessageDate >= :start ';
        }
        if (dto != null) {
            Datetime endDt = Datetime.newInstance(dto, Time.newInstance(23,59,59,999));
            q += 'AND MessageDate <= :endDt ';
        }

        // Search — covers subject, fromName, fromAddress, toAddress, ccAddress.
        // TextBody is a Long Text Area and cannot be used in a SOQL WHERE clause.
        if (!String.isBlank(searchTerm)) {
            String term = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            q +=
                'AND (Subject     LIKE :term ' +
                '  OR FromName    LIKE :term ' +
                '  OR FromAddress LIKE :term ' +
                '  OR ToAddress   LIKE :term ' +
                '  OR CcAddress   LIKE :term) ';
        }

        q += 'ORDER BY MessageDate DESC LIMIT 2000';

        List<EmailMessage> emails = Database.query(q);
        List<CommItem> items = new List<CommItem>();
        for (EmailMessage em : emails) {
            items.add(toEmailItem(em, byEmailId.get(em.Id)));
        }
        return items;
    }

    private static CommItem toEmailItem(
        EmailMessage em, Related_Email_Message__c jxn
    ) {
        CommItem c      = new CommItem();
        c.commType      = 'EMAIL';
        c.recordId      = em.Id;
        c.junctionId    = jxn != null ? jxn.Id : null;
        c.subject       = em.Subject;
        c.fromName      = em.FromName;
        c.fromAddress   = em.FromAddress;
        c.toAddress     = em.ToAddress;
        c.ccAddress     = em.CcAddress;
        c.messageDate   = em.MessageDate;
        c.isIncoming    = em.Incoming;
        c.hasAttachment = em.HasAttachment;
        c.threadId      = em.ThreadIdentifier;
        c.htmlBody      = em.getPopulatedFieldsAsMap().containsKey('HtmlBody') ? em.HtmlBody : null;
        c.textBody      = em.TextBody;
        if (!String.isBlank(em.TextBody)) {
            c.bodyPreview = em.TextBody.length() > 160
                ? em.TextBody.substring(0, 160) + '…'
                : em.TextBody;
        }
        return c;
    }


    // ── Calls ─────────────────────────────────────────────────────────────────
    // Long Text Area fields cannot be traversed via __r — query target objects directly.

    private static List<CommItem> getCalls(
        Id opportunityId, String searchTerm, Date dfrom, Date dto
    ) {
        // Step 1 — junction records
        List<Related_Call_Transcript__c> junctions = [
            SELECT Id, Call_Transcript__c, CreatedDate
            FROM   Related_Call_Transcript__c
            WHERE  Opportunity__c = :opportunityId
            AND    Call_Transcript__c != null
        ];
        if (junctions.isEmpty()) return new List<CommItem>();

        Map<Id, Related_Call_Transcript__c> junctionByTranscript = new Map<Id, Related_Call_Transcript__c>();
        for (Related_Call_Transcript__c j : junctions) {
            junctionByTranscript.put(j.Call_Transcript__c, j);
        }
        Set<Id> transcriptIds = junctionByTranscript.keySet();

        // Step 2 — query Call_Transcript__c directly (avoids Long Text Area traversal)
        List<Call_Transcript__c> transcripts = [
            SELECT Id, Transcript_Text__c, Call_Owner_Name__c, Communication_Type__c,
                   Voice_Call__r.CallStartDateTime, Voice_Call__r.CallDurationInSeconds
            FROM   Call_Transcript__c
            WHERE  Id IN :transcriptIds
        ];

        List<CommItem> items = new List<CommItem>();
        for (Call_Transcript__c ct : transcripts) {
            Related_Call_Transcript__c j = junctionByTranscript.get(ct.Id);

            Datetime callDate = (ct.Voice_Call__r != null && ct.Voice_Call__r.CallStartDateTime != null)
                ? ct.Voice_Call__r.CallStartDateTime : j.CreatedDate;

            if (dfrom != null && callDate != null) {
                if (callDate < Datetime.newInstance(dfrom, Time.newInstance(0,0,0,0))) continue;
            }
            if (dto != null && callDate != null) {
                if (callDate > Datetime.newInstance(dto, Time.newInstance(23,59,59,999))) continue;
            }
            if (!String.isBlank(searchTerm)) {
                String term = searchTerm.toLowerCase();
                Boolean match =
                    (!String.isBlank(ct.Call_Owner_Name__c)  && ct.Call_Owner_Name__c.toLowerCase().contains(term)) ||
                    (!String.isBlank(ct.Transcript_Text__c)  && ct.Transcript_Text__c.toLowerCase().contains(term));
                if (!match) continue;
            }

            // Extract the customer name from the transcript.
            // The transcript always has two speakers — one is the JT attorney
            // (Call_Owner_Name__c), the other is the customer. We exclude the
            // JT name and return the remaining speaker as the customer display name.
            String jtName       = ct.Call_Owner_Name__c;
            String customerName = extractCustomerName(ct.Transcript_Text__c, jtName);

            // Fall back to a generic label only when the transcript is truly empty.
            String displayName = !String.isBlank(customerName) ? customerName : 'Voice Call';
            String callSubject = 'Call — ' + displayName;

            CommItem c       = new CommItem();
            c.commType       = 'CALL';
            c.recordId       = ct.Id;
            c.junctionId     = j.Id;
            c.fromName       = displayName;
            c.subject        = callSubject;
            c.messageDate    = callDate;
            c.isIncoming     = false;
            c.transcriptBody = ct.Transcript_Text__c;
            if (!String.isBlank(ct.Transcript_Text__c)) {
                c.bodyPreview = ct.Transcript_Text__c.length() > 120
                    ? ct.Transcript_Text__c.substring(0, 120) + '…'
                    : ct.Transcript_Text__c;
            }
            if (ct.Voice_Call__r != null && ct.Voice_Call__r.CallDurationInSeconds != null) {
                c.durationSeconds = Integer.valueOf(ct.Voice_Call__r.CallDurationInSeconds);
            }
            items.add(c);
        }
        return items;
    }


    // ── Texts ─────────────────────────────────────────────────────────────────

    private static List<CommItem> getTexts(
        Id opportunityId, String searchTerm, Date dfrom, Date dto
    ) {
        // Step 1 — junction records
        List<Related_Text_Message__c> junctions = [
            SELECT Id, Text_Message_Session__c, CreatedDate
            FROM   Related_Text_Message__c
            WHERE  Opportunity__c = :opportunityId
            AND    Text_Message_Session__c != null
        ];
        if (junctions.isEmpty()) return new List<CommItem>();

        Map<Id, Related_Text_Message__c> junctionBySession = new Map<Id, Related_Text_Message__c>();
        for (Related_Text_Message__c j : junctions) {
            junctionBySession.put(j.Text_Message_Session__c, j);
        }
        Set<Id> sessionIds = junctionBySession.keySet();

        // Step 2 — query SMS_Session__c directly
        // Account__r.Name is used as the client display name in subject / avatar.
        // SMS_Session_Text__c stores the full conversation log in the format written
        // by ZoomSMSIntegration: each message block separated by \n\n, containing
        //   Date/Time: <ISO-8601>\nSender: <name>\nTo: <name>\nMessage: <body>
        Map<Id, SMS_Session__c> sessionsById = new Map<Id, SMS_Session__c>([
            SELECT Id, SMS_Session_Date__c, SMS_Session_Text__c,
                   SMS_Phone__c, Johnson_Turner_User__r.Name,
                   Account__r.Name
            FROM   SMS_Session__c
            WHERE  Id IN :sessionIds
        ]);

        List<CommItem> items = new List<CommItem>();
        for (Id sessionId : sessionIds) {
            Related_Text_Message__c j    = junctionBySession.get(sessionId);
            SMS_Session__c          sess = sessionsById.get(sessionId);
            if (sess == null) continue;

            Datetime sessionDate = sess.SMS_Session_Date__c != null
                ? Datetime.newInstance(sess.SMS_Session_Date__c, Time.newInstance(0,0,0,0))
                : j.CreatedDate;

            if (dfrom != null && sessionDate != null) {
                if (sessionDate < Datetime.newInstance(dfrom, Time.newInstance(0,0,0,0))) continue;
            }
            if (dto != null && sessionDate != null) {
                if (sessionDate > Datetime.newInstance(dto, Time.newInstance(23,59,59,999))) continue;
            }

            String sessionText = sess.SMS_Session_Text__c;
            String userName    = sess.Johnson_Turner_User__r?.Name;
            String clientName  = sess.Account__r?.Name;

            if (!String.isBlank(searchTerm)) {
                String term = searchTerm.toLowerCase();
                Boolean match =
                    (!String.isBlank(userName)          && userName.toLowerCase().contains(term))   ||
                    (!String.isBlank(clientName)        && clientName.toLowerCase().contains(term)) ||
                    (!String.isBlank(sess.SMS_Phone__c) && sess.SMS_Phone__c.contains(term))        ||
                    (!String.isBlank(sessionText)       && sessionText.toLowerCase().contains(term));
                if (!match) continue;
            }

            // Parse SMS_Session_Text__c into individual message bubbles.
            // Each block is delimited by a blank line (\n\n). Lines within a block:
            //   Date/Time: <ISO-8601 UTC>
            //   Sender: <name>,
            //   To: <name>,
            //   Message: <body text>
            List<TextMsgItem> bubbles = new List<TextMsgItem>();
            if (!String.isBlank(sessionText)) {
                for (String block : sessionText.split('\n\n')) {
                    if (String.isBlank(block.trim())) continue;
                    String dtStr   = '';
                    String sender  = '';
                    String message = '';
                    for (String line : block.trim().split('\n')) {
                        if      (line.startsWith('Date/Time: ')) dtStr   = line.substringAfter('Date/Time: ').trim();
                        else if (line.startsWith('Sender: '))    sender  = line.substringAfter('Sender: ').removeEnd(', ').trim();
                        else if (line.startsWith('Message: '))   message = line.substringAfter('Message: ').trim();
                    }
                    if (String.isBlank(message)) continue;

                    // Outgoing when the sender name contains the JT user's name
                    Boolean isOut = !String.isBlank(userName) && !String.isBlank(sender)
                        && sender.toLowerCase().contains(userName.toLowerCase());

                    String sentTime = '';
                    if (!String.isBlank(dtStr)) {
                        try {
                            // Convert "2025-11-07T16:29:43Z" → Datetime
                            Datetime msgDt = Datetime.valueOfGmt(dtStr.replace('T', ' ').replace('Z', ''));
                            sentTime = msgDt.format('M/d/yy h:mm a');
                        } catch (Exception e) {
                            sentTime = dtStr;
                        }
                    }

                    TextMsgItem tm = new TextMsgItem();
                    tm.id       = sessionId + '_' + dtStr;
                    tm.fromName = !String.isBlank(sender) ? sender
                                : (isOut ? userName : (!String.isBlank(clientName) ? clientName : sess.SMS_Phone__c));
                    tm.sentTime = sentTime;
                    tm.body     = message;
                    tm.incoming = !isOut;
                    bubbles.add(tm);
                }
            }
            // Fallback: if the session text doesn't follow the Zoom block format,
            // surface it as a single raw bubble so content is never lost.
            if (bubbles.isEmpty() && !String.isBlank(sessionText)) {
                TextMsgItem tm = new TextMsgItem();
                tm.id       = sessionId;
                tm.fromName = !String.isBlank(clientName) ? clientName : sess.SMS_Phone__c;
                tm.sentTime = sessionDate.format('M/d/yy h:mm a');
                tm.body     = sessionText;
                tm.incoming = true;
                bubbles.add(tm);
            }

            // Display name: prefer client (Account) name, then phone, then JT user
            String displayName = !String.isBlank(clientName) ? clientName
                               : (!String.isBlank(sess.SMS_Phone__c) ? sess.SMS_Phone__c : userName);

            CommItem c     = new CommItem();
            c.commType     = 'TEXT';
            c.recordId     = sessionId;
            c.junctionId   = j.Id;
            c.fromName     = displayName;
            c.subject      = 'Text — ' + (String.isBlank(displayName) ? 'SMS Session' : displayName);
            c.messageDate  = sessionDate;
            c.isIncoming   = true;
            c.textMessages = bubbles;
            // Preview: use first parsed message body; fall back to raw session text
            if (!bubbles.isEmpty() && !String.isBlank(bubbles[0].body)) {
                String preview = bubbles[0].body;
                c.bodyPreview  = preview.length() > 120 ? preview.substring(0, 120) + '…' : preview;
            } else if (!String.isBlank(sessionText)) {
                c.bodyPreview  = sessionText.length() > 120 ? sessionText.substring(0, 120) + '…' : sessionText;
            }
            items.add(c);
        }
        return items;
    }


    // ── Meetings ──────────────────────────────────────────────────────────────

    private static List<CommItem> getMeetings(
        Id opportunityId, String searchTerm, Date dfrom, Date dto
    ) {
        // Step 1 — junction records
        List<Related_Meeting_Transcript__c> junctions = [
            SELECT Id, Meeting_Transcript__c, CreatedDate
            FROM   Related_Meeting_Transcript__c
            WHERE  Opportunity__c = :opportunityId
            AND    Meeting_Transcript__c != null
        ];
        if (junctions.isEmpty()) return new List<CommItem>();

        Map<Id, Related_Meeting_Transcript__c> junctionByTranscript = new Map<Id, Related_Meeting_Transcript__c>();
        for (Related_Meeting_Transcript__c j : junctions) {
            junctionByTranscript.put(j.Meeting_Transcript__c, j);
        }
        Set<Id> transcriptIds = junctionByTranscript.keySet();

        // Step 2 — query Meeting_Transcript__c directly
        List<Meeting_Transcript__c> transcripts = [
            SELECT Id, Transcript__c, Meeting_Date__c,
                   Johnson_Turner_User__r.Name
            FROM   Meeting_Transcript__c
            WHERE  Id IN :transcriptIds
        ];

        List<CommItem> items = new List<CommItem>();
        for (Meeting_Transcript__c mt : transcripts) {
            Related_Meeting_Transcript__c j = junctionByTranscript.get(mt.Id);

            Datetime meetingDate = mt.Meeting_Date__c != null
                ? Datetime.newInstance(mt.Meeting_Date__c, Time.newInstance(0,0,0,0))
                : j.CreatedDate;

            if (dfrom != null && meetingDate != null) {
                if (meetingDate < Datetime.newInstance(dfrom, Time.newInstance(0,0,0,0))) continue;
            }
            if (dto != null && meetingDate != null) {
                if (meetingDate > Datetime.newInstance(dto, Time.newInstance(23,59,59,999))) continue;
            }

            String transcript = mt.Transcript__c;
            String userName   = mt.Johnson_Turner_User__r?.Name;

            if (!String.isBlank(searchTerm)) {
                String term = searchTerm.toLowerCase();
                Boolean match =
                    (!String.isBlank(userName)   && userName.toLowerCase().contains(term)) ||
                    (!String.isBlank(transcript) && transcript.toLowerCase().contains(term));
                if (!match) continue;
            }

            CommItem c       = new CommItem();
            c.commType       = 'MEETING';
            c.recordId       = mt.Id;
            c.junctionId     = j.Id;
            c.fromName       = userName;
            c.subject        = 'Zoom Meeting' + (mt.Meeting_Date__c != null
                                 ? ' — ' + mt.Meeting_Date__c.format() : '');
            c.messageDate    = meetingDate;
            c.isIncoming     = false;
            c.transcriptBody = transcript;
            if (!String.isBlank(transcript)) {
                c.bodyPreview = transcript.length() > 120
                    ? transcript.substring(0, 120) + '…'
                    : transcript;
            }
            items.add(c);
        }
        return items;
    }


    // ── Transcript customer-name extractor ───────────────────────────────────

    /**
     * Parse the transcript text and return the non-JT speaker name.
     *
     * Supports two transcript formats produced in this org:
     *
     * Format 1 — "Name: spoken text"
     *   Amanda Johnson: Hi Deanna, how are you?
     *   Deanna Zimmer: I'm good, thanks.
     *
     * Format 2 — "User: Name\ntext: body"
     *   User: Patricia Jean Pawlitschek
     *   text: Hello there...
     *
     * Strategy:
     *   - Collect unique speaker names from both formats.
     *   - Skip structural keywords (User, text, speaker, Time).
     *   - Exclude the JT attorney name (jtUserName) from candidates.
     *   - Return the first remaining candidate — that is the customer.
     */
    @TestVisible
    private static String extractCustomerName(String transcriptText, String jtUserName) {
        if (String.isBlank(transcriptText)) return null;

        Set<String> keywords = new Set<String>{ 'user', 'text', 'speaker', 'time' };

        List<String> format1Speakers = new List<String>(); // names before ":"
        List<String> format2Values   = new List<String>(); // names after "User:"
        Set<String>  seen            = new Set<String>();

        for (String line : transcriptText.split('\n')) {
            line = line.trim();
            if (String.isBlank(line)) continue;

            Integer colonIdx = line.indexOf(':');
            if (colonIdx <= 0) continue;

            String label = line.substring(0, colonIdx).trim();
            String value = line.substring(colonIdx + 1).trim();
            if (String.isBlank(label)) continue;

            if (label.equalsIgnoreCase('User') && !String.isBlank(value)) {
                // Format 2 — value is the speaker's full name
                if (!seen.contains(value.toLowerCase())) {
                    seen.add(value.toLowerCase());
                    format2Values.add(value);
                }
            } else if (!keywords.contains(label.toLowerCase())) {
                // Format 1 — label is the speaker's name
                if (!seen.contains(label.toLowerCase())) {
                    seen.add(label.toLowerCase());
                    format1Speakers.add(label);
                }
            }
        }

        // Prefer Format 1 speakers; fall back to Format 2 values
        List<String> candidates = !format1Speakers.isEmpty() ? format1Speakers : format2Values;

        if (!String.isBlank(jtUserName)) {
            String jtLower = jtUserName.toLowerCase();
            for (String name : candidates) {
                // Partial match: handles "Amanda J." vs "Amanda Johnson"
                if (!name.toLowerCase().contains(jtLower) && !jtLower.contains(name.toLowerCase())) {
                    return name;
                }
            }
        }

        // If we couldn't exclude the JT user (blank name or all match), return the first candidate
        return candidates.isEmpty() ? null : candidates[0];
    }


    // ── Sort comparator ───────────────────────────────────────────────────────

    private class DateComparator implements Comparator<CommItem> {
        public Integer compare(CommItem a, CommItem b) {
            if (a.messageDate == null && b.messageDate == null) return 0;
            if (a.messageDate == null) return 1;
            if (b.messageDate == null) return -1;
            if (a.messageDate > b.messageDate) return -1;
            if (a.messageDate < b.messageDate) return 1;
            return 0;
        }
    }
}