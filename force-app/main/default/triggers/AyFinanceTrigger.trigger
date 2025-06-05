trigger AyFinanceTrigger on Finance__c (after update){
    if(trigger.isAfter && trigger.isUpdate){
        set<Id> financeIds = new set<Id>();
        for(Finance__c fin : trigger.new){
            if(fin.Create_Accounting__c && !trigger.oldMap.get(fin.Id).Create_Accounting__c){
                financeIds.add(fin.Id);
            }
        }

        if(financeIds.size() > 0){
            AyFinanceHandler.createFinanceAccounting(financeIds);
        }
    }
}