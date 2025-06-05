trigger AyCPATrigger on Customer_Products_Approval__c (after update){

    if(trigger.isUpdate){
        set<Id> cpaIds = new set<Id>();
        for(Customer_Products_Approval__c  cpa : trigger.new){
            if(cpa.DocuSign_Signature_Complete__c && !trigger.oldMap.get(cpa.Id).DocuSign_Signature_Complete__c && cpa.Down_Payment__c != null && cpa.Down_Payment__c > 0 && cpa.Payment_Method_Token__c != null){
                //AyCPATriggerHandler.chargeDownpayment(cpa.Id);
            }
        }

    }
}