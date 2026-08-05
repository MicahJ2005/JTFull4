trigger EmailMessageTrigger on EmailMessage (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        // Gate execution behind Custom Metadata setting: Email_Trigger_Setting__mdt.Email_Trigger_Active__c == true
        Boolean isActive = false;
        try {
            // Assuming a single-row setting. Adjust WHERE clause if you store multiple rows by key.
            Email_Trigger_Setting__mdt setting = [
                SELECT Active__c
                FROM Email_Trigger_Setting__mdt
                LIMIT 1
            ];
            isActive = (setting != null && setting.Active__c == true);
        } catch (Exception e) {
            // If metadata is missing or query fails, default to not running to be safe
            isActive = false;
        }

        if (isActive || Test.isRunningTest()) {
            EmailMessageTriggerHandler.handleAfterInsert(Trigger.new);
        }
    }
}