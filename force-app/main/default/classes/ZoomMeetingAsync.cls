public without sharing class ZoomMeetingAsync {

    @future(callout=true)
    public static void createAndUpdateEvent(String eventId, String cesEmail,
                                             String topic, String slotStartString) {
        try {
            DateTime slotStart = (DateTime) JSON.deserialize(
                '"' + slotStartString + '"', DateTime.class
            );

            String joinUrl = ZoomIntegrationService.createMeeting(
                cesEmail,
                topic,
                slotStart
            );

            Event evt = new Event(
                Id               = eventId,
                Zoom_Join_URL__c = joinUrl
            );
            update evt;

        } catch (Exception e) {
            System.debug('ZoomMeetingAsync error: ' + e.getMessage());
        }
    }
}