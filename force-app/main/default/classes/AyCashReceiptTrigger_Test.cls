/***************************************************
@author       :  Shubham@Ayodia
@date         :  12march,2020
@description  :  TestClass for AyCashReceiptTrigger
****************************************************/
@isTest
private class AyCashReceiptTrigger_Test {
    
    private static testMethod void testautoApplyCR(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in User 
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        AyTestDataSuite.Opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.Opportunities[0].Originator_LU__c = u.Id;
        AyTestDataSuite.Opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.Opportunities[0].Area_of_Law__c = 'Criminal Defense';
        update AyTestDataSuite.Opportunities[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Project TestData
        accorto__Project__c pro = new accorto__Project__c();
        pro.Name = 'City of Hugo';
        pro.Matter__c = matter.Id;
        pro.accorto__IsActive__c  = true;
        insert pro;
        
        // Setup Project Line TestData
        accorto__Project_Line__c projectLine = new accorto__Project_Line__c();
        projectLine.Name = 'Test Project Line';
        projectLine.accorto__Project__c = pro.Id;
        projectLine.accorto__Unit_Price__c = 10;
        insert projectLine;
        
        // Setup Product TestData
        Product2 product = new Product2();
        product.Name = 'Additional 1-hour meeting with attorney';
        product.ProductCode = 'Amwa';
        product.IsActive = true;
        product.Family = 'Diyvorce';
        insert product; 
        
        // Setup Resource TestData
        accorto__Resource__c res = new accorto__Resource__c();
        res.Name = 'Kunal Sharma';
        res.accorto__IsActive__c = true;
        res.accorto__Code__c = 'KS';
        insert res;
        
        // Setup DocumentType TestData
        accorto__DocumentType__c docType = new accorto__DocumentType__c();
        docType.Name = 'AR Invoice';
        docType.accorto__IsReceivables__c = true;
        docType.accorto__IsDefault__c = true;
        docType.accorto__DocNo_Current__c = 2000;
        docType.accorto__DocNo_Increment__c = 1;
        docType.accorto__DocNo_Format__c = '{0}';
        insert docType;
        
        // Setup Invoice TestData
        accorto__Invoice__c inv = new accorto__Invoice__c ();
        inv.Name = '10';
        inv.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        inv.accorto__Project__c = pro.Id;
        inv.accorto__DocumentType__c = docType.Id;
        inv.accorto__BillingStreet2__c = '500 North Michigan Avenue';
        inv.accorto__BillingCity__c = 'Chicago';
        inv.accorto__BillingState__c = 'IL';
        inv.accorto__BillingPostalCode__c = '60611';
        inv.accorto__BillingCountry__c = 'United States';
        insert inv;
        
        // Setup Invoice Line TestData
        accorto__InvoiceLine__c invLine = new accorto__InvoiceLine__c();
        invLine.accorto__Invoice__c = inv.Id;
        invLine.accorto__Resource__c = res.Id;
        invLine.accorto__Product__c = product.Id;
        invLine.accorto__Project__c = pro.Id;
        invLine.accorto__Project_Line__c = projectLine.Id;
        invLine.accorto__Quantity__c = 10;
        invLine.accorto__Hours__c = 10;
        invLine.accorto__ListPrice__c = 100;
        invLine.accorto__UnitPrice__c = 100;
        insert invLine;
        
        // Setup affinipay Transaction TestData
        affinipay__Transaction__c trans = new affinipay__Transaction__c();
        trans.Matter__c = matter.Id;
        trans.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        trans.affinipay__Link_Object_ID__c = AyTestDataSuite.accounts[0].Id;
        trans.Transaction_Type__c = 'Deposit to Trust';
        insert trans;
        
        // Setup Finance TestData        
        Finance__c fin = new Finance__c();
        fin.Downpayment__c = 10000;
        fin.Payment_Frequency__c= 'Monthly';
        fin.No_of_Instalments__c = 1;
        fin.Create_Accounting__c = false;
        fin.Parent_Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        fin.Matter__c = matter.Id;
        fin.First_Instalment_Payment_Date__c = date.today();
        insert fin;
        
        // Start Test
        Test.startTest();
        
        // Setup Cash receipt TestData 1
        AcctSeed__Cash_Receipt__c cashReceipts = new AcctSeed__Cash_Receipt__c();
        cashReceipts.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cashReceipts.AcctSeed__Amount__c = 200;
        cashReceipts.AcctSeed__Payment_Reference__c = '0000000432';
        cashReceipts.AcctSeed__Status__c = 'Draft';
        cashReceipts.AcctSeed__Receipt_Date__c = AyTestDataSuite.acctPeriods[0].AcctSeed__Start_Date__c;
        cashReceipts.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        cashReceipts.AcctSeed__Project__c = matter.Id;
        cashReceipts.Affinipay_Transaction__c = trans.Id;
        cashReceipts.Auto_Apply__c = false;        
        insert cashReceipts;
        
        // Cash receipt List
        list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
        receipts.add(cashReceipts);
        
        // Post the cash receipts
        AcctSeed.PostResult[] postResultsCR = AcctSeed.CashReceiptPostService.postCashReceipts(receipts);
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.Accorto_Invoice__c = inv.Id;
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        bill.Finance__c = fin.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 40;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;
        
        // Billing List
        List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c>();
        billings.add(bill);
        
        // Call the post billings service
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billings);
        
        // Setup Cash Receipt TestData 2
        AcctSeed__Cash_Receipt__c cr2 = new AcctSeed__Cash_Receipt__c();
        cr2.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cr2.AcctSeed__Amount__c = 1000;
        cr2.AcctSeed__Payment_Reference__c = '0000000432';
        cr2.AcctSeed__Status__c = 'Posted';
        cr2.AcctSeed__Receipt_Date__c = AyTestDataSuite.acctPeriods[0].AcctSeed__Start_Date__c;
        cr2.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        cr2.Auto_Apply__c = false;      
        cr2.Affinipay_Transaction__c = trans.Id;
        insert cr2;
        
        cr2.Auto_Apply__c = true;
        update cr2;
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod void testautoApplyCR1(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in User 
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        AyTestDataSuite.Opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.Opportunities[0].Originator_LU__c = u.Id;
        AyTestDataSuite.Opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.Opportunities[0].Area_of_Law__c = 'Criminal Defense';
        update AyTestDataSuite.Opportunities[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Project TestData
        accorto__Project__c pro = new accorto__Project__c();
        pro.Name = 'City of Hugo';
        pro.Matter__c = matter.Id;
        pro.accorto__IsActive__c  = true;
        insert pro;
        
        // Setup Project Line TestData
        accorto__Project_Line__c projectLine = new accorto__Project_Line__c();
        projectLine.Name = 'Test Project Line';
        projectLine.accorto__Project__c = pro.Id;
        projectLine.accorto__Unit_Price__c = 10;
        insert projectLine;
        
        // Setup Product TestData
        Product2 product = new Product2();
        product.Name = 'Additional 1-hour meeting with attorney';
        product.ProductCode = 'Amwa';
        product.IsActive = true;
        product.Family = 'Diyvorce';
        insert product; 
        
        // Setup Resource TestData
        accorto__Resource__c res = new accorto__Resource__c();
        res.Name = 'Kunal Sharma';
        res.accorto__IsActive__c = true;
        res.accorto__Code__c = 'KS';
        insert res;
        
        // Setup DocumentType TestData
        accorto__DocumentType__c docType = new accorto__DocumentType__c();
        docType.Name = 'AR Invoice';
        docType.accorto__IsReceivables__c = true;
        docType.accorto__IsDefault__c = true;
        docType.accorto__DocNo_Current__c = 2000;
        docType.accorto__DocNo_Increment__c = 1;
        docType.accorto__DocNo_Format__c = '{0}';
        insert docType;
        
        // Setup Invoice TestData
        accorto__Invoice__c inv = new accorto__Invoice__c ();
        inv.Name = '10';
        inv.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        inv.accorto__Project__c = pro.Id;
        inv.accorto__DocumentType__c = docType.Id;
        inv.accorto__BillingStreet2__c = '500 North Michigan Avenue';
        inv.accorto__BillingCity__c = 'Chicago';
        inv.accorto__BillingState__c = 'IL';
        inv.accorto__BillingPostalCode__c = '60611';
        inv.accorto__BillingCountry__c = 'United States';
        insert inv;
        
        // Setup Invoice Line TestData
        accorto__InvoiceLine__c invLine = new accorto__InvoiceLine__c();
        invLine.accorto__Invoice__c = inv.Id;
        invLine.accorto__Resource__c = res.Id;
        invLine.accorto__Product__c = product.Id;
        invLine.accorto__Project__c = pro.Id;
        invLine.accorto__Project_Line__c = projectLine.Id;
        invLine.accorto__Quantity__c = 10;
        invLine.accorto__Hours__c = 10;
        invLine.accorto__ListPrice__c = 100;
        invLine.accorto__UnitPrice__c = 100;
        insert invLine;
        
        // Start Test
        Test.startTest();
        
        // Setup Cash receipt TestData
        AcctSeed__Cash_Receipt__c cashReceipts = new AcctSeed__Cash_Receipt__c();
        cashReceipts.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cashReceipts.AcctSeed__Amount__c = 1000;
        cashReceipts.AcctSeed__Payment_Reference__c = '0000000432';
        cashReceipts.AcctSeed__Status__c = 'Posted';
        cashReceipts.AcctSeed__Receipt_Date__c = AyTestDataSuite.acctPeriods[0].AcctSeed__Start_Date__c;
        cashReceipts.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        cashReceipts.AcctSeed__Project__c = matter.Id;
        cashReceipts.Auto_Apply__c = false;        
        insert cashReceipts;
        
        // Update Cash receipt TestData
        cashReceipts.Auto_Apply__c = true; 
        update cashReceipts;
        
        // Cash receipt List
        list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
        receipts.add(cashReceipts);
        
        // Unpost the cash receipts
        AcctSeed.PostResult[] unPostResultsCR = AcctSeed.CashReceiptPostService.unpostCashReceipts(receipts);
        
        // Stop Test
        Test.stopTest();
    }
}