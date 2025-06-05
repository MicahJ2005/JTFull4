/***
 * @description : trigger to handle DML on accorto__Invoice__c
 * @author      : prateek@ayodia 
 * @contents    : 
 *                1. Create Bills & Reverse Bills
 ***/
trigger AyInvoiceTrigger on accorto__Invoice__c (after update){

    // 1. Create Bills & Reverse Bills
    if(trigger.isAfter && trigger.isUpdate){
        set<Id> invoiceIds_toCreateBills = new set<Id>();
        list<accorto__Invoice__c> invoiceList_toReverseBills = new list<accorto__Invoice__c>();
        for(accorto__Invoice__c inv : trigger.new){
            if(inv.Create_Billing__c && !trigger.oldMap.get(inv.Id).Create_Billing__c){
                invoiceIds_toCreateBills.add(inv.Id);    
            }else if(!inv.Create_Billing__c && trigger.oldMap.get(inv.Id).Create_Billing__c){
                invoiceList_toReverseBills.add(inv);
            }
        }
        
        if(invoiceIds_toCreateBills.size() > 0){
            AyAccountingFunctions.createBillingFromAccortoInvoice(invoiceIds_toCreateBills);
        }
        
        if(invoiceList_toReverseBills.size() > 0){
            AyAccountingFunctions.reverseBillingsOfAccortoInvoice(invoiceList_toReverseBills);
        }
    }

}