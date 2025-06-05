global class AyBatchCloseTrustBalance implements Database.Batchable<sObject>, Database.Stateful{

    global String errorBody {get;set;}
    global set<Id> tbIds {get;set;}
    public AyBatchCloseTrustBalance(set<Id> trustBalanceIds){
        errorBody = '';  
        this.tbIds = trustBalanceIds;  
    }

    // Start Method
    global Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'Select Id From Trust_Balance__c Where Id IN : tbIds';
        return Database.getQueryLocator(query);
    }
    
    // Execute Method
    // handle one record at a time.
    global void execute(Database.BatchableContext BC, list<Trust_Balance__c> scope){
        System.Savepoint sp = Database.setSavePoint();
        try{
            for(Trust_Balance__c tb : scope){
                tb.Status__c = 'Closed';
                update tb;
            }
        }catch(Exception e){errorBody += scope[0].Id + ' : ' + e.getMessage() + ' | ' + e.getLineNumber();
            Database.rollback(sp);}
    }   
     
    // Finish Method
    global void finish(Database.BatchableContext BC) {
        
        if(errorBody != '' || test.isRunningTest()){
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
            emailText = 'There were following error(s) while processing. Please see details below : ';
            emailText += '<Br/>'; 
            mail.setHtmlBody(errorBody);
            if(!test.isRunningTest()){
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            } 
        } 
    }
}