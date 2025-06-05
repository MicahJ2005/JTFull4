trigger AyMatterTrigger on AcctSeed__Project__c (after insert) {

    if(Label.Enable_Matter_Billing.toLowerCase() == 'yes'){
        if(trigger.isAfter && trigger.isInsert){
            map<Id,Id> oppIdMatterIdMap = new  map<Id,Id>();
            set<Id> matterIds_forTrustBalance  = new set<Id>();
            for(AcctSeed__Project__c proj : trigger.new){
                matterIds_forTrustBalance.add(proj.Id);
                //System.debug('****AyMatterTrigger***proj.Opportunity_Rate_Type__c=='+proj.Opportunity_Rate_Type__c);
                if(proj.Opportunity_Rate_Type__c == 'Flat Fee' && proj.AcctSeed__Opportunity__c != null){
                    oppIdMatterIdMap.put(proj.AcctSeed__Opportunity__c, proj.Id);
                }
            }
            //System.debug('****AyMatterTrigger***oppIdMatterIdMap=='+oppIdMatterIdMap);
            if(oppIdMatterIdMap.size() > 0){
                AyAccountingFunctions.createBillsFromOpportunity(oppIdMatterIdMap);
            }
    
            // fire batch to create trust balances
            if(matterIds_forTrustBalance.size() > 0){
                AyBatchCreateTrustBalance b = new AyBatchCreateTrustBalance(matterIds_forTrustBalance);
                Database.executeBatch(b,1);
            }
        }
    }
    
}