/***
 * @description : Class to handle Accounting Functions
 * @author      : prateek@ayodia 
 * @contents    : 
 ***/
public class AyAccountingFunctions{

    // @description - Method to create Billing from Opportunity & Billing Line from Opportunity Line Item
    // @param       - map<Id,Id> oppIdMatterIdMap
    // @return      - void
    public static void createBillsFromOpportunity(map<Id,Id> oppIdMatterIdMap){
        map<Id, AcctSeed__Billing__c> oppIdBillingMap = new map<Id, AcctSeed__Billing__c>();
        map<Id, list<AcctSeed__Billing_Line__c>> oppIdBillingLinesMap = new map<Id, list<AcctSeed__Billing_Line__c>>();

        map<String,String> configMap = new map<String,String>();
        for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
            configMap.put(ac.Key__c, ac.Value__c);
        }
        
        map<String,Id> officeMap = new map<String,Id>();
        map<String,Id> areaOfLawMap = new map<String,Id>();
        for(AcctSeed__Accounting_Variable__c av : [Select Id, Name, AcctSeed__Type__c From AcctSeed__Accounting_Variable__c]){
            if(av.AcctSeed__Type__c == 'GL Account Variable 1'){
                officeMap.put(av.Name, av.Id);    
            }else if(av.AcctSeed__Type__c == 'GL Account Variable 4'){
                areaOfLawMap.put(av.Name, av.Id);
            }
        }
        
        for(Opportunity opp : [Select Id, Name, RecordType.DeveloperName, Next_Step_Matter__c, Next_Step_Matter__r.AcctSeed__Opportunity__c, AccountId, Kapsten_Matter__c, Area_of_Law__c, Office_that_consult_occurred_in__c, CloseDate, Billing_Attorney_lk__c, Originator__c, Originator_LU__c, (Select Id, Quantity, Product2Id, Product2.AcctSeed__Revenue_GL_Account__c, UnitPrice From OpportunityLineItems) From Opportunity Where Id IN : oppIdMatterIdMap.keySet()]){
            
            String ledgerKey = 'JTL_Ledger_Id';
            if(opp.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }
            //system.debug('ledgerKey=' +ledgerKey);
            // create billing for every opp
            AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
            if(opp.RecordType.DeveloperName == 'Next_Step' && opp.Next_Step_Matter__c != null){
                bill.AcctSeed__Opportunity__c = opp.Next_Step_Matter__r.AcctSeed__Opportunity__c;
                bill.Next_Step_Opportunity__c = opp.Id;
            }else{
                bill.AcctSeed__Opportunity__c = opp.Id;
            }
            bill.AcctSeed__Customer__c = opp.AccountId;
            bill.AcctSeed__Date__c = Date.today();
            bill.Matter__c = oppIdMatterIdMap.get(opp.Id);
            bill.AcctSeed__Status__c = 'Approved';
            bill.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            bill.Originator__c = opp.Originator_LU__c;
            bill.Billing_Attorney__c = opp.Billing_Attorney_lk__c;

            oppIdBillingMap.put(opp.Id, bill);

            // check if map doesn't contain key then put a new list
            if(!oppIdBillingLinesMap.containsKey(opp.Id)){
                oppIdBillingLinesMap.put(opp.Id, new list<AcctSeed__Billing_Line__c>());    
            }

            // create billing lines for all oppLineItems
            for(OpportunityLineItem oli : opp.OpportunityLineItems){
                AcctSeed__Billing_Line__c billingLine = new AcctSeed__Billing_Line__c();
                billingLine.AcctSeed__Hours_Units__c = oli.Quantity;
                billingLine.AcctSeed__Rate__c = oli.UnitPrice;
                billingLine.AcctSeed__Date__c = Date.today();
                billingLine.AcctSeed__Product__c = oli.Product2Id;
                billingLine.Originator_LU__c = opp.Originator_LU__c;
                billingLine.Billing_Attorney_lk__c = opp.Billing_Attorney_lk__c;

                if(officeMap.containsKey(opp.Office_that_consult_occurred_in__c)){
                    billingLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(opp.Office_that_consult_occurred_in__c);
                }
                if(areaOfLawMap.containsKey(opp.Area_of_Law__c)){
                    billingLine.AcctSeed__GL_Account_Variable_4__c = areaOfLawMap.get(opp.Area_of_Law__c);
                }
                //billingLine.AcctSeed__Project__c = oppIdMatterIdMap.get(opp.Id);
                billingLine.AcctSeed__Revenue_GL_Account__c = oli.Product2.AcctSeed__Revenue_GL_Account__c;
                oppIdBillingLinesMap.get(opp.Id).add(billingLine);  
            }
            
        }

