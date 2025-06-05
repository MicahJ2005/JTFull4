/***
 * @description : Trigger to handle DML on AcctSeed Billing
 * @author      : prateek@ayodia 
 * @contents    : 
 ***/
trigger AyBillingTrigger on AcctSeed__Billing__c (after update, after delete){
    

    // to handle billing post
    if(trigger.isUpdate){
        set<Id> accountIds_toSettleBill = new set<Id>();
        set<Id> billingIds_toSettleBill = new set<Id>();
        for(AcctSeed__Billing__c bill : trigger.new){
            if(bill.AcctSeed__Status__c == 'Posted' && trigger.oldMap.get(bill.Id).AcctSeed__Status__c != 'Posted'){
                // check if bill is created against hardcost payable or not
                if(bill.Accorto_Invoice__c != null){
                    accountIds_toSettleBill.add(bill.AcctSeed__Customer__c);
                }else if(bill.Payable__c != null ){
                    billingIds_toSettleBill.add(bill.Id);
                }
            }
        }
        // settle with Open CRs 
        if(accountIds_toSettleBill.size() > 0){
            AyAccountingFunctions.autoApplyCR(accountIds_toSettleBill);
        }
        // settle with trust balance
        if(billingIds_toSettleBill.size() > 0){
            AyTrustBalanceHandler.handleHardcostBillSettlement(billingIds_toSettleBill);
        }
    }
    
    /*
    @author       :  Shubham@Ayodia
    @date         :  13May,2021
    @description  :  Trigger to Rollup BillingBalance on Matter
    */
    
    // Variable declaration
    Set<Id> matterIds = new Set<Id>();
    Set<Id> matterIds_forCreditMemo = new Set<Id>();
    if(trigger.isUpdate && trigger.isAfter){ 
        for(AcctSeed__Billing__c bill : trigger.new){
            if(bill.Matter__c != null){
                AcctSeed__Billing__c oldVals = trigger.oldMap.get(bill.Id);
                if( (bill.AcctSeed__Balance__c != oldVals.AcctSeed__Balance__c && bill.AcctSeed__Status__c == 'Posted' && bill.AcctSeed__Type__c != 'Credit Memo') 
                   || (bill.AcctSeed__Status__c == 'Posted' && oldVals.AcctSeed__Status__c != 'Posted' && bill.AcctSeed__Type__c != 'Credit Memo')
                   || (bill.AcctSeed__Status__c != 'Posted' && oldVals.AcctSeed__Status__c == 'Posted' && bill.AcctSeed__Type__c != 'Credit Memo')){
                    System.debug('****Billing Name==='+bill.Name);
                    matterIds.add(bill.Matter__c);
                }
                if( (bill.AcctSeed__Balance__c != oldVals.AcctSeed__Balance__c && bill.AcctSeed__Status__c == 'Posted' && bill.AcctSeed__Type__c == 'Credit Memo') 
                   || (bill.AcctSeed__Status__c == 'Posted' && oldVals.AcctSeed__Status__c != 'Posted' && bill.AcctSeed__Type__c == 'Credit Memo')
                   || (bill.AcctSeed__Status__c != 'Posted' && oldVals.AcctSeed__Status__c == 'Posted' && bill.AcctSeed__Type__c == 'Credit Memo')){
                    System.debug('****Memo Name==='+bill.Name);
                    matterIds_forCreditMemo.add(bill.Matter__c);   
                }
            }
        }
    }
    
    if(trigger.isDelete && trigger.isAfter){
        for(AcctSeed__Billing__c bill :trigger.old){
            if(bill.Matter__c != null){
                matterIds.add(bill.Matter__c);
                matterIds_forCreditMemo.add(bill.Matter__c);
            }
        }
    }
    
    if(matterIds.size() > 0){
        /*AyCustomRollupHandler.balanceRollupOnMatter(matterIds);
        AyCustomRollupHandler.currentBalanceRollupOnMatter(matterIds);
        AyCustomRollupHandler.hardCostBalanceRollupOnMatter(matterIds);*/
        AyCustomRollupHandler.populateDataOnMatter(matterIds);
        AyCustomRollupHandler.billingTotalRollupOnMatter(matterIds);
    }
    
    if(matterIds_forCreditMemo.size() > 0 ){
        AyCustomRollupHandler.creditMemoBalRollupOnMatter(matterIds_forCreditMemo);
    }
       
}