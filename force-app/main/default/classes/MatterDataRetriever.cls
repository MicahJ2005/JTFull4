public without sharing class MatterDataRetriever {

    private static final Integer MAX_JSON_LENGTH = 120000;

    @InvocableMethod
    public static List<Response> getMatterData() {
        List<Response> responses = new List<Response>();
        Id currentUserId = UserInfo.getUserId();

        // 1) Query all relevant Matters (no 2-week filter)
        List<acctseed__Project__c> matters = [
            SELECT
                Id,
                Name, 
                ICMC_Date_and_Time__c, 
                Default_Hearing__c, 
                FENE__c, 
                Mediation__c, 
                Motion_Hearing__c, 
                Pre_Trial__c, 
                SENE__c, 
                Trial__c, 
                AcctSeed__Opportunity__c, 
                AcctSeed__Account__c,
                Billing_Attorney_LU__c,
                Paralegal_LU__c
            FROM acctseed__Project__c
            WHERE AcctSeed__Status__c = 'Active'
              AND RecordType.Name = 'Fixed Fee'
              AND (
                   Billing_Attorney_LU__c = :currentUserId
                OR Paralegal_LU__c = :currentUserId
              )
        ];
        if (matters.isEmpty()) {
            return buildSingleResponse('[]');
        }

        // Gather Matter IDs and Account IDs
        Set<Id> matterIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (acctseed__Project__c m : matters) {
            matterIds.add(m.Id);
            if (m.AcctSeed__Account__c != null) {
                accountIds.add(m.AcctSeed__Account__c);
            }
        }

        // 2) Query Tasks (no date limit)
        List<Task> allTasks = [
            SELECT Id, Subject, Status, ActivityDate, WhatId
            FROM Task
            WHERE WhatId IN :matterIds
               OR WhatId IN :accountIds
            ORDER BY ActivityDate ASC NULLS LAST
        ];

        // 3) Query Events (no date limit)
        List<Event> allEvents = [
            SELECT Id, Subject, StartDateTime, EndDateTime, WhatId
            FROM Event
            WHERE WhatId IN :matterIds
               OR WhatId IN :accountIds
            ORDER BY StartDateTime ASC NULLS LAST
        ];

        // 4) Query FeedItem (must union Matter + Account IDs into one set)
        Set<Id> feedParentIds = new Set<Id>();
        feedParentIds.addAll(matterIds);
        feedParentIds.addAll(accountIds);

        List<FeedItem> allFeeds = new List<FeedItem>();
        if (!feedParentIds.isEmpty()) {
            allFeeds = [
                SELECT Id, Body, ParentId, CreatedDate
                FROM FeedItem
                WHERE ParentId IN :feedParentIds
                ORDER BY CreatedDate DESC
            ];
        }

        // 5) Query EmailMessage (no date limit)
        List<EmailMessage> allEmails = [
            SELECT Id, Subject, RelatedToId, MessageDate, FromName
            FROM EmailMessage
            WHERE RelatedToId IN :matterIds
               OR RelatedToId IN :accountIds
            ORDER BY MessageDate DESC
        ];

        // 6) Group records by parent
        Map<Id, List<SObject>> tasksByParent  = groupById(allTasks,  Task.WhatId);
        Map<Id, List<SObject>> eventsByParent = groupById(allEvents, Event.WhatId);
        Map<Id, List<SObject>> feedsByParent  = groupById(allFeeds,  FeedItem.ParentId);
        Map<Id, List<SObject>> emailsByParent = groupById(allEmails, EmailMessage.RelatedToId);

        // 7) Build final data
        List<Map<String, Object>> allMattersData = new List<Map<String, Object>>();

        for (acctseed__Project__c matter : matters) {
            Map<String, Object> dataMap = new Map<String, Object>();
            dataMap.put('matterRecord', matter);

            // TASKS: combine matter + account
            List<Task> combinedTasks = new List<Task>();
            if (tasksByParent.containsKey(matter.Id)) {
                for (SObject sob : tasksByParent.get(matter.Id)) {
                    combinedTasks.add((Task) sob);
                }
            }
            if (matter.AcctSeed__Account__c != null && tasksByParent.containsKey(matter.AcctSeed__Account__c)) {
                for (SObject sob : tasksByParent.get(matter.AcctSeed__Account__c)) {
                    combinedTasks.add((Task) sob);
                }
            }

            // Separate upcoming vs. past by comparing ActivityDate >= today
            Task upcomingTask = null;
            Task pastTask = null;
            List<Task> upcomingCandidates = new List<Task>();
            List<Task> pastCandidates = new List<Task>();
            for (Task t : combinedTasks) {
                if (t.ActivityDate != null && t.ActivityDate >= Date.today()) {
                    upcomingCandidates.add(t);
                } else {
                    pastCandidates.add(t);
                }
            }
            // earliest upcoming is at index 0
            if (!upcomingCandidates.isEmpty()) {
                upcomingTask = upcomingCandidates[0];
            }
            // most recent past is last item
            if (!pastCandidates.isEmpty()) {
                pastTask = pastCandidates[pastCandidates.size() - 1];
            }

            dataMap.put('upcomingTask', upcomingTask);
            dataMap.put('pastTask', pastTask);

            // EVENTS: combine matter + account
            List<Event> combinedEvents = new List<Event>();
            if (eventsByParent.containsKey(matter.Id)) {
                for (SObject sob : eventsByParent.get(matter.Id)) {
                    combinedEvents.add((Event) sob);
                }
            }
            if (matter.AcctSeed__Account__c != null && eventsByParent.containsKey(matter.AcctSeed__Account__c)) {
                for (SObject sob : eventsByParent.get(matter.AcctSeed__Account__c)) {
                    combinedEvents.add((Event) sob);
                }
            }

            // Separate upcoming vs. past by comparing StartDateTime >= now
            Event upcomingEvent = null;
            Event pastEvent = null;
            List<Event> upcomingEventCandidates = new List<Event>();
            List<Event> pastEventCandidates = new List<Event>();
            for (Event e : combinedEvents) {
                if (e.StartDateTime != null && e.StartDateTime >= Datetime.now()) {
                    upcomingEventCandidates.add(e);
                } else {
                    pastEventCandidates.add(e);
                }
            }
            if (!upcomingEventCandidates.isEmpty()) {
                upcomingEvent = upcomingEventCandidates[0];
            }
            if (!pastEventCandidates.isEmpty()) {
                pastEvent = pastEventCandidates[pastEventCandidates.size() - 1];
            }

            dataMap.put('upcomingEvent', upcomingEvent);
            dataMap.put('pastEvent', pastEvent);

            // FEEDITEM: union matter + account
            List<FeedItem> combinedFeedsList = new List<FeedItem>();
            if (feedsByParent.containsKey(matter.Id)) {
                for (SObject sob : feedsByParent.get(matter.Id)) {
                    combinedFeedsList.add((FeedItem) sob);
                }
            }
            if (matter.AcctSeed__Account__c != null && feedsByParent.containsKey(matter.AcctSeed__Account__c)) {
                for (SObject sob : feedsByParent.get(matter.AcctSeed__Account__c)) {
                    combinedFeedsList.add((FeedItem) sob);
                }
            }
            // Query is ordered by CreatedDate DESC
            FeedItem mostRecentChatterPost = !combinedFeedsList.isEmpty() ? combinedFeedsList[0] : null;
            dataMap.put('mostRecentChatterPost', mostRecentChatterPost);

            // EMAIL: union matter + account
            List<EmailMessage> combinedEmails = new List<EmailMessage>();
            if (emailsByParent.containsKey(matter.Id)) {
                for (SObject sob : emailsByParent.get(matter.Id)) {
                    combinedEmails.add((EmailMessage) sob);
                }
            }
            if (matter.AcctSeed__Account__c != null && emailsByParent.containsKey(matter.AcctSeed__Account__c)) {
                for (SObject sob : emailsByParent.get(matter.AcctSeed__Account__c)) {
                    combinedEmails.add((EmailMessage) sob);
                }
            }
            // Ordered by MessageDate DESC
            EmailMessage mostRecentEmail = !combinedEmails.isEmpty() ? combinedEmails[0] : null;
            dataMap.put('mostRecentEmail', mostRecentEmail);

            // Add to final list
            allMattersData.add(dataMap);
        }

        // 8) Serialize and (optionally) truncate
        String finalJson = JSON.serialize(allMattersData);
        System.debug('Final JSON length before truncation: ' + finalJson.length());
        if (finalJson.length() > MAX_JSON_LENGTH) {
            finalJson = finalJson.substring(0, MAX_JSON_LENGTH);
            System.debug('Truncated final JSON to 120,000 characters.');
        }

        // 9) Return a single Response
        return buildSingleResponse(finalJson);
    }

    // Helper to group by a parent field
    private static Map<Id, List<SObject>> groupById(List<SObject> records, SObjectField parentField) {
        Map<Id, List<SObject>> results = new Map<Id, List<SObject>>();
        for (SObject record : records) {
            Id parentId = (Id) record.get(parentField);
            if (parentId == null) continue;
            if (!results.containsKey(parentId)) {
                results.put(parentId, new List<SObject>());
            }
            results.get(parentId).add(record);
        }
        return results;
    }

    // Helper to build a single Response
    private static List<Response> buildSingleResponse(String jsonString) {
        Response r = new Response();
        r.Prompt = jsonString;
        return new List<Response>{ r };
    }

    // Invocable return type
    public class Response {
        @InvocableVariable
        public String Prompt;
    }
}