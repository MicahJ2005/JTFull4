public class EventTriggerHandler {
    public static void handleAfterInsert(List<Event> newEvents) {
        Set<Id> eventIdsToProcess = new Set<Id>();

        for (Event evt : newEvents) {
            // Existing behavior: attempt to populate WhatId for invite-based Event records.
            if (evt.WhatId == null && evt.WhoId == null) {
                eventIdsToProcess.add(evt.Id);
            }
        }

        if (!eventIdsToProcess.isEmpty()) {
            System.enqueueJob(new PopulateEventWhatIdQueueable(eventIdsToProcess));
        }

        // New behavior: if the Event is not already related to an Account/Lead, see whether
        // the subject is likely to match a Person Account or Lead and set the checkbox.
        List<Event> eventsToEvaluate = new List<Event>();
        for (Event evt : newEvents) {
            if (evt.WhatId == null && evt.WhoId == null && String.isNotBlank(evt.Subject)) {
                eventsToEvaluate.add(evt);
            }
        }

        if (!eventsToEvaluate.isEmpty()) {
            List<Event> eventsToUpdate = new List<Event>();
            for (Event evt : eventsToEvaluate) {
                List<EventAccountMatchController.AccountMatchWrapper> matches =
                    EventAccountMatchController.getPotentialMatches(evt.Id);

                eventsToUpdate.add(new Event(
                    Id = evt.Id,
                    Has_Potential_Account_Matches__c = !matches.isEmpty()
                ));
            }

            if (!eventsToUpdate.isEmpty()) {
                update eventsToUpdate;
            }
        }
    }
}