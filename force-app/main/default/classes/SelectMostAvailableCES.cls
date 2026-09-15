/**
 * Picks the Client Engagement Specialist with the most open time over the next five business days.
 *
 * Used before the scheduling link is generated so the booking page renders a real CES's
 * calendar, and so the Zoom room can be created under that same person. Choosing the CES
 * up front is what makes host, owner and assignee the same user.
 *
 * "Most available" is self balancing: whoever is busiest stops being picked until their
 * calendar clears. No stored state, so there is no race between concurrent bookings.
 */
public with sharing class SelectMostAvailableCES {

    private static final String CLASS_NAME  = 'SelectMostAvailableCES';
    private static final String CES_PROFILE = 'Client Engagement Specialist';

    // Business hours in the org's timezone, and how far ahead to measure.
    // Five business days rather than calendar days, so a Thursday request still looks at
    // a full working week rather than being half consumed by the weekend.
    private static final Integer DAY_START_HOUR       = 8;   // 8am
    private static final Integer DAY_END_HOUR         = 17;  // 5pm
    private static final Integer BUSINESS_DAYS_AHEAD  = 5;

    @TestVisible private static List<User>  testPool;
    @TestVisible private static List<Event> testEvents;

    public class ActionRequest {
        @InvocableVariable(
            label='Fallback User Id'
            description='Used only if no active CES can be found. Leave blank to fail loudly instead.'
            required=false)
        public String fallbackUserId;
    }

    public class ActionResult {
        @InvocableVariable(label='Selected CES User Id')
        public String cesUserId;

        @InvocableVariable(label='Selected CES Name')
        public String cesName;

        @InvocableVariable(label='Selected CES Email')
        public String cesEmail;

        @InvocableVariable(label='Open Slots Found')
        public Integer openSlots;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Select Most Available CES'
        description='Returns the Client Engagement Specialist with the most open time in the next five business days.'
    )
    public static List<ActionResult> selectCes(List<ActionRequest> requests) {
        ActionResult result = new ActionResult();
        result.success = false;

        String fallbackUserId = (requests != null && !requests.isEmpty())
            ? requests[0].fallbackUserId : null;

        try {
            List<User> pool = getPool();

            if (pool.isEmpty()) {
                return finishWithFallback(result, fallbackUserId,
                    'No active Client Engagement Specialist was found.');
            }

            Map<Id, Integer> openByUser = countOpenSlots(pool);

            User best = null;
            Integer bestCount = -1;
            for (User u : pool) {
                Integer count = openByUser.get(u.Id);
                // Ties break on the lowest User Id so the result is deterministic.
                if (count > bestCount || (count == bestCount && best != null && u.Id < best.Id)) {
                    best      = u;
                    bestCount = count;
                }
            }

            if (best == null || bestCount <= 0) {
                return finishWithFallback(result, fallbackUserId,
                    'No Client Engagement Specialist has open time in the next '
                    + BUSINESS_DAYS_AHEAD + ' business days.');
            }

            result.cesUserId = best.Id;
            result.cesName   = best.Name;
            result.cesEmail  = best.Email;
            result.openSlots = bestCount;
            result.success   = true;

        } catch (Exception ex) {
            ZoomIntegrationErrorLogger.log(CLASS_NAME, 'selectCes', null, null, ex);
            return finishWithFallback(result, fallbackUserId,
                'Could not determine CES availability: ' + ex.getMessage());
        }

        return new List<ActionResult>{ result };
    }

    // ─────────────────────────────────────────────────────────────────────────

    private static List<User> getPool() {
        if (testPool != null) {
            return testPool;
        }
        return [
            SELECT Id, Name, Email, Zoom_User_Id__c
            FROM   User
            WHERE  Profile.Name = :CES_PROFILE
            AND    IsActive = true
            ORDER BY Name
        ];
    }

    /**
     * End of the Nth business day from the given start, counting the start day itself when
     * it is a weekday. Weekends are skipped rather than consuming part of the window.
     */
    @TestVisible
    private static DateTime endOfBusinessDaysAhead(DateTime start, Integer businessDays) {
        Date     day     = start.date();
        Integer  counted = 0;

        while (true) {
            Integer dayOfWeek = Integer.valueOf(
                DateTime.newInstance(day, Time.newInstance(12, 0, 0, 0)).format('u'));
            if (dayOfWeek >= 1 && dayOfWeek <= 5) {
                counted++;
                if (counted == businessDays) break;
            }
            day = day.addDays(1);
        }
        return DateTime.newInstance(day, Time.newInstance(DAY_END_HOUR, 0, 0, 0));
    }

    /**
     * Counts free one hour business-hours slots per CES over the window. An event blocks a
     * slot when it overlaps it at all, so multi hour events block correctly rather than only
     * matching on start time.
     */
    private static Map<Id, Integer> countOpenSlots(List<User> pool) {
        Set<Id> ids = new Map<Id, User>(pool).keySet();

        DateTime rangeStart = DateTime.now();
        DateTime rangeEnd   = endOfBusinessDaysAhead(rangeStart, BUSINESS_DAYS_AHEAD);

        // Inline SOQL is not allowed inside a ternary in Apex, so this stays an if/else.
        List<Event> busy;
        if (testEvents != null) {
            busy = testEvents;
        } else {
            busy = [
                SELECT OwnerId, StartDateTime, EndDateTime
                FROM   Event
                WHERE  OwnerId IN :ids
                AND    StartDateTime <= :rangeEnd
                AND    EndDateTime   >= :rangeStart
            ];
        }

        Map<Id, List<Event>> byOwner = new Map<Id, List<Event>>();
        for (User u : pool) {
            byOwner.put(u.Id, new List<Event>());
        }
        for (Event e : busy) {
            if (byOwner.containsKey(e.OwnerId)) {
                byOwner.get(e.OwnerId).add(e);
            }
        }

        Map<Id, Integer> counts = new Map<Id, Integer>();

        for (User u : pool) {
            Integer open = 0;
            DateTime cursor = rangeStart;

            while (cursor < rangeEnd) {
                // Local time, so business hours mean business hours where the firm is.
                Integer dayOfWeek = Integer.valueOf(cursor.format('u'));
                Integer hour      = cursor.hour();

                Boolean weekday  = dayOfWeek >= 1 && dayOfWeek <= 5;
                Boolean inHours  = hour >= DAY_START_HOUR && hour < DAY_END_HOUR;

                if (weekday && inHours) {
                    DateTime slotEnd = cursor.addHours(1);
                    Boolean blocked  = false;

                    for (Event e : byOwner.get(u.Id)) {
                        if (e.StartDateTime < slotEnd && e.EndDateTime > cursor) {
                            blocked = true;
                            break;
                        }
                    }
                    if (!blocked) open++;
                }
                cursor = cursor.addHours(1);
            }
            counts.put(u.Id, open);
        }
        return counts;
    }

    /** Falls back to a configured user only if one was supplied, and always says why. */
    private static List<ActionResult> finishWithFallback(ActionResult result,
                                                          String fallbackUserId,
                                                          String reason) {
        if (String.isNotBlank(fallbackUserId)) {
            List<User> fb = [
                SELECT Id, Name, Email FROM User
                WHERE Id = :fallbackUserId AND IsActive = true LIMIT 1
            ];
            if (!fb.isEmpty()) {
                result.cesUserId    = fb[0].Id;
                result.cesName      = fb[0].Name;
                result.cesEmail     = fb[0].Email;
                result.openSlots    = 0;
                result.success      = true;
                result.errorMessage = reason + ' Fell back to ' + fb[0].Name + '.';
                return new List<ActionResult>{ result };
            }
        }
        result.success      = false;
        result.errorMessage = reason;
        return new List<ActionResult>{ result };
    }
}