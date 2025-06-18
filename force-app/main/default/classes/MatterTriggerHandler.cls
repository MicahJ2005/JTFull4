public class MatterTriggerHandler {
    // public static void RelateCommunications(Map<Id, AcctSeed__Project__c> newMap) {
    //     Set<Id> accountIds = new Set<Id>();
    //     for (AcctSeed__Project__c matter : newMap.values()) {
    //         if (matter.AcctSeed__Account__c != null) {
    //             accountIds.add(matter.AcctSeed__Account__c);
    //         }
    //     }

    //     // Get all prior matters for the same account, excluding the newly inserted ones
    //     List<AcctSeed__Project__c> priorMatters = [
    //         SELECT Id, AcctSeed__Account__c, CreatedDate
    //         FROM AcctSeed__Project__c
    //         WHERE AcctSeed__Account__c IN :accountIds
    //         AND Id NOT IN :newMap.keySet()
    //         ORDER BY CreatedDate DESC
    //     ];

    //     // Map of AccountId -> most recent previous Matter
    //     Map<Id, AcctSeed__Project__c> mostRecentPriorMatterMap = new Map<Id, AcctSeed__Project__c>();
    //     for (AcctSeed__Project__c prior : priorMatters) {
    //         if (!mostRecentPriorMatterMap.containsKey(prior.AcctSeed__Account__c)) {
    //             mostRecentPriorMatterMap.put(prior.AcctSeed__Account__c, prior);
    //         }
    //     }

    //     List<SObject> newLinks = new List<SObject>();

    //     for (AcctSeed__Project__c newMatter : newMap.values()) {
    //         Id acctId = newMatter.AcctSeed__Account__c;
    //         if (acctId == null || !mostRecentPriorMatterMap.containsKey(acctId)) continue;

    //         AcctSeed__Project__c prevMatter = mostRecentPriorMatterMap.get(acctId);

    //         // Call Transcripts
    //         List<Related_Call_Transcript__c> prevCalls = [
    //             SELECT Id, Call_Transcript__c
    //             FROM Related_Call_Transcript__c
    //             WHERE Matter__c = :prevMatter.Id
    //         ];
    //         for (Related_Call_Transcript__c call : prevCalls) {
    //             newLinks.add(new Related_Call_Transcript__c(
    //                 Matter__c = newMatter.Id,
    //                 Call_Transcript__c = call.Call_Transcript__c
    //             ));
    //         }

    //         // Meeting Transcripts
    //         List<Related_Meeting_Transcript__c> prevMeetings = [
    //             SELECT Id, Meeting_Transcript__c
    //             FROM Related_Meeting_Transcript__c
    //             WHERE Matter__c = :prevMatter.Id
    //         ];
    //         for (Related_Meeting_Transcript__c meeting : prevMeetings) {
    //             newLinks.add(new Related_Meeting_Transcript__c(
    //                 Matter__c = newMatter.Id,
    //                 Meeting_Transcript__c = meeting.Meeting_Transcript__c
    //             ));
    //         }

    //         // Text Messages
    //         List<Related_Text_Message__c> prevTexts = [
    //             SELECT Id, Text_Message_Session__c
    //             FROM Related_Text_Message__c
    //             WHERE Matter__c = :prevMatter.Id
    //         ];
    //         for (Related_Text_Message__c text : prevTexts) {
    //             newLinks.add(new Related_Text_Message__c(
    //                 Matter__c = newMatter.Id,
    //                 Text_Message_Session__c = text.Text_Message_Session__c
    //             ));
    //         }
    //     }

    //     if (!newLinks.isEmpty()) {
    //         // insert newLinks;
    //     }
    // }
}
