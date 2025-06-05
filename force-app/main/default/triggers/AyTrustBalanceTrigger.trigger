trigger AyTrustBalanceTrigger on Trust_Balance__c (before insert, after insert, after update){

    // to populate prior month trust balance
    if(trigger.isBefore && trigger.isInsert){
        set<Id> matterIds = new set<Id>();
        for(Trust_Balance__c tbal : trigger.new){
            matterIds.add(tbal.Matter__c);
        }

        map<Id,Id> previousTrustBalanceMap = new map<Id,Id>();
        for(Trust_Balance__c prev : [Select Id, Matter__c From Trust_Balance__c Where Matter__c IN : matterIds AND Accounting_Period__c != null Order By Accounting_Period__r.AcctSeed__Start_Date__c ASC]){
            previousTrustBalanceMap.put(prev.Matter__c, prev.Id);
        }

        for(Trust_Balance__c tbal : trigger.new){
            if(previousTrustBalanceMap.containsKey(tbal.Matter__c) && tbal.Prior_Month_Trust_Balance__c == null){
                tbal.Prior_Month_Trust_Balance__c = previousTrustBalanceMap.get(tbal.Matter__c);
            }
        }
    }

    // to populate latest trust balance on Matter
    if(trigger.isAfter && trigger.isInsert){
        AyTrustBalanceHandler.populateLatestTrustBalanceOnMatter(trigger.new);
        AyTrustBalanceHandler.handlePreviousMonthTrustBalance(trigger.new);
    }

    // to create JE for movement of money when trust balance is closed
    // to delete JE for movement of money when trust balance is opened 
    if(trigger.isAfter && trigger.isUpdate){
        AyTrustBalanceHandler.handleTrustBalanceOpenClose(trigger.new, trigger.oldMap);
    }   
}