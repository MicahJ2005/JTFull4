global class AyBatchCreateTrustBalance implements Database.Batchable<sObject>, Database.Stateful{

    global String errorBody {get;set;}
    global set<Id> matterIds {get;set;}
    global date processingDate {get;set;}

    public AyBatchCreateTrustBalance(){
        errorBody = '';
        processingDate = Date.today();
    }

    public AyBatchCreateTrustBalance(Date processingDate){
        errorBody = '';
        this.processingDate = processingDate;
    }

    public AyBatchCreateTrustBalance(set<Id> matterIdSet){
        errorBody = ''; 
        processingDate = Date.today(); 
        this.matterIds = matterIdSet;  
    }

    public AyBatchCreateTrustBalance(set<Id> matterIdSet, Date processingDate){
        errorBody = ''; 
        this.processingDate = processingDate;
        this.matterIds = matterIdSet;  
    }

    // Start Method
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        String query = 'Select Id, AcctSeed__Account__c, AcctSeed__Opportunity__r.Rate_Type__c, AcctSeed__Account__r.AcctSeed__Billing_Contact__c From AcctSeed__Project__c where Create_Trust_Balance__c = true';

        set<Id> temp  = new set<Id>();
        temp = matterIds;
        if(temp != null && temp.size() > 0){
            query += ' AND Id IN : temp';
        }


        return Database.getQueryLocator(query);
    }
    
    // Execute Method
    // handle one record at a time.
    global void execute(Database.BatchableContext BC, list<AcctSeed__Project__c> scope){
        System.Savepoint sp = Database.setSavePoint();
        try{
            Date dt = processingDate;
            Id accountingPeriodId; 
            for(AcctSeed__Accounting_Period__c ap : [Select Id From AcctSeed__Accounting_Period__c Where AcctSeed__Start_Date__c <=: dt AND AcctSeed__End_Date__c >=: dt AND AcctSeed__Status__c = 'Open']){
                accountingPeriodId = ap.Id;
            }

            if(accountingPeriodId != null){
                map<Id,Id> matterIdAPIdMap = new map<Id,Id>();
                matterIdAPIdMap.put(scope[0].Id, accountingPeriodId);

                AyTrustBalanceHandler.handleTrustBalanceCreation(matterIdAPIdMap);
            }

            /*Trust_Balance__c tbal;
            for(Trust_Balance__c tb : [Select Id From Trust_Balance__c Where Matter__c =: scope[0].Id AND Accounting_Period__c =: accountingPeriodId]){
                tbal = tb;
            }

            if(tbal == null){
                tbal = new Trust_Balance__c();
                tbal.Matter__c = scope[0].Id;
                if(scope[0].AcctSeed__Account__c != null){
                    tbal.Account__c = scope[0].AcctSeed__Account__c;
                    tbal.Billing_Contact__c = scope[0].AcctSeed__Account__r.AcctSeed__Billing_Contact__c;
                }
                tbal.Accounting_Period__c = accountingPeriodId;
                tbal.Date_of_Trust_Account_Creation__c = Date.today();
                insert tbal;
            }

            set<Id> tbalSet = new set<Id>();
            tbalSet.add(tbal.Id);
            
            // for only flat fee
            if(scope[0].AcctSeed__Opportunity__r.Rate_Type__c == 'Flat Fee'){
                AyTrustBalanceHandler.createTrustActivityStatementFlatFee(tbalSet);
            }else{    // for hourly
                AyTrustBalanceHandler.createTrustActivityStatement(tbalSet);
            }*/

            
            
        }catch(Exception e){errorBody += scope[0].Id + ' : ' + e.getMessage() + ' | ' + e.getLineNumber();
            Database.rollback(sp);
        }
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
            mail.setSubject('Create Trust Balance Process');
            emailText = 'There were error(s) while creating Trust Balance records. Please see details below : ';
            emailText += '<Br/>'; 
            mail.setHtmlBody(emailText);
            if(!test.isRunningTest()){Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });} 
        }
    }
}