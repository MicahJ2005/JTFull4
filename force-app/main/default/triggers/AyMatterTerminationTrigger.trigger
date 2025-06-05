trigger AyMatterTerminationTrigger on Matter_Termination__c (before insert, after update){
    
    // code block to prepopulate rollup values
    if(trigger.isBefore && trigger.isInsert){
        set<Id> matterIds = new set<Id>();
        set<Id> mtIds = new set<Id>();
        for(Matter_Termination__c mt : trigger.new){
            if(mt.Matter__c != null){
                matterIds.add(mt.Matter__c);
            }
            mtIds.add(mt.Id);
        }
        
        if(matterIds.size() > 0){

            /*map<Id,AggregateResult> objectMap = new map<Id,AggregateResult>();
            for(AggregateResult ag : [Select Matter__c, SUM(AcctSeed__Total__c) total, SUM(AcctSeed__Received_Amount__c) rcvd From AcctSeed__Billing__c Where Matter__c IN : matterIds AND Matter__c != null GROUP BY Matter__c]){
                Id matterId = (ID) ag.get('Matter__c');
                objectMap.put(matterId, ag);    
            }
            
            map<Id,Decimal> matterIdhardCostAmountMap = new map<Id,Decimal>();
            for(AggregateResult ag : [Select Matter__c, SUM(AcctSeed__Total__c) hcost From AcctSeed__Billing__c Where Matter__c IN : matterIds AND Matter__c != null AND Payable__c != null GROUP BY Matter__c]){
                Id matterId = (ID) ag.get('Matter__c');
                matterIdhardCostAmountMap.put(matterId, (Decimal) ag.get('hcost'));    
            }
            
            for(Matter_Termination__c mt : trigger.new){
                if(mt.Matter__c != null && objectMap.containsKey(mt.Matter__c)){
                    AggregateResult obj = objectMap.get(mt.Matter__c);
                    mt.Total_Billed_Amount__c = (Decimal) obj.get('total');
                    mt.Total_Received__c = (Decimal) obj.get('rcvd');
                    if(matterIdhardCostAmountMap.containsKey(mt.Matter__c)){
                        mt.Total_Hardcost_Billing_Amount__c = matterIdhardCostAmountMap.get(mt.Matter__c);
                    }
                }
            }*/

            map<Id,AyAccountingFunctions.AccountingWrapper> matterIdAccountingMap = new map<Id,AyAccountingFunctions.AccountingWrapper>();
            matterIdAccountingMap = AyAccountingFunctions.getAccountingDetailsMap(matterIds);

            for(Matter_Termination__c mt : trigger.new){
                if(mt.Matter__c != null && matterIdAccountingMap.containsKey(mt.Matter__c)){
                    AyAccountingFunctions.AccountingWrapper w = matterIdAccountingMap.get(mt.Matter__c);
                    mt.Total_Billed_Amount__c = w.totalBilledAmount;
                    mt.Total_Received__c = w.totalReceivedAmount;
                    mt.Total_Hardcost_Billing_Amount__c = w.totalHarcostBillingAmount;
                }
            }

        }
    }
    
    // code block to handle accounting
    // handles one record at a time
    if(trigger.isAfter && trigger.isUpdate && trigger.new.size() == 1){
        for(Matter_Termination__c mt : trigger.new){
            if(mt.Create_Accounting__c && !trigger.oldMap.get(mt.Id).Create_Accounting__c){
                if(mt.Termination_Type__c == 'Standard Opportunity'){
                    System.debug('****AyMatterTerminationTrigger***AyAccountingFunctions.handleStandardTermination***');
                    AyAccountingFunctions.handleStandardTermination(mt.Id);
                }else if(mt.Termination_Type__c == 'Next Step Opportunity'){
                    System.debug('****AyMatterTerminationTrigger***AyAccountingFunctions.handleNextStepTermination***');
                    AyAccountingFunctions.handleNextStepTermination(mt.Id);
                }
            }
        }
    
    }
    
    /*set<Id> mtIds = new set<Id>();
    if(trigger.isAfter && trigger.isUpdate){
        for(Matter_Termination__c mt : trigger.new){
            if(mt.Termination_Status__c == 'Completed' && trigger.oldMap.get(mt.Id).Termination_Status__c != 'Completed'){
                mtIds.add(mt.Id);  
            }
        }
    }
    System.debug('****AyMatterTerminationTrigger***mtIds='+mtIds);
    if(mtIds.size()>0){
        AyMatterTermStatusCompleted.updateCaseStatusToTerminated(mtIds);
    }*/
    
}