trigger MatterTrigger on AcctSeed__Project__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
       MatterTriggerHandler.RelateCommunications(Trigger.newMap);
    }
}