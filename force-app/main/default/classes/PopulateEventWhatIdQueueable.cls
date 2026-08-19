public class PopulateEventWhatIdQueueable implements Queueable {
    private Set<Id> eventIds;

    public PopulateEventWhatIdQueueable(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }

    public void execute(QueueableContext context) {
        if (eventIds == null || eventIds.isEmpty()) {
            return;
        }

        // Query invited attendees for these events. An Account cannot exist as a standalone
        // EventRelation row (Salesforce only allows it as the IsParent=true mirror of WhatId
        // itself), so the Account has to be derived from an invited Contact's AccountId, or --
        // for portal users (005 prefix) -- from the Person Account behind the User's Contact.
        List<EventRelation> relations = [
            SELECT Id, EventId, RelationId
            FROM EventRelation
            WHERE EventId IN :eventIds
              AND IsInvitee = true
            ORDER BY CreatedDate ASC
        ];

        if (relations.isEmpty()) {
            return;
        }

        // Contacts (003 prefix) carry an AccountId directly; Users (005 prefix) may be portal
        // users whose Contact needs to be looked up first.
        Set<Id> contactIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        for (EventRelation er : relations) {
            if (er.RelationId == null) {
                continue;
            }
            String relationIdStr = String.valueOf(er.RelationId);
            if (relationIdStr.startsWith('003')) {
                contactIds.add(er.RelationId);
            } else if (relationIdStr.startsWith('005')) {
                userIds.add(er.RelationId);
            }
        }

        // Resolve portal users to their underlying Contact so it resolves through the same
        // Contact-to-Account lookup as a directly-invited Contact.
        Map<Id, Id> userToContactMap = new Map<Id, Id>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, ContactId FROM User WHERE Id IN :userIds AND ContactId != null]) {
                userToContactMap.put(u.Id, u.ContactId);
                contactIds.add(u.ContactId);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Id> contactToAccountMap = new Map<Id, Id>();
        for (Contact con : [SELECT Id, AccountId FROM Contact WHERE Id IN :contactIds AND AccountId != null]) {
            contactToAccountMap.put(con.Id, con.AccountId);
        }

        // Map the first invited Contact/portal User's Account to each Event
        Map<Id, Id> eventToAccountMap = new Map<Id, Id>();
        for (EventRelation er : relations) {
            if (eventToAccountMap.containsKey(er.EventId)) {
                continue;
            }

            Id contactId = userToContactMap.containsKey(er.RelationId) ? userToContactMap.get(er.RelationId) : er.RelationId;
            if (contactToAccountMap.containsKey(contactId)) {
                eventToAccountMap.put(er.EventId, contactToAccountMap.get(contactId));
            }
        }

        if (eventToAccountMap.isEmpty()) {
            return;
        }

        // Prepare Event updates
        List<Event> eventsToUpdate = new List<Event>();
        for (Id evtId : eventToAccountMap.keySet()) {
            eventsToUpdate.add(new Event(
                Id = evtId,
                WhatId = eventToAccountMap.get(evtId)
            ));
        }

        if (!eventsToUpdate.isEmpty()) {
            update eventsToUpdate;
        }
    }
}
