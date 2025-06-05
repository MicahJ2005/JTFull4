trigger AyFinanceOpportunityTrigger on Finance_Opportunity__c (after insert, after update){
    
    // 1. populate rollup values
    if(trigger.isAfter && (trigger.isInsert || trigger.isUpdate)){
        set<Id> fopIds = new set<Id>();
        for(Finance_Opportunity__c fop : trigger.new){
            if(trigger.isInsert){
                if(fop.Opportunity__c != null){
                     fopIds.add(fop.Id);   
                }
            }
            
            if(trigger.isUpdate){
                if( (trigger.oldMap.get(fop.Id).Opportunity__c == null && fop.Opportunity__c != null) 
                    || (trigger.oldMap.get(fop.Id).Matter__c == null && fop.Matter__c != null)){
                    fopIds.add(fop.Id);   
                }
            }
        }
        
        if(fopIds.size() > 0){
            AyFinanceHandler.populateRollupValues(fopIds);
        }
    }
       
}