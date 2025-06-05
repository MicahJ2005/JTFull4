global class AyBatchCreateBillFromInvoice implements Database.Batchable<sObject>, Database.Stateful{

    global String errorBody {get;set;}
    global set<Id> invIds {get;set;}
    public AyBatchCreateBillFromInvoice(set<Id> invoiceIds){
        errorBody = '';  
        this.invIds = invoiceIds;  
    }

    // Start Method
    global Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'Select Id From accorto__Invoice__c Where Id IN : invIds';
        return Database.getQueryLocator(query);
    }
    
    // Execute Method
    // handle one record at a time.
    global void execute(Database.BatchableContext BC, list<accorto__Invoice__c> scope){
        System.Savepoint sp = Database.setSavePoint();
        try{
            for(accorto__Invoice__c inv : scope){
                inv.Create_Billing__c = true;
                update inv;
            }
        }catch(Exception e){errorBody += scope[0].Id + ' : ' + e.getMessage() + ' | ' + e.getLineNumber();
            Database.rollback(sp);}
    }   
     
    // Finish Method
    global void finish(Database.BatchableContext BC) {
        
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        set<String> emailSet = new set<String>();
        emailSet.add([select Email from User where Id=:UserInfo.getUserId()].Email);
        list<String> toAddresses =  new list<String>(); 
        for(string e : emailSet){
            toAddresses.add(e);
        } 
        string emailText ;
        mail.setToAddresses(toAddresses);
        mail.setSubject('Trust Balance Closing Process');
        if(errorBody != ''){
            emailText = 'There were following error(s) while processing. Please see details below : ';
            emailText += errorBody;
        }else{
            emailText = 'All the records have been processed.';
        }
        emailText += '<Br/>'; 
        mail.setHtmlBody(errorBody);
        if(!test.isRunningTest()){Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });} 
         
    }
}