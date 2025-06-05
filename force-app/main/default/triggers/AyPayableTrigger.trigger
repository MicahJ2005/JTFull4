/***
* @description : Trigger to handle DML on AcctSeed Payable
* @author      : prateek@ayodia 
* @contents    : 
***/
trigger AyPayableTrigger on AcctSeed__Account_Payable__c (after update){
    
    // on record posting
    // create hardcost bills
    // handle unposting of Payable
    // delete trust activity statement for Payable and Payable line
    if(trigger.isAfter && trigger.isUpdate){
        set<Id> payableIds_forPosting = new set<Id>();
        list<AcctSeed__Account_Payable__c> payableList_forUnposting = new list<AcctSeed__Account_Payable__c>();
        
        for(AcctSeed__Account_Payable__c pay : trigger.new){
            if(pay.Matter__c != null && pay.Hardcost__c){
                if(pay.AcctSeed__Status__c == 'Posted' && trigger.oldMap.get(pay.Id).AcctSeed__Status__c != 'Posted'){
                    payableIds_forPosting.add(pay.Id);
                    // }else if(pay.AcctSeed__Status__c != 'Posted' && trigger.oldMap.get(pay.Id).AcctSeed__Status__c == 'Posted'){
                    //  payableList_forUnposting.add(pay);
                }   
            }        
        }
        
        if(payableIds_forPosting.size() > 0){ 
            AyAccountingFunctions.handlePayablepost(payableIds_forPosting);    
        }
        /*
        if(payableList_forUnposting.size() > 0){
            AyTrustBalanceHandler.handlePayableUnpost(payableList_forUnposting);
        }
        */
    }
    if(trigger.isAfter && trigger.isUpdate){
       list<AcctSeed__Account_Payable__c> payableList = new list<AcctSeed__Account_Payable__c>();
		for(AcctSeed__Account_Payable__c pay : trigger.new){
            if(pay.Matter__c != null){
                if(pay.AcctSeed__Status__c == 'Posted' && trigger.oldMap.get(pay.Id).AcctSeed__Status__c != 'Posted'){
                    payableList.add(pay);
                    
                }   
            }        
        }
        if(payableList.size() > 0){
            AyAccountingFunctions.handletotalpayabletoclient(payableList);
        }
        
    }
    
}