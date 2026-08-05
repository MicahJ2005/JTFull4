public without sharing class CESAvailabilityAction {

    public class SlotInfo {
        @AuraEnabled public String label;       
        @AuraEnabled public DateTime slotStart;
        @AuraEnabled public List<Id> availableCESIds;
    }

    public class AvailabilityRequest {
        @InvocableVariable public String leadId;
    }

    public class AvailabilityResult {
        @InvocableVariable public String slotsJson;
        @InvocableVariable public Boolean clientHasActiveAppointment;
        @InvocableVariable public String activeAppointmentDetail;
    }

    @InvocableMethod(label='Get Unified CES Availability')
    public static List<AvailabilityResult> getAvailability(
        List<AvailabilityRequest> requests
    ) {
        AvailabilityResult result = new AvailabilityResult();
        String leadId = requests[0].leadId;

        List<Event> clientEvents = [
            SELECT Id, StartDateTime, Owner.Name
            FROM Event
            WHERE WhoId = :leadId
            AND CES_Appointment__c = true
            AND StartDateTime >= :DateTime.now()
            ORDER BY StartDateTime ASC
            LIMIT 1
        ];

        if (!clientEvents.isEmpty()) {
            Event existing = clientEvents[0];
            result.clientHasActiveAppointment = true;
            result.activeAppointmentDetail = 
                existing.Owner.Name + ' — ' + 
                existing.StartDateTime.format('EEEE d \'de\' MMMM, h:mm a', 'es_SV');
            result.slotsJson = '[]';
            return new List<AvailabilityResult>{ result };
        }

        List<User> cesList = [
            SELECT Id, Name, Email
            FROM User
            WHERE UserRole.Name = 'Client Engagement Specialist'
            AND IsActive = true
        ];

        Date minDate = Date.today().addDays(1);
        DateTime rangeStart = DateTime.newInstance(minDate, Time.newInstance(8,0,0,0));
        DateTime rangeEnd   = DateTime.newInstance(minDate.addDays(13), Time.newInstance(17,0,0,0));

        Set<Id> cesIds = new Map<Id, User>(cesList).keySet();

        List<Event> existingEvents = [
            SELECT OwnerId, StartDateTime, EndDateTime
            FROM Event
            WHERE OwnerId IN :cesIds
            AND StartDateTime >= :rangeStart
            AND EndDateTime   <= :rangeEnd
        ];

        Map<DateTime, Set<Id>> busyMap = new Map<DateTime, Set<Id>>();
        for (Event e : existingEvents) {
            DateTime slotKey = e.StartDateTime;
            if (!busyMap.containsKey(slotKey)) {
                busyMap.put(slotKey, new Set<Id>());
            }
            busyMap.get(slotKey).add(e.OwnerId);
        }

        List<SlotInfo> availableSlots = new List<SlotInfo>();
        DateTime cursor = rangeStart;

        while (cursor <= rangeEnd && availableSlots.size() < 20) {
            Integer dow = Integer.valueOf(cursor.format('u')); 
            Integer hour = cursor.hour();

            if (dow >= 1 && dow <= 5 && hour >= 8 && hour < 17) {
                Set<Id> busy = busyMap.containsKey(cursor) 
                    ? busyMap.get(cursor) 
                    : new Set<Id>();

                List<Id> available = new List<Id>();
                for (User ces : cesList) {
                    if (!busy.contains(ces.Id)) {
                        available.add(ces.Id);
                    }
                }

                if (!available.isEmpty()) {
                    SlotInfo slot = new SlotInfo();
                    slot.label = cursor.format('EEEE d \'de\' MMMM - h:mm a', 'es_SV');
                    slot.slotStart = cursor;
                    slot.availableCESIds = available;
                    availableSlots.add(slot);
                }
            }

            cursor = cursor.addHours(1);
        }

        result.clientHasActiveAppointment = false;
        result.slotsJson = JSON.serialize(availableSlots);
        return new List<AvailabilityResult>{ result };
    }
}