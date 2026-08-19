trigger EventTrigger on Event (after insert) {
    List<TriggerActivation__mdt> activations = [
        SELECT Active__c
        FROM TriggerActivation__mdt
        WHERE Trigger_Class_Name__c = 'EventTrigger'
        LIMIT 1
    ];

    if (!activations.isEmpty() && !activations[0].Active__c) {
        return;
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        EventTriggerHandler.handleAfterInsert(Trigger.new);
    }
}