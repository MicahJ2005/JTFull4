trigger LeadTrigger on Lead (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
