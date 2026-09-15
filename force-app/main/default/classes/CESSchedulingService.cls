public without sharing class CESSchedulingService {

    public class SlotInfo {
        @AuraEnabled public String   label;
        @AuraEnabled public String   slotStartString;
        @AuraEnabled public List<Id> availableCESIds;

        public SlotInfo(String label, DateTime slotStart, List<Id> cesIds) {
            this.label           = label;
            this.slotStartString = slotStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            this.availableCESIds = cesIds;
        }
    }

    public class ActiveAppointment {
        public String cesName;
        public String slotLabel;
        public String appointmentType;
    }

    public class BookingInput {
        public Id      leadId;
        public String  slotsJson;
        public Integer selectedIndex;
        public String  appointmentType;
        public String  leadName;
        public String  notes;
    }

    public class BookingOutput {
        public Boolean success;
        public String  eventId;
        public String  cesName;
        public String  confirmedSlotLabel;
        public String  zoomJoinUrl;
        public String  appointmentType;
        public String  errorMessage;
    }

    // ─────────────────────────────────────────────
    // CHECK EXISTING APPOINTMENT
    // ─────────────────────────────────────────────

    public static ActiveAppointment getActiveAppointment(Id leadId) {
        List<Event> existing = [
            SELECT Id, StartDateTime, Owner.Name, Appointment_Type__c
            FROM Event
            WHERE WhoId              = :leadId
            AND   CES_Appointment__c = true
            AND   StartDateTime      >= :DateTime.now()
            ORDER BY StartDateTime ASC
            LIMIT 1
        ];

        if (existing.isEmpty()) return null;

        ActiveAppointment appt = new ActiveAppointment();
        appt.cesName           = existing[0].Owner.Name;
        appt.appointmentType   = existing[0].Appointment_Type__c;
        appt.slotLabel         = existing[0].StartDateTime
                                    .format('EEEE d \'de\' MMMM - h:mm a', 'es_SV');
        return appt;
    }

    // ─────────────────────────────────────────────
    // GET AVAILABLE SLOTS
    // ─────────────────────────────────────────────

    public static List<SlotInfo> getAvailableSlots() {
        // A CES is identified by profile, not by the free text Title field, so a typo or a
        // title change cannot silently drop someone out of the pool. Kept identical to
        // SelectMostAvailableCES so both classes agree on who counts as a CES.
        List<User> cesList = [
            SELECT Id, Name, Title
            FROM User
            WHERE Profile.Name = 'Client Engagement Specialist'
            AND   IsActive     = true
        ];

        if (cesList.isEmpty()) return new List<SlotInfo>();

        Date     minDate    = Date.today().addDays(1);
        DateTime rangeStart = DateTime.newInstance(minDate, Time.newInstance(8, 0, 0, 0));
        DateTime rangeEnd   = DateTime.newInstance(minDate.addDays(13), Time.newInstance(17, 0, 0, 0));

        Set<Id> cesIds = new Map<Id, User>(cesList).keySet();

        List<Event> busyEvents = [
            SELECT OwnerId, StartDateTime
            FROM Event
            WHERE OwnerId            IN :cesIds
            AND   CES_Appointment__c = true
            AND   StartDateTime      >= :rangeStart
            AND   StartDateTime      <= :rangeEnd
        ];

        Map<DateTime, Set<Id>> busyMap = new Map<DateTime, Set<Id>>();
        for (Event e : busyEvents) {
            if (!busyMap.containsKey(e.StartDateTime)) {
                busyMap.put(e.StartDateTime, new Set<Id>());
            }
            busyMap.get(e.StartDateTime).add(e.OwnerId);
        }

        List<SlotInfo> slots  = new List<SlotInfo>();
        DateTime       cursor = rangeStart;

        while (cursor <= rangeEnd && slots.size() < 20) {
            Integer dayOfWeek     = Integer.valueOf(cursor.format('u'));
            Integer hour          = cursor.hour();
            Boolean isWeekday     = dayOfWeek >= 1 && dayOfWeek <= 5;
            Boolean isWorkingHour = hour >= 8 && hour < 17;

            if (isWeekday && isWorkingHour) {
                Set<Id>  busy      = busyMap.containsKey(cursor)
                    ? busyMap.get(cursor)
                    : new Set<Id>();
                List<Id> available = new List<Id>();

                for (User ces : cesList) {
                    if (!busy.contains(ces.Id)) {
                        available.add(ces.Id);
                    }
                }

                if (!available.isEmpty()) {
                    String label = cursor.format('EEEE d \'de\' MMMM - h:mm a', 'es_SV');
                    slots.add(new SlotInfo(label, cursor, available));
                }
            }

            cursor = cursor.addHours(1);
        }

        return slots;
    }

    // ─────────────────────────────────────────────
    // ASSIGN RANDOM CES
    // ─────────────────────────────────────────────

    public static Id assignCES(List<Id> availableIds) {
        if (availableIds == null || availableIds.isEmpty()) return null;
        if (availableIds.size() == 1) return availableIds[0];

        Integer idx = Math.mod(
            Math.abs(Crypto.getRandomInteger()),
            availableIds.size()
        );
        return availableIds[idx];
    }

    // ─────────────────────────────────────────────
    // BOOK APPOINTMENT
    // ─────────────────────────────────────────────

    public static BookingOutput bookAppointment(BookingInput input) {
        BookingOutput output = new BookingOutput();

        try {
            List<Object>        rawSlots     = (List<Object>) JSON.deserializeUntyped(input.slotsJson);
            Map<String, Object> selectedSlot = (Map<String, Object>) rawSlots[input.selectedIndex];

            String   slotStartStr = (String) selectedSlot.get('slotStartString');
            DateTime slotStart    = (DateTime) JSON.deserialize('"' + slotStartStr + '"', DateTime.class);
            DateTime slotEnd      = slotStart.addHours(1);
            String   slotLabel    = (String) selectedSlot.get('label');

            List<Object> rawIds       = (List<Object>) selectedSlot.get('availableCESIds');
            List<Id>     availableIds = new List<Id>();
            for (Object o : rawIds) {
                availableIds.add((Id)(String) o);
            }

            Id assignedCESId = assignCES(availableIds);

            // Fetch CES name and email — email is needed for Zoom meeting creation
            User assignedCES = [
                SELECT Id, Name, Email
                FROM User
                WHERE Id = :assignedCESId
                LIMIT 1
            ];

            // Generate unique Zoom meeting link via ZoomIntegrationService
            String zoomUrl = null;
            if (input.appointmentType == 'Zoom') {
                String meetingTopic = 'Consultation with ' + input.leadName;
                zoomUrl = ZoomIntegrationService.createMeeting(
                    assignedCES.Email,
                    meetingTopic,
                    slotStart
                );
            }

            Event newEvent = new Event(
                Subject             = 'CES Consultation - ' + input.leadName,
                OwnerId             = assignedCESId,
                WhoId               = input.leadId,
                StartDateTime       = slotStart,
                EndDateTime         = slotEnd,
                Description         = input.notes,
                CES_Appointment__c  = true,
                Appointment_Type__c = input.appointmentType,
                Zoom_Join_URL__c    = zoomUrl
            );
            insert newEvent;

            output.success            = true;
            output.eventId            = newEvent.Id;
            output.cesName            = assignedCES.Name;
            output.confirmedSlotLabel = slotLabel;
            output.zoomJoinUrl        = zoomUrl;
            output.appointmentType    = input.appointmentType;

        } catch (CalloutException ce) {
            output.success      = false;
            output.errorMessage = 'Could not generate Zoom meeting link. Please try again or choose a phone call instead.';
        } catch (Exception e) {
            output.success      = false;
            output.errorMessage = e.getMessage();
        }

        return output;
    }
}