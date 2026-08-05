public without sharing class CheckAndGetSlotsAction {

    public class ActionRequest {
        @InvocableVariable(label='Lead Id' required=true)
        public String leadId;
    }

    public class ActionResult {
        @InvocableVariable(label='Has Active Appointment')
        public Boolean hasActiveAppointment;

        @InvocableVariable(label='Active Appointment Detail')
        public String activeAppointmentDetail;

        @InvocableVariable(label='Slots JSON')
        public String slotsJson;

        @InvocableVariable(label='Slots Summary')
        public String slotsSummary;

        @InvocableVariable(label='No Availability')
        public Boolean noAvailability;
    }

    @InvocableMethod(
        label='Check Appointment and Get Available Slots'
        description='Checks if the Lead already has an active appointment. If not, returns unified CES availability.'
    )
    public static List<ActionResult> execute(List<ActionRequest> requests) {
        ActionResult result = new ActionResult();
        Id           leadId = (Id) requests[0].leadId;

        CESSchedulingService.ActiveAppointment existing =
            CESSchedulingService.getActiveAppointment(leadId);

        if (existing != null) {
            result.hasActiveAppointment    = true;
            result.activeAppointmentDetail =
                'You already have a consultation scheduled with ' + existing.cesName +
                ' on ' + existing.slotLabel +
                ' (' + existing.appointmentType + ').';
            result.slotsJson      = '[]';
            result.slotsSummary   = '';
            result.noAvailability = false;
            return new List<ActionResult>{ result };
        }

        List<CESSchedulingService.SlotInfo> slots =
            CESSchedulingService.getAvailableSlots();

        result.hasActiveAppointment    = false;
        result.activeAppointmentDetail = null;

        if (slots.isEmpty()) {
            result.noAvailability = true;
            result.slotsJson      = '[]';
            result.slotsSummary   = 'There are no available time slots in the next 14 days. Please contact us directly.';
            return new List<ActionResult>{ result };
        }

        result.noAvailability = false;
        result.slotsJson      = JSON.serialize(slots);

        List<String> lines = new List<String>();
        for (Integer i = 0; i < slots.size(); i++) {
            lines.add((i + 1) + '. ' + slots[i].label);
        }
        result.slotsSummary = String.join(lines, '\n');

        return new List<ActionResult>{ result };
    }
}