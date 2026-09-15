/**
 * Powers the "Unrelated Calls" LWC feed: surfaces Related_Call_Transcript__c
 * junction rows owned by the running user that are not yet tied to a Matter,
 * and lets the user relate one to a Matter (backfilling Account/Opportunity
 * from the Matter's parent record).
 */
public with sharing class UnrelatedCallFeedController {

    private static final Integer PAGE_SIZE = 50;

    // Safety cap on how many raw junction rows we'll pull into Apex to build
    // one page of collapsed call groups (see buildUnrelatedCallGroups) — a
    // single busy attorney can have 10k+ rows in a wide date window, and we
    // never want an unbounded query. Keeps the transaction well under the
    // synchronous heap limit; a user hitting this cap should narrow their
    // date filter.
    private static final Integer CANDIDATE_ROW_CAP = 2000;

    @AuraEnabled(cacheable=true)
    public static List<UnrelatedCallDTO> getUnrelatedCalls(Integer daysBack, Integer pageOffset, Date customSinceDate, Id viewAsUserId, Boolean viewDismissed) {
        Datetime sinceDate = resolveSinceDate(daysBack, customSinceDate);
        Id currentUserId = resolveScopeUserId(viewAsUserId);
        Integer offset = (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;
        Boolean dismissedOnly = (viewDismissed == true);

        List<CallGroup> groups = buildUnrelatedCallGroups(currentUserId, sinceDate, dismissedOnly);

        List<UnrelatedCallDTO> dtos = new List<UnrelatedCallDTO>();
        if (offset >= groups.size()) {
            return dtos;
        }
        Integer endExclusive = Math.min(groups.size(), offset + PAGE_SIZE);
        List<CallGroup> page = new List<CallGroup>();
        for (Integer i = offset; i < endExclusive; i++) {
            page.add(groups[i]);
        }

        // Collect the "other party" phone number for each group's
        // representative row (the caller on an inbound call, the recipient
        // on an outbound call) so we can batch-resolve them to a
        // Contact/Lead name in as few queries as possible.
        Map<Id, String> otherPartyPhoneByRctId = new Map<Id, String>();
        Set<String> normalizedNumbers = new Set<String>();

        for (CallGroup g : page) {
            String otherPartyPhone = resolveOtherPartyPhone(g.representativeRow);
            if (String.isNotBlank(otherPartyPhone)) {
                otherPartyPhoneByRctId.put(g.representativeRow.Id, otherPartyPhone);
                String normalized = normalizePhone(otherPartyPhone);
                if (String.isNotBlank(normalized)) {
                    normalizedNumbers.add(normalized);
                }
            }
        }

        Map<String, PhoneMatch> matchByNormalizedPhone = resolveMatchesByPhone(normalizedNumbers);

        for (CallGroup g : page) {
            String otherPartyPhone = otherPartyPhoneByRctId.get(g.representativeRow.Id);
            String normalized = String.isNotBlank(otherPartyPhone)
                ? normalizePhone(otherPartyPhone)
                : null;
            PhoneMatch match = (normalized != null) ? matchByNormalizedPhone.get(normalized) : null;

            UnrelatedCallDTO dto = new UnrelatedCallDTO(g.representativeRow, otherPartyPhone, match);
            dto.relatedRowCount = g.memberRowIds.size();
            if (!g.otherLabels.isEmpty()) {
                dto.otherRelationLabel = g.otherLabels.size() == 1
                    ? g.otherLabels[0]
                    : g.otherLabels[0] + ' (+' + (g.otherLabels.size() - 1) + ' more)';
            }
            dtos.add(dto);
        }
        return dtos;
    }

    /**
     * Total count of the current user's fully-unrelated CALLS (after
     * collapsing duplicate junction rows per Call_Transcript__c and
     * excluding any call that already has a Matter on ANY of its rows) —
     * used to render "Page X of Y" and to disable the Next arrow.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getUnrelatedCallsCount(Integer daysBack, Date customSinceDate, Id viewAsUserId, Boolean viewDismissed) {
        Datetime sinceDate = resolveSinceDate(daysBack, customSinceDate);
        Id currentUserId = resolveScopeUserId(viewAsUserId);
        Boolean dismissedOnly = (viewDismissed == true);
        return buildUnrelatedCallGroups(currentUserId, sinceDate, dismissedOnly).size();
    }

    /**
     * A single physical call (Call_Transcript__c) commonly has MULTIPLE
     * Related_Call_Transcript__c junction rows pointing at it — one per
     * Opportunity/Matter/Account/Lead the caller happens to touch, since a
     * junction row can't reference more than one of those at a time
     * (confirmed with the business owner 2026-09-07). Two rules that follow:
     *   1. Collapse all rows sharing a Call_Transcript__c into ONE feed
     *      entry — otherwise the same call shows up once per sibling row.
     *   2. If ANY sibling row already has Matter__c populated, the call is
     *      already handled (an SF flow relates it to the caller's other
     *      Opportunities/Matters once one link lands) — exclude the WHOLE
     *      call, not just that one row, even though the other sibling rows
     *      individually still show Matter__c = null. Without this, a call
     *      that's genuinely resolved keeps reappearing via its unresolved
     *      siblings.
     * Rows with no Call_Transcript__c at all can't be deduplicated (there's
     * no shared key) and are each their own singleton group.
     */
    private static List<CallGroup> buildUnrelatedCallGroups(Id currentUserId, Datetime sinceDate, Boolean dismissedOnly) {
        List<Related_Call_Transcript__c> candidateRows = queryCandidateRows(currentUserId, sinceDate, dismissedOnly);
        Set<Id> callTranscriptIdsWithAMatter = findCallTranscriptIdsWithAMatter(candidateRows);
        return groupRows(candidateRows, callTranscriptIdsWithAMatter);
    }

    /**
     * Runs the same scoped/windowed junction-row query buildUnrelatedCallGroups
     * uses, split out so getFeedStats can reuse it without duplicating the
     * SOQL (and so any future change to the scoping predicate only needs to
     * happen in one place).
     */
    private static List<Related_Call_Transcript__c> queryCandidateRows(Id currentUserId, Datetime sinceDate, Boolean dismissedOnly) {
        // "Who does this call belong to?" is NOT reliably OwnerId on the
        // junction row — verified live (2026-09-07): the vast majority of
        // Related_Call_Transcript__c rows are owned by a sync/integration
        // user ("Demandchain Admin"), not the attorney who actually took the
        // call. The real call-taker is Call_Transcript__r.Voice_Call__r.UserId
        // (confirmed to match VoiceCall.OwnerId, i.e. reliable). Scope
        // PRIMARILY on that; fall back to the junction row's own OwnerId only
        // for rows where the Voice Call doesn't resolve at all (older/
        // orphaned rows a user directly owns should still surface, not
        // silently disappear).
        String query =
            'SELECT Id, Name, CreatedDate, Matter__c, ' +
            'Dismissed__c, Dismissed_Date__c, Dismissed_By__c, Dismissed_By__r.Name, ' +
            'Call_Transcript__c, Call_Transcript__r.Name, ' +
            'Call_Transcript__r.Voice_Call__c, ' +
            'Call_Transcript__r.Voice_Call__r.Id, ' +
            'Call_Transcript__r.Voice_Call__r.UserId, ' +
            'Call_Transcript__r.Voice_Call__r.CallType, ' +
            'Call_Transcript__r.Voice_Call__r.CallStartDateTime, ' +
            'Call_Transcript__r.Voice_Call__r.CallDurationInSeconds, ' +
            'Call_Transcript__r.Voice_Call__r.FromPhoneNumber, ' +
            'Call_Transcript__r.Voice_Call__r.ToPhoneNumber, ' +
            'Account__c, Account__r.Name, ' +
            'Opportunity__c, Opportunity__r.Name, ' +
            'Lead__c, Lead__r.Name ' +
            'FROM Related_Call_Transcript__c ' +
            'WHERE (Call_Transcript__r.Voice_Call__r.UserId = :currentUserId ' +
            'OR (Call_Transcript__r.Voice_Call__c = null AND OwnerId = :currentUserId)) ' +
            'AND Matter__c = NULL ' +
            (dismissedOnly ? 'AND Dismissed__c = true ' : 'AND Dismissed__c = false ') +
            (sinceDate != null ? 'AND CreatedDate >= :sinceDate ' : '') +
            'ORDER BY CreatedDate DESC LIMIT :CANDIDATE_ROW_CAP';

        return Database.query(query);
    }

    /**
     * Regardless of scope/date window, if ANY junction row anywhere for one
     * of these call transcripts already has a Matter, the whole call is
     * excluded — this check is intentionally NOT limited to the current
     * user's scoped/windowed rows above.
     */
    private static Set<Id> findCallTranscriptIdsWithAMatter(List<Related_Call_Transcript__c> candidateRows) {
        Set<Id> callTranscriptIds = new Set<Id>();
        for (Related_Call_Transcript__c r : candidateRows) {
            if (r.Call_Transcript__c != null) {
                callTranscriptIds.add(r.Call_Transcript__c);
            }
        }

        Set<Id> callTranscriptIdsWithAMatter = new Set<Id>();
        if (!callTranscriptIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Call_Transcript__c cid
                FROM Related_Call_Transcript__c
                WHERE Call_Transcript__c IN :callTranscriptIds AND Matter__c != null
                GROUP BY Call_Transcript__c
            ]) {
                callTranscriptIdsWithAMatter.add((Id) ar.get('cid'));
            }
        }
        return callTranscriptIdsWithAMatter;
    }

    /**
     * Stats for the feed header: how many distinct calls are in the current
     * scope/window BEFORE the "already linked via another Matter-bearing
     * sibling row" exclusion, vs. how many are genuinely still unrelated.
     * Built to explain a surprising-looking small "unrelated" count — e.g. a
     * busy attorney's 128 recent calls collapsing to only 3 truly unrelated
     * ones, once the other 125 are recognized as already handled via a
     * sibling row's Matter (confirmed live 2026-09-07, Eric Parker: 128
     * distinct calls, 125 already linked, 3 genuinely unrelated).
     */
    @AuraEnabled(cacheable=true)
    public static FeedStatsDTO getFeedStats(Integer daysBack, Date customSinceDate, Id viewAsUserId, Boolean viewDismissed) {
        Datetime sinceDate = resolveSinceDate(daysBack, customSinceDate);
        Id currentUserId = resolveScopeUserId(viewAsUserId);
        Boolean dismissedOnly = (viewDismissed == true);

        List<Related_Call_Transcript__c> candidateRows = queryCandidateRows(currentUserId, sinceDate, dismissedOnly);
        Set<Id> callTranscriptIdsWithAMatter = findCallTranscriptIdsWithAMatter(candidateRows);

        // Same de-duplication key groupRows uses (Call_Transcript__c, or the
        // row's own Id when there's no Call_Transcript__c to key on) — but
        // counted WITHOUT the exclusion, so we get the true "how many
        // distinct calls did we even look at" denominator.
        Set<Id> allDistinctKeys = new Set<Id>();
        for (Related_Call_Transcript__c r : candidateRows) {
            allDistinctKeys.add((r.Call_Transcript__c != null) ? r.Call_Transcript__c : r.Id);
        }

        Integer unrelatedCount = groupRows(candidateRows, callTranscriptIdsWithAMatter).size();

        FeedStatsDTO stats = new FeedStatsDTO();
        stats.totalDistinctCalls = allDistinctKeys.size();
        stats.unrelatedCount = unrelatedCount;
        stats.alreadyLinkedCount = stats.totalDistinctCalls - unrelatedCount;
        return stats;
    }

    /**
     * Pure grouping/exclusion logic, split out from buildUnrelatedCallGroups
     * so it's unit-testable without a real Call_Transcript__c/VoiceCall (both
     * awkward to insert in a test context — see the class-level test file's
     * JSON.deserialize fixture pattern). Takes the already-queried candidate
     * rows plus the precomputed set of Call_Transcript__c Ids that already
     * have a Matter somewhere among their sibling rows.
     */
    @TestVisible
    private static List<CallGroup> groupRows(
        List<Related_Call_Transcript__c> candidateRows,
        Set<Id> callTranscriptIdsWithAMatter
    ) {
        Map<Id, CallGroup> groupsByKey = new Map<Id, CallGroup>();
        List<CallGroup> orderedGroups = new List<CallGroup>();

        for (Related_Call_Transcript__c r : candidateRows) {
            if (r.Call_Transcript__c != null && callTranscriptIdsWithAMatter.contains(r.Call_Transcript__c)) {
                continue;
            }
            // Rows with no Call_Transcript__c have no shared key to collapse
            // on — each is its own group, keyed by its own Id.
            Id groupKey = (r.Call_Transcript__c != null) ? r.Call_Transcript__c : r.Id;

            CallGroup callGroup = groupsByKey.get(groupKey);
            if (callGroup == null) {
                callGroup = new CallGroup();
                callGroup.representativeRow = r; // rows arrive CreatedDate DESC, so the first one seen is the most recent
                groupsByKey.put(groupKey, callGroup);
                orderedGroups.add(callGroup);
            }
            callGroup.memberRowIds.add(r.Id);

            String label = null;
            if (r.Account__r != null) {
                label = 'Account: ' + r.Account__r.Name;
            } else if (r.Opportunity__r != null) {
                label = 'Opportunity: ' + r.Opportunity__r.Name;
            } else if (r.Lead__r != null) {
                label = 'Lead: ' + r.Lead__r.Name;
            }
            if (label != null && !callGroup.otherLabels.contains(label)) {
                callGroup.otherLabels.add(label);
            }
        }

        return orderedGroups;
    }

    /**
     * Resolves which user's calls to scope the feed to. Normally the running
     * user themselves. A System Administrator MAY pass viewAsUserId to preview
     * another user's feed (e.g. QA'ing the feature against a real attorney's
     * data without needing their login) — but this is checked SERVER-SIDE
     * against the running user's actual profile, not merely hidden behind a
     * UI control, so a non-admin passing an arbitrary Id here can't see
     * anyone else's calls. Falls back to the running user whenever the
     * override isn't both present AND authorized.
     */
    @TestVisible
    private static Id resolveScopeUserId(Id viewAsUserId) {
        Id currentUserId = UserInfo.getUserId();
        if (viewAsUserId == null) {
            return currentUserId;
        }
        Boolean isAdmin = [
            SELECT Profile.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ].Profile.Name == 'System Administrator';
        return isAdmin ? viewAsUserId : currentUserId;
    }

    /**
     * Resolves the effective "since" cutoff for the feed's date filter.
     * A custom date, if given, takes priority — it's an explicit choice via
     * the LWC's "Custom" picklist option and always wins over daysBack.
     * Otherwise: null daysBack = caller didn't specify anything -> default to
     * 30 days; <= 0 (explicitly passed, e.g. the LWC's "All time" option) ->
     * no date bound at all. These are two different meanings of "no value"
     * and must NOT be collapsed into one, or "All time" silently behaves like
     * the 30-day default (a bug already hit live once).
     */
    @TestVisible
    private static Datetime resolveSinceDate(Integer daysBack, Date customSinceDate) {
        if (customSinceDate != null) {
            return Datetime.newInstance(customSinceDate, Time.newInstance(0, 0, 0, 0));
        }
        Integer days = (daysBack == null) ? 30 : daysBack;
        return (days > 0) ? Datetime.now().addDays(-days) : null;
    }

    /**
     * The "other party" is whoever ISN'T the firm on the call: the caller on
     * an inbound call (FromPhoneNumber), the recipient on an outbound call
     * (ToPhoneNumber). Falls back to FromPhoneNumber when CallType is
     * missing/unrecognized rather than showing nothing.
     */
    @TestVisible
    private static String resolveOtherPartyPhone(Related_Call_Transcript__c r) {
        if (r.Call_Transcript__r == null || r.Call_Transcript__r.Voice_Call__r == null) {
            return null;
        }
        VoiceCall vc = r.Call_Transcript__r.Voice_Call__r;
        if (vc.CallType == 'Outbound') {
            return vc.ToPhoneNumber;
        }
        return vc.FromPhoneNumber;
    }

    @TestVisible
    private static String normalizePhone(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String digits = raw.replaceAll('[^0-9]', '');
        // Compare on the last 10 digits so a stored "+1XXXXXXXXXX" still
        // matches a Contact's plain "XXXXXXXXXX" (and vice versa).
        if (digits.length() > 10) {
            digits = digits.substring(digits.length() - 10);
        }
        return digits.length() == 10 ? digits : null;
    }

    @TestVisible
    private static Map<String, PhoneMatch> resolveMatchesByPhone(Set<String> normalizedNumbers) {
        Map<String, PhoneMatch> result = new Map<String, PhoneMatch>();
        if (normalizedNumbers.isEmpty()) {
            return result;
        }

        // Scope the query to ONLY the numbers actually on screen (bounded by
        // the feed's row limit, so at most ~50) — never scan the full
        // Contact/Lead tables (70k+/19k+ rows at JT), which would blow the
        // synchronous heap limit and be slow regardless. LIKE match on the
        // last 4 digits only: stored phone values keep their original
        // punctuation (e.g. "(612) 555-3333"), and a 4-digit block is the one
        // segment guaranteed not to have a space/dash inside it in any common
        // US format — a longer digit-only window (e.g. 7 digits) would span
        // the dash before the last 4 digits and silently never match. The
        // wider net here is intentionally loose; indexIfMatch below does the
        // real exact-normalized-number comparison so false positives from a
        // shared last-4 never leak through.
        List<String> likePatterns = new List<String>();
        for (String normalized : normalizedNumbers) {
            String suffix = normalized.length() >= 4
                ? normalized.substring(normalized.length() - 4)
                : normalized;
            likePatterns.add('%' + suffix);
        }

        for (Contact c : queryContactsByPhonePatterns(likePatterns)) {
            indexIfMatch(result, c.Phone, c.Id, c.Name, true, normalizedNumbers);
            indexIfMatch(result, c.MobilePhone, c.Id, c.Name, true, normalizedNumbers);
            indexIfMatch(result, c.OtherPhone, c.Id, c.Name, true, normalizedNumbers);
        }

        for (Lead l : queryLeadsByPhonePatterns(likePatterns)) {
            indexIfMatch(result, l.Phone, l.Id, l.Name, false, normalizedNumbers);
            indexIfMatch(result, l.MobilePhone, l.Id, l.Name, false, normalizedNumbers);
        }

        return result;
    }

    private static List<Contact> queryContactsByPhonePatterns(List<String> likePatterns) {
        List<String> whereClauses = new List<String>();
        for (String pattern : likePatterns) {
            // Patterns are built exclusively from digits (see normalizePhone,
            // which strips everything but 0-9) plus a leading '%' wildcard we
            // add ourselves — never raw user input, so inlining as a literal
            // here is safe from SOQL injection.
            String safePattern = pattern.replaceAll('[^0-9%]', '');
            whereClauses.add(
                '(Phone LIKE \'' + safePattern + '\' OR MobilePhone LIKE \'' + safePattern +
                '\' OR OtherPhone LIKE \'' + safePattern + '\')'
            );
        }
        String query =
            'SELECT Name, Phone, MobilePhone, OtherPhone FROM Contact ' +
            'WHERE IsDeleted = false AND (' + String.join(whereClauses, ' OR ') + ')';
        return (List<Contact>) Database.query(query);
    }

    private static List<Lead> queryLeadsByPhonePatterns(List<String> likePatterns) {
        List<String> whereClauses = new List<String>();
        for (String pattern : likePatterns) {
            String safePattern = pattern.replaceAll('[^0-9%]', '');
            whereClauses.add(
                '(Phone LIKE \'' + safePattern + '\' OR MobilePhone LIKE \'' + safePattern + '\')'
            );
        }
        String query =
            'SELECT Name, Phone, MobilePhone FROM Lead ' +
            'WHERE IsDeleted = false AND IsConverted = false AND (' +
            String.join(whereClauses, ' OR ') + ')';
        return (List<Lead>) Database.query(query);
    }

    private static void indexIfMatch(
        Map<String, PhoneMatch> result,
        String candidatePhone,
        Id recordId,
        String name,
        Boolean isContact,
        Set<String> normalizedNumbers
    ) {
        String normalized = normalizePhone(candidatePhone);
        if (normalized != null && normalizedNumbers.contains(normalized) && !result.containsKey(normalized)) {
            result.put(normalized, new PhoneMatch(recordId, name, isContact));
        }
    }

    /**
     * Whether the running user can use the admin-only "View as" override.
     * The LWC calls this once to decide whether to render the control at all
     * — the real enforcement lives in resolveScopeUserId above regardless of
     * what the client shows.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isViewAsEligible() {
        return [
            SELECT Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ].Profile.Name == 'System Administrator';
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupResult> searchUsers(String searchTerm) {
        List<LookupResult> results = new List<LookupResult>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return results;
        }
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        for (User u : [
            SELECT Id, Name
            FROM User
            WHERE Name LIKE :term AND IsActive = true
            ORDER BY Name
            LIMIT 20
        ]) {
            results.add(new LookupResult(u.Id, u.Name));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupResult> searchMatters(String searchTerm) {
        List<LookupResult> results = new List<LookupResult>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return results;
        }
        // Matter Names at JT are generic case-type labels (e.g. "Marital
        // Dissolution w/children", "Post Decree") — they do NOT contain the
        // client's name, so a search on Name alone misses every real
        // client-name search a user actually types (confirmed live
        // 2026-09-07: searching "Jurkovich" found nothing even though
        // Rebecca Jurkovich has 2 real open matters). Also match the
        // Matter's parent Account (client) name, and show it in the result
        // label so multiple same-named matters for different clients are
        // still distinguishable.
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        for (AcctSeed__Project__c m : [
            SELECT Id, Name, AcctSeed__Account__r.Name
            FROM AcctSeed__Project__c
            WHERE Name LIKE :term OR AcctSeed__Account__r.Name LIKE :term
            ORDER BY AcctSeed__Account__r.Name, Name
            LIMIT 20
        ]) {
            String label = (m.AcctSeed__Account__r != null)
                ? m.AcctSeed__Account__r.Name + ' — ' + m.Name
                : m.Name;
            results.add(new LookupResult(m.Id, label));
        }
        return results;
    }

    @AuraEnabled
    public static void relateCallToMatter(Id relatedCallTranscriptId, Id matterId) {
        if (relatedCallTranscriptId == null || matterId == null) {
            throw new AuraHandledException('Both a call and a matter are required.');
        }

        AcctSeed__Project__c matter = [
            SELECT Id, AcctSeed__Account__c, AcctSeed__Opportunity__c
            FROM AcctSeed__Project__c
            WHERE Id = :matterId
            LIMIT 1
        ];

        Related_Call_Transcript__c rct = [
            SELECT Id, Matter__c, Account__c, Opportunity__c, Call_Transcript__c
            FROM Related_Call_Transcript__c
            WHERE Id = :relatedCallTranscriptId
            LIMIT 1
        ];

        // The feed collapses multiple Related_Call_Transcript__c rows that
        // share one Call_Transcript__c (one physical call, several
        // Opportunity/Account/Lead-specific junction rows — see
        // buildUnrelatedCallGroups) into a single entry. Relating that entry
        // must update EVERY still-unrelated sibling row, not just the one Id
        // the UI happened to pass — otherwise the other siblings would keep
        // reappearing in the feed even though the user just resolved this
        // exact call.
        List<Related_Call_Transcript__c> rowsToUpdate = new List<Related_Call_Transcript__c>{ rct };
        if (rct.Call_Transcript__c != null) {
            for (Related_Call_Transcript__c sibling : [
                SELECT Id, Matter__c, Account__c, Opportunity__c
                FROM Related_Call_Transcript__c
                WHERE Call_Transcript__c = :rct.Call_Transcript__c
                  AND Id != :rct.Id
                  AND Matter__c = null
            ]) {
                rowsToUpdate.add(sibling);
            }
        }

        for (Related_Call_Transcript__c row : rowsToUpdate) {
            row.Matter__c = matter.Id;
            if (matter.AcctSeed__Account__c != null) {
                row.Account__c = matter.AcctSeed__Account__c;
            }
            if (matter.AcctSeed__Opportunity__c != null) {
                row.Opportunity__c = matter.AcctSeed__Opportunity__c;
            }
        }

        update rowsToUpdate;
    }

    /**
     * Dismisses a call from the "My Unrelated Calls" feed WITHOUT relating
     * it to a Matter — for calls that genuinely don't need a Matter
     * relationship (e.g. a wrong number, an internal/staff call, a call
     * already handled some other way). Mirrors relateCallToMatter's
     * sibling-row behavior: a physical call can be represented by several
     * Related_Call_Transcript__c rows (one per Opportunity/Account/Lead it
     * touches — see buildUnrelatedCallGroups), so dismissing one dismisses
     * ALL of that call's still-unrelated, not-yet-dismissed sibling rows too
     * — otherwise the other siblings would keep reappearing in the feed.
     */
    @AuraEnabled
    public static void dismissCall(Id relatedCallTranscriptId) {
        if (relatedCallTranscriptId == null) {
            throw new AuraHandledException('A call is required.');
        }
        setDismissedOnCallAndSiblings(relatedCallTranscriptId, true);
    }

    /**
     * Reverses a dismissal, restoring the call (and its still-Matter-less
     * sibling rows) to the normal "My Unrelated Calls" feed.
     */
    @AuraEnabled
    public static void undismissCall(Id relatedCallTranscriptId) {
        if (relatedCallTranscriptId == null) {
            throw new AuraHandledException('A call is required.');
        }
        setDismissedOnCallAndSiblings(relatedCallTranscriptId, false);
    }

    private static void setDismissedOnCallAndSiblings(Id relatedCallTranscriptId, Boolean dismissed) {
        Related_Call_Transcript__c rct = [
            SELECT Id, Call_Transcript__c, Dismissed__c
            FROM Related_Call_Transcript__c
            WHERE Id = :relatedCallTranscriptId
            LIMIT 1
        ];

        List<Related_Call_Transcript__c> rowsToUpdate = new List<Related_Call_Transcript__c>{ rct };
        if (rct.Call_Transcript__c != null) {
            Boolean siblingCurrentDismissedState = !dismissed;
            for (Related_Call_Transcript__c sibling : [
                SELECT Id, Dismissed__c
                FROM Related_Call_Transcript__c
                WHERE Call_Transcript__c = :rct.Call_Transcript__c
                  AND Id != :rct.Id
                  AND Matter__c = null
                  AND Dismissed__c = :siblingCurrentDismissedState
            ]) {
                rowsToUpdate.add(sibling);
            }
        }

        Id currentUserId = UserInfo.getUserId();
        Datetime nowStamp = dismissed ? Datetime.now() : null;
        Id dismissedByStamp = dismissed ? currentUserId : null;

        for (Related_Call_Transcript__c row : rowsToUpdate) {
            row.Dismissed__c = dismissed;
            row.Dismissed_Date__c = nowStamp;
            row.Dismissed_By__c = dismissedByStamp;
        }

        update rowsToUpdate;
    }

    /**
     * Suggests Matters likely related to the caller matched on a
     * Related_Call_Transcript__c row, so the "Relate to Matter" picker can
     * pre-populate instead of the user typing a search from scratch.
     *
     * Resolution chain (mirrors how a client's calls are already linked to
     * their matters elsewhere in the org):
     *   Contact -> (if a client) their Person Account -> Related_People__c
     *     rows where Person_Account_Name__c = that Account -> Matter_Name__c
     *   Contact -> (if a business/professional contact) Related_Professionals__c
     *     rows where Business_Contact__c = that Contact -> Matter_Name__c
     * Both sources are queried and the results de-duplicated by Matter Id,
     * since the same Contact can appear as a client on one matter and a
     * professional (e.g. opposing counsel) on another.
     */
    @AuraEnabled(cacheable=true)
    public static List<LookupResult> getSuggestedMatters(Id contactId) {
        List<LookupResult> results = new List<LookupResult>();
        if (contactId == null) {
            return results;
        }

        Contact c = [
            SELECT Id, AccountId, Account.IsPersonAccount
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        Map<Id, String> matterNameById = new Map<Id, String>();

        if (c.Account != null && c.Account.IsPersonAccount) {
            for (Related_People__c rp : [
                SELECT Matter_Name__c, Matter_Name__r.Name
                FROM Related_People__c
                WHERE Person_Account_Name__c = :c.AccountId
                  AND Matter_Name__c != null
                LIMIT 50
            ]) {
                matterNameById.put(rp.Matter_Name__c, rp.Matter_Name__r.Name);
            }
        }

        for (Related_Professionals__c rpr : [
            SELECT Matter_Name__c, Matter_Name__r.Name
            FROM Related_Professionals__c
            WHERE Business_Contact__c = :contactId
              AND Matter_Name__c != null
            LIMIT 50
        ]) {
            matterNameById.put(rpr.Matter_Name__c, rpr.Matter_Name__r.Name);
        }

        for (Id matterId : matterNameById.keySet()) {
            results.add(new LookupResult(matterId, matterNameById.get(matterId)));
        }
        return results;
    }

    /**
     * A collapsed group of Related_Call_Transcript__c rows that all share
     * the same Call_Transcript__c (i.e. the same physical call) — see
     * buildUnrelatedCallGroups for why this collapsing exists.
     */
    @TestVisible
    private class CallGroup {
        public Related_Call_Transcript__c representativeRow;
        public Set<Id> memberRowIds = new Set<Id>();
        public List<String> otherLabels = new List<String>();
    }

    public class LookupResult {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        public LookupResult(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }

    public class FeedStatsDTO {
        @AuraEnabled public Integer totalDistinctCalls;
        @AuraEnabled public Integer unrelatedCount;
        @AuraEnabled public Integer alreadyLinkedCount;
    }

    public class PhoneMatch {
        public Id recordId;
        public String name;
        public Boolean isContact;
        public PhoneMatch(Id recordId, String name, Boolean isContact) {
            this.recordId = recordId;
            this.name = name;
            this.isContact = isContact;
        }
    }

    public class UnrelatedCallDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String callTranscriptId;
        @AuraEnabled public String callTranscriptName;
        @AuraEnabled public String voiceCallId;
        @AuraEnabled public Datetime callStartDateTime;
        @AuraEnabled public Integer callDurationInSeconds;
        @AuraEnabled public String otherPartyPhone;
        @AuraEnabled public String otherPartyName;
        @AuraEnabled public String otherRelationLabel;
        @AuraEnabled public Id matchedContactId;
        // How many Related_Call_Transcript__c rows this feed entry
        // represents (collapsed by shared Call_Transcript__c). Relating this
        // entry to a Matter updates ALL of them, not just the representative
        // row — see relateCallToMatter.
        @AuraEnabled public Integer relatedRowCount;
        @AuraEnabled public Boolean isDismissed;
        @AuraEnabled public Datetime dismissedDate;
        @AuraEnabled public String dismissedByName;

        public UnrelatedCallDTO(Related_Call_Transcript__c r, String otherPartyPhone, PhoneMatch match) {
            this.id = r.Id;
            this.callTranscriptId = r.Call_Transcript__c;
            this.callTranscriptName = (r.Call_Transcript__r != null)
                ? r.Call_Transcript__r.Name
                : r.Name;

            VoiceCall vc = (r.Call_Transcript__r != null) ? r.Call_Transcript__r.Voice_Call__r : null;
            this.voiceCallId = (vc != null) ? vc.Id : null;
            this.callStartDateTime = (vc != null) ? vc.CallStartDateTime : null;
            this.callDurationInSeconds = (vc != null) ? vc.CallDurationInSeconds : null;

            this.otherPartyPhone = otherPartyPhone;
            this.otherPartyName = (match != null) ? match.name : null;
            // Suggested-matter lookup only makes sense for a matched Contact
            // (a Lead has no Matter yet) — leave null for a Lead match.
            this.matchedContactId = (match != null && match.isContact) ? match.recordId : null;

            this.isDismissed = r.Dismissed__c;
            this.dismissedDate = r.Dismissed_Date__c;
            this.dismissedByName = (r.Dismissed_By__r != null) ? r.Dismissed_By__r.Name : null;

            if (r.Account__r != null) {
                this.otherRelationLabel = 'Account: ' + r.Account__r.Name;
            } else if (r.Opportunity__r != null) {
                this.otherRelationLabel = 'Opportunity: ' + r.Opportunity__r.Name;
            } else if (r.Lead__r != null) {
                this.otherRelationLabel = 'Lead: ' + r.Lead__r.Name;
            }
        }
    }
}