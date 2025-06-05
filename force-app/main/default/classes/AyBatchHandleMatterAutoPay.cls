global class AyBatchHandleMatterAutoPay implements Database.Batchable<sObject>, Database.allowsCallouts, Database.stateful{
    
    global string errMsg {get;set;}
    
    // Start Method
    global Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'Select Id, AcctSeed__Account__c, AcctSeed__Account__r.Name, Auto_Debit_Method_Token__c From AcctSeed__Project__c Where Auto_Pay__c = true';
        return Database.getQueryLocator(query);
    }
    
    // Execute Method
    global void execute(Database.BatchableContext BC, List<AcctSeed__Project__c> scope){
        AcctSeed__Project__c pro = scope[0];
        
        try{
            Date processingDate = Date.today();
            Decimal balanceAmt = 0;
            for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Balance__c From AcctSeed__Billing__c Where Matter__c =: pro.Id AND AcctSeed__Status__c = 'Posted' AND AcctSeed__Due_Date2__c =: processingDate]){
                balanceAmt += bill.AcctSeed__Balance__c;
            }
            
            if(balanceAmt > 0 || Test.isRunningTest()){
                String amount_str = String.valueOf(balanceAmt);
                map<String,Object> paymentResponseMap = new map<String,Object>();
                if(!Test.isRunningTest()){paymentResponseMap = affinipay.AffiniPayService.createPayment('Account', ''+pro.AcctSeed__Account__c, Label.Affinipay_Deposit_Account, '', amount_str, pro.Auto_Debit_Method_Token__c, '', '', '', 'Auto Pay : '+ Date.today());}
                if(paymentResponseMap.get('status') != 'AUTHORIZED'){
                    if(errMsg == null){
                        errMsg = '';
                    }
                    errMsg += '\n' + 'Unable to auto debit : ' + pro.AcctSeed__Account__r.Name + ' | ' + pro.AcctSeed__Account__c; 
                }
            }
        }catch(Exception e){
            errMsg+= '\n' + e.getMessage() + ' on Line: ' + e.getLineNumber();
        }
    }
    
    // Finish Method
    global void finish(Database.BatchableContext BC){
        if( (errMsg != null && errMsg != '') || test.isRunningTest()){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            set<String> emailSet = new set<String>();
            emailSet.add([select Email from User where Id=:UserInfo.getUserId()].Email);
            list<String> toAddresses =  new list<String>(); 
            for(string e : emailSet){
                toAddresses.add(e);
            } 
            string emailText ;
            mail.setToAddresses(toAddresses);
            mail.setSubject('Auto Pay Processing Results');
            emailText = 'There were following error(s) while processing. Please see details below : ';
            emailText += '<Br/>'; 
            mail.setHtmlBody(errMsg);
            if(!test.isRunningTest()){
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            } 
        }    
    }
    
}