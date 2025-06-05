trigger AyBillingCashReceiptTrigger on AcctSeed__Billing_Cash_Receipt__c (after insert) {
    
    // To create JE
    if(trigger.isAfter && trigger.isInsert){
        set<Id> bcrIds_toCreateJE = new set<Id>();
        for(AcctSeed__Billing_Cash_Receipt__c bcr : trigger.new){
            if(bcr.Is_SYS_Trust_Account_Activity__c){
                bcrIds_toCreateJE.add(bcr.Id);
            }
        }    
        
        if(bcrIds_toCreateJE.size() > 0){
            AyAccountingFunctions.createJEonBCRInsert(bcrIds_toCreateJE);        
        }
    }

}