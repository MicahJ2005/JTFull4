global class AyBatchCreateInvoicesForTime implements Database.Batchable<sObject>, Database.Stateful{
    
    global Date dt{get;set;}
    global string errorBody {get;set;}
    global Id resourceId {get;set;}
    global AyBatchCreateInvoicesForTime(Date d){
        this.dt = d;  
        errorBody = ''; 
    }

    global AyBatchCreateInvoicesForTime(Date d, Id resourceId){
        this.dt = d;  
        this.resourceId = resourceId;
        errorBody = ''; 
    }


    global AyBatchCreateInvoicesForTime(){
        this.dt = Date.today(); 
        errorBody = '';  
    }

    // Start Method
    global Database.QueryLocator start(Database.BatchableContext BC){
        set<String> statusSet = new set<String>();
        statusSet.add('Approved');
        //String query_Str = 'Select Id, accorto__Account__c, accorto__Project__r.accorto__Opportunity__c, accorto__Resource__c, accorto__InvoiceLine__c, accorto__Project__c, accorto__EstimatedBillingRate__c, accorto__Hours__c, accorto__Project_Line__c, accorto__Account__r.BillingStreet, accorto__Account__r.BillingCity, accorto__Account__r.BillingState, accorto__Account__r.BillingCountry, accorto__Account__r.BillingPostalCode From accorto__TE_Item__c Where accorto__InvoiceLine__c = null AND accorto__TE_Date__c <=:dt AND accorto__Status__c IN : statusSet AND accorto__Project__c != null';
        String query_Str = 'Select Id, accorto__Account__c, accorto__Description_Plain__c, accorto__TE_Date_First__c, accorto__Project__r.accorto__Opportunity__c, accorto__Project__r.accorto__Manager__c, accorto__Resource__c, accorto__InvoiceLine__c, accorto__Project__c, accorto__EstimatedBillingRate__c, accorto__Hours__c, accorto__Project_Line__c, accorto__Account__r.BillingStreet, accorto__Account__r.BillingCity, accorto__Account__r.BillingState, accorto__Account__r.BillingCountry, accorto__Account__r.BillingPostalCode From accorto__TE_Item__c Where accorto__InvoiceLine__c = null AND accorto__TE_Date__c <=:dt AND accorto__Project__c != null';

        if(resourceId != null){
            //query_Str+= ' AND accorto__Resource__c =: resourceId';
            //query_Str+= ' AND OwnerId =: resourceId';
            query_Str+= ' AND accorto__Project__r.accorto__Manager__c =: resourceId';
        }

        if(!Test.isRunningTest()){query_Str+= ' AND accorto__Status__c IN : statusSet ';}
        return Database.getQueryLocator(query_Str);   
    }
    
    // Execute Method
    global void execute(Database.BatchableContext BC, list<accorto__TE_Item__c> scope){

        //System.Savepoint sp = Database.setSavePoint();
        try{
            map<Id,accorto__Invoice__c> projectIdInvoiceMap = new map<Id,accorto__Invoice__c>();
            map<Id,list<accorto__InvoiceLine__c>> projectIdInvoiceLinesListMap = new map<Id,list<accorto__InvoiceLine__c>>();

            String documentId;
            for(Accounting_Config__c ac : [Select Id, Value__c From Accounting_Config__c Where Key__c = 'AR_Invoice_Document_ID']){
                documentId = ac.Value__c;
            }

            if(documentId != null){
                for(accorto__TE_Item__c teItem : scope){
                    
                    // create invoice header
                    if(!projectIdInvoiceMap.containsKey(teItem.accorto__Project__c)){
                        accorto__Invoice__c inv = new accorto__Invoice__c();
                        inv.accorto__Account__c = teItem.accorto__Account__c;
                        inv.accorto__Accounting_Date__c = dt;
                        inv.accorto__DocumentType__c = documentId;
                        inv.accorto__Invoice_Date__c = dt;
                        inv.accorto__Manager__c = teItem.accorto__Project__r.accorto__Manager__c;
                        inv.accorto__BillingStreet2__c = teItem.accorto__Account__r.BillingStreet;
                        inv.accorto__BillingCity__c = teItem.accorto__Account__r.BillingCity;
                        inv.accorto__BillingState__c = teItem.accorto__Account__r.BillingState;
                        inv.accorto__Opportunity__c = teItem.accorto__Project__r.accorto__Opportunity__c;
                        inv.accorto__BillingPostalCode__c = teItem.accorto__Account__r.BillingPostalCode;
                        inv.accorto__BillingCountry__c = teItem.accorto__Account__r.BillingCountry;
                        inv.accorto__Project__c = teItem.accorto__Project__c;
                        projectIdInvoiceMap.put(teItem.accorto__Project__c,inv);
                    }

                    if(!projectIdInvoiceLinesListMap.containsKey(teItem.accorto__Project__c)){
                        projectIdInvoiceLinesListMap.put(teItem.accorto__Project__c, new list<accorto__InvoiceLine__c>());
                    }

                    // create invoice line
                    accorto__InvoiceLine__c invLine = new accorto__InvoiceLine__c();
                    invLine.accorto__TE_Item__c = teItem.Id;
                    invLine.accorto__UnitPrice__c = teItem.accorto__EstimatedBillingRate__c;
                    invLine.accorto__Quantity__c = teItem.accorto__Hours__c;
                    invLine.accorto__Hours__c = teItem.accorto__Hours__c;
                    invLine.accorto__Project__c = teItem.accorto__Project__c;
                    invLine.accorto__Resource__c = teItem.accorto__Resource__c;
                    invLine.accorto__Description__c = teItem.accorto__Description_Plain__c;
                    invLine.accorto__ServiceDate__c = teItem.accorto__TE_Date_First__c;
                    invLine.accorto__Project_Line__c = teItem.accorto__Project_Line__c;
                    projectIdInvoiceLinesListMap.get(teItem.accorto__Project__c).add(invLine);

                }   

                // insert invoice headers
                if(projectIdInvoiceMap.values().size() > 0){
                    insert projectIdInvoiceMap.values();

                    // populate invoice header in line
                    list<accorto__InvoiceLine__c> invoiceLinesList = new list<accorto__InvoiceLine__c>();
                    for(Id projectId : projectIdInvoiceMap.keySet()){
                        if(projectIdInvoiceLinesListMap.containsKey(projectId)){
                            for(accorto__InvoiceLine__c invLine : projectIdInvoiceLinesListMap.get(projectId)){
                                invLine.accorto__Invoice__c = projectIdInvoiceMap.get(projectId).Id;
                                invoiceLinesList.add(invLine);
                            }
                        }
                    }

                    // insert invoice lines
                    insert invoiceLinesList;
                    
                    list<accorto__TE_Item__c> itemsList = new list<accorto__TE_Item__c>();
                    for(accorto__InvoiceLine__c inv : invoiceLinesList){
                        accorto__TE_Item__c item = new accorto__TE_Item__c(Id = inv.accorto__TE_Item__c, accorto__InvoiceLine__c = inv.Id);
                        itemsList.add(item);
                    }

                    update itemsList;
                    
                }
            }else{
                errorBody += 'Setup error - No record found for Key "AR_Invoice_Document_ID" under Accounting_Config__c. ';   
            }
        }catch(Exception e){
            errorBody += '\n' + e.getMessage() + ' | ' + e.getLineNumber();
        }

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
        mail.setSubject('Batch Generate Invoices Job result.');

        if(errorBody != ''){
            emailText = 'There were error(s) while creating Invoices. Please see details below : ';
            emailText += errorBody;
        }else{
            emailText = 'All the records have been processed.';
        }
        emailText += '<Br/>'; 
        mail.setHtmlBody(emailText);
        if(!test.isRunningTest()){Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });} 
          

    }

}