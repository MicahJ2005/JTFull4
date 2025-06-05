trigger AyTrustAccountActivityTrigger on Trust_Account_Activity__c (before insert, before update) {
    
    // to set a -ve withdrawl as deposit
    // to set a -ve deposit as withdrawl
    if(trigger.isBefore && (trigger.isInsert || trigger.isUpdate)){
        for(Trust_Account_Activity__c taa : trigger.new){
            if(taa.Withdrawal__c < 0){
                taa.Deposit__c = taa.Withdrawal__c * (-1);
                taa.Withdrawal__c = null;
            }
            
            if(taa.Deposit__c < 0){
                taa.Withdrawal__c = taa.Deposit__c * (-1);
                taa.Deposit__c = null;
            }
        }
    }
}