trigger AyOpportunityTrigger on Opportunity (after update, before delete){

    if(trigger.isAfter && trigger.isUpdate){
        map<Id,Id> oppIdMatterIdMap = new map<Id,Id>();
        set<Id> matterIds_forTaskCalc = new set<Id>();
        for(Opportunity op : trigger.new){

            if(op.Create_Billing__c && trigger.oldMap.get(op.Id).Create_Billing__c == false && op.Next_Step_Matter__c != null){
                oppIdMatterIdMap.put(op.Id, op.Next_Step_Matter__c);    
            }

            if(op.StageName == 'Closed Won' && trigger.oldMap.get(op.Id).StageName != 'Closed Won' && op.Next_Step_Matter__c != null){
                matterIds_forTaskCalc.add(op.Next_Step_Matter__c);
            }else if(op.StageName != 'Closed Won' && trigger.oldMap.get(op.Id).StageName == 'Closed Won' && op.Next_Step_Matter__c != null){
                matterIds_forTaskCalc.add(op.Next_Step_Matter__c);
            }
        }
        
        if(oppIdMatterIdMap.size() > 0){
            AyAccountingFunctions.createBillsFromOpportunity(oppIdMatterIdMap); 
        }

        if(matterIds_forTaskCalc.size() > 0){   
            AyTaskhandler.handleTaskHourCalculations(matterIds_forTaskCalc);
        }
    }
    
    
    /*
    @author       :  Shubham@Ayodia
    @date         :  26Aug,2021
    @description  :  Trigger to Rollup OpportunityPrice on Matter
    */
    
    /*
    // Variable declaration

    Set<Id> oppIds = new Set<Id>();
    
    if(trigger.isUpdate && trigger.isAfter){ 
        Set<Id> oppIdsToQuery = new Set<Id>();
        for(Opportunity opp : trigger.new){
            oppIdsToQuery.add(opp.Id);
        }
        
        map<Id, Id> oppIdRelatedOppIdMap = new map<Id,Id>();
        for(Opportunity opp : [Select id, Next_Step_Matter__r.AcctSeed__Opportunity__c From Opportunity Where Id IN : oppIdsToQuery]){
            if(opp.Next_Step_Matter__r.AcctSeed__Opportunity__c != null){
	            oppIdRelatedOppIdMap.put(opp.Id, opp.Next_Step_Matter__r.AcctSeed__Opportunity__c);	
            }
        }
        
        for(Opportunity opp : trigger.new){
            Opportunity oldVals = trigger.oldMap.get(opp.Id);

            if(oldVals.Amount != opp.Amount){
            	oppIds.add(opp.Id);    
                if(opp.Next_Step_Matter__r.AcctSeed__Opportunity__c != null){
                    if(oppIdRelatedOppIdMap.containsKey(opp.Id)){
                    	oppIds.add(oppIdRelatedOppIdMap.get(opp.Id));    
                    }    
                }
            }
                
        }
    }
    
    if(trigger.isDelete && trigger.isBefore){
        for(Opportunity opp :trigger.old){
            if(opp.Next_Step_Matter__c != null){
                oppIds.add(opp.Next_Step_Matter__r.AcctSeed__Opportunity__c);
            }
            oppIds.add(opp.Id);
        }
    }
    
    if(oppIds.size() > 0){
        AyCustomRollupHandler.oppPriceRollupOnMatter(oppIds);
    }
    */
    
}