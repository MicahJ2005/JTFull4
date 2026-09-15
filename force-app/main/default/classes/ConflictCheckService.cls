/**
 * ConflictCheckService
 * --------------------------------------------------------------------------
 * Invocable conflict-of-interest check for the Opportunity intake process.
 *
 * Given an Opportunity, it parses the free-text opposing-party name
 * (Opposing_Party_s_Full_Name__c), searches the ~66k Person Accounts in the
 * org for name matches (SOSL name-field search + an Apex nickname / edit-
 * distance scoring layer so "Jeff"~"Jeffrey" and "Clemons"~"Clemens" surface),
 * flags any matched party that is tied to an ACTIVE Matter (AcctSeed__Project__c),
 * and returns a hyperlinked breakdown for the reviewer.
 *
 * It ALSO runs two checks on the POTENTIAL CLIENT (the Opportunity's own Account,
 * plus Client 2 / Spouse__c):
 *   1) PROSECUTION -- is the client a related person on a prosecution matter? The
 *      firm cannot be hired by someone it is prosecuting.
 *   2) OPPOSING PARTY ELSEWHERE -- is the client named as the opposing party on
 *      another Opportunity of ours? (the "Dan / Sally / Heather" case: Dan lists
 *      Heather as his opposing party, but we once represented Sally against Dan.)
 * The client is identified by lookup, not by name search -- Client_Name__c is a
 * formula over Account.PersonContact, so Opportunity.AccountId *is* the client.
 *
 * ESTATE PLANNING is handled differently, per the firm: those intakes have no
 * opposing party by nature, so the whole opposing-party side is SKIPPED (even on
 * the ~700 of 3,504 that do carry a value) and a blank field no longer holds the
 * check open. They pass unless the client themselves turns up as an opposing
 * party. In exchange they get a third check that only runs for them:
 *   3) OPPOSING PARTY ON OUR MATTERS -- is the client a Related_People__c of class
 *      "Opposing Party" on one of our matters? Active is coloured red, closed
 *      amber. This is the Matters half of the Dan / Sally / Heather case.
 *
 * The reviewer always has the final say on Conflict_Check_Status__c. This class
 * only RECOMMENDS a default:
 *   - nothing found                      -> Pass
 *   - opposing party on an active matter -> Fail
 *   - client on an ACTIVE prosecution    -> Fail
 *   - anything else found                -> Not Done Yet (human must decide)
 *
 * Per the firm, checks (2) and (3) never recommend Fail on their own. For (2) the
 * reason is that it matches free text. For (3) it was a deliberate call -- an
 * active adverse matter reviews rather than fails, because "either way she will
 * have to review" -- so it is red in the findings but Not Done Yet in status.
 *
 * NOTE: there is intentionally no "Match Found - Review" status in this org.
 * The picklist is Not Done Yet / Pass / Fail, so uncertain matches recommend
 * "Not Done Yet" to force a human decision rather than silently passing.
 */