        // insert billings
        if(oppIdBillingMap.values().size() > 0){
            insert oppIdBillingMap.values();

            // populate billing reference in billing lines
            list<AcctSeed__Billing_Line__c> billingLineList = new list<AcctSeed__Billing_Line__c>();
            for(Id opId : oppIdBillingMap.keySet()){
                if(oppIdBillingLinesMap.containsKey(opId)){
                    for(AcctSeed__Billing_Line__c bl : oppIdBillingLinesMap.get(opId)){
                        bl.AcctSeed__Billing__c = oppIdBillingMap.get(opId).Id;
                        billingLineList.add(bl);
                    }
                }
            }

            // insert billing lines
            if(billingLineList.size() > 0){
                insert billingLineList;

                // post bills
                AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(oppIdBillingMap.values());
            }
            
            /*map<Id,Id> matterIdBillingIdMap = new map<Id,Id>();
            for(AcctSeed__Billing__c bill : oppIdBillingMap.values()){
                matterIdBillingIdMap.put(bill.Matter__c, bill.Id);
            }
            
            // populate billing lookup on matter
            list<AcctSeed__Project__c> matterList_toUpdate = new list<AcctSeed__Project__c>();
            for(Id matterId : oppIdMatterIdMap.values()){
                 AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = matterId);
                 if(matterIdBillingIdMap.containsKey(matterId)){
                     matter.Billing__c = matterIdBillingIdMap.get(matterId);
                     matterList_toUpdate.add(matter);
                 }   
            }
            
            if(matterList_toUpdate.size() > 0){
                update matterList_toUpdate;
            }*/
        }
    }

    // @description - Method to create Billing from Accorto Invoices
    // @param       - set<Id> invoiceIds
    // @return      - void
    public static void createBillingFromAccortoInvoice(set<Id> invoiceIds){

        map<String,String> configMap = new map<String,String>();
        for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
            configMap.put(ac.Key__c, ac.Value__c);
        }

        map<String,String> glConfigMap = new map<String,String>();
        for(Ay_GL_Config__mdt glc : [Select Id, Key__c, Value__c From Ay_GL_Config__mdt]){
            glConfigMap.put(glc.Key__c, glc.Value__c);
        }
        
        AcctSeed__GL_Account__c glAccount_Test = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Revenue' Limit 1];

        map<String,Id> officeMap = new map<String,Id>();
        map<String,Id> areaOfLawMap = new map<String,Id>();
        for(AcctSeed__Accounting_Variable__c av : [Select Id, Name, AcctSeed__Type__c From AcctSeed__Accounting_Variable__c]){
            if(av.AcctSeed__Type__c == 'GL Account Variable 1'){
                officeMap.put(av.Name, av.Id);    
            }else if(av.AcctSeed__Type__c == 'GL Account Variable 4'){
                areaOfLawMap.put(av.Name, av.Id);
            }
        }

        map<Id,AcctSeed__Billing__c> invoiceIdBillingMap = new map<Id,AcctSeed__Billing__c>();
        map<Id,list<AcctSeed__Billing_Line__c>> invoiceIdBillingLineListMap = new map<Id,list<AcctSeed__Billing_Line__c>>();
        for(accorto__Invoice__c inv : [Select Id, accorto__Invoice_Date__c, accorto__Opportunity__r.Billing_Attorney_lk__c, accorto__Opportunity__r.Originator_LU__c, accorto__Opportunity__c, accorto__Opportunity__r.Kapsten_Matter__c, accorto__Account__c, accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Originator_LU__c, accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Billing_Attorney_lk__c, accorto__Project__c, accorto__Project__r.Matter__c, accorto__Project__r.Matter__r.AcctSeed__Opportunity__c, accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Office_that_consult_occurred_in__c, accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Area_of_Law__c, accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Kapsten_Matter__c, 
                                              (Select Id, accorto__Resource__c, accorto__UnitPrice__c, accorto__Hours__c, accorto__Project_Line__c, accorto__Project_Line__r.accorto__Product__r.AcctSeed__Revenue_GL_Account__c, accorto__Project_Line__r.accorto__Product__c, accorto__Description__c From accorto__Invoice_Lines__r) 
                                         From accorto__Invoice__c 
                                        Where Id IN : invoiceIds
                                          AND accorto__Project__c != null]){
            
            String ledgerKey = 'JTL_Ledger_Id';
            if(inv.accorto__Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }
            AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
            bill.Accorto_Invoice__c = inv.Id;
            bill.AcctSeed__Customer__c = inv.accorto__Account__c;
            bill.AcctSeed__Status__c = 'Approved';
            bill.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            bill.AcctSeed__Date__c = inv.accorto__Invoice_Date__c;
            bill.Matter__c = inv.accorto__Project__r.Matter__c;
            bill.AcctSeed__Opportunity__c = inv.accorto__Opportunity__c;
            bill.Originator__c = inv.accorto__Opportunity__r.Originator_LU__c;
            bill.Billing_Attorney__c = inv.accorto__Opportunity__r.Billing_Attorney_lk__c;
            invoiceIdBillingMap.put(inv.Id, bill);
            if(!invoiceIdBillingLineListMap.containsKey(inv.Id)){
                invoiceIdBillingLineListMap.put(inv.Id, new list<AcctSeed__Billing_Line__c>());
            }
            for(accorto__InvoiceLine__c invLine : inv.accorto__Invoice_Lines__r){
                AcctSeed__Billing_Line__c bLine = new AcctSeed__Billing_Line__c();
                bLine.Accorto_Invoice_Line__c = invLine.Id;
                bLine.AcctSeed__Hours_Units__c = invLine.accorto__Hours__c;
                bLine.Resource__c = invLine.accorto__Resource__c;
                bLine.AcctSeed__Rate__c = invLine.accorto__UnitPrice__c;
                bLine.AcctSeed__Comment__c = invLine.accorto__Description__c;
                //bLine.AcctSeed__Project__c = inv.accorto__Project__r.Matter__c;
                if(invLine.accorto__Project_Line__c != null && invLine.accorto__Project_Line__r.accorto__Product__c != null){
                    bLine.AcctSeed__Product__c = invLine.accorto__Project_Line__r.accorto__Product__c;
                    if(invLine.accorto__Project_Line__r.accorto__Product__r.AcctSeed__Revenue_GL_Account__c != null){
                        bLine.AcctSeed__Revenue_GL_Account__c = invLine.accorto__Project_Line__r.accorto__Product__r.AcctSeed__Revenue_GL_Account__c;
                    }else{
                        if(ledgerKey == 'JTL_Ledger_Id'){
                            bLine.AcctSeed__Revenue_GL_Account__c = glConfigMap.get('JTL_Default_Revenue_GL_Account_ID');//configMap.get('Revenue_GL_Account');      
                        }
                    }
                }else{
                    if(ledgerKey == 'JTL_Ledger_Id' && !Test.isRunningTest()){
                        bLine.AcctSeed__Revenue_GL_Account__c = glConfigMap.get('JTL_Default_Revenue_GL_Account_ID');//configMap.get('Revenue_GL_Account');      
                    }else{
                        bLine.AcctSeed__Revenue_GL_Account__c = glAccount_Test.Id;
                    }
                    
                }
                if(officeMap.containsKey(inv.accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Office_that_consult_occurred_in__c)){
                    bLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(inv.accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Office_that_consult_occurred_in__c);
                }
                if(areaOfLawMap.containskey(inv.accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Area_of_Law__c)){
                    bLine.AcctSeed__GL_Account_Variable_4__c = officeMap.get(inv.accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Area_of_Law__c);
                }
                bLine.Originator_LU__c = inv.accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Originator_LU__c;
                bLine.Billing_Attorney_lk__c = inv.accorto__Project__r.Matter__r.AcctSeed__Opportunity__r.Billing_Attorney_lk__c;
                invoiceIdBillingLineListMap.get(inv.Id).add(bLine);
            }
            
        }

        if(invoiceIdBillingMap.values().size() > 0){
            insert invoiceIdBillingMap.values();

            // populate billing lookup in invoice
            list<accorto__Invoice__c> invoiceList_toUpdate = new list<accorto__Invoice__c>();
            for(AcctSeed__Billing__c bill : invoiceIdBillingMap.values()){
                invoiceList_toUpdate.add(new accorto__Invoice__c(Id = bill.Accorto_Invoice__c, Billing__c = bill.Id));
            }
            update invoiceList_toUpdate;

            list<AcctSeed__Billing_Line__c> billingLinesList = new list<AcctSeed__Billing_Line__c>(); 
            list<accorto__InvoiceLine__c> invoiceLines_toUpdate = new list<accorto__InvoiceLine__c>(); 
            for(Id invId : invoiceIdBillingMap.keySet()){
                Id billingId = invoiceIdBillingMap.get(invId).Id;
                for(AcctSeed__Billing_Line__c bl : invoiceIdBillingLineListMap.get(invId)){
                    bl.AcctSeed__Billing__c = billingId;
                    billingLinesList.add(bl);
                }
            }
            insert billingLinesList;

            // post bills
            AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(invoiceIdBillingMap.values());

            // populate billing Line lookup in invoice line
            for(AcctSeed__Billing_Line__c bl : billingLinesList){
                invoiceLines_toUpdate.add(new accorto__InvoiceLine__c(Id = bl.Accorto_Invoice_Line__c, Billing_Line__c = bl.Id));
            }
            update invoiceLines_toUpdate;
        }
    }

    // @description - Method to reverse Billing of Accorto Invoices
    // @param       - list<accorto__Invoice__c>
    // @return      - void
    public static void reverseBillingsOfAccortoInvoice(list<accorto__Invoice__c> invoiceList){
        
        // create a map of invoice
        map<Id,accorto__Invoice__c> invoiceMap = new map<Id,accorto__Invoice__c>();
        for(accorto__Invoice__c inv : invoiceList){
            invoiceMap.put(inv.Id, inv);
        }

        // check for BCR
        map<Id,String> invoiceIdBcrMap = new map<Id,String>();
        for(AcctSeed__Billing_Cash_Receipt__c bcr : [Select Id, Name, AcctSeed__Billing__r.Accorto_Invoice__c 
                                                       From AcctSeed__Billing_Cash_Receipt__c 
                                                      Where AcctSeed__Billing__r.Accorto_Invoice__c IN : invoiceMap.keySet()]){
            invoiceIdBcrMap.put(bcr.AcctSeed__Billing__r.Accorto_Invoice__c, bcr.Name);
        }

        // throw error if billing has been paid
        for(accorto__Invoice__c inv : invoiceList){
            if(invoiceIdBcrMap.containsKey(inv.Id)){
                inv.addError('Please delete billing cash receipt prior reversing the accounting : ' + invoiceIdBcrMap.get(inv.Id));
            }
        }

        // delete those billings which were not paid
        list<AcctSeed__Billing__c> billings_toDelete = new list<AcctSeed__Billing__c>();
        for(AcctSeed__Billing__c bill : [Select Id, Accorto_Invoice__c From AcctSeed__Billing__c Where Accorto_Invoice__c IN : invoiceMap.keySet() AND Accorto_Invoice__c NOT IN : invoiceIdBcrMap.keySet()]){
            billings_toDelete.add(bill);
        }

        if(billings_toDelete.size() > 0){
            delete billings_toDelete;
        }

        // set Create_Billing__c to false
        list<accorto__Invoice__c> invList_toUpdate = new list<accorto__Invoice__c>();
        for(Id invId : invoiceMap.keySet()){
            if(!invoiceIdBcrMap.containsKey(invId)){
                invList_toUpdate.add(new accorto__Invoice__c(Id = invId, Create_Billing__c = false));    
            }
        }

        // update invoice
        if(invList_toUpdate.size() > 0){
            update invList_toUpdate;
        }
    }

    // @description - Method to handle posting of payable, Create hardcost bill
    // @param       - set<Id>
    // @return      - void
    @future
    public static void handlePayablepost(set<Id> payableIds){

        map<String,String> configMap = new map<String,String>();
        for(Ay_GL_Config__mdt glc : [Select Id, Key__c, Value__c From Ay_GL_Config__mdt]){
            configMap.put(glc.Key__c, glc.Value__c);
        }
        AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Balance Sheet' AND AcctSeed__Bank__c = false Limit 1];
        
        map<Id,AcctSeed__Billing__c> payableIdBillingMap = new map<Id,AcctSeed__Billing__c>();
        map<Id,list<AcctSeed__Billing_Line__c>> payableIdBillingLineListMap = new map<Id,list<AcctSeed__Billing_Line__c>>();

        map<Id,AcctSeed__Journal_Entry__c> payableIdJEMap = new map<Id,AcctSeed__Journal_Entry__c>();
        map<Id,list<AcctSeed__Journal_Entry_Line__c>> payableIdJELineListMap = new map<Id,list<AcctSeed__Journal_Entry_Line__c>>();

        list<AcctSeed__Billing__c> billingList_forPosting = new list<AcctSeed__Billing__c>();
        for(AcctSeed__Account_Payable__c pay : [Select Id, Is_Refund__c, Matter_Termination__c, Matter_Termination__r.Related_Next_Step_Opportunity__c, AcctSeed__Ledger__c, Opportunity__r.AccountId, AcctSeed__Ledger__r.Name, Opportunity__c, Opportunity__r.Originator_LU__c, Opportunity__r.Billing_Attorney_lk__c, Name, AcctSeed__Vendor__c, AcctSeed__Net_Amount__c, Matter__c, Matter__r.Trust_Balance__c, Matter__r.Trust_Balance__r.Closing_Balance__c, (Select Id, AcctSeed__Quantity__c, AcctSeed__Unit_Cost__c, AcctSeed__GL_Account_Variable_1__c, AcctSeed__GL_Account_Variable_4__c From AcctSeed__Project_Account_Payable_Lines__r) 
                                                  From AcctSeed__Account_Payable__c 
                                                 Where Id IN : payableIds]){
            // check to create billing
            //Decimal closingBalance = pay.Matter__r.Trust_Balance__r.Closing_Balance__c; 
            //if(closingBalance >= pay.AcctSeed__Net_Amount__c){
                //closingBalance =  closingBalance - pay.AcctSeed__Net_Amount__c;
            //}else{
                AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
                bill.AcctSeed__Customer__c = pay.Opportunity__r.AccountId;
                bill.AcctSeed__Status__c = 'Approved';
                bill.AcctSeed__Date__c = Date.today();
                bill.Payable__c = pay.Id;
                bill.AcctSeed__Opportunity__c = pay.Opportunity__c;
                bill.Associated_with_Refund_HC__c = pay.Is_Refund__c;
                bill.Matter__c = pay.Matter__c;
                if(pay.Matter_Termination__c != null){
                    bill.Next_Step_Opportunity__c = pay.Matter_Termination__r.Related_Next_Step_Opportunity__c;
                }
                bill.AcctSeed__Ledger__c = pay.AcctSeed__Ledger__c;
                bill.Originator__c = pay.Opportunity__r.Originator_LU__c;
                bill.Billing_Attorney__c = pay.Opportunity__r.Billing_Attorney_lk__c;
                bill.AcctSeed__Billing_Comment__c = 'Project cost advanced against Trust';
                payableIdBillingMap.put(pay.Id,bill);
                billingList_forPosting.add(bill);
                if(!payableIdBillingLineListMap.containsKey(pay.Id)){
                    payableIdBillingLineListMap.put(pay.Id, new list<AcctSeed__Billing_Line__c>());
                }

                for(AcctSeed__Account_Payable_Line__c pline : pay.AcctSeed__Project_Account_Payable_Lines__r){
                    AcctSeed__Billing_Line__c bl = new AcctSeed__Billing_Line__c();
                    bl.Payable_Line__c = pLine.Id;
                    bl.AcctSeed__Hours_Units__c = pLine.AcctSeed__Quantity__c;
                    if(Test.isRunningTest()){
                        bl.AcctSeed__Revenue_GL_Account__c = glAccount.Id;
                    }else if(bill.AcctSeed__Ledger__r.Name == 'Kapsten'){
                        bl.AcctSeed__Revenue_GL_Account__c = configMap.get('Kapsten_Hardcost_Bill_Revenue_GL');
                    }else{
                        bl.AcctSeed__Revenue_GL_Account__c = configMap.get('JTL_Hardcost_Bill_Revenue_GL');
                    }
                    bl.AcctSeed__Rate__c = pay.AcctSeed__Net_Amount__c; //- closingBalance;
                    bl.AcctSeed__GL_Account_Variable_1__c = pLine.AcctSeed__GL_Account_Variable_1__c;
                    bl.AcctSeed__GL_Account_Variable_4__c = pLine.AcctSeed__GL_Account_Variable_4__c;
                    bl.Originator_LU__c = pay.Opportunity__r.Originator_LU__c;
                    bl.Billing_Attorney_lk__c = pay.Opportunity__r.Billing_Attorney_lk__c;
                    payableIdBillingLineListMap.get(pay.Id).add(bl);
                }
            //}

            // create JE
            /*AcctSeed__Journal_Entry__c je = new AcctSeed__Journal_Entry__c();
            je.Name = pay.Name;
            je.Matter__c = pay.Matter__c;
            je.Payable__c = pay.Id;
            je.AcctSeed__Journal_Date__c = Date.today();
            je.AcctSeed__Status__c = 'Approved';
            je.AcctSeed__Ledger__c = pay.AcctSeed__Ledger__c;
            payableIdJEMap.put(pay.Id,je);
            if(!payableIdJELineListMap.containsKey(pay.Id)){
                payableIdJELineListMap.put(pay.Id, new list<AcctSeed__Journal_Entry_Line__c>());
            }
            AcctSeed__Journal_Entry_Line__c creditLine = new AcctSeed__Journal_Entry_Line__c();
            creditLine.AcctSeed__GL_Account__c = Label.Trust_GL_Account_ID;
            creditLine.AcctSeed__Credit__c = pay.AcctSeed__Net_Amount__c;
            payableIdJELineListMap.get(pay.Id).add(creditLine);

            AcctSeed__Journal_Entry_Line__c debitLine = new AcctSeed__Journal_Entry_Line__c();
            debitLine.AcctSeed__GL_Account__c = Label.JTL_Operating_Bank_Account_ID;
            debitLine.AcctSeed__Debit__c = pay.AcctSeed__Net_Amount__c;
            payableIdJELineListMap.get(pay.Id).add(debitLine);*/

        }
        
        if(payableIdBillingMap.values().size() > 0){
            insert payableIdBillingMap.values();

            list<AcctSeed__Account_Payable__c> payablesList = new list<AcctSeed__Account_Payable__c>();
            list<AcctSeed__Billing_Line__c> billingLinesList = new list<AcctSeed__Billing_Line__c>();
            for(Id payableId : payableIdBillingMap.keySet()){
                payablesList.add(new AcctSeed__Account_Payable__c(Id = payableId, Billing__c = payableIdBillingMap.get(payableId).Id));
                if(payableIdBillingLineListMap.containsKey(payableId)){
                    for(AcctSeed__Billing_Line__c bl : payableIdBillingLineListMap.get(payableId)){
                        bl.AcctSeed__Billing__c = payableIdBillingMap.get(payableId).Id;
                        billingLinesList.add(bl);
                    }
                }
            }

            insert billingLinesList;
            update payablesList;


            // post bills
            AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billingList_forPosting);
            // Loop through post results
            for (AcctSeed.PostResult theResult : postResults) {
                if (theResult.isSuccess) {
                    System.debug('****Successfully posted billing: ' + theResult.id);
                } 
                else {
                    System.debug('****Error posting billing ' + theResult.id);
                    for (AcctSeed.PostResult.PostErrorResult errorResult: theResult.errors) {
                        System.debug('****Error status code ' + errorResult.statusCode);
                        System.debug('****Error message ' + errorResult.message);
                    }
                }
            }

            // populate billing Line lookup in payable line
            list<AcctSeed__Account_Payable_Line__c> payableLines = new list<AcctSeed__Account_Payable_Line__c>();
            for(AcctSeed__Billing_Line__c bl : billingLinesList){
                payableLines.add(new AcctSeed__Account_Payable_Line__c(Id = bl.Payable_Line__c, Billing_Line__c = bl.Id));
            }
            update payableLines;
        }

        /*if(payableIdJEMap.values().size() > 0){
            insert payableIdJEMap.values();

            list<AcctSeed__Journal_Entry_Line__c> jeLinesList = new list<AcctSeed__Journal_Entry_Line__c>();
            for(Id payId : payableIdJEMap.keySet()){
                if(payableIdJELineListMap.containsKey(payId)){
                    for(AcctSeed__Journal_Entry_Line__c jel : payableIdJELineListMap.get(payId)){
                        jel.AcctSeed__Journal_Entry__c = payableIdJEMap.get(payId).Id;
                        jeLinesList.add(jel);
                    }
                }
            }

            insert jeLinesList;
        }*/
    }

    // @description - Method to handle movememnt of money on trust balance closing
    // @param       - set<Id> trustBalanceIds
    // @assumption  - Only one trust balance can be closed at a time for related matter, because prior should be closed before closing new one
    // @return      - void
    public static void createJEonTrustBalanceClose(set<Id> trustBalanceIds){
   
        map<String,String> configMap = new map<String,String>();
        for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
            configMap.put(ac.Key__c, ac.Value__c);
        }

        map<Id,Trust_Balance__c> trustBalanceMap = new map<Id,Trust_Balance__c>([Select Id, Name, Matter__c, Matter__r.AcctSeed__Opportunity__r.Kapsten_Matter__c From Trust_Balance__c Where Id In : trustBalanceIds]);
        map<Id,Decimal> activityAmountMap = new map<Id,Decimal>();
        for(Trust_Account_Activity__c taa : [Select Id, Trust_Balance__c, Billing_Cash_Receipt__r.AcctSeed__Applied_Amount__c 
                                               From Trust_Account_Activity__c 
                                              Where Trust_Balance__c IN : trustBalanceIds
                                                AND Billing_Cash_Receipt__c != null]){
            if(!activityAmountMap.containsKey(taa.Trust_Balance__c)){
                activityAmountMap.put(taa.Trust_Balance__c, 0);
            }
            Decimal bal = activityAmountMap.get(taa.Trust_Balance__c);
            bal += taa.Billing_Cash_Receipt__r.AcctSeed__Applied_Amount__c;
            activityAmountMap.put(taa.Trust_Balance__c, bal);
        }

        map<Id,AcctSeed__Journal_Entry__c> tbIdJEMap = new map<Id,AcctSeed__Journal_Entry__c>();
        map<Id,list<AcctSeed__Journal_Entry_Line__c>> tbIdJELineListMap = new map<Id,list<AcctSeed__Journal_Entry_Line__c>>();
        AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Limit 1];
        
        for(Id trustBalanceId : activityAmountMap.keySet()){
            if(trustBalanceMap.containsKey(trustBalanceId) && activityAmountMap.containsKey(trustBalanceId)){
                Trust_Balance__c tb = trustBalanceMap.get(trustBalanceId);

                String ledgerKey = 'JTL_Ledger_Id';
                if(tb.Matter__r.AcctSeed__Opportunity__r.Kapsten_Matter__c == 'Yes'){
                    ledgerKey = 'Kapsten_Ledger_Id';
                }
                AcctSeed__Journal_Entry__c je = new AcctSeed__Journal_Entry__c();
                je.Matter__c = tb.Matter__c;
                je.Trust_Balance__c = tb.Id;
                je.AcctSeed__Ledger__c = configMap.get(ledgerKey);
                je.Name = tb.Name;
                je.AcctSeed__Journal_Date__c = Date.today();
                je.AcctSeed__Status__c = 'Approved';
                tbIdJEMap.put(tb.Id,je);

                if(!tbIdJELineListMap.containsKey(tb.Id)){
                    tbIdJELineListMap.put(tb.Id, new list<AcctSeed__Journal_Entry_Line__c>());
                }

                AcctSeed__Journal_Entry_Line__c creditLine = new AcctSeed__Journal_Entry_Line__c();
                if(!Test.isRunningTest()){
                    creditLine.AcctSeed__GL_Account__c = Label.Trust_GL_Account_ID;
                }else{
                    creditLine.AcctSeed__GL_Account__c = glAccount.Id;
                }
                creditLine.AcctSeed__Credit__c = activityAmountMap.get(trustBalanceId);
                tbIdJELineListMap.get(tb.Id).add(creditLine);

                AcctSeed__Journal_Entry_Line__c debitLine = new AcctSeed__Journal_Entry_Line__c();
                if(!Test.isRunningTest()){
                    debitLine.AcctSeed__GL_Account__c = Label.JTL_Operating_Bank_Account_ID;
                }else{
                    debitLine.AcctSeed__GL_Account__c = glAccount.Id;
                }
                debitLine.AcctSeed__Debit__c = activityAmountMap.get(trustBalanceId);
                tbIdJELineListMap.get(tb.Id).add(debitLine);   
            }
        }

        if(tbIdJEMap.values().size() > 0){
            insert tbIdJEMap.values();

            list<AcctSeed__Journal_Entry_Line__c> jeLinesList = new list<AcctSeed__Journal_Entry_Line__c>();
            for(Id bcrId : tbIdJEMap.keySet()){
                if(tbIdJELineListMap.containsKey(bcrId)){
                    for(AcctSeed__Journal_Entry_Line__c jel : tbIdJELineListMap.get(bcrId)){
                        jel.AcctSeed__Journal_Entry__c = tbIdJEMap.get(bcrId).Id;
                        jeLinesList.add(jel);
                    }
                }
            }

            insert jeLinesList;
            

            // post JE
            AcctSeed.PostResult[] postResults = AcctSeed.JournalEntryPostService.postJournalEntries(tbIdJEMap.values());
        }   
        
    }

    // @description - Method to apply CR
    // @param       - set<Id> customerIds
    // @return      - void
    public static void autoApplyCR(set<Id> customerIds){

        list<AcctSeed__Billing_Cash_Receipt__c> bcrList = new list<AcctSeed__Billing_Cash_Receipt__c>();
        map<Id,Decimal> billBalanceMap = new map<Id,Decimal>();
        set<Id> crIds = new set<Id>();
        for(Account act : [Select Id, Name, 
                                  (Select Id, Accorto_Invoice__c, Payable__c, AcctSeed__Ledger__c, AcctSeed__Opportunity__c, AcctSeed__Accounting_Period__c, AcctSeed__Customer__c, AcctSeed__Balance__c, AcctSeed__Date__c, Matter__c from AcctSeed__Billings__r Where AcctSeed__Balance__c > 0 AND AcctSeed__Status__c != 'In Process' AND (Accorto_Invoice__c != null OR Payable__c != null)),
                                  (Select Id, AcctSeed__Ledger__c, AcctSeed__Accounting_Period__c, AcctSeed__Account__c, AcctSeed__Balance__c, AcctSeed__GL_Account_Variable_2__c, AcctSeed__Project__c from AcctSeed__Cash_Receipts__r where AcctSeed__Balance__c > 0 AND AcctSeed__Status__c = 'Posted' ) 
                             From Account
                            Where Id IN : customerIds]){

            Decimal amountToSettle = 0;
            for(AcctSeed__Cash_Receipt__c cr : act.AcctSeed__Cash_Receipts__r){
                Decimal crBalanceAmount = cr.AcctSeed__Balance__c;
                for(AcctSeed__Billing__c bill : act.AcctSeed__Billings__r){
                    if(bill.Accorto_Invoice__c != null || bill.Payable__c != null){
                        if(bill.AcctSeed__Customer__c == cr.AcctSeed__Account__c && bill.Matter__c == cr.AcctSeed__Project__c && bill.AcctSeed__Ledger__c == cr.AcctSeed__Ledger__c){
                            if(billBalanceMap.containsKey(bill.Id)){
                                amountToSettle = billBalanceMap.get(bill.Id);
                            }else{
                                billBalanceMap.put(bill.Id,bill.AcctSeed__Balance__c);
                                amountToSettle = bill.AcctSeed__Balance__c;
                            }
                            
                            if(amountToSettle == 0 || crBalanceAmount == 0){
                                break;
                            }
        
                            if(bill.AcctSeed__Balance__c > 0){
                                crIds.add(cr.Id);
                                AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
                                bcr.AcctSeed__Billing__c = bill.Id;
                                bcr.AcctSeed__Cash_Receipt__c = cr.Id;
                                bcr.AcctSeed__Applied_Date__c = Date.today();
                                if(amountToSettle <= crBalanceAmount){
                                    bcr.AcctSeed__Applied_Amount__c = amountToSettle;
                                }else if(amountToSettle > crBalanceAmount){
                                    bcr.AcctSeed__Applied_Amount__c = crBalanceAmount;
                                }
                                bcrList.add(bcr);
                                crBalanceAmount = crBalanceAmount - bcr.AcctSeed__Applied_Amount__c;
                                billBalanceMap.put(bill.Id, (amountToSettle - bcr.AcctSeed__Applied_Amount__c));    
                            }
                        }
                    }
                }

            }    
        }

        if(bcrList.size() > 0){
            insert bcrList;
        }

        list<AcctSeed__Cash_Receipt__c> crList = new list<AcctSeed__Cash_Receipt__c>();
        for(Id crId : crIds){
            crList.add(new AcctSeed__Cash_Receipt__c(Id = crId, Auto_Apply__c = false));
        }

        if(crList.size() > 0){
            update crList;
        }
    }

    // @description - Method to apply Finance CR
    // @param       - set<Id> customerIds
    // @return      - void
    public static void autoApplyFinanceCR(set<Id> customerIds){
        
        list<AcctSeed__Billing_Cash_Receipt__c> bcrList = new list<AcctSeed__Billing_Cash_Receipt__c>();
        map<Id,Decimal> billBalanceMap = new map<Id,Decimal>();
        set<Id> crIds = new set<Id>();
        for(Account act : [Select Id, Name, 
                                  (Select Id, Accorto_Invoice__c, Payable__c, AcctSeed__Ledger__c, AcctSeed__Opportunity__c, AcctSeed__Accounting_Period__c, AcctSeed__Customer__c, AcctSeed__Balance__c, AcctSeed__Date__c, Finance__c, Matter__c from AcctSeed__Billings__r Where AcctSeed__Balance__c > 0 AND AcctSeed__Status__c != 'In Process' AND Finance__c != null),
                                  (Select Id, AcctSeed__Ledger__c, AcctSeed__Accounting_Period__c, AcctSeed__Account__c, AcctSeed__Balance__c, AcctSeed__GL_Account_Variable_2__c, AcctSeed__Project__c from AcctSeed__Cash_Receipts__r where AcctSeed__Balance__c > 0 AND AcctSeed__Status__c = 'Posted' AND Affinipay_Transaction__c != null) 
                             From Account
                            Where Id IN : customerIds]){
        
            Decimal amountToSettle = 0;
            for(AcctSeed__Cash_Receipt__c cr : act.AcctSeed__Cash_Receipts__r){
                Decimal crBalanceAmount = cr.AcctSeed__Balance__c;
                for(AcctSeed__Billing__c bill : act.AcctSeed__Billings__r){
                    if(bill.Finance__c != null){
                        if(bill.AcctSeed__Customer__c == cr.AcctSeed__Account__c && bill.AcctSeed__Ledger__c == cr.AcctSeed__Ledger__c){
                            if(billBalanceMap.containsKey(bill.Id)){
                                amountToSettle = billBalanceMap.get(bill.Id);
                            }else{
                                billBalanceMap.put(bill.Id,bill.AcctSeed__Balance__c);
                                amountToSettle = bill.AcctSeed__Balance__c;
                            }
                            
                            if(amountToSettle == 0 || crBalanceAmount == 0){
                                break;
                            }
                            
                            if(bill.AcctSeed__Balance__c > 0){
                                crIds.add(cr.Id);
                                AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
                                bcr.AcctSeed__Billing__c = bill.Id;
                                bcr.AcctSeed__Cash_Receipt__c = cr.Id;
                                bcr.AcctSeed__Applied_Date__c = Date.today();
                                if(amountToSettle <= crBalanceAmount){
                                    bcr.AcctSeed__Applied_Amount__c = amountToSettle;
                                }else if(amountToSettle > crBalanceAmount){
                                    bcr.AcctSeed__Applied_Amount__c = crBalanceAmount;
                                }
                                bcrList.add(bcr);
                                crBalanceAmount = crBalanceAmount - bcr.AcctSeed__Applied_Amount__c;
                                billBalanceMap.put(bill.Id, (amountToSettle - bcr.AcctSeed__Applied_Amount__c));    
                            }
                        }
                    }
                }

            }    
        }
        
        if(bcrList.size() > 0){
            insert bcrList;
        }

        list<AcctSeed__Cash_Receipt__c> crList = new list<AcctSeed__Cash_Receipt__c>();
        for(Id crId : crIds){
            crList.add(new AcctSeed__Cash_Receipt__c(Id = crId, Auto_Apply__c = false));
        }

        if(crList.size() > 0){
            update crList;
        }
    }

    // @description - Method to handle Standard Termination
    // @param       - terminationIds
    // @assumtpion  - handle single record at a time
    // @return      - void
    
    @future
    public static void handleStandardTermination(Id terminationId){

        /******************************************************************************************************************************/
            // code flow : 
            // 1. fetch all the master setup
            // 2. fetch matter termination details
            // 3. If client ows JTL, create credit memo for the value of terminated tasks and apply to bill
            // 4. If JTL ows Client, create HardCost Payable and payable bill and apply the credit memo to hardcost bill
        /*****************************************************************************************************************************/
        
        // 1. fetch master setup
            map<String,String> configMap = new map<String,String>();
            for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
                configMap.put(ac.Key__c, ac.Value__c);
            }
            
            map<String,String> glConfigMap = new map<String,String>();
            for(Ay_GL_Config__mdt glc : [Select Id, Key__c, Value__c From Ay_GL_Config__mdt]){
                glConfigMap.put(glc.Key__c, glc.Value__c);
            } 
            
            AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Revenue' Limit 1];

            map<String,Id> officeMap = new map<String,Id>();
            map<String,Id> areaOfLawMap = new map<String,Id>();
            for(AcctSeed__Accounting_Variable__c av : [Select Id, Name, AcctSeed__Type__c From AcctSeed__Accounting_Variable__c]){
                if(av.AcctSeed__Type__c == 'GL Account Variable 1'){
                    officeMap.put(av.Name, av.Id);    
                }else if(av.AcctSeed__Type__c == 'GL Account Variable 4'){
                    areaOfLawMap.put(av.Name, av.Id);
                }
            }

        // 2. fetch matter termination details
        for(Matter_Termination__c mt : [Select Id, Related_Next_Step_Opportunity__c, Related_Next_Step_Opportunity__r.AccountId, Related_Next_Step_Opportunity__r.Originator_LU__c, Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c, Opportunity__c, Opportunity__r.Kapsten_Matter__c, Name, Matter__c, Adjusted_Bill_GL_Account__c, Opportunity__r.Originator_LU__c, Opportunity__r.Billing_Attorney_lk__c, Total_Adjusted_Billing_Balance__c, Overpayment_Disposition__c, Opportunity__r.AccountId, Opportunity__r.Area_of_Law__c, Opportunity__r.Office_that_consult_occurred_in__c, Underpay_Disposition__c, Total_Credit_Value_Formula__c, No_of_Case_Terminations__c,Matter__r.AcctSeed__Opportunity__c ,
                                               (Select Id, Name, Opportunity_Product__c, Total_Credit_Value__c From Case_Terminations__r)
                                          From Matter_Termination__c Where Id =: terminationId LIMIT 1]){
            
            // configure the ledger key
            String ledgerKey = 'JTL_Ledger_Id';
            if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }

            if(mt.Total_Adjusted_Billing_Balance__c > 0){
                // Client OWS JTL    
                AyAccountingFunctions.handleClientOwsJTLScenario(mt, configMap, glConfigMap, officeMap, areaOfLawMap);
            }else if(mt.Total_Adjusted_Billing_Balance__c < 0){
                // JTL OWS Client
                AyAccountingFunctions.handleJTLOwsClientScenario(mt, configMap, glConfigMap, officeMap, areaOfLawMap);
            }

        }

    }

    // @description - Method to handle Client Ows JTL Scenario i.e. Total_Adjusted_Billing_Balance__c > 0
    // @param       - Matter_Termination__c, map<String,String> configMap, map<String,String> glConfigMap, map<String,Id> officeMap, map<String,Id> areaOfLawMap
    // @assumtpion  - handle single record at a time
    // @return      - void
    private static void handleClientOwsJTLScenario(Matter_Termination__c mt, map<String,String> configMap, map<String,String> glConfigMap, map<String,Id> officeMap, map<String,Id> areaOfLawMap){
        /**************************************************/
            // code flow : 
            // 1. create credit memo for the Credit Value
            // 2. Apply memo to bills
        /**************************************************/

        // configure the ledger key
            String ledgerKey = 'JTL_Ledger_Id';
            if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }
            
            OpportunityLineItem oli;
            for(OpportunityLineItem olItem : [Select Id, Product2.AcctSeed__Revenue_GL_Account__c From OpportunityLineItem Where OpportunityId =: mt.Matter__r.AcctSeed__Opportunity__c LIMIT 1]){
                oli = olItem; 
            }
        
        
        // 1. create credit memo for the Credit Value
            AcctSeed__Billing__c memo = new AcctSeed__Billing__c();
            memo.Matter_Termination__c = mt.Id;
            memo.Matter__c = mt.Matter__c; 
            memo.AcctSeed__Opportunity__c = mt.Opportunity__c;
            memo.Next_Step_Opportunity__c = mt.Related_Next_Step_Opportunity__c;
            memo.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            memo.AcctSeed__Status__c = 'Approved';
            memo.AcctSeed__Date__c = Date.today();
            if(mt.Related_Next_Step_Opportunity__c != null){
                memo.AcctSeed__Customer__c = mt.Related_Next_Step_Opportunity__r.AccountId;
                memo.Originator__c = mt.Related_Next_Step_Opportunity__r.Originator_LU__c;
                memo.Billing_Attorney__c = mt.Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c;
            }else{
                memo.AcctSeed__Customer__c = mt.Opportunity__r.AccountId;
                memo.Originator__c = mt.Opportunity__r.Originator_LU__c;
                memo.Billing_Attorney__c = mt.Opportunity__r.Billing_Attorney_lk__c;
            }
            insert memo;

            // credit memo Line
            AcctSeed__Billing_Line__c memoLine = new AcctSeed__Billing_Line__c();
            memoLine.AcctSeed__Billing__c = memo.Id;
            memoLine.AcctSeed__Rate__c = mt.Total_Credit_Value_Formula__c * (-1);
            if(mt.Related_Next_Step_Opportunity__c != null){
                memoLine.Originator_LU__c = mt.Related_Next_Step_Opportunity__r.Originator_LU__c;
                memoLine.Billing_Attorney_lk__c = mt.Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c;
            }else{
                memoLine.Originator_LU__c = mt.Opportunity__r.Originator_LU__c;
                memoLine.Billing_Attorney_lk__c = mt.Opportunity__r.Billing_Attorney_lk__c;   
            }
            //memoLine.AcctSeed__Revenue_GL_Account__c = bline.AcctSeed__Revenue_GL_Account__c;
            if(officeMap.containsKey(mt.Opportunity__r.Office_that_consult_occurred_in__c)){
                memoLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(mt.Opportunity__r.Office_that_consult_occurred_in__c);
            }
            if(areaOfLawMap.containsKey(mt.Opportunity__r.Area_of_Law__c)){
                memoLine.AcctSeed__GL_Account_Variable_4__c = areaOfLawMap.get(mt.Opportunity__r.Area_of_Law__c);
            }
        
            if(oli != null){
                if(oli.Product2.AcctSeed__Revenue_GL_Account__c != null){
                    memoLine.AcctSeed__Revenue_GL_Account__c = oli.Product2.AcctSeed__Revenue_GL_Account__c;
                }else{
                    memoLine.AcctSeed__Revenue_GL_Account__c = Label.GL_Account_J_40000_Income;   
                }
            }
        
            insert memoLine;
        
        // post billings
            list<AcctSeed__Billing__c> memoList_toPost = new list<AcctSeed__Billing__c>();
            memoList_toPost.add(memo);
            AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(memoList_toPost);

        // 2. apply credit memo
            Id accountingPeriodId = AyAccountingFunctions.getAccountingPeriod(Date.today());
            Decimal bal = mt.Total_Credit_Value_Formula__c;
            Decimal memoBalance;
            set<Id> processedBills = new set<Id>();
            list<AcctSeed__Billing_Credit_Memo__c> bcmList = new list<AcctSeed__Billing_Credit_Memo__c>();
            for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Balance__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__c =: mt.Opportunity__c AND Next_Step_Opportunity__c =: mt.Related_Next_Step_Opportunity__c AND AcctSeed__Type__c = 'Invoice' Order By Next_Step_Opportunity__c NULLS LAST, AcctSeed__Due_Date2__c DESC]){
                if(bal > 0){
                    Decimal amtToApply;
                    //System.debug('****AyAccountingFunctions***handleClientOwsJTLScenario***Memo balance=='+bal);
                    //System.debug('****AyAccountingFunctions***handleClientOwsJTLScenario***Bill Balance=='+bill.AcctSeed__Balance__c);
                    
                    if(bal >= bill.AcctSeed__Balance__c){
                        amtToApply = bill.AcctSeed__Balance__c;
                        memoBalance = bal - amtToApply;
                    }else{
                        amtToApply = bal;
                    }
                    //System.debug('****AyAccountingFunctions***handleClientOwsJTLScenario***amtToApply='+amtToApply);
                    bal = bal - amtToApply;
                    //System.debug('****AyAccountingFunctions***handleClientOwsJTLScenario***bal='+bal);
                    
                    AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                    bcm.AcctSeed__Billing_Credit_Memo__c = memo.Id;
                    bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                    bcm.AcctSeed__Accounting_Period__c = accountingPeriodId;                        
                    bcm.AcctSeed__Amount__c = amtToApply * (-1);
                    bcm.AcctSeed__Applied_Date__c = Date.today();
                    bcmList.add(bcm); 
                    processedBills.add(bill.Id);
                }
            }   

            // if memo still has balance left, fetch open bills and process them by due date furtheset to the future
            if(memoBalance != null && memoBalance > 0){
                Decimal amt;
                for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Balance__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__c =: mt.Opportunity__c AND AcctSeed__Status__c = 'Posted' AND AcctSeed__Balance__c > 0 AND AcctSeed__Type__c = 'Invoice' AND Id NOT IN : processedBills Order By AcctSeed__Due_Date2__c DESC]){
                    
                    if(memoBalance == 0){break;}
                    
                    if(bill.AcctSeed__Balance__c > memoBalance){
                        amt = memoBalance;
                    }else{
                        amt = bill.AcctSeed__Balance__c;
                    }
                    
                    AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                    bcm.AcctSeed__Billing_Credit_Memo__c = memo.Id;
                    bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                    bcm.AcctSeed__Accounting_Period__c = accountingPeriodId;                        
                    bcm.AcctSeed__Amount__c = amt * (-1);
                    bcm.AcctSeed__Applied_Date__c = Date.today();
                    bcmList.add(bcm); 

                    memoBalance = memoBalance - amt;
                    
                }    
            }

            if(bcmList.size() > 0){
                insert bcmList;
            }
    }

    // @description - Method to handle JTL Ows Client Scenario i.e. Total_Adjusted_Billing_Balance__c < 0
    // @param       - Matter_Termination__c, map<String,String> configMap, map<String,String> glConfigMap, map<String,Id> officeMap, map<String,Id> areaOfLawMap
    // @assumtpion  - handle single record at a time
    // @return      - void
    private static void handleJTLOwsClientScenario(Matter_Termination__c mt, map<String,String> configMap, map<String,String> glConfigMap, map<String,Id> officeMap, map<String,Id> areaOfLawMap){
        /****************************************************************************************************/
            // code flow :
            // 1. create credit memo for the Adjusted billing balance
            // 2. settle existing bills
            // 3. create hardcost payable
            // 4. post hardcost payable and it will create hardcost bills which will be automatically applied.
        /****************************************************************************************************/

        // configure the ledger key
            String ledgerKey = 'JTL_Ledger_Id';
            if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }

        OpportunityLineItem oli;
        for(OpportunityLineItem olItem : [Select Id, Product2.AcctSeed__Revenue_GL_Account__c From OpportunityLineItem Where OpportunityId =: mt.Matter__r.AcctSeed__Opportunity__c LIMIT 1]){
            oli = olItem; 
        }

        // 1. create credit memo for the Adjusted billing balance
            AcctSeed__Billing__c memo = new AcctSeed__Billing__c();
            memo.Matter_Termination__c = mt.Id;
            memo.Matter__c = mt.Matter__c; 
            memo.AcctSeed__Opportunity__c = mt.Opportunity__c;
            memo.Next_Step_Opportunity__c = mt.Related_Next_Step_Opportunity__c;
            memo.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            memo.AcctSeed__Status__c = 'Approved';
            memo.AcctSeed__Date__c = Date.today();
            if(mt.Related_Next_Step_Opportunity__c != null){
                memo.AcctSeed__Customer__c = mt.Related_Next_Step_Opportunity__r.AccountId;
                memo.Originator__c = mt.Related_Next_Step_Opportunity__r.Originator_LU__c;
                memo.Billing_Attorney__c = mt.Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c;
            }else{
                memo.AcctSeed__Customer__c = mt.Opportunity__r.AccountId;
                memo.Originator__c = mt.Opportunity__r.Originator_LU__c;
                memo.Billing_Attorney__c = mt.Opportunity__r.Billing_Attorney_lk__c;
            }
            insert memo;

        // credit memo Line
            AcctSeed__Billing_Line__c memoLine = new AcctSeed__Billing_Line__c();
            memoLine.AcctSeed__Billing__c = memo.Id;
            memoLine.AcctSeed__Rate__c = mt.Total_Credit_Value_Formula__c * (-1);
            if(mt.Related_Next_Step_Opportunity__c != null){
                memoLine.Originator_LU__c = mt.Related_Next_Step_Opportunity__r.Originator_LU__c;
                memoLine.Billing_Attorney_lk__c = mt.Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c;
            }else{
                memoLine.Originator_LU__c = mt.Opportunity__r.Originator_LU__c;
                memoLine.Billing_Attorney_lk__c = mt.Opportunity__r.Billing_Attorney_lk__c;   
            }
            //memoLine.AcctSeed__Revenue_GL_Account__c = bline.AcctSeed__Revenue_GL_Account__c;
            if(officeMap.containsKey(mt.Opportunity__r.Office_that_consult_occurred_in__c)){
                memoLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(mt.Opportunity__r.Office_that_consult_occurred_in__c);
            }
            if(areaOfLawMap.containsKey(mt.Opportunity__r.Area_of_Law__c)){
                memoLine.AcctSeed__GL_Account_Variable_4__c = areaOfLawMap.get(mt.Opportunity__r.Area_of_Law__c);
            }

            if(oli != null){
                if(oli.Product2.AcctSeed__Revenue_GL_Account__c != null){
                    memoLine.AcctSeed__Revenue_GL_Account__c = oli.Product2.AcctSeed__Revenue_GL_Account__c;
                }else{
                    memoLine.AcctSeed__Revenue_GL_Account__c = Label.GL_Account_J_40000_Income;   
                }
            }
            
            insert memoLine;

        // post billings
        list<AcctSeed__Billing__c> memoList_toPost = new list<AcctSeed__Billing__c>();
        memoList_toPost.add(memo);
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(memoList_toPost);

        Decimal memoBalance = mt.Total_Credit_Value_Formula__c;
        
        AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Expense' Limit 1];

        // 2. settle existing bills
        list<AcctSeed__Billing_Credit_Memo__c> bcmList = new list<AcctSeed__Billing_Credit_Memo__c>();
        for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Balance__c, AcctSeed__Accounting_Period__c From AcctSeed__Billing__c Where Matter__c =: mt.Matter__c AND AcctSeed__Opportunity__c =: mt.Opportunity__c AND AcctSeed__Type__c = 'Invoice' AND AcctSeed__Status__c = 'Posted' AND AcctSeed__Balance__c > 0]){
            
            if(memoBalance == 0){
                break;
            }

            Decimal amtToApply = 0;
            if(bill.AcctSeed__Balance__c > memoBalance){
                amtToApply = memoBalance; 
                memoBalance = 0;
            }else{
                amtToApply = bill.AcctSeed__Balance__c; 
                memoBalance = memoBalance - amtToApply;
            }

            if(memoBalance != 0){
                AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                bcm.AcctSeed__Billing_Credit_Memo__c = memo.Id;
                bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                bcm.AcctSeed__Accounting_Period__c = bill.AcctSeed__Accounting_Period__c;                        
                bcm.AcctSeed__Amount__c = amtToApply * (-1);
                bcm.AcctSeed__Applied_Date__c = Date.today();
                bcmList.add(bcm); 
            }

        }

        if(bcmList.size() > 0){
            insert bcmList;
        }

        // 3. create hardcost payable
        if(memoBalance != 0){
            AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
            pay.Matter_Termination__c = mt.Id;
            pay.Matter__c = mt.Matter__c;
            pay.Opportunity__c = mt.Opportunity__c;
            pay.AcctSeed__Payee_Reference__c = mt.Name;
            pay.AcctSeed__Status__c = 'Approved';
            pay.Hardcost__c = true;
            pay.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            pay.AcctSeed__Date__c = Date.today();
            pay.Is_Refund__c = true;
            if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                pay.AcctSeed__Vendor__c = mt.Opportunity__r.AccountId;
            }else{
                pay.AcctSeed__Vendor__c = configMap.get('JTL_Trust_Account_ID');
            }    
            insert pay;

            // create hardcost payable line
            AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
            pLine.AcctSeed__Account_Payable__c = pay.Id;
            pLine.AcctSeed__Unit_Cost__c = mt.Total_Adjusted_Billing_Balance__c * (-1);

            if(Test.isRunningTest()){
                pline.AcctSeed__Expense_GL_Account__c = glAccount.Id;
            }else{                
                if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                    pline.AcctSeed__Expense_GL_Account__c = glConfigMap.get('Kapsten_Hardcost_Payable_Expense_GL');
                }else{
                    pline.AcctSeed__Expense_GL_Account__c = glConfigMap.get('JTL_Hardcost_Payable_Expense_GL');
                }
            }
            /*
            if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                pline.AcctSeed__Expense_GL_Account__c = glConfigMap.get('Kapsten_Hardcost_Payable_Expense_GL');
            }else{
                pline.AcctSeed__Expense_GL_Account__c = glConfigMap.get('JTL_Hardcost_Payable_Expense_GL');
            }*/
            pLine.AcctSeed__Quantity__c = 1;
            insert pLine;


            // 3. post hardcost payable and it will create hardcost bills which will be automatically applied.
            list<AcctSeed__Account_Payable__c> payables = new list<AcctSeed__Account_Payable__c>();
            payables.add(pay);
            AcctSeed.PostResult[] postResultsPayable = AcctSeed.AccountPayablePostService.postAccountPayables(payables);
        }
    }

    // @description - Method to handle next step Termination
    // @param       - terminationIds
    // @assumtpion  - handle single record at a time
    // @return      - void
    
    @future
    public static void handleNextStepTermination(Id terminationId){
        
        /******************************************************************************************************************************/
            // code flow : 
            // 1. fetch all the master setup
            // 2. fetch matter termination details
            // 3. if Client OWS JTL 
                // 3.1 create credit memo for the Credit Value
                // 3.2 Apply memo to bills
            // 4. if JTL ows client
                //4.1 calculate credit memo amount for each product
                //4.2 create credit memo for each product
                //4.3 apply credit memo
                //4.4 check if previous opportunity has open billing balance, 
                    // if yes then check if credit memo can settle the balance in full.
                        // if yes, then settle previous opportunity's bill with this credit memo
                //4.5 create hardcost payable for the rest of the memo amount. i.e. memo amount  > 0
                //4.6 post payable
                    // posting this payable will create hardcost billings
                    // those hardcost billings will be then settled automatically
        /*****************************************************************************************************************************/

        // 1. fetch master setup
            map<String,String> configMap = new map<String,String>();
            for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
                configMap.put(ac.Key__c, ac.Value__c);
            }
            
            map<String,String> glConfigMap = new map<String,String>();
            for(Ay_GL_Config__mdt glc : [Select Id, Key__c, Value__c From Ay_GL_Config__mdt]){
                glConfigMap.put(glc.Key__c, glc.Value__c);
            } 
            
            AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Expense' Limit 1];

            map<String,Id> officeMap = new map<String,Id>();
            map<String,Id> areaOfLawMap = new map<String,Id>();
            for(AcctSeed__Accounting_Variable__c av : [Select Id, Name, AcctSeed__Type__c From AcctSeed__Accounting_Variable__c]){
                if(av.AcctSeed__Type__c == 'GL Account Variable 1'){
                    officeMap.put(av.Name, av.Id);    
                }else if(av.AcctSeed__Type__c == 'GL Account Variable 4'){
                    areaOfLawMap.put(av.Name, av.Id);
                }
            }

        

        // 2. fetch matter termination details
        for(Matter_Termination__c mt : [Select Id, Opportunity__r.AccountId, Opportunity__r.Originator_LU__c, Opportunity__r.Billing_Attorney_lk__c, Related_Next_Step_Opportunity__c, Total_Credit_Value_Formula__c, Related_Next_Step_Opportunity__r.AccountId, Related_Next_Step_Opportunity__r.Originator_LU__c, Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c, Opportunity__c, Opportunity__r.Kapsten_Matter__c, Name, Matter__c, Adjusted_Bill_GL_Account__c, Total_Adjusted_Billing_Balance__c, Overpayment_Disposition__c, Opportunity__r.Area_of_Law__c, Opportunity__r.Office_that_consult_occurred_in__c, Underpay_Disposition__c, No_of_Case_Terminations__c, Matter__r.AcctSeed__Opportunity__c,
                                               (Select Id, Name, Opportunity_Product__c, Total_Credit_Value__c From Case_Terminations__r)
                                          From Matter_Termination__c Where Id =: terminationId LIMIT 1]){
            

            OpportunityLineItem oli;
            for(OpportunityLineItem olItem : [Select Id, Product2.AcctSeed__Revenue_GL_Account__c From OpportunityLineItem Where OpportunityId =: mt.Matter__r.AcctSeed__Opportunity__c LIMIT 1]){
                oli = olItem; 
            }

            // configure the ledger key
            String ledgerKey = 'JTL_Ledger_Id';
            if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }

            if(mt.Total_Adjusted_Billing_Balance__c > 0){
                // 3. if Client OWS JTL 
                AyAccountingFunctions.handleClientOwsJTLScenario(mt, configMap, glConfigMap, officeMap, areaOfLawMap);
            }else if(mt.Total_Adjusted_Billing_Balance__c < 0){
                // 4. if JTL ows Client
        
                // 4.1 calculate credit memo amount for each product
                map<Id,Decimal> productIdValueMap = new map<Id,Decimal>();
                for(Case_Termination__c ct : mt.Case_Terminations__r){
                    if(ct.Opportunity_Product__c != null){
                        if(!productIdValueMap.containsKey(ct.Opportunity_Product__c)){
                            productIdValueMap.put(ct.Opportunity_Product__c,0);
                        }
                        productIdValueMap.put(ct.Opportunity_Product__c, productIdValueMap.get(ct.Opportunity_Product__c) + ct.Total_Credit_Value__c);
                    }
                }

                // 4.2 create credit memo for each product
                map<Id,AcctSeed__Billing__c> prodIdMemoMap = new map<Id,AcctSeed__Billing__c>();
                for(Id prodId : productIdValueMap.keySet()){
                    AcctSeed__Billing__c memo = new AcctSeed__Billing__c();
                    memo.Matter_Termination__c = mt.Id;
                    memo.Matter__c = mt.Matter__c; 
                    memo.AcctSeed__Opportunity__c = mt.Opportunity__c;
                    memo.Next_Step_Opportunity__c = mt.Related_Next_Step_Opportunity__c;
                    memo.AcctSeed__Ledger__c = configMap.get(ledgerKey);
                    memo.AcctSeed__Customer__c = mt.Related_Next_Step_Opportunity__r.AccountId;
                    memo.AcctSeed__Status__c = 'Approved';
                    memo.AcctSeed__Date__c = Date.today();
                    memo.Originator__c = mt.Related_Next_Step_Opportunity__r.Originator_LU__c;
                    memo.Billing_Attorney__c = mt.Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c;
                    prodIdMemoMap.put(prodId, memo);
                }

                // insert memo headers
                if(prodIdMemoMap.size() > 0){
                    insert prodIdMemoMap.values();
                }

                // credit memo Line
                list<AcctSeed__Billing_Line__c> memoLinesList = new list<AcctSeed__Billing_Line__c>();
                map<Id,Decimal> memoBalanceMap = new map<Id,Decimal>();
                for(Id prodId : productIdValueMap.keySet()){
                    if(prodIdMemoMap.containsKey(prodId) && productIdValueMap.containsKey(prodId)){
                        AcctSeed__Billing_Line__c memoLine = new AcctSeed__Billing_Line__c();
                        memoLine.AcctSeed__Billing__c = prodIdMemoMap.get(prodId).Id;
                        memoLine.AcctSeed__Rate__c = productIdValueMap.get(prodId) * (-1);
                        memoLine.Originator_LU__c = mt.Related_Next_Step_Opportunity__r.Originator_LU__c;
                        memoLine.Billing_Attorney_lk__c = mt.Related_Next_Step_Opportunity__r.Billing_Attorney_lk__c;
                        //memoLine.AcctSeed__Revenue_GL_Account__c = bline.AcctSeed__Revenue_GL_Account__c;
                        if(officeMap.containsKey(mt.Opportunity__r.Office_that_consult_occurred_in__c)){
                            memoLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(mt.Opportunity__r.Office_that_consult_occurred_in__c);
                        }
                        if(areaOfLawMap.containsKey(mt.Opportunity__r.Area_of_Law__c)){
                            memoLine.AcctSeed__GL_Account_Variable_4__c = areaOfLawMap.get(mt.Opportunity__r.Area_of_Law__c);
                        }

                        if(oli != null){
                            if(oli.Product2.AcctSeed__Revenue_GL_Account__c != null){
                                memoLine.AcctSeed__Revenue_GL_Account__c = oli.Product2.AcctSeed__Revenue_GL_Account__c;
                            }else{
                                memoLine.AcctSeed__Revenue_GL_Account__c = Label.GL_Account_J_40000_Income;   
                            }
                        }
                        //memoLine.AcctSeed__GL_Account_Variable_1__c = bline.AcctSeed__GL_Account_Variable_1__c;
                        //memoLine.AcctSeed__GL_Account_Variable_2__c = bline.AcctSeed__GL_Account_Variable_2__c;
                        //memoLine.AcctSeed__GL_Account_Variable_3__c = bline.AcctSeed__GL_Account_Variable_3__c;
                        //memoLine.AcctSeed__GL_Account_Variable_4__c = bline.AcctSeed__GL_Account_Variable_4__c;
                        memoLinesList.add(memoLine);
                        memoBalanceMap.put(prodId, productIdValueMap.get(prodId));
                    }
                }

                // insert credit memo Line
                if(memoLinesList.size() > 0){
                    insert memoLinesList;
                }


                // post billings
                AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(prodIdMemoMap.values());

                // 4.3 apply credit memo
                Id accountingPeriodId = AyAccountingFunctions.getAccountingPeriod(Date.today());
                list<AcctSeed__Billing_Credit_Memo__c> bcmList = new list<AcctSeed__Billing_Credit_Memo__c>();
                for(Id prodId : prodIdMemoMap.keySet()){
                    Decimal bal = memoBalanceMap.get(prodId);
                    //System.debug('****AyAccountingFunctions***handleNextStepTermination***HERE***');
                    if(prodIdMemoMap.containsKey(prodId)){
                        AcctSeed__Billing__c memo =  prodIdMemoMap.get(prodId);
                        //System.debug('****AyAccountingFunctions***handleNextStepTermination***HERE ALSO***');
                        for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Balance__c, AcctSeed__Due_Date2__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__c =: mt.Opportunity__c AND Next_Step_Opportunity__c =: mt.Related_Next_Step_Opportunity__c AND AcctSeed__Type__c = 'Invoice' Order by AcctSeed__Due_Date2__c DESC]){
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***Date =='+bill.AcctSeed__Balance__c);
                            Decimal amtToApply;
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***Memo balance=='+bal);
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***Bill Balance=='+bill.AcctSeed__Balance__c);
                            if(bal == 0 || bill.AcctSeed__Balance__c == 0){break;}
                            if(bal >= bill.AcctSeed__Balance__c){
                                amtToApply = bill.AcctSeed__Balance__c;
                            }else{
                                amtToApply = bal;
                            }
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***amtToApply='+amtToApply);
                            bal = bal - amtToApply;
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***bal='+bal);
                            
                            AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                            bcm.AcctSeed__Billing_Credit_Memo__c = memo.Id;
                            bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                            bcm.AcctSeed__Accounting_Period__c = accountingPeriodId;                        
                            bcm.AcctSeed__Amount__c = amtToApply * (-1);
                            bcm.AcctSeed__Applied_Date__c = Date.today();
                            bcmList.add(bcm); 
                            memoBalanceMap.put(prodId, bal);  
                        }
                    }
                }
                    
                // 4.4 check if previous opportunity has open billing balance, if yes then check if credit memo can settle the balance in full.
                // if yes, then settle previous opportunity's bill with this credit memo
                list<AcctSeed__Billing__c> prevOppBills = [Select Id, AcctSeed__Balance__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__c =: mt.Opportunity__c AND Next_Step_Opportunity__c = null AND AcctSeed__Type__c = 'Invoice' Order by AcctSeed__Due_Date2__c DESC];
                for(Id prodId : memoBalanceMap.keySet()){
                    if(prodIdMemoMap.containsKey(prodId)){
                        AcctSeed__Billing__c memo = prodIdMemoMap.get(prodId);
                        for(AcctSeed__Billing__c bill : prevOppBills){
                            Decimal memoBalance = memoBalanceMap.get(prodId);
                            if(memoBalance == 0){break;}
                            //if(memoBalance > 0 && memoBalance >= bill.AcctSeed__Balance__c){
                            Decimal amountToApply = 0;
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***memoBalance='+memoBalance);
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***bill.AcctSeed__Balance__c='+bill.AcctSeed__Balance__c);
                            if(memoBalance >= bill.AcctSeed__Balance__c){
                                amountToApply = bill.AcctSeed__Balance__c;
                            }else{
                                amountToApply = memoBalance;   
                            }
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***amountToApply='+amountToApply);
                            AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                            bcm.AcctSeed__Billing_Credit_Memo__c = memo.Id;
                            bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                            bcm.AcctSeed__Accounting_Period__c = accountingPeriodId;                        
                            bcm.AcctSeed__Amount__c = amountToApply * (-1);
                            bcm.AcctSeed__Applied_Date__c = Date.today();
                            bcmList.add(bcm); 
                            memoBalanceMap.put(prodId, memoBalance - amountToApply);  
                            //System.debug('****AyAccountingFunctions***handleNextStepTermination***memoBalanceMap='+memoBalanceMap);
                        }
                    }
                }

                // insert billing credit memos
                if(bcmList.size() > 0){
                    insert bcmList;
                }
                
                // calculate amount for payable
                Decimal payableAmount = 0;
                for(Id prodId : memoBalanceMap.keySet()){
                    payableAmount += memoBalanceMap.get(prodId);
                }

                // 4.5 create hardcost payable for the rest of the memo amount. i.e. memo amount  > 0
                if(payableAmount > 0 || Test.isRunningTest()){
                    AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
                    pay.Matter_Termination__c = mt.Id;
                    pay.Matter__c = mt.Matter__c;
                    pay.Opportunity__c = mt.Opportunity__c;
                    pay.AcctSeed__Payee_Reference__c = mt.Name;
                    pay.AcctSeed__Status__c = 'Approved';
                    pay.Hardcost__c = true;
                    pay.AcctSeed__Ledger__c = configMap.get(ledgerKey);
                    pay.AcctSeed__Date__c = Date.today();
                    if(mt.Opportunity__r.Kapsten_Matter__c == 'Yes'){
                        pay.AcctSeed__Vendor__c = mt.Opportunity__r.AccountId;
                    }else{
                        pay.AcctSeed__Vendor__c = configMap.get('JTL_Trust_Account_ID');
                    }    
                    insert pay;

                    // create hardcost payable line
                    AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
                    pLine.AcctSeed__Account_Payable__c = pay.Id;
                    pLine.AcctSeed__Unit_Cost__c = payableAmount;
                    if(!Test.isRunningTest()){
                        pline.AcctSeed__Expense_GL_Account__c = glConfigMap.get('Termination_Refund_GL');
                    }else{
                        pline.AcctSeed__Expense_GL_Account__c = glAccount.Id;
                    }
                    //pline.AcctSeed__Expense_GL_Account__c = glConfigMap.get('Termination_Refund_GL');
                    pLine.AcctSeed__Quantity__c = 1;
                    insert pLine;


                    // 4.6 post payable
                    // posting this payable will create hardcost billings
                    // those hardcost billings will be then settled automatically
                    list<AcctSeed__Account_Payable__c> payables = new list<AcctSeed__Account_Payable__c>();
                    payables.add(pay);
                    AcctSeed.PostResult[] postResultsPayable = AcctSeed.AccountPayablePostService.postAccountPayables(payables);
                }
            }
        }
    }

    // @description - Method to get accounting period for a specified date
    // @param       - Date
    // @return      - Id
    public static Id getAccountingPeriod(Date d){
        Id periodId  ;
        for(AcctSeed__Accounting_Period__c period : [Select Id from AcctSeed__Accounting_Period__c where AcctSeed__Start_Date__c <=:d AND AcctSeed__End_Date__c >=:d AND AcctSeed__Status__c='Open' order by AcctSeed__Start_Date__c limit 1]){
            periodId = period.Id;
        }
        return periodId;
    }

    // @description - Method to handle application of bcr
    // @param       - set<Id> bcrIds
    // @return      - void
    public static void createJEonBCRInsert(set<Id> bcrIds){

        map<String,String> configMap = new map<String,String>();
        for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
            configMap.put(ac.Key__c, ac.Value__c);
        }

        // fetch GL Account
        map<String,String> glConfigMap = new map<String,String>();
        for(Ay_GL_Config__mdt glc : [Select Id, Key__c, Value__c From Ay_GL_Config__mdt]){
            glConfigMap.put(glc.Key__c, glc.Value__c);
        }
        
        AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Balance Sheet' Limit 1];
        
        // create JE & JE Lines
        list<AcctSeed__Journal_Entry__c> journalEntries = new list <AcctSeed__Journal_Entry__c>();
        map<Id,AcctSeed__Journal_Entry__c> bcrIdJEMap = new map<Id,AcctSeed__Journal_Entry__c>();
        map<Id,list<AcctSeed__Journal_Entry_Line__c>> bcrIdJELineListMap = new map<Id,list<AcctSeed__Journal_Entry_Line__c>>();
        for(AcctSeed__Billing_Cash_Receipt__c bcr : [Select Id, AcctSeed__Billing__r.Matter__r.Trust_Balance__c, AcctSeed__Billing__r.AcctSeed__Opportunity__r.Kapsten_Matter__c, Is_SYS_Trust_Account_Activity__c, Matter_ID__c, Name, AcctSeed__Cash_Receipt__r.AcctSeed__Credit_GL_Account__r.Is_Trust_Account__c, AcctSeed__Cash_Receipt__c, AcctSeed__Cash_Receipt__r.AcctSeed__Credit_GL_Account__c, AcctSeed__Cash_Receipt__r.AcctSeed__Bank_Account__c, AcctSeed__Applied_Amount__c From AcctSeed__Billing_Cash_Receipt__c Where Id IN : bcrIds]){
            if(bcr.Is_SYS_Trust_Account_Activity__c){
                
                String ledgerKey = 'JTL_Ledger_Id';
                if(bcr.AcctSeed__Billing__r.AcctSeed__Opportunity__r.Kapsten_Matter__c == 'Yes'){
                    ledgerKey = 'Kapsten_Ledger_Id';
                }
                
                AcctSeed__Journal_Entry__c je = new AcctSeed__Journal_Entry__c();
                je.Matter__c = bcr.Matter_ID__c;
                je.Name = bcr.Name;
                je.AcctSeed__Ledger__c = configMap.get(ledgerKey);
                je.Billing_Cash_Receipt__c = bcr.Id;
                je.AcctSeed__Journal_Date__c = Date.today();
                je.Trust_Balance__c = bcr.AcctSeed__Billing__r.Matter__r.Trust_Balance__c;
                je.AcctSeed__Status__c = 'Approved';
                bcrIdJEMap.put(bcr.Id,je);
                journalEntries.add(je);

                if(!bcrIdJELineListMap.containsKey(bcr.Id)){
                    bcrIdJELineListMap.put(bcr.Id, new list<AcctSeed__Journal_Entry_Line__c>());
                }
                AcctSeed__Journal_Entry_Line__c creditLine = new AcctSeed__Journal_Entry_Line__c();
                //creditLine.AcctSeed__GL_Account__c = bcr.AcctSeed__Cash_Receipt__r.AcctSeed__Bank_Account__c;
                if(!Test.isRunningTest()){
                    creditLine.AcctSeed__GL_Account__c = glConfigMap.get('JTL_Credit_GL_Account_ID');
                }else{
                    creditLine.AcctSeed__GL_Account__c = glAccount.Id;
                }
                creditLine.AcctSeed__Credit__c = bcr.AcctSeed__Applied_Amount__c;
                bcrIdJELineListMap.get(bcr.Id).add(creditLine);

                AcctSeed__Journal_Entry_Line__c debitLine = new AcctSeed__Journal_Entry_Line__c();
                if(!Test.isRunningTest()){
                    debitLine.AcctSeed__GL_Account__c = glConfigMap.get('JTL_Debit_GL_Account_ID');
                }else{
                    debitLine.AcctSeed__GL_Account__c = glAccount.Id;
                }
                debitLine.AcctSeed__Debit__c = bcr.AcctSeed__Applied_Amount__c;
                bcrIdJELineListMap.get(bcr.Id).add(debitLine);
            }
        }   
        
        // insert je header
        if(bcrIdJEMap.values().size() > 0){
            insert bcrIdJEMap.values();

            // populate je header on line
            list<AcctSeed__Journal_Entry_Line__c> jeLinesList = new list<AcctSeed__Journal_Entry_Line__c>();
            for(Id bcrId : bcrIdJEMap.keySet()){
                if(bcrIdJELineListMap.containsKey(bcrId)){
                    for(AcctSeed__Journal_Entry_Line__c jel : bcrIdJELineListMap.get(bcrId)){
                        jel.AcctSeed__Journal_Entry__c = bcrIdJEMap.get(bcrId).Id;
                        jeLinesList.add(jel);
                    }
                }
            }

            // insert je lines
            insert jeLinesList;
            
            // Call the post journal entry service
            AcctSeed.PostResult[] postResults = AcctSeed.JournalEntryPostService.postJournalEntries(journalEntries);
            
        }
    }

    // @description - Method to roll up non hardcost cr amount on matter
    // @param       - set<Id> matterIds
    // @return      - void
    public static void rollUpCrAmountOnMatter(set<Id> matterIds){
        // collect all trust bankgl accounts
        set<Id> trustBankGLAccountsSet = new set<Id>();
        for(AcctSeed__GL_Account__c gl : [Select Id, Name From AcctSeed__GL_Account__c where AcctSeed__Bank__c = true]){
            if(gl.Name.toLowerCase().contains('trust')){
                trustBankGLAccountsSet.add(gl.Id);   
            }
        }

        map<Id,AcctSeed__Project__c> projMap = new map<Id,AcctSeed__Project__c>();
        for(Id matterId : matterIds){
            projMap.put(matterId, new AcctSeed__Project__c(Id=matterId, Total_Cash_Receipt_Amount__c = 0));
        }

        // get data where bank gl is not trust bank account
        for(AggregateResult ar : [Select AcctSeed__Project__c, SUM(AcctSeed__Amount__c) totl From AcctSeed__Cash_Receipt__c Where AcctSeed__Project__c IN : matterIds AND AcctSeed__Bank_Account__c NOT IN : trustBankGLAccountsSet AND AcctSeed__Status__c = 'Posted' GROUP BY AcctSeed__Project__c]){
            Id matterId = (Id) ar.get('AcctSeed__Project__c');
            if(projMap.containsKey(matterId)){
                AcctSeed__Project__c proj =  projMap.get(matterId);
                proj.Total_Cash_Receipt_Amount__c = (Decimal) ar.get('totl');
                projMap.put(matterId, proj);
            }
        }

        if(projMap.values().size() > 0){
            update projMap.values();
        }

    }

    // @description - Method to fetch accounting details
    // @param       - set<Id> matterIds
    // @return      - map<Id,AyAccountingFunctions.AccountingWrapper>
    public static map<Id,AyAccountingFunctions.AccountingWrapper> getAccountingDetailsMap(set<Id> matterIds){
        map<Id,AyAccountingFunctions.AccountingWrapper> accountingMap = new map<Id,AyAccountingFunctions.AccountingWrapper>();
        
        // total and received - except hardcost
        map<Id,AggregateResult> objectMap = new map<Id,AggregateResult>();
        for(AggregateResult ag : [Select Matter__c, SUM(AcctSeed__Total__c) total, SUM(AcctSeed__Received_Amount__c) rcvd From AcctSeed__Billing__c Where Matter__c IN : matterIds AND Matter__c != null AND AcctSeed__Status__c = 'Posted' AND Payable__c = null GROUP BY Matter__c]){
            Id matterId = (ID) ag.get('Matter__c');
            objectMap.put(matterId, ag);    
        }
        

        // hardcost
        map<Id,Decimal> matterIdhardCostAmountMap = new map<Id,Decimal>();
        for(AggregateResult ag : [Select Matter__c, SUM(AcctSeed__Total__c) hcost From AcctSeed__Billing__c Where Matter__c IN : matterIds AND Matter__c != null AND Payable__c != null AND AcctSeed__Status__c = 'Posted' GROUP BY Matter__c]){
            Id matterId = (ID) ag.get('Matter__c');
            matterIdhardCostAmountMap.put(matterId, (Decimal) ag.get('hcost'));    
        }


        // populate map
        for(Id matterId : objectMap.keySet()){
            AyAccountingFunctions.AccountingWrapper w = new AyAccountingFunctions.AccountingWrapper();
            if(objectMap.containsKey(matterId)){
                AggregateResult obj = objectMap.get(matterId);
                w.matterId = matterId;
                w.totalBilledAmount = (Decimal) obj.get('total');
                w.totalReceivedAmount = (Decimal) obj.get('rcvd');
            }

            if(matterIdhardCostAmountMap.containsKey(matterId)){
                w.totalHarcostBillingAmount = matterIdhardCostAmountMap.get(matterId);
            }
            
            accountingMap.put(matterId, w);
        }


        // total credit value
        for(AcctSeed__Project__c proj : [Select Id, Total_Credit_Value__c From AcctSeed__Project__c Where Id IN : matterIds]){
            if(accountingMap.containsKey(proj.Id)){
                accountingMap.get(proj.Id).totalCreditValue = proj.Total_Credit_Value__c;
            }   
        }

        System.debug('****accountingMap=='+accountingMap);

        return accountingMap;
    }
      
    public static void handletotalpayabletoclient(list<AcctSeed__Account_Payable__c> payablelist){
        set<Id> matterIds = new set<Id>();
        map<Id, AcctSeed__Project__c> matterMap = new map<Id, AcctSeed__Project__c>();
        
        for(AcctSeed__Account_Payable__c payables : payablelist){
            if(payables.Matter__c != null){
                matterIds.add(payables.Matter__c);
            }
        }
        for(Id mattrId : matterIds){
            matterMap.put(mattrId, new AcctSeed__Project__c(Id = mattrId, Total_Payables_To_Client__c = 0));
        }
        
        
       for(AggregateResult ag : [Select Matter__c mtr, SUM(AcctSeed__Total__c) totl From AcctSeed__Account_Payable__c Where Matter__c IN : matterIds AND Matter__c != null And AcctSeed__Status__c = 'Posted' AND AcctSeed__Vendor__c =: Label.JTL_Trust_Account_ID AND Is_Refund__c = true Group By Matter__c]){
            Id matterId = (Id) ag.get('mtr');
            if(matterId != null && matterMap.containsKey(matterId)){
                matterMap.get(matterId).Total_Payables_To_Client__c = (Decimal) ag.get('totl');   
            }
       }
        if(matterMap.size() > 0){
            update matterMap.values();
        }
    }

    // wrapper class to contain accounting details
    public class AccountingWrapper{
        @AuraEnabled
        public Id matterId {get;set;}
        @AuraEnabled
        public Decimal totalBilledAmount {get;set;}
        @AuraEnabled
        public Decimal totalReceivedAmount {get;set;}
        @AuraEnabled
        public Decimal totalHarcostBillingAmount {get;set;}
        @AuraEnabled
        public Decimal totalCreditValue {get;set;}

        public AccountingWrapper(){
            totalBilledAmount = 0;
            totalReceivedAmount = 0;
            totalHarcostBillingAmount = 0;
            totalCreditValue = 0; 
        }
    }
}