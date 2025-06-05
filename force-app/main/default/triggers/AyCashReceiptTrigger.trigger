/***
 * @description : Trigger to handle DML on AcctSeed Cash Receipt
 * @author      : prateek@ayodia 
 * @contents    : 
 ***/
trigger AyCashReceiptTrigger on AcctSeed__Cash_Receipt__c (before insert, after update){

    // populate matter
    if(trigger.isBefore && trigger.isInsert){
        // get account details
        set<Id> accountIds = new set<Id>();
        for(AcctSeed__Cash_Receipt__c cr : trigger.new){
            accountIds.add(cr.AcctSeed__Account__c);     
        }
        
        // check if there exists only one open matter against one account
        // all the open bills should belong to the same matter against same customer
        map<Id,Id> accountIdMatterIdMap = new map<Id,Id>();
        map<Id,Boolean> accountIdIsSameMatterMap = new map<Id,Boolean>();
        for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Customer__c, Matter__c From AcctSeed__Billing__c Where AcctSeed__Customer__c IN : accountIds AND AcctSeed__Status__c = 'Posted' AND AcctSeed__Balance__c > 0 AND Matter__c != null]){
            if(accountIdMatterIdMap.containsKey(bill.AcctSeed__Customer__c)){
                if(accountIdMatterIdMap.get(bill.AcctSeed__Customer__c) != bill.Matter__c){
                    accountIdIsSameMatterMap.put(bill.AcctSeed__Customer__c, false);
                }
            }else{
                accountIdMatterIdMap.put(bill.AcctSeed__Customer__c, bill.Matter__c);
                accountIdIsSameMatterMap.put(bill.AcctSeed__Customer__c, true);    
            }
        }

        // populate matter now
        for(AcctSeed__Cash_Receipt__c cr : trigger.new){
            if(accountIdIsSameMatterMap.containsKey(cr.AcctSeed__Account__c) && accountIdMatterIdMap.containsKey(cr.AcctSeed__Account__c)){
                if(accountIdIsSameMatterMap.get(cr.AcctSeed__Account__c)){
                    cr.AcctSeed__Project__c =  accountIdMatterIdMap.get(cr.AcctSeed__Account__c);
                }
            }    
        }
    }
   
    // handle auto apply of cash receipt
    if(trigger.isAfter && trigger.isUpdate){
        set<Id> crAccountIds_toAutoApply = new set<Id>();
        set<Id> crAccountIds_toAutoApplyFinanceCR = new set<Id>();
        set<Id> crIds = new set<Id>();
        for(AcctSeed__Cash_Receipt__c cr : trigger.new){
            if(cr.Auto_Apply__c && !trigger.oldMap.get(cr.Id).Auto_Apply__c){
                if(cr.Affinipay_Transaction__c == null){
                    crAccountIds_toAutoApply.add(cr.AcctSeed__Account__c);
                }else if(cr.Affinipay_Transaction__c != null){
                    crAccountIds_toAutoApplyFinanceCR.add(cr.AcctSeed__Account__c);
                }
                crIds.add(cr.Id);
            }   
        }

        // for non finance part
        if(crAccountIds_toAutoApply.size() > 0){
                AyAccountingFunctions.autoApplyCR(crAccountIds_toAutoApply);
                
                // revert auto apply checkbox to false
                list<AcctSeed__Cash_Receipt__c> crList_toUpdate = new list<AcctSeed__Cash_Receipt__c>();
                for(Id crId : crIds){
                    crList_toUpdate.add(new AcctSeed__Cash_Receipt__c(Id = crId, Auto_Apply__c = false)); 
                }

                update crList_toUpdate;
        }

        // to handle finance part
        if(crAccountIds_toAutoApplyFinanceCR.size() > 0){
            
            AyAccountingFunctions.autoApplyFinanceCR(crAccountIds_toAutoApplyFinanceCR);
            
            // revert auto apply checkbox to false
            list<AcctSeed__Cash_Receipt__c> crList_toUpdate = new list<AcctSeed__Cash_Receipt__c>();
            for(Id crId : crIds){
                crList_toUpdate.add(new AcctSeed__Cash_Receipt__c(Id = crId, Auto_Apply__c = false)); 
            }

            update crList_toUpdate;
        }
    }

    // handle cr amount on Matter
    set<Id> matterIds = new set<Id>();
    if(trigger.isAfter && trigger.isUpdate){    
        for(AcctSeed__Cash_Receipt__c cr : trigger.new){
            if(cr.AcctSeed__Project__c != null && cr.AcctSeed__Status__c == 'Posted' && trigger.oldMap.get(cr.Id).AcctSeed__Status__c != 'Posted' 
                || cr.AcctSeed__Project__c != null && cr.AcctSeed__Status__c != 'Posted' && trigger.oldMap.get(cr.Id).AcctSeed__Status__c == 'Posted'){
                    matterIds.add(cr.AcctSeed__Project__c);
            }
        }
    }

    if(trigger.isBefore && trigger.isDelete){
        for(AcctSeed__Cash_Receipt__c cr : trigger.old){
            matterIds.add(cr.AcctSeed__Project__c);
        }
    }
    
    if(matterIds.size() > 0){
        AyAccountingFunctions.rollUpCrAmountOnMatter(matterIds);
    }

   
}