public with sharing class ConflictCheckService {

    // ==== CONFIG (reconciled to JT Full, 2026-07) ====================
    @TestVisible private static final String STATUS_PASS     = 'Pass';
    @TestVisible private static final String STATUS_FAIL     = 'Fail';
    @TestVisible private static final String STATUS_NOT_DONE = 'Not Done Yet';

    // AcctSeed__Project__c (label "Matter") statuses that count as "active"
    @TestVisible private static final Set<String> ACTIVE_MATTER_STATUSES = new Set<String>{
        'Active', 'On hold', 'Conversion',
        'Pending Close', 'Pending Close - Open AR Only', 'Pending Close - Refund Review'
    };

    // Areas of law where the firm does not expect an opposing party at all, so a
    // blank/placeholder Opposing Party's Full Name must NOT hold the check open.
    // Compared case-insensitively against Opportunity.Area_of_Law__c.
    @TestVisible private static final Set<String> NO_OPPOSING_PARTY_AREAS = new Set<String>{
        'estate planning'
    };

    // Placeholders that people type into the opposing-party field instead of a
    // name. Compared against the whole normalized value (norm() strips spaces and
    // punctuation, so "N/A" and "N / A" both arrive as "na"). Without this, "NA"
    // prefix-matches real accounts ("Nancy", "Nathan") at 88% and manufactures
    // conflicts out of nothing.
    @TestVisible private static final Set<String> NAME_PLACEHOLDERS = new Set<String>{
        'na', 'n', 'no', 'none', 'nil', 'tbd', 'tba', 'unknown', 'unk',
        'notavailable', 'notapplicable', 'nonapplicable', 'pending', 'notyetknown'
    };

    // Honorifics / professional titles / generational suffixes to strip from a
    // name before searching and scoring. Compared against WHOLE tokens only
    // (lowercased, punctuation removed) so real names like "Vaughn" (vs "V"),
    // "Ivan" (vs "IV") or "Vera" (vs "V") are never partially matched.
    private static final Set<String> NAME_STOPWORDS = new Set<String>{
        'mr', 'mrs', 'ms', 'miss', 'dr', 'hon', 'esq',
        'jr', 'sr', 'ii', 'iii', 'iv', 'v'
    };

    // Match-score thresholds (0-100)
    private static final Integer SCORE_MIN      = 60;  // below this we discard
    private static final Integer SCORE_STRONG   = 90;
    private static final Integer SCORE_LIKELY   = 75;
    private static final Integer MAX_CANDIDATES = 50;  // per parsed name, per object

    // Common nickname <-> canonical map (both directions handled at compare time)
    private static final Map<String, String> NICKNAMES = new Map<String, String>{
        'jeff'=>'jeffrey','jeffery'=>'jeffrey','geoff'=>'jeffrey',
        'bob'=>'robert','rob'=>'robert','bobby'=>'robert','robbie'=>'robert',
        'bill'=>'william','will'=>'william','billy'=>'william','liam'=>'william',
        'jim'=>'james','jimmy'=>'james','jamie'=>'james',
        'mike'=>'michael','mikey'=>'michael',
        'tom'=>'thomas','tommy'=>'thomas',
        'dave'=>'david','davey'=>'david',
        'dan'=>'daniel','danny'=>'daniel',
        'chris'=>'christopher','topher'=>'christopher',
        'steve'=>'steven','stevie'=>'steven','stephen'=>'steven',
        'joe'=>'joseph','joey'=>'joseph',
        'tony'=>'anthony',
        'ed'=>'edward','eddie'=>'edward','ted'=>'edward',
        'rick'=>'richard','rich'=>'richard','dick'=>'richard','richie'=>'richard',
        'ken'=>'kenneth','kenny'=>'kenneth',
        'ron'=>'ronald','ronnie'=>'ronald',
        'nick'=>'nicholas','nicky'=>'nicholas',
        'matt'=>'matthew',
        'greg'=>'gregory',
        'sam'=>'samuel','sammy'=>'samuel',
        'ben'=>'benjamin','benji'=>'benjamin',
        'andy'=>'andrew','drew'=>'andrew',
        'pat'=>'patrick','paddy'=>'patrick',
        'phil'=>'philip','phillip'=>'philip',
        'vince'=>'vincent',
        'walt'=>'walter',
        'gabe'=>'gabriel',
        'zach'=>'zachary','zack'=>'zachary',
        'josh'=>'joshua',
        'alex'=>'alexander','xander'=>'alexander',
        // female
        'liz'=>'elizabeth','beth'=>'elizabeth','betsy'=>'elizabeth','eliza'=>'elizabeth','lizzie'=>'elizabeth',
        'kate'=>'katherine','katie'=>'katherine','kathy'=>'katherine','cathy'=>'katherine','kat'=>'katherine','catherine'=>'katherine',
        'meg'=>'margaret','maggie'=>'margaret','peggy'=>'margaret',
        'sue'=>'susan','susie'=>'susan',
        'jen'=>'jennifer','jenny'=>'jennifer',
        'becky'=>'rebecca','becca'=>'rebecca',
        'trish'=>'patricia','patty'=>'patricia',
        'deb'=>'deborah','debbie'=>'deborah',
        'cindy'=>'cynthia',
        'chris tina'=>'christina',
        'abby'=>'abigail',
        'val'=>'valerie',
        'vicky'=>'victoria','tori'=>'victoria',
        'nan'=>'nancy',
        'mandy'=>'amanda',
        'sandy'=>'sandra',
        'tina'=>'christina',
        'gina'=>'regina'
    };

    // =================================================================
    //  Invocable entry point
    // =================================================================
    @InvocableMethod(label='Run Conflict Check'
                     description='Searches Person Accounts for the Opportunity\'s opposing-party name and returns matches + a recommended Conflict Check Status.'
                     category='Conflict Check')
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(runOne(req.opportunityId));
        }
        return results;
    }

    // =================================================================
    //  Core
    // =================================================================
    private static Result runOne(Id oppId) {
        Result res = new Result();
        res.matches = new List<MatchRow>();
        res.clientNames = '';
        res.clientProsecution = false;
        res.clientProsecutionActive = false;
        res.clientNamedAsOpposing = false;
        res.clientNamedAsOpposingCount = 0;

        Opportunity opp = loadOpportunity(oppId);
        if (opp == null) {
            res.recommendedStatus = STATUS_NOT_DONE;
            res.matchCount = 0;
            res.summaryHtml = wrap('<p style="color:#c23934;"><b>Opportunity not found.</b></p>');
            res.plainNotes = 'Conflict check could not run: Opportunity not found.';
            res.notesSummary = res.plainNotes;
            return res;
        }

        // ---- CLIENT side -----------------------------------------------------
        // Runs first and unconditionally: neither client check depends on the
        // opposing-party name, so a blank opposing name must NOT suppress them.
        ClientSide cs = new ClientSide();
        // Estate Planning intakes have no opposing party by nature, so for them the
        // whole opposing-party side is skipped and the client-side checks decide the
        // outcome on their own. Every other area of law is untouched by this.
        Boolean isEstatePlanning = expectsNoOpposingParty(opp.Area_of_Law__c);
        res.opposingPartyExpected = !isEstatePlanning;

        cs.parties = buildClientParties(opp);
        checkClientMatterLinks(cs, isEstatePlanning);
        checkClientNamedAsOpposing(cs, oppId);

        res.clientNames                = String.join(cs.names(), ', ');
        res.clientProsecution          = cs.prosAny;
        res.clientProsecutionActive    = cs.prosActive;
        res.clientNamedAsOpposing      = cs.advAny;
        res.clientNamedAsOpposingCount   = cs.advCount;
        res.clientOpposingOnMatter       = cs.advMatterAny;
        res.clientOpposingOnActiveMatter = cs.advMatterActive;

        // ---- OPPOSING side ---------------------------------------------------
        // Only names we can actually act on count. A value like "N/A" parses to a
        // name but yields no searchable token, and "NA" / "Not Available" are
        // searchable but meaningless -- either way zero real searches run, which
        // must NOT be reported as a Pass.
        // For Estate Planning we do not search at all -- per the firm, "we will not
        // have an opposing party so it shouldn't check for those on estate plans."
        // ~700 of the 3,504 estate-planning Opportunities do carry a value, and it
        // is ignored deliberately.
        List<String> parsedNames = new List<String>();
        if (!isEstatePlanning) {
            for (String nm : parseNames(opp.Opposing_Party_s_Full_Name__c)) {
                if (isUsableName(nm)) parsedNames.add(nm);
            }
        }
        Boolean opposingSearchRan = !parsedNames.isEmpty();
        Boolean opposingRequired  = !isEstatePlanning;

        Map<Id, MatchRow> byAccount = new Map<Id, MatchRow>();
        Boolean anyActiveMatter = false;

        if (opposingSearchRan) {
            for (String nm : parsedNames) {
                for (Account acc : searchAccounts(nm)) {
                    Integer score = scoreName(nm, acc.FirstName, acc.LastName, acc.Name);
                    if (score < SCORE_MIN) continue;

                    MatchRow existing = byAccount.get(acc.Id);
                    if (existing != null && existing.score >= score) continue;

                    MatchRow row = new MatchRow();
                    row.party        = nm;
                    row.enteredName  = nm;
                    row.accountId    = acc.Id;
                    row.accountName  = acc.Name;
                    row.matchedName  = acc.Name;
                    row.recordUrl    = recordUrl(acc.Id);
                    row.score        = score;
                    row.verdict      = verdictFor(score);
                    row.reasons      = 'Name similarity ' + score + '% to searched "' + nm + '"';
                    byAccount.put(acc.Id, row);
                }
            }

            // ---- active-matter + open-opportunity enrichment -----------------
            anyActiveMatter = enrichWithMatters(byAccount);
            enrichWithOpenOpps(byAccount, oppId);
        }

        res.matches = byAccount.values();
        res.matchCount = res.matches.size();
        sortByScoreDesc(res.matches);

        // ---- recommendation --------------------------------------------------
        // Fail always wins. A blank opposing name can never Pass -- the opposing
        // search did not run, so there is nothing to clear. Per the firm, the
        // client-named-as-opposing-party check never escalates past Not Done Yet:
        // it matches against free text, so a human confirms every hit.
        // Fail is reserved for the two hard conflicts: the opposing party is a party
        // on an active matter of ours, or we are actively prosecuting the client.
        // Being the opposing party on our active matter is deliberately NOT a Fail
        // (the firm's call -- "either way she will have to review"); it reviews, and
        // is coloured red in the findings so the severity is still obvious.
        if (anyActiveMatter || cs.prosActive) {
            res.recommendedStatus = STATUS_FAIL;
        } else if ((opposingRequired && !opposingSearchRan)
                   || res.matchCount > 0
                   || cs.prosAny
                   || cs.anyAdverse()) {
            res.recommendedStatus = STATUS_NOT_DONE;
        } else {
            res.recommendedStatus = STATUS_PASS;
        }

        // ---- narratives ------------------------------------------------------
        res.summaryHtml   = buildHtml(opp, parsedNames, res, cs, opposingSearchRan, opposingRequired);
        res.plainNotes    = buildPlain(opp, parsedNames, res, cs, opposingSearchRan, opposingRequired);
        res.notesSummary  = buildNotesSummary(parsedNames, res, cs, opposingSearchRan, opposingRequired);
        return res;
    }

    // =================================================================
    //  Data access
    // =================================================================
    private static Opportunity loadOpportunity(Id oppId) {
        if (oppId == null) return null;
        List<Opportunity> opps = [
            SELECT Id, Name, Opposing_Party_s_Full_Name__c, Client_Name__c,
                   Client_2_First_Name__c, Conflict_Check_Status__c, Area_of_Law__c,
                   AccountId, Account.Name, Account.FirstName, Account.LastName,
                   Spouse__c, Spouse__r.Name, Spouse__r.FirstName, Spouse__r.LastName
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    /**
     * SOSL name-field search over Person Accounts. Terms are wildcarded per
     * token so a prefix like "Jeff" reaches "Jeffrey".
     *
     * We run three passes and union the results:
     *   1) full name  – best precision (all tokens must prefix-match)
     *   2) last-name only  – catches first-name nickname/typo variants
     *   3) first-name only – catches LAST-name typo variants
     *
     * Passes 2 and 3 are what keep recall high: a one-letter typo in EITHER
     * name part is still reachable through the other part's prefix search
     * (e.g. searched "Veronica Ezeka" reaches account "Veronica Ezuka" via the
     * first-name pass, since "Ezuka" never prefix-matches "Ezeka"). The Apex
     * scorer then decides whether each candidate is actually similar enough.
     */
    private static List<Account> searchAccounts(String name) {
        Map<Id, Account> found = new Map<Id, Account>();

        String full = buildSearchTerm(name, false);
        if (String.isNotBlank(full)) {
            found.putAll(runAccountSosl(full));
        }

        String last  = lastToken(name);
        String first = firstToken(name);

        if (String.isNotBlank(last) && last.length() >= 3) {
            found.putAll(runAccountSosl(wildcardToken(last)));
        }
        if (String.isNotBlank(first) && first.length() >= 3 && first != last) {
            found.putAll(runAccountSosl(wildcardToken(first)));
        }
        return found.values();
    }

    private static Map<Id, Account> runAccountSosl(String searchTerm) {
        Map<Id, Account> out = new Map<Id, Account>();
        // SOSL cannot bind a WHERE inside RETURNING with a bind var cleanly across
        // versions for IsPersonAccount, so we filter in Apex after the search.
        List<List<SObject>> searchList = [
            FIND :searchTerm IN NAME FIELDS
            RETURNING Account(Id, Name, FirstName, LastName, IsPersonAccount
                              ORDER BY LastName LIMIT :MAX_CANDIDATES)
        ];
        if (!searchList.isEmpty()) {
            for (SObject s : searchList[0]) {
                Account a = (Account) s;
                if (a.IsPersonAccount == true) out.put(a.Id, a);
            }
        }
        return out;
    }

    /**
     * Finds active matters for any matched account (as client or spouse) and
     * annotates the MatchRow verdict/reasons/detailHtml. Returns true if any
     * matched party is on an active matter.
     */
    private static Boolean enrichWithMatters(Map<Id, MatchRow> byAccount) {
        if (byAccount.isEmpty()) return false;
        Set<Id> accIds = byAccount.keySet();

        Map<Id, List<AcctSeed__Project__c>> mattersByAcct = new Map<Id, List<AcctSeed__Project__c>>();
        for (AcctSeed__Project__c m : [
                SELECT Id, Name, AcctSeed__Status__c, Type_of_Case__c,
                       AcctSeed__Account__c, Spouse__c
                FROM AcctSeed__Project__c
                WHERE AcctSeed__Account__c IN :accIds OR Spouse__c IN :accIds
                ORDER BY AcctSeed__Status__c
                LIMIT 2000]) {
            addMatter(mattersByAcct, m.AcctSeed__Account__c, m);
            addMatter(mattersByAcct, m.Spouse__c, m);
        }

        Boolean anyActive = false;
        for (Id accId : byAccount.keySet()) {
            List<AcctSeed__Project__c> matters = mattersByAcct.get(accId);
            if (matters == null || matters.isEmpty()) continue;

            MatchRow row = byAccount.get(accId);
            List<String> plain = new List<String>();
            List<String> html  = new List<String>();
            Boolean rowActive = false;

            for (AcctSeed__Project__c m : matters) {
                Boolean active = ACTIVE_MATTER_STATUSES.contains(m.AcctSeed__Status__c);
                rowActive = rowActive || active;
                Boolean prosecution = isProsecution(m.Type_of_Case__c);
                String tag = (active ? '[ACTIVE]' : '[' + safe(m.AcctSeed__Status__c) + ']')
                             + (prosecution ? ' [PROSECUTION]' : '');
                plain.add('   - Matter ' + safe(m.Name) + ' ' + tag
                          + (String.isNotBlank(m.Type_of_Case__c) ? ' (' + m.Type_of_Case__c + ')' : '')
                          + ' ' + recordUrl(m.Id));
                html.add('<li><a href="' + recordUrl(m.Id) + '" target="_blank">'
                         + esc(safe(m.Name)) + '</a> '
                         + '<span style="color:' + (active ? '#c23934' : '#706e6b') + ';font-weight:bold;">' + esc(tag) + '</span>'
                         + (String.isNotBlank(m.Type_of_Case__c) ? ' <i>' + esc(m.Type_of_Case__c) + '</i>' : '')
                         + '</li>');
            }

            anyActive = anyActive || rowActive;
            row.detailHtml = '<ul style="margin:4px 0 4px 16px;">' + String.join(html, '') + '</ul>';
            row.reasons += '; ' + matters.size() + ' matter(s)' + (rowActive ? ', ACTIVE' : '');
            if (rowActive) row.verdict = 'ACTIVE MATTER – ' + row.verdict;
            row.plainMatters = String.join(plain, '\n');
        }
        return anyActive;
    }

    /**
     * Flags OPEN (not-closed) opportunities where a matched party is the client.
     * Closed-won opportunities are intentionally skipped: they always spawn a
     * Matter, which the active-matter check above already covers. An open
     * opportunity means the party has an in-flight deal with us -> review.
     */
    private static void enrichWithOpenOpps(Map<Id, MatchRow> byAccount, Id currentOppId) {
        if (byAccount.isEmpty()) return;
        Set<Id> accIds = byAccount.keySet();

        Map<Id, List<Opportunity>> oppsByAcct = new Map<Id, List<Opportunity>>();
        for (Opportunity o : [
                SELECT Id, Name, StageName, AccountId
                FROM Opportunity
                WHERE AccountId IN :accIds AND IsClosed = false
                  AND Id != :currentOppId
                ORDER BY CreatedDate DESC
                LIMIT 500]) {
            if (!oppsByAcct.containsKey(o.AccountId)) oppsByAcct.put(o.AccountId, new List<Opportunity>());
            oppsByAcct.get(o.AccountId).add(o);
        }

        for (Id accId : byAccount.keySet()) {
            MatchRow row = byAccount.get(accId);
            List<Opportunity> opps = oppsByAcct.get(accId);
            if (opps == null || opps.isEmpty()) {
                row.openOppsDetailHtml = '<div style="color:#706e6b;font-size:0.9em;">No open opportunities linked to this party.</div>';
                row.plainOpenOpps = '   No open opportunities linked to this party.';
                continue;
            }
            row.hasOpenOpp = true;
            List<String> html = new List<String>();
            List<String> plain = new List<String>();
            for (Opportunity o : opps) {
                html.add('<li><a href="' + recordUrl(o.Id) + '" target="_blank">' + esc(safe(o.Name)) + '</a> '
                         + '<span style="color:#706e6b;">[' + esc(safe(o.StageName)) + ']</span></li>');
                plain.add('   - Open opportunity ' + safe(o.Name) + ' [' + safe(o.StageName) + '] ' + recordUrl(o.Id));
            }
            row.openOppsDetailHtml = '<div><b>Open opportunities:</b><ul style="margin:4px 0 4px 16px;">'
                                     + String.join(html, '') + '</ul></div>';
            row.plainOpenOpps = String.join(plain, '\n');
            row.reasons += '; ' + opps.size() + ' open opp(s)';
        }
    }

    /**
     * PROSECUTION check on the POTENTIAL CLIENT.
     *
     * The firm cannot be hired by someone it is prosecuting, so this question is
     * only ever about the client -- never about the opposing party. The client is
     * the Opportunity's own Account (Client_Name__c is a formula over
     * Account.PersonContact), plus Client 2 (Spouse__c). Both are looked up by Id,
     * so no name search and no fuzzy matching is involved here.
     *
     * A prosecution matter is one whose Name contains "prosecut" (the org has no
     * type field for this; ~12 such matters, e.g. "City of Lakeland- Prosecution").
     * An ACTIVE one is a hard conflict; a closed one still goes to the reviewer,
     * who confirms status with the team before clearing it.
     *
     * On the PROSECUTION bucket, Related_People_Class__c is deliberately NOT
     * filtered: a handful of rows on those matters have a null or
     * non-"Opposing Party" class, and dropping them would hide a real link.
     *
     * -------------------------------------------------------------------------
     * The same query also answers a second question: is the client an OPPOSING
     * PARTY on one of our matters? (the Matters half of the Dan / Sally / Heather
     * case -- the Opportunity half lives in checkClientNamedAsOpposing.) An
     * ACTIVE such matter means we currently act against this person for another
     * client; a closed one is a former-client judgement call.
     *
     * Both buckets come from ONE query so a client who is an opposing party on a
     * prosecution matter is reported once, under prosecution, rather than twice.
     */
    private static void checkClientMatterLinks(ClientSide cs, Boolean includeOpposingRole) {
        if (cs.parties.isEmpty()) return;

        Set<Id> clientAccIds = cs.accountIds();
        // Two query shapes on purpose. Outside Estate Planning the adverse-matter
        // bucket is not wanted, so we keep the original prosecution-only query and
        // non-estate-planning behaviour stays byte-identical.
        List<Related_People__c> rps = includeOpposingRole
            ? [SELECT Id, Person_Account_Name__c, Related_People_Class__c,
                      Matter_Name__c, Matter_Name__r.Name, Matter_Name__r.AcctSeed__Status__c,
                      Matter_Name__r.AcctSeed__Account__r.Name
               FROM Related_People__c
               WHERE Person_Account_Name__c IN :clientAccIds
                 AND (Matter_Name__r.Name LIKE '%rosecut%'
                      OR Related_People_Class__c = 'Opposing Party')
               ORDER BY Matter_Name__r.AcctSeed__Status__c
               LIMIT 500]
            : [SELECT Id, Person_Account_Name__c, Related_People_Class__c,
                      Matter_Name__c, Matter_Name__r.Name, Matter_Name__r.AcctSeed__Status__c,
                      Matter_Name__r.AcctSeed__Account__r.Name
               FROM Related_People__c
               WHERE Person_Account_Name__c IN :clientAccIds
                 AND Matter_Name__r.Name LIKE '%rosecut%'
               ORDER BY Matter_Name__r.AcctSeed__Status__c
               LIMIT 500];
        if (rps.isEmpty()) return;

        List<String> prosHtml  = new List<String>();
        List<String> prosPlain = new List<String>();
        List<String> advHtml   = new List<String>();
        List<String> advPlain  = new List<String>();

        for (Related_People__c rp : rps) {
            String mName = (rp.Matter_Name__r != null) ? safe(rp.Matter_Name__r.Name) : '';
            String mStat = (rp.Matter_Name__r != null) ? safe(rp.Matter_Name__r.AcctSeed__Status__c) : '';
            Boolean act  = ACTIVE_MATTER_STATUSES.contains(mStat);
            String who   = cs.nameFor(rp.Person_Account_Name__c);
            String cls   = safe(rp.Related_People_Class__c);
            String statusTag = act ? 'ACTIVE' : mStat;
            String ourClient = (rp.Matter_Name__r != null && rp.Matter_Name__r.AcctSeed__Account__r != null)
                             ? safe(rp.Matter_Name__r.AcctSeed__Account__r.Name) : '';

            if (mName.toLowerCase().contains('rosecut')) {
                cs.prosAny    = true;
                cs.prosActive = cs.prosActive || act;
                prosHtml.add('<li>' + esc(who) + ' on <a href="' + recordUrl(rp.Matter_Name__c) + '" target="_blank">'
                         + esc(mName) + '</a> '
                         + '<span style="color:' + (act ? '#c23934' : '#706e6b') + ';font-weight:bold;">['
                         + esc(statusTag) + ']</span>'
                         + (String.isNotBlank(cls) ? ' <i>as ' + esc(cls) + '</i>' : '') + '</li>');
                prosPlain.add('   - ' + who + ' on prosecution matter ' + mName
                          + ' [' + statusTag + ']'
                          + (String.isNotBlank(cls) ? ' as ' + cls : '') + ' ' + recordUrl(rp.Matter_Name__c));
            } else if (includeOpposingRole) {
                cs.advMatterAny    = true;
                cs.advMatterActive = cs.advMatterActive || act;
                cs.advMatterCount++;
                advHtml.add('<li>' + esc(who) + ' is the opposing party on <a href="' + recordUrl(rp.Matter_Name__c)
                         + '" target="_blank">' + esc(mName) + '</a> '
                         + '<span style="color:' + (act ? '#c23934' : '#706e6b') + ';font-weight:bold;">['
                         + esc(statusTag) + ']</span>'
                         + (String.isNotBlank(ourClient) ? '<br/><span style="font-size:0.9em;">our client was <b>'
                              + esc(ourClient) + '</b></span>' : '') + '</li>');
                advPlain.add('   - ' + who + ' is the opposing party on matter ' + mName + ' [' + statusTag + ']'
                          + (String.isNotBlank(ourClient) ? '; our client was ' + ourClient : '')
                          + ' ' + recordUrl(rp.Matter_Name__c));
            }
        }

        if (cs.prosAny) {
            String color = cs.prosActive ? '#c23934' : '#dd7a01';
            String lead  = cs.prosActive
                ? 'The firm is CURRENTLY prosecuting this potential client. We cannot be hired by someone we are prosecuting.'
                : 'This potential client is a related person on a closed prosecution matter. Confirm the matter really is closed with the team before clearing.';
            cs.prosHtml = '<div style="background:#fef1ee;border:1px solid ' + color + ';padding:6px 10px;margin:6px 0;">'
                + '<b style="color:' + color + ';">&#9888; PROSECUTION FLAG &ndash; POTENTIAL CLIENT</b>'
                + '<div style="margin-top:2px;">' + esc(lead) + '</div>'
                + '<ul style="margin:4px 0 4px 16px;">' + String.join(prosHtml, '') + '</ul></div>';
            cs.prosPlain = '** PROSECUTION FLAG - POTENTIAL CLIENT: ' + lead + '\n' + String.join(prosPlain, '\n');
        }

        if (cs.advMatterAny) {
            String color = cs.advMatterActive ? '#c23934' : '#dd7a01';
            String lead  = cs.advMatterActive
                ? 'We CURRENTLY act against this potential client on an active matter. Taking them on would put us on both sides.'
                : 'This potential client is the opposing party on a closed matter of ours. Confirm we can act for them now.';
            cs.advMatterHtml = '<div style="background:#fef1ee;border:1px solid ' + color + ';padding:6px 10px;margin:6px 0;">'
                + '<b style="color:' + color + ';">&#9888; CLIENT IS AN OPPOSING PARTY ON OUR MATTER'
                + (cs.advMatterActive ? ' &ndash; ACTIVE' : '') + '</b>'
                + '<div style="margin-top:2px;">' + esc(lead) + '</div>'
                + '<ul style="margin:4px 0 4px 16px;">' + String.join(advHtml, '') + '</ul></div>';
            cs.advMatterPlain = '** CLIENT IS AN OPPOSING PARTY ON OUR MATTER'
                + (cs.advMatterActive ? ' - ACTIVE' : '') + ': ' + lead + '\n' + String.join(advPlain, '\n');
        }
    }

    /**
     * Is the POTENTIAL CLIENT named as the opposing party on some OTHER
     * Opportunity of ours?
     *
     * This is the "Dan / Sally / Heather" case: Dan comes to us listing Heather as
     * his opposing party, but we once represented Sally against Dan. Searching only
     * Heather never surfaces that -- searching DAN does.
     *
     * Matching strategy: SOQL substring on the client's SURNAME against
     * Opposing_Party_s_Full_Name__c, then score in Apex. Surname-then-score (rather
     * than a full-name search) is what makes "Dan" reach "Daniel" and "Bob" reach
     * "Robert" -- the existing nickname map and Levenshtein scorer do that work.
     *
     * Note the scorer arguments are FLIPPED versus the opposing-party search: the
     * free-text opposing name is the "entered" name and the client is the candidate.
     * That is deliberate -- the client has real FirstName/LastName fields, and it lets
     * scoreName's single-token branch handle a bare surname entry like "Kowalski".
     *
     * The client's own Opportunities are excluded. In family law the opposing party
     * very often shares the client's surname (e.g. client "Jodie Darwitz" vs opposing
     * "Eric Darwitz"), so those records match the surname but are not conflicts.
     *
     * Per the firm this NEVER recommends Fail on its own -- it matches free text, so
     * a human confirms every hit.
     */
    private static void checkClientNamedAsOpposing(ClientSide cs, Id currentOppId) {
        if (cs.parties.isEmpty()) return;

        Set<Id> clientAccIds = cs.accountIds();
        Map<Id, OppHit> hits = new Map<Id, OppHit>();

        for (ClientParty party : cs.parties) {
            String surname = String.isNotBlank(party.lastName) ? party.lastName : lastToken(party.name);
            // Keep hyphens and apostrophes -- "Ahlgren-Louden" and "O'Brien" must match
            // as stored -- but strip anything that LIKE would treat as a wildcard.
            surname = (surname == null) ? '' : surname.replaceAll('[^\\p{L}\\-\']', '').trim();
            // Anything shorter is too broad to scan 37k+ opportunities against.
            if (norm(surname).length() < 3) continue;

            String likeTerm = '%' + surname + '%';
            for (Opportunity o : [
                    SELECT Id, Name, StageName, IsClosed, AccountId, Account.Name,
                           Opposing_Party_s_Full_Name__c
                    FROM Opportunity
                    WHERE Opposing_Party_s_Full_Name__c LIKE :likeTerm
                      AND Id != :currentOppId
                      AND (AccountId = null OR AccountId NOT IN :clientAccIds)
                    ORDER BY IsClosed ASC, CreatedDate DESC
                    LIMIT 200]) {

                // The surname matched somewhere in the free text -- now confirm the
                // whole name really refers to this client.
                Integer best = 0;
                String bestName = '';
                for (String opposingName : parseNames(o.Opposing_Party_s_Full_Name__c)) {
                    Integer sc = scoreName(opposingName, party.firstName, party.lastName, party.name);
                    if (sc > best) { best = sc; bestName = opposingName; }
                }
                if (best < SCORE_MIN) continue;

                OppHit existing = hits.get(o.Id);
                if (existing != null && existing.score >= best) continue;

                OppHit hit      = new OppHit();
                hit.oppId       = o.Id;
                hit.oppName     = safe(o.Name);
                hit.stage       = safe(o.StageName);
                hit.isOpen      = (o.IsClosed == false);
                hit.ourClient   = (o.Account != null) ? safe(o.Account.Name) : '';
                hit.opposingRaw = safe(o.Opposing_Party_s_Full_Name__c);
                hit.matchedName = bestName;
                hit.clientName  = party.name;
                hit.score       = best;
                hits.put(o.Id, hit);
            }
        }

        if (hits.isEmpty()) return;

        cs.advAny   = true;
        cs.advCount = hits.size();
        List<String> html  = new List<String>();
        List<String> plain = new List<String>();

        for (OppHit h : hits.values()) {
            cs.advOpen = cs.advOpen || h.isOpen;
            String stageTag = h.isOpen ? 'OPEN – ' + h.stage : h.stage;
            html.add('<li><a href="' + recordUrl(h.oppId) + '" target="_blank">' + esc(h.oppName) + '</a> '
                     + '<span style="color:' + (h.isOpen ? '#c23934' : '#706e6b') + ';font-weight:bold;">['
                     + esc(stageTag) + ']</span>'
                     + '<br/><span style="font-size:0.9em;">opposing party recorded as "' + esc(h.opposingRaw) + '" '
                     + '(' + h.score + '% to ' + esc(h.clientName) + ')'
                     + (String.isNotBlank(h.ourClient) ? '; our client was <b>' + esc(h.ourClient) + '</b>' : '')
                     + '</span></li>');
            plain.add('   - ' + h.oppName + ' [' + stageTag + '] opposing party "' + h.opposingRaw + '" '
                      + '(' + h.score + '% to ' + h.clientName + ')'
                      + (String.isNotBlank(h.ourClient) ? '; our client was ' + h.ourClient : '')
                      + ' ' + recordUrl(h.oppId));
        }

        String lead = 'This potential client appears to be the OPPOSING PARTY on '
            + cs.advCount + ' other opportunit' + (cs.advCount == 1 ? 'y' : 'ies') + ' of ours'
            + (cs.advOpen ? ', including at least one that is still OPEN' : ' (all closed)')
            + '. Confirm whether we can act for them against a different opposing party.';

        cs.advHtml = '<div style="background:#fff7e6;border:1px solid #dd7a01;padding:6px 10px;margin:6px 0;">'
            + '<b style="color:#dd7a01;">&#9888; CLIENT IS AN OPPOSING PARTY ELSEWHERE</b>'
            + '<div style="margin-top:2px;">' + esc(lead) + '</div>'
            + '<ul style="margin:4px 0 4px 16px;">' + String.join(html, '') + '</ul></div>';
        cs.advPlain = '** CLIENT IS AN OPPOSING PARTY ELSEWHERE: ' + lead + '\n' + String.join(plain, '\n');
    }

    /** The people who would become clients on this Opportunity: Account + Client 2. */
    private static List<ClientParty> buildClientParties(Opportunity opp) {
        List<ClientParty> parties = new List<ClientParty>();
        if (opp.AccountId != null) {
            ClientParty p = new ClientParty();
            p.accId     = opp.AccountId;
            p.name      = (opp.Account != null && String.isNotBlank(opp.Account.Name))
                              ? opp.Account.Name : safe(opp.Client_Name__c);
            p.firstName = (opp.Account != null) ? opp.Account.FirstName : null;
            p.lastName  = (opp.Account != null) ? opp.Account.LastName  : null;
            parties.add(p);
        }
        if (opp.Spouse__c != null) {
            ClientParty p = new ClientParty();
            p.accId     = opp.Spouse__c;
            p.name      = (opp.Spouse__r != null && String.isNotBlank(opp.Spouse__r.Name))
                              ? opp.Spouse__r.Name : safe(opp.Client_2_First_Name__c);
            p.firstName = (opp.Spouse__r != null) ? opp.Spouse__r.FirstName : null;
            p.lastName  = (opp.Spouse__r != null) ? opp.Spouse__r.LastName  : null;
            parties.add(p);
        }
        return parties;
    }

    // =================================================================
    //  Client-side DTOs
    // =================================================================
    private class ClientParty {
        public Id accId;
        public String name;
        public String firstName;
        public String lastName;
    }

    private class OppHit {
        public Id oppId;
        public String oppName;
        public String stage;
        public Boolean isOpen;
        public String ourClient;
        public String opposingRaw;
        public String matchedName;
        public String clientName;
        public Integer score;
    }

    /** Everything the client-side checks found, plus the parties they ran against. */
    private class ClientSide {
        public List<ClientParty> parties = new List<ClientParty>();
        // prosecution: the firm cannot be hired by someone it is prosecuting
        public Boolean prosAny    = false;
        public Boolean prosActive = false;
        public String prosHtml    = '';
        public String prosPlain   = '';
        // named as the opposing party on another Opportunity of ours
        public Boolean advAny   = false;
        public Boolean advOpen  = false;
        public Integer advCount = 0;
        public String advHtml   = '';
        public String advPlain  = '';
        // the opposing party on one of our MATTERS (Related_People__c)
        public Boolean advMatterAny    = false;
        public Boolean advMatterActive = false;
        public Integer advMatterCount  = 0;
        public String advMatterHtml    = '';
        public String advMatterPlain   = '';

        public Set<Id> accountIds() {
            Set<Id> ids = new Set<Id>();
            for (ClientParty p : parties) ids.add(p.accId);
            return ids;
        }
        public List<String> names() {
            List<String> out = new List<String>();
            for (ClientParty p : parties) {
                if (String.isNotBlank(p.name)) out.add(p.name);
            }
            return out;
        }
        public String nameFor(Id accId) {
            for (ClientParty p : parties) {
                if (p.accId == accId) return safe(p.name);
            }
            return '';
        }
        public Boolean anyFinding()  { return prosAny || advAny || advMatterAny; }
        /** Any client-side link that says we are, or were, against this person. */
        public Boolean anyAdverse()  { return advAny || advMatterAny; }
    }

    private static void addMatter(Map<Id, List<AcctSeed__Project__c>> byAcct, Id accId, AcctSeed__Project__c m) {
        if (accId == null) return;
        if (!byAcct.containsKey(accId)) byAcct.put(accId, new List<AcctSeed__Project__c>());
        byAcct.get(accId).add(m);
    }

    // =================================================================
    //  Name parsing / scoring
    // =================================================================
    @TestVisible
    private static List<String> parseNames(String raw) {
        List<String> names = new List<String>();
        if (String.isBlank(raw)) return names;

        String s = raw.trim();
        // normalize connectors that separate distinct parties into a pipe
        s = s.replaceAll('(?i)\\s+(and|&|vs\\.?|v\\.?|versus|a/?k/?a|aka)\\s+', '|');
        s = s.replaceAll('[;/]', '|');

        Set<String> seen = new Set<String>();
        for (String part : s.split('\\|')) {
            String cleaned = cleanName(part);
            if (String.isBlank(cleaned)) continue;
            String key = cleaned.toLowerCase();
            if (seen.contains(key)) continue;
            seen.add(key);
            names.add(cleaned);
        }
        return names;
    }

    private static String cleanName(String part) {
        if (part == null) return null;
        // Periods (e.g. "Dr.", "Jr.") become spaces so titles/suffixes tokenize.
        String p = part.replace('.', ' ').trim();

        // Titles/suffixes are stripped BEFORE the "Last, First" reorder, so a
        // trailing suffix on the second half (e.g. "Jane Doe, Esq.") empties it
        // and no reorder happens, while a real "Last, First" still flips.
        String result;
        Integer comma = p.indexOf(',');
        if (comma >= 0) {
            String firstHalf  = stripStopTokens(p.substring(0, comma));
            String secondHalf = stripStopTokens(p.substring(comma + 1));
            if (String.isNotBlank(firstHalf) && String.isNotBlank(secondHalf)) {
                result = secondHalf + ' ' + firstHalf;         // Last, First -> First Last
            } else {
                result = String.isNotBlank(firstHalf) ? firstHalf : secondHalf;
            }
        } else {
            result = stripStopTokens(p);
        }

        // Keep only letters, spaces, hyphens, apostrophes; collapse and trim.
        return result.replaceAll('[^\\p{L}\\-\'\\s]', ' ').replaceAll('\\s+', ' ').trim();
    }

    /** Drops whole-token honorifics/titles/suffixes; keeps every other token verbatim. */
    private static String stripStopTokens(String s) {
        if (String.isBlank(s)) return '';
        List<String> keep = new List<String>();
        for (String t : s.trim().split('\\s+')) {
            String bare = t.replaceAll('[^\\p{L}]', '').toLowerCase();
            if (bare == '') continue;                 // punctuation-only token
            if (NAME_STOPWORDS.contains(bare)) continue;
            keep.add(t);
        }
        return String.join(keep, ' ');
    }

    /** All tokens of a name as prefix wildcards, space-joined (SOSL ANDs them). */
    private static String buildSearchTerm(String name, Boolean lastOnly) {
        String base = lastOnly ? lastToken(name) : name;
        if (String.isBlank(base)) return null;
        List<String> tokens = new List<String>();
        for (String t : base.split('\\s+')) {
            String clean = t.replaceAll('[^\\p{L}]', '');
            if (clean.length() >= 2) tokens.add(clean + '*');
        }
        return tokens.isEmpty() ? null : String.join(tokens, ' ');
    }

    /**
     * True if this name has at least one token we can actually search on, using the
     * same >= 2 letter rule as buildSearchTerm. Guards against unsearchable junk
     * ("N/A", "TBD", initials) being reported as a clean Pass.
     */
    @TestVisible
    private static Boolean isSearchable(String name) {
        if (String.isBlank(name)) return false;
        for (String t : name.trim().split('\\s+')) {
            if (t.replaceAll('[^\\p{L}]', '').length() >= 2) return true;
        }
        return false;
    }

    /**
     * A name we can act on: searchable AND not one of the placeholders people type
     * in place of a name. "N/A" is unsearchable anyway, but "NA" and "Not Available"
     * are not -- and "NA" prefix-matches Nancy/Nathan at 88%.
     */
    @TestVisible
    private static Boolean isUsableName(String name) {
        if (!isSearchable(name)) return false;
        return !NAME_PLACEHOLDERS.contains(norm(name));
    }

    /** True when this area of law is not expected to have an opposing party at all. */
    @TestVisible
    private static Boolean expectsNoOpposingParty(String areaOfLaw) {
        if (String.isBlank(areaOfLaw)) return false;
        return NO_OPPOSING_PARTY_AREAS.contains(areaOfLaw.trim().toLowerCase());
    }

    /** A single token as a prefix wildcard (e.g. "Veronica" -> "Veronica*"). */
    private static String wildcardToken(String token) {
        if (String.isBlank(token)) return null;
        String clean = token.replaceAll('[^\\p{L}]', '');
        return clean.length() >= 2 ? clean + '*' : null;
    }

    private static String lastToken(String name) {
        if (String.isBlank(name)) return null;
        List<String> t = name.trim().split('\\s+');
        return t[t.size() - 1];
    }

    private static String firstToken(String name) {
        if (String.isBlank(name)) return null;
        return name.trim().split('\\s+')[0];
    }

    /**
     * Score 0-100 comparing an entered name to a candidate account.
     * Weighted 60% last name, 40% first name, nickname-aware.
     */
    @TestVisible
    private static Integer scoreName(String entered, String accFirst, String accLast, String accFull) {
        String eFirst = norm(firstToken(entered));
        String eLast  = norm(lastToken(entered));

        String aFirst = norm(accFirst);
        String aLast  = norm(accLast);
        // Person accounts always have first/last, but guard for business names
        if (String.isBlank(aFirst) && String.isBlank(aLast)) {
            return ratio(norm(entered), norm(accFull));
        }

        Integer lastScore  = tokenScore(eLast, aLast);
        Integer firstScore = tokenScore(eFirst, aFirst);

        // Single-token entered name (e.g. just a surname): all we can judge is
        // that one token, so score on the best-matching name part.
        if (String.isBlank(eFirst) || eFirst == eLast) {
            return Math.max(tokenScore(eLast, aLast), tokenScore(eLast, aFirst));
        }

        // Full name entered: BOTH first AND last must be similar. Multiplicative
        // scoring means a shared surname alone (first name mismatch) collapses
        // toward zero, while true matches and nickname/typo variants stay high.
        return (Integer) Math.round(((Decimal) lastScore * firstScore) / 100);
    }

    private static Integer tokenScore(String a, String b) {
        if (String.isBlank(a) || String.isBlank(b)) return 0;
        if (a == b) return 100;
        if (canonical(a) == canonical(b)) return 95;           // nickname equivalence
        if (a.startsWith(b) || b.startsWith(a)) return 88;      // prefix (Jeff/Jeffrey)
        return ratio(a, b);
    }

    private static String canonical(String t) {
        if (String.isBlank(t)) return t;
        return NICKNAMES.containsKey(t) ? NICKNAMES.get(t) : t;
    }

    private static String verdictFor(Integer score) {
        if (score >= SCORE_STRONG) return 'Strong match';
        if (score >= SCORE_LIKELY) return 'Likely match';
        return 'Possible match';
    }

    private static Boolean isProsecution(String typeOfCase) {
        if (String.isBlank(typeOfCase)) return false;
        String t = typeOfCase.toLowerCase();
        return t.contains('prosecut') || t.contains('opposing');
    }

    // =================================================================
    //  Similarity helpers (Levenshtein ratio, normalized 0-100)
    // =================================================================
    private static Integer ratio(String a, String b) {
        if (String.isBlank(a) || String.isBlank(b)) return 0;
        Integer dist = levenshtein(a, b);
        Integer maxLen = Math.max(a.length(), b.length());
        if (maxLen == 0) return 100;
        return (Integer) Math.round((1 - ((Decimal) dist / maxLen)) * 100);
    }

    private static Integer levenshtein(String a, String b) {
        Integer n = a.length();
        Integer m = b.length();
        if (n == 0) return m;
        if (m == 0) return n;
        Integer[] prev = new Integer[m + 1];
        Integer[] curr = new Integer[m + 1];
        for (Integer j = 0; j <= m; j++) prev[j] = j;
        for (Integer i = 1; i <= n; i++) {
            curr[0] = i;
            for (Integer j = 1; j <= m; j++) {
                Integer cost = (a.substring(i - 1, i) == b.substring(j - 1, j)) ? 0 : 1;
                curr[j] = Math.min(Math.min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
            }
            Integer[] tmp = prev; prev = curr; curr = tmp;
        }
        return prev[m];
    }

    private static String norm(String s) {
        if (s == null) return null;
        return s.toLowerCase().replaceAll('[^\\p{L}]', '').trim();
    }

    // =================================================================
    //  Narrative builders
    // =================================================================
    private static String buildHtml(Opportunity opp, List<String> parsed, Result res,
                                   ClientSide cs, Boolean opposingSearchRan,
                                   Boolean opposingRequired) {
        String color; String headline;
        if (res.recommendedStatus == STATUS_PASS) {
            color = '#2e844a'; headline = 'No conflicts found – recommended: PASS';
        } else if (res.recommendedStatus == STATUS_FAIL) {
            color = '#c23934';
            headline = cs.prosActive
                ? 'We are prosecuting this potential client – recommended: FAIL'
                : 'Active-matter conflict found – recommended: FAIL';
        } else {
            color = '#dd7a01';
            // Don't say "0 potential match(es)" when the finding is on the client
            // side or no opposing search ran -- it reads as a contradiction.
            headline = res.matchCount > 0
                ? res.matchCount + ' potential match(es) – review required'
                : 'Review required';
        }
        if (cs.prosAny) {
            color = '#c23934';
            headline = '⚠ PROSECUTION FLAG – ' + headline;
        } else if (cs.advMatterActive) {
            color = '#c23934';
            headline = '⚠ WE CURRENTLY ACT AGAINST THIS CLIENT – ' + headline;
        } else if (cs.anyAdverse()) {
            color = '#dd7a01';
            headline = '⚠ CLIENT IS AN OPPOSING PARTY ELSEWHERE – ' + headline;
        }

        String h = '<p style="font-size:1.1em;"><b style="color:' + color + ';">' + esc(headline) + '</b></p>';
        h += '<p><b>Client:</b> ' + esc(safe(opp.Client_Name__c)) + '<br/>'
           + '<b>Area of law:</b> ' + esc(safe(opp.Area_of_Law__c)) + '<br/>'
           + '<b>Searched opposing party name(s):</b> '
           + (opposingSearchRan ? esc(String.join(parsed, ', '))
                : (opposingRequired ? '<i>none entered</i>' : '<i>not applicable for this area of law</i>')) + '</p>';

        // ---- potential client -------------------------------------------------
        h += '<h3 style="margin:10px 0 2px;font-size:1em;">Potential client</h3>';
        if (cs.parties.isEmpty()) {
            h += '<div style="color:#706e6b;font-size:0.9em;">No client Person Account is linked to this Opportunity, so the client could not be checked.</div>';
        } else {
            h += '<div style="color:#706e6b;font-size:0.9em;">Checked: '
               + esc(String.join(cs.names(), ', ')) + '</div>';
            if (cs.prosAny) {
                h += cs.prosHtml;
            } else {
                h += '<div style="color:#706e6b;font-size:0.9em;">Not a related person on any prosecution matter.</div>';
            }
            if (cs.advAny) {
                h += cs.advHtml;
            } else {
                h += '<div style="color:#706e6b;font-size:0.9em;">Not named as the opposing party on any other opportunity.</div>';
            }
            if (!opposingRequired) {
                if (cs.advMatterAny) {
                    h += cs.advMatterHtml;
                } else {
                    h += '<div style="color:#706e6b;font-size:0.9em;">Not the opposing party on any matter of ours.</div>';
                }
            }
        }

        // ---- opposing party ---------------------------------------------------
        h += '<h3 style="margin:10px 0 2px;font-size:1em;">Opposing party</h3>';
        if (!opposingRequired) {
            h += '<div style="color:#706e6b;font-size:0.9em;">'
               + esc(safe(opp.Area_of_Law__c)) + ' intakes do not have an opposing party, so no opposing-party search was run. '
               + 'This does not hold the check open &ndash; the potential-client checks above decide the outcome.</div>';
            return wrap(h);
        }
        if (!opposingSearchRan) {
            h += '<p><b style="color:#dd7a01;">The opposing-party search could not be completed.</b></p>'
               + '<p>No usable opposing-party name was entered on this Opportunity &ndash; the "Opposing Party\'s Full Name" field is blank, or holds a placeholder rather than a name (e.g. "N/A", "NA", a title on its own, or bare initials). No search was run, so <b>this is not a clean result</b>. Enter the opposing party\'s name and run the check again.</p>';
            return wrap(h);
        }
        if (res.matchCount == 0) {
            h += '<p>No Person Account in the system matched the opposing party name.</p>';
            return wrap(h);
        }

        h += '<p><b>' + res.matchCount + '</b> potential match(es):</p>';
        for (MatchRow row : res.matches) {
            String vColor = row.verdict.startsWith('ACTIVE') ? '#c23934'
                          : (row.score >= SCORE_STRONG ? '#dd7a01' : '#706e6b');
            h += '<div style="border-left:3px solid ' + vColor + ';padding:4px 8px;margin:6px 0;">';
            h += '<b><a href="' + row.recordUrl + '" target="_blank">' + esc(row.accountName) + '</a></b> '
               + '<span style="color:' + vColor + ';">(' + esc(row.verdict) + ', ' + row.score + '%)</span>';
            h += '<br/><span style="color:#706e6b;font-size:0.9em;">matched to searched "' + esc(row.enteredName) + '"</span>';
            if (String.isNotBlank(row.detailHtml)) {
                h += '<div><b>Matters:</b>' + row.detailHtml + '</div>';
            } else {
                h += '<div style="color:#706e6b;font-size:0.9em;">No matters linked to this party.</div>';
            }
            if (String.isNotBlank(row.openOppsDetailHtml)) {
                h += row.openOppsDetailHtml;
            }
            h += '</div>';
        }
        return wrap(h);
    }

    private static String buildPlain(Opportunity opp, List<String> parsed, Result res,
                                    ClientSide cs, Boolean opposingSearchRan,
                                    Boolean opposingRequired) {
        List<String> lines = new List<String>();
        lines.add('CONFLICT CHECK – recommended: ' + res.recommendedStatus);
        lines.add('Client: ' + safe(opp.Client_Name__c));
        lines.add('Searched opposing party name(s): '
                  + (opposingSearchRan ? String.join(parsed, ', ') : '(none entered)'));
        lines.add('');
        lines.add('POTENTIAL CLIENT:');
        if (cs.parties.isEmpty()) {
            lines.add('   No client Person Account is linked to this Opportunity, so the client could not be checked.');
        } else {
            lines.add('   Checked: ' + String.join(cs.names(), ', '));
            lines.add(cs.prosAny ? cs.prosPlain : '   Not a related person on any prosecution matter.');
            lines.add(cs.advAny  ? cs.advPlain  : '   Not named as the opposing party on any other opportunity.');
            if (!opposingRequired) {
                lines.add(cs.advMatterAny ? cs.advMatterPlain
                                          : '   Not the opposing party on any matter of ours.');
            }
        }
        lines.add('');
        lines.add('OPPOSING PARTY:');
        if (!opposingRequired) {
            lines.add('   ' + safe(opp.Area_of_Law__c) + ' intakes do not have an opposing party, so no search was run. This does not hold the check open.');
            return String.join(lines, '\n');
        }
        if (!opposingSearchRan) {
            lines.add('   The opposing-party search could not be completed: no usable opposing-party name was entered (blank, or a placeholder such as "N/A"). No search was run - this is NOT a clean result.');
            return String.join(lines, '\n');
        }
        if (res.matchCount == 0) {
            lines.add('   No Person Account matched the opposing party name.');
            return String.join(lines, '\n');
        }
        lines.add(res.matchCount + ' potential match(es):');
        for (MatchRow row : res.matches) {
            lines.add('- ' + row.accountName + ' (' + row.verdict + ', ' + row.score + '%) '
                      + row.recordUrl);
            lines.add('   matched to searched "' + row.enteredName + '"');
            if (String.isNotBlank(row.plainMatters)) lines.add(row.plainMatters);
            if (String.isNotBlank(row.plainOpenOpps)) lines.add(row.plainOpenOpps);
        }
        return String.join(lines, '\n');
    }

    /** Concise determination note capped at 255 chars for Conflict_Determination_Notes__c. */
    private static String buildNotesSummary(List<String> parsed, Result res,
                                           ClientSide cs, Boolean opposingSearchRan,
                                           Boolean opposingRequired) {
        String s = 'Conflict check (' + res.recommendedStatus + '): ';
        // Client-side findings lead -- prosecution is the hard conflict.
        if (cs.prosAny) {
            s += (cs.prosActive ? '[ACTIVE PROSECUTION - CLIENT]' : '[PROSECUTION - CLIENT, closed]') + ' ';
        }
        if (cs.advMatterAny) {
            s += '[CLIENT IS OPPOSING PARTY ON ' + cs.advMatterCount + ' MATTER(S)'
               + (cs.advMatterActive ? ', 1+ ACTIVE' : ', all closed') + '] ';
        }
        if (cs.advAny) {
            s += '[CLIENT IS OPPOSING PARTY ON ' + cs.advCount + ' OTHER OPP(S)'
               + (cs.advOpen ? ', 1+ OPEN' : '') + '] ';
        }
        if (!opposingRequired) {
            s += 'no opposing-party search - not applicable for this area of law.';
        } else if (!opposingSearchRan) {
            s += 'opposing-party search not run – no usable opposing-party name entered.';
        } else if (res.matchCount == 0) {
            s += 'no opposing-party match for "' + String.join(parsed, ', ') + '".';
        } else {
            MatchRow top = res.matches[0];
            s += res.matchCount + ' opposing match(es); top: ' + top.accountName + ' ' + top.score + '%'
               + (top.verdict.startsWith('ACTIVE') ? ' [ACTIVE MATTER]' : '')
               + '. See conflict-check screen for full detail + links.';
        }
        return s.length() > 255 ? s.substring(0, 255) : s;
    }

    private static String wrap(String bodyHtml) {
        return '<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.4;">' + bodyHtml + '</div>';
    }

    // =================================================================
    //  Small utils
    // =================================================================
    private static String recordUrl(Id recId) {
        if (recId == null) return '';
        String base;
        try {
            base = URL.getOrgDomainUrl().toExternalForm();
        } catch (Exception e) {
            base = '';
        }
        return (String.isBlank(base) ? '' : base) + '/' + recId;
    }

    private static String safe(String s) { return s == null ? '' : s; }

    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;');
    }

    private static void sortByScoreDesc(List<MatchRow> rows) {
        // simple insertion sort (small N) descending by score
        for (Integer i = 1; i < rows.size(); i++) {
            MatchRow key = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].score < key.score) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = key;
        }
    }

    // =================================================================
    //  Invocable DTOs
    // =================================================================
    public class Request {
        @InvocableVariable(label='Opportunity Id' required=true)
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable(label='Recommended Status')
        public String recommendedStatus;
        @InvocableVariable(label='Summary (rich text/HTML)')
        public String summaryHtml;
        @InvocableVariable(label='Plain Notes')
        public String plainNotes;
        @InvocableVariable(label='Notes Summary (<=255 chars, for the notes field)')
        public String notesSummary;
        @InvocableVariable(label='Match Count')
        public Integer matchCount;
        @InvocableVariable(label='Matches')
        public List<MatchRow> matches;
        @InvocableVariable(label='Client Name(s) Checked')
        public String clientNames;
        @InvocableVariable(label='Client on a Prosecution Matter')
        public Boolean clientProsecution;
        @InvocableVariable(label='Client on an ACTIVE Prosecution Matter')
        public Boolean clientProsecutionActive;
        @InvocableVariable(label='Client Named as Opposing Party Elsewhere')
        public Boolean clientNamedAsOpposing;
        @InvocableVariable(label='Other Opportunities Naming the Client as Opposing Party')
        public Integer clientNamedAsOpposingCount;
        @InvocableVariable(label='Client is Opposing Party on One of Our Matters')
        public Boolean clientOpposingOnMatter;
        @InvocableVariable(label='Client is Opposing Party on an ACTIVE Matter')
        public Boolean clientOpposingOnActiveMatter;
        @InvocableVariable(label='An Opposing Party is Expected for this Area of Law')
        public Boolean opposingPartyExpected;
    }

    public class MatchRow {
        @InvocableVariable public String party;
        @InvocableVariable public String accountName;
        @InvocableVariable public String accountId;
        @InvocableVariable public String recordUrl;
        @InvocableVariable public String enteredName;
        @InvocableVariable public String matchedName;
        @InvocableVariable public Integer score;
        @InvocableVariable public String verdict;
        @InvocableVariable public String reasons;
        @InvocableVariable public String detailHtml;
        @InvocableVariable public String plainMatters;
        @InvocableVariable public Boolean hasOpenOpp;
        @InvocableVariable public String openOppsDetailHtml;
        @InvocableVariable public String plainOpenOpps;
    }
}