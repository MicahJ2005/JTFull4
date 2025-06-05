trigger AyTransactionTrigger on AcctSeed__Transaction__c (after insert, before delete) {

    if(Trigger.isAfter && Trigger.isInsert){
        map<Id,Id> matterIdAccountingPeriodIdMap = new map<Id,Id>();
        for(AcctSeed__Transaction__c tr : Trigger.new){
            if(tr.Matter_ID__c != null){
                matterIdAccountingPeriodIdMap.put(tr.Matter_ID__c, tr.AcctSeed__Accounting_Period__c);
            }
        }
        
        // sync trust balance
        if(matterIdAccountingPeriodIdMap.size() > 0){
            AyTrustBalanceHandler.handleTrustBalanceCreation(matterIdAccountingPeriodIdMap);
        }
    }

    if(Trigger.isBefore && Trigger.isDelete){
        set<Id> billingIds = new set<Id>();
        set<Id> payableIds = new set<Id>();
        set<Id> cdIds = new set<Id>();
        set<Id> crIds = new set<Id>();
        set<Id> bcrIds = new set<Id>();
        set<Id> jeLineIds = new set<Id>();

        for(AcctSeed__Transaction__c tr : Trigger.old){
            if(tr.AcctSeed__Billing__c != null){
                billingIds.add(tr.AcctSeed__Billing__c);
            }

            if(tr.AcctSeed__Account_Payable__c != null){
                payableIds.add(tr.AcctSeed__Account_Payable__c);
            }

            if(tr.AcctSeed__Cash_Receipt__c != null){
                crIds.add(tr.AcctSeed__Cash_Receipt__c);
            }

            if(tr.AcctSeed__Billing_Cash_Receipt__c != null){
                bcrIds.add(tr.AcctSeed__Billing_Cash_Receipt__c);
            }

            if(tr.AcctSeed__Cash_Disbursement__c != null){
                cdIds.add(tr.AcctSeed__Cash_Disbursement__c);
            }

            if(tr.AcctSeed__Journal_Entry_Line__c != null){
                jeLineIds.add(tr.AcctSeed__Journal_Entry_Line__c);
            }
        }    

        if(billingIds.size() > 0){
            AyTrustBalanceHandler.handleBillingUnpost(billingIds);
        }

        if(payableIds.size() > 0){
            AyTrustBalanceHandler.handlePayableUnpost(payableIds);
        }

        if(cdIds.size() > 0){
            AyTrustBalanceHandler.handleCDUnpost(cdIds);
        }

        if(crIds.size() > 0){
            AyTrustBalanceHandler.handleCRUnpost(crIds);
        }

        if(bcrIds.size() > 0){
            AyTrustBalanceHandler.handleBCRDelete(bcrIds);
        }

        if(jeLineIds.size() > 0){
            AyTrustBalanceHandler.handleJEUnpost(jeLineIds);
        }
    }
}