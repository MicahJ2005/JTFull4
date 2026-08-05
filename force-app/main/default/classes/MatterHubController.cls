/**
 * Read-only service for the "My Matter" client portal page (Experience Cloud).
 * Uses REAL fields on AcctSeed__Project__c (the Matter):
 *   - Questionnaire links (multiple typed link fields; shows the highest-priority one)
 *   - Box documents (Box_Matter_Folder_ID__c + Box_Client_Upload_Link__c)
 *   - Contact (Contact__c direct lookup, with Opportunity->Account fallback)
 *   - Upcoming Appointments (derived from the matter's court Date/Time fields)
 *   - Current Tasks (standard Task via Matter__c lookup; client-visible filter)
 *
 * Pairs with the existing TeamHubController (My Legal Team).
 * @Date June 2026
 */
public without sharing class MatterHubController {

    // ---------------------------------------------------------------------
    // OVERVIEW
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static MatterOverview getMatterOverview(Id recordId) {
        MatterOverview ov = new MatterOverview();
        if (recordId == null) return ov;

        try {
            AcctSeed__Project__c m = [
                SELECT Id, Name,
                       Contact__c,
                       AcctSeed__Opportunity__r.AccountId,
                       Billing_Attorney_LU__c,
                       // Phase (placeholder fields - see README; Chris may own the picklist)
                       Matter_Phase__c, Current_Phase_Title__c, Current_Phase_Description__c,
                       // Box documents
                       Box_Matter_Folder_ID__c, Box_Client_Upload_Link__c,
                       // Questionnaire link fields (priority order below)
                       Client_Questionnaire_Link__c,
                       Assets_Debts_Questionnaire_link__c,
                       OFPHRO_Questionnaire_Link__c,
                       SENE_Prep_Questionnaire_Link__c,
                       Fairwell_2nd_Interview_link__c,
                       Expense_Worksheet_Link__c
                FROM AcctSeed__Project__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            ov.matterName          = m.Name;
            ov.hasBillingAttorney  = m.Billing_Attorney_LU__c != null;

            // ---- Contact (direct lookup first, then Opp->Account) ----
            ov.contactId = resolveContactId(m);

            // ---- Phase ----
            ov.phaseValue              = m.Matter_Phase__c;
            ov.phaseIndex              = mapPhaseIndex(m.Matter_Phase__c);
            ov.currentPhaseTitle       = m.Current_Phase_Title__c;
            ov.currentPhaseDescription = m.Current_Phase_Description__c;

            // ---- Box documents ----
            if (String.isNotBlank(m.Box_Matter_Folder_ID__c)) {
                ov.boxFolderEmbedUrl = 'https://app.box.com/embed/folder/'
                    + m.Box_Matter_Folder_ID__c.trim();
            }
            ov.boxUploadUrl = m.Box_Client_Upload_Link__c;

            // ---- Questionnaire: first non-blank by priority, "one at a time" ----
            populateQuestionnaire(ov, m);

        } catch (Exception e) {
            System.debug('getMatterOverview error: ' + e.getMessage());
        }
        return ov;
    }

    private static Id resolveContactId(AcctSeed__Project__c m) {
        if (m.Contact__c != null) return m.Contact__c;
        if (m.AcctSeed__Opportunity__r != null && m.AcctSeed__Opportunity__r.AccountId != null) {
            List<Contact> cs = [
                SELECT Id FROM Contact
                WHERE AccountId = :m.AcctSeed__Opportunity__r.AccountId LIMIT 1
            ];
            if (!cs.isEmpty()) return cs[0].Id;
        }
        return null;
    }

    private static void populateQuestionnaire(MatterOverview ov, AcctSeed__Project__c m) {
        // Priority order; first one with a value wins.
        List<List<String>> options = new List<List<String>>{
            new List<String>{ 'Client Questionnaire',        m.Client_Questionnaire_Link__c },
            new List<String>{ 'Assets & Debts Questionnaire', m.Assets_Debts_Questionnaire_link__c },
            new List<String>{ 'OFP/HRO Questionnaire',        m.OFPHRO_Questionnaire_Link__c },
            new List<String>{ 'SENE Prep Questionnaire',      m.SENE_Prep_Questionnaire_Link__c },
            new List<String>{ 'Farewell 2nd Interview',       m.Fairwell_2nd_Interview_link__c },
            new List<String>{ 'Expense Worksheet',            m.Expense_Worksheet_Link__c }
        };
        for (List<String> opt : options) {
            if (String.isNotBlank(opt[1])) {
                ov.questionnaireLabel = opt[0];
                ov.questionnaireUrl   = opt[1].trim();
                return;
            }
        }
    }

    /** Maps the Matter_Phase__c picklist value to a 1-4 stepper index. */
    @TestVisible
    private static Integer mapPhaseIndex(String phase) {
        if (String.isBlank(phase)) return 1;
        String p = phase.toLowerCase();
        if (p.contains('4')) return 4;
        if (p.contains('3')) return 3;
        if (p.contains('2')) return 2;
        return 1;
    }

    // ---------------------------------------------------------------------
    // UPCOMING APPOINTMENTS  (derived from the matter's court Date/Time fields)
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<AppointmentItem> getUpcomingAppointments(Id recordId, Integer maxEvents) {
        List<AppointmentItem> items = new List<AppointmentItem>();
        if (recordId == null) return items;
        Integer lim = (maxEvents == null || maxEvents <= 0) ? 3 : maxEvents;

        try {
            AcctSeed__Project__c m = [
                SELECT ICMC_Date_and_Time__c, Mediation__c, Motion_Hearing__c,
                       Pre_Trial__c, Trial__c, FENE__c, SENE__c,
                       Default_Hearing__c, Review_Hearing_Date_and_Time__c
                FROM AcctSeed__Project__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            List<AppointmentItem> all = new List<AppointmentItem>();
            addAppt(all, 'ICMC',           m.ICMC_Date_and_Time__c);
            addAppt(all, 'Mediation',      m.Mediation__c);
            addAppt(all, 'Motion Hearing', m.Motion_Hearing__c);
            addAppt(all, 'Pre-Trial',      m.Pre_Trial__c);
            addAppt(all, 'Trial',          m.Trial__c);
            addAppt(all, 'FENE',           m.FENE__c);
            addAppt(all, 'SENE',           m.SENE__c);
            addAppt(all, 'Default Hearing',m.Default_Hearing__c);
            addAppt(all, 'Review Hearing', m.Review_Hearing_Date_and_Time__c);

            all.sort(); // by StartDateTime asc (see compareTo)
            for (AppointmentItem a : all) {
                if (items.size() >= lim) break;
                items.add(a);
            }
        } catch (Exception e) {
            System.debug('getUpcomingAppointments error: ' + e.getMessage());
        }
        return items;
    }

    private static void addAppt(List<AppointmentItem> appts, String label, Datetime dt) {
        if (dt != null && dt >= System.now()) {
            appts.add(new AppointmentItem(label, dt));
        }
    }

    // ---------------------------------------------------------------------
    // TASK PROGRESS  (overall % from the Matter's task rollups)
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static TaskProgress getTaskProgress(Id recordId) {
        TaskProgress tp = new TaskProgress();
        if (recordId == null) return tp;
        try {
            AcctSeed__Project__c m = [
                SELECT Total_Task__c, Completed_Task__c, Open_Task__c
                FROM AcctSeed__Project__c WHERE Id = :recordId LIMIT 1
            ];
            tp.total     = (m.Total_Task__c == null)     ? 0 : Integer.valueOf(m.Total_Task__c);
            tp.completed = (m.Completed_Task__c == null) ? 0 : Integer.valueOf(m.Completed_Task__c);
            tp.openCount = (m.Open_Task__c == null)      ? 0 : Integer.valueOf(m.Open_Task__c);
            tp.percentComplete = (tp.total > 0)
                ? Integer.valueOf((Decimal.valueOf(tp.completed) / tp.total * 100).round())
                : 0;
        } catch (Exception e) {
            System.debug('getTaskProgress error: ' + e.getMessage());
        }
        return tp;
    }

    // ---------------------------------------------------------------------
    // CURRENT TASKS  (3 most urgent OPEN tasks the client can see; read-only)
    //
    // Standard Task object, related to the Matter via the custom Matter__c lookup.
    // By default only tasks flagged IsVisibleInSelfService = true are shown, so the
    // client never sees internal tasks (per Chris's note). Toggle clientVisibleOnly
    // to false to show all open matter tasks.
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<TaskItem> getCurrentTasks(Id recordId, Integer maxTasks, Boolean clientVisibleOnly) {
        List<TaskItem> items = new List<TaskItem>();
        if (recordId == null) return items;

        Integer lim = (maxTasks == null || maxTasks <= 0) ? 3 : maxTasks;
        Boolean visOnly = (clientVisibleOnly == null) ? true : clientVisibleOnly;

        String soql =
            'SELECT Id, Subject, ActivityDate, Status, IsHighPriority ' +
            'FROM Task ' +
            'WHERE Matter__c = :recordId AND IsClosed = false ';
        if (visOnly) {
            soql += 'AND IsVisibleInSelfService = true ';
        }
        soql += 'ORDER BY ActivityDate ASC NULLS LAST, Order__c ASC NULLS LAST LIMIT :lim';

        try {
            for (Task t : (List<Task>) Database.query(soql)) {
                items.add(new TaskItem(t.Id, t.Subject, t.ActivityDate, t.Status));
            }
        } catch (Exception e) {
            System.debug('getCurrentTasks error: ' + e.getMessage());
        }
        return items;
    }

    // =====================================================================
    // DTOs
    // =====================================================================
    public class MatterOverview {
        @AuraEnabled public String  matterName;
        @AuraEnabled public Id      contactId;
        @AuraEnabled public Boolean hasBillingAttorney = false;
        // Phase
        @AuraEnabled public String  phaseValue;
        @AuraEnabled public Integer phaseIndex = 1;
        @AuraEnabled public String  currentPhaseTitle;
        @AuraEnabled public String  currentPhaseDescription;
        // Questionnaire
        @AuraEnabled public String  questionnaireLabel;
        @AuraEnabled public String  questionnaireUrl;
        // Documents
        @AuraEnabled public String  boxFolderEmbedUrl;
        @AuraEnabled public String  boxUploadUrl;
    }

    public class TaskProgress {
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer completed = 0;
        @AuraEnabled public Integer openCount = 0;
        @AuraEnabled public Integer percentComplete = 0;
    }

    public class TaskItem {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  subject;
        @AuraEnabled public Date    dueDate;
        @AuraEnabled public String  dueLabel;
        @AuraEnabled public String  status;
        @AuraEnabled public Boolean isOverdue = false;

        public TaskItem(Id recId, String subj, Date due, String status) {
            this.id      = recId;
            this.subject = subj;
            this.dueDate = due;
            this.status  = status;
            if (due == null) {
                this.dueLabel = '';
            } else if (due < Date.today()) {
                this.dueLabel  = 'Overdue';
                this.isOverdue = true;
            } else if (due == Date.today()) {
                this.dueLabel = 'Due ASAP';
            } else {
                this.dueLabel = 'Due ' + due.format();
            }
        }
    }

    public class AppointmentItem implements Comparable {
        @AuraEnabled public String   subject;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public String   whenLabel;

        public AppointmentItem(String subject, Datetime dt) {
            this.subject       = subject;
            this.startDateTime = dt;
            this.whenLabel     = dt.format('EEEE, MMM d \'at\' h:mm a');
        }
        public Integer compareTo(Object other) {
            AppointmentItem o = (AppointmentItem) other;
            if (this.startDateTime == o.startDateTime) return 0;
            return this.startDateTime > o.startDateTime ? 1 : -1;
        }
    }
}