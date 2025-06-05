trigger AyAccortoProjectTrigger on accorto__Project__c (after insert) {
    if(trigger.isAfter && trigger.isInsert){
        set<Id> accortoProjectIds = new set<Id>();
        for(accorto__Project__c aProj : trigger.new){
            if(aProj.accorto__Opportunity__c != null){  //aProj.Matter__c != null && 
                accortoProjectIds.add(aProj.Id);
            }
        }
        //System.debug('****AyAccortoProjectTrigger***accortoProjectIds=='+accortoProjectIds);
        if(accortoProjectIds.size() > 0){
            AyAccortoProjectHandler.createAccortoProjectLines(accortoProjectIds);
        }
    }
}