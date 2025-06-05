//batch size should always be 1 
public class AyBatchEmailTrustBalance implements Database.Batchable<sObject> , Database.stateful{
    
    public String errorMessage {get;set;}
    public Integer totalRecordsProcessed {get;set;}
    public Integer totalErrorRecords {get;set;}
    public set<Id> trustBalanceIdSet {get;set;}
    
    private EmailTemplate emailTemplate ;
    
    public AyBatchEmailTrustBalance(set<Id> trustBalanceIdSet){
        this.trustBalanceIdSet = trustBalanceIdSet;
        totalRecordsProcessed = 0;
        totalErrorRecords = 0;  
        errorMessage = ''; 
        emailTemplate = [SELECT Id, Name, HtmlValue, Body, DeveloperName FROM EmailTemplate LIMIT 1]; //where DeveloperName = 'Template'];
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC){
        set<Id> trustBalanceIdSetTemp = trustBalanceIdSet;
        return Database.getQueryLocator([Select Id, Name, Billing_Contact__c, Billing_Contact__r.Email, Accounting_Period__r.Name From Trust_Balance__c Where Id IN : trustBalanceIdSetTemp]);
    }
    
    public void execute(Database.BatchableContext info, list<Trust_Balance__c> scope){
        if(scope.size() != 1){
            // throw exception
        }

        System.Savepoint sp = Database.setSavePoint();
        try{
            totalRecordsProcessed ++;
            Trust_Balance__c tbal = scope[0];
            //fetch receipients 
            set<Id> recepientIds = new set<Id>();
    
            if(tbal.Billing_Contact__c != null && tbal.Billing_Contact__r.Email != null){
                recepientIds.add(tbal.Billing_Contact__c);
            }

            if(recepientIds.size() == 0){
                totalErrorRecords++;
                errorMessage += '<BR/>';
                errorMessage += 'No contacts found associated with Trust Balance to email Monthly Statement' + ' | ' + tbal.Name;
            }else{
                //send email 
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                Id orgEmailId ;
                for(OrgWideEmailAddress address : [SELECT Id FROM OrgWideEmailAddress Limit 1]){ //WHERE Address = 'abc@jtl.com']){
                    orgEmailId = address.Id;
                }

                if(orgEmailId != null){
                    mail.setOrgWideEmailAddressId(orgEmailId);
                    mail.setUseSignature(false);
                }

                //set to addresses
                list<String> recepientIdsList = new list<String>();
                for(Id s: recepientIds){
                    recepientIdsList.add(s);
                }
                mail.setToAddresses(recepientIdsList);
                mail.setTargetObjectId(tbal.Billing_Contact__c);
                mail.setTreatBodiesAsTemplate(true);

                //set template
                mail.setTemplateId(emailTemplate.Id);
                if(emailTemplate.HtmlValue != null){
                    mail.setHtmlBody(emailTemplate.HtmlValue);
                }
                if(emailTemplate.Body != null){
                    mail.setPlainTextBody(emailTemplate.Body);
                }
                //set subject
                mail.setSubject('Your Monthly Statement for '+ tbal.Accounting_Period__r.Name);
                //set what id
                //mail.setWhatId(tbal.Id);
                
                //set attachment 
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setFileName('Monthly Statement | '+ tbal.Accounting_Period__r.Name +'.pdf');
                efa.setContentType('application/pdf');
                //set attachment content

                PageReference pg = Page.AyMonthlyStatementPDF;
                pg.getParameters().put('id',tbal.Id);
                
                Blob content ;
                if(Test.isRunningTest()){
                    content = Blob.valueOf('Test');
                }else{
                    content =  pg.getContent();
                }
                efa.setBody(content);

                list<Messaging.EmailFileAttachment> attachmentList = new list<Messaging.EmailFileAttachment>();
                attachmentList.add(efa);
                mail.setFileAttachments(attachmentList);
                if(!Test.isRunningTest()){Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }); }

                tbal.Last_Statement_Sent_On__c = DateTime.now();
                update tbal;
            }             
        }catch(Exception e){
            totalErrorRecords++;
            Database.rollback(sp);
            errorMessage += '<BR/>';
            errorMessage += e.getMessage() + ' | ' + scope;
        }
    }
        
    public void finish(Database.BatchableContext info) { 
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            set<String> emailSet = new set<String>();
            emailSet.add([select Email from User where Id =:UserInfo.getUserId()].Email);

            list<String> toAddresses =  new list<String>(); 
            for(string e : emailSet){
                toAddresses.add(e);
            } 
            string emailText ;
            mail.setToAddresses(toAddresses);
            mail.setSubject('Monthly Statement Email Action Summary');

            emailText = 'Please find the detailed report below : '; 
            emailText += '<Br/>'; 
            emailText += '<Br/>'; 
            emailText += 'Total Records Processed : ' + totalRecordsProcessed; 
            emailText += '<Br/>'; 
            emailText += 'Total Records Failed : ' + totalErrorRecords; 
            if(errorMessage != null && errorMessage != ''){
                emailText += '<Br/>'; 
                emailText += 'There were error(s) while emailing Monthly statements . Please see details below : ';
                emailText += '<Br/>'; 
                emailText += errorMessage;
            }else{
                emailText += '<Br/>'; 
                emailText += 'All records processed successfully. '; 
            }
            
            mail.setHtmlBody(emailText);
            if(!Test.isRunningTest()){Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }); }
    }
}