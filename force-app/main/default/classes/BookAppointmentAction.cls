public without sharing class BookAppointmentAction {

    public class ActionRequest {
        @InvocableVariable(label='Lead Id' required=true)
        public String leadId;

        @InvocableVariable(label='Lead Name' required=true)
        public String leadName;

        @InvocableVariable(label='Slots JSON' required=true)
        public String slotsJson;

        @InvocableVariable(label='Selected Slot Index' required=true)
        public Integer selectedIndex; // 1-based: client picks "option 2"

        @InvocableVariable(label='Appointment Type' required=true)
        public String appointmentType; // 'Zoom' or 'Phone'

        @InvocableVariable(label='Notes')
        public String notes;
    }

    public class ActionResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Confirmation Message')
        public String confirmationMessage;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Book CES Appointment'
        description='Creates the Event, assigns a CES, generates Zoom link if needed, and returns confirmation.'
    )
    public static List<ActionResult> execute(List<ActionRequest> requests) {
        ActionRequest req    = requests[0];
        ActionResult  result = new ActionResult();

        CESSchedulingService.BookingInput input = new CESSchedulingService.BookingInput();
        input.leadId          = (Id) req.leadId;
        input.leadName        = req.leadName;
        input.slotsJson       = req.slotsJson;
        input.selectedIndex   = req.selectedIndex - 1; // Convert to 0-based
        input.appointmentType = req.appointmentType;
        input.notes           = req.notes;

        CESSchedulingService.BookingOutput output =
            CESSchedulingService.bookAppointment(input);

        result.success = output.success;

        if (output.success) {
            String typeDetail = (output.zoomJoinUrl != null)
                ? 'Type: Zoom call. Your meeting link: ' + output.zoomJoinUrl
                : 'Type: Phone call. Your specialist will call you at the number on file.';

            result.confirmationMessage =
                'Your consultation has been successfully scheduled. ' +
                'Date and time: ' + output.confirmedSlotLabel + '. ' +
                'Your specialist: ' + output.cesName + '. ' +
                typeDetail + '. ' +
                'You will receive a confirmation email shortly, and a reminder 2 hours before your appointment.';
        } else {
            result.errorMessage = output.errorMessage;
        }

        return new List<ActionResult>{ result };
    }
}