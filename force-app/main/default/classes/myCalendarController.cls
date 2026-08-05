/**
 * Calendar service for the client portal "My Calendar" page (Experience Cloud).
 * Returns the LOGGED-IN client's appointments (standard Event records related to
 * their Contact / Person Account), grouped into Next 14 days / Future / Past,
 * plus the set of days that have appointments (for the month-view dots).
 */
public without sharing class myCalendarController {

    @AuraEnabled(cacheable=true)
    public static CalendarData getMyAppointments() {
        Id contactId;
        Id accountId;
        try {
            User u = [
                SELECT ContactId, AccountId, Contact.AccountId
                FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
            ];
            contactId = u.ContactId;
            accountId = (u.AccountId != null) ? u.AccountId
                        : (u.Contact != null ? u.Contact.AccountId : null);
        } catch (Exception e) {
            System.debug('User resolve error: ' + e.getMessage());
        }
        return buildCalendar(contactId, accountId);
    }

    @TestVisible
    private static CalendarData buildCalendar(Id contactId, Id accountId) {
        CalendarData data = new CalendarData();
        if (contactId == null && accountId == null) return data;

        // Build WHERE with only the available relationships (avoid null matches)
        List<String> clauses = new List<String>();
        if (contactId != null) clauses.add('WhoId = :contactId');
        if (accountId != null) clauses.add('AccountId = :accountId');
        String soql =
            'SELECT Id, Subject, StartDateTime, EndDateTime, Location, Type, Description, ' +
            'IsAllDayEvent, Owner.Name, Who.Name ' +
            'FROM Event WHERE ' + String.join(clauses, ' OR ') +
            ' ORDER BY StartDateTime ASC';

        Datetime nowDt = System.now();
        Datetime in14 = nowDt.addDays(14);

        try {
            for (Event e : (List<Event>) Database.query(soql)) {
                Appt a = new Appt(e);
                if (a.dateKey != null) data.daysWithAppts.add(a.dateKey);

                if (e.StartDateTime == null) { data.future.add(a); continue; }
                if (e.StartDateTime < nowDt)        data.past.add(a);
                else if (e.StartDateTime <= in14)   data.next14.add(a);
                else                                data.future.add(a);
            }
        } catch (Exception e) {
            System.debug('buildCalendar query error: ' + e.getMessage());
        }

        // Past: most recent first
        List<Appt> rev = new List<Appt>();
        for (Integer i = data.past.size() - 1; i >= 0; i--) rev.add(data.past[i]);
        data.past = rev;

        return data;
    }

    private static String deriveIcon(Event e) {
        String s = (
            (e.Type != null ? e.Type : '') + ' ' +
            (e.Subject != null ? e.Subject : '') + ' ' +
            (e.Location != null ? e.Location : '')
        ).toLowerCase();
        if (s.contains('zoom') || s.contains('video'))   return 'utility:video';
        if (s.contains('phone') || s.contains('call'))   return 'utility:call';
        if (s.contains('person') || s.contains('office') || s.contains('mediation')
            || s.contains('court') || s.contains('hearing') || s.contains('in-person'))
            return 'utility:location';
        return 'utility:event';
    }

    // ===================== DTOs =====================
    public class CalendarData {
        @AuraEnabled public List<Appt> next14 = new List<Appt>();
        @AuraEnabled public List<Appt> future = new List<Appt>();
        @AuraEnabled public List<Appt> past   = new List<Appt>();
        @AuraEnabled public List<String> daysWithAppts = new List<String>();
    }

    public class Appt {
        @AuraEnabled public Id       id;
        @AuraEnabled public String   subject;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public String   location;
        @AuraEnabled public String   apptType;
        @AuraEnabled public String   iconName;
        @AuraEnabled public String   withWho;
        @AuraEnabled public String   monthAbbr;
        @AuraEnabled public Integer  day;
        @AuraEnabled public String   weekday;
        @AuraEnabled public String   timeLabel;
        @AuraEnabled public String   dateKey;     // yyyy-MM-dd (matches LWC calendar)
        @AuraEnabled public Boolean  isPast = false;
        @AuraEnabled public String   summaryNotes;
        @AuraEnabled public String   icsStart;    // UTC for .ics
        @AuraEnabled public String   icsEnd;

        public Appt(Event e) {
            this.id            = e.Id;
            this.subject       = e.Subject;
            this.startDateTime = e.StartDateTime;
            this.endDateTime   = e.EndDateTime;
            this.location      = e.Location;
            this.apptType      = e.Type;
            this.withWho       = (e.Who != null && e.Who.Name != null) ? e.Who.Name
                                 : (e.Owner != null ? e.Owner.Name : null);
            this.summaryNotes  = e.Description;
            this.iconName      = deriveIcon(e);

            if (e.StartDateTime != null) {
                this.monthAbbr = e.StartDateTime.format('MMM').toUpperCase();
                this.day       = Integer.valueOf(e.StartDateTime.format('d'));
                this.weekday   = e.StartDateTime.format('EEE').toUpperCase();
                this.timeLabel = 'Starts at ' + e.StartDateTime.format('h:mm a z');
                this.dateKey   = e.StartDateTime.format('yyyy-MM-dd');
                this.icsStart  = e.StartDateTime.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
                this.isPast    = e.StartDateTime < System.now();
            }
            if (e.EndDateTime != null) {
                this.icsEnd = e.EndDateTime.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
            }
        }
    }
}