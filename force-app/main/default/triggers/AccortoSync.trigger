/**
 * Sync Matter to Accorto Project
 */
trigger AccortoSync on AcctSeed__Project__c (before insert, before update, after insert) {

    // before insert/update
    if (Trigger.isBefore) {
        List<AcctSeed__Project__c> matters = new List<AcctSeed__Project__c>();
        for (AcctSeed__Project__c matter : Trigger.new) {
            if (matter.Project__c == null) {
                matters.add(matter);
            }
        }
        if (!matters.isEmpty()) {
            AccortoSyncMatter sync = new AccortoSyncMatter();
            sync.syncTrigger(matters);
        }
    }

    // after insert - update id
    if (Trigger.isAfter) {
        List<AcctSeed__Project__c> matters = new List<AcctSeed__Project__c>();
        for (AcctSeed__Project__c matter : Trigger.new) {
            if (matter.Project__c != null) {
                matters.add(matter);
            }
        }
        if (!matters.isEmpty()) {
            AccortoSyncMatter sync = new AccortoSyncMatter();
            sync.syncTriggerIds(matters);
        }
    }

} // AccortoSync