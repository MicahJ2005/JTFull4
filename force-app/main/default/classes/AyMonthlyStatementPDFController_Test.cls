/**************************************************************
@author       :  Shubham@Ayodia
@date         :  09march,2020
@description  :  TestClass for AyMonthlyStatementPDFController
***************************************************************/
@isTest
private class AyMonthlyStatementPDFController_Test{
    
    private static testMethod void testMonthlyStatementPdf1(){
        
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
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
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
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Due_Date2__c = Date.today().addDays(-20); 
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c bLine = new AcctSeed__Billing_Line__c();
        bLine.AcctSeed__Billing__c = bill.Id;
        //bLine.Resource__c = u.Id;
        bLine.AcctSeed__Date__c = Date.today();
        bLine.AcctSeed__Rate__c = 100;
        bLine.AcctSeed__Hours_Units__c = 10;
        insert bLine;
        
        // Billing List
        List<AcctSeed__Billing__c> bList = new List <AcctSeed__Billing__c> ();
        bList.add(bill);
        
        // Call the post billings service
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(bList);
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Status__c  = 'Open';
        tb.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        insert tb;
        
        // Setup Cash receipt TestData
        AcctSeed__Cash_Receipt__c cr = new AcctSeed__Cash_Receipt__c();
        cr.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cr.AcctSeed__Amount__c = 100;
        cr.AcctSeed__Payment_Reference__c = 'Cash';
        cr.AcctSeed__Status__c = 'Draft';
        cr.AcctSeed__Accounting_Period__c = tb.Accounting_Period__c;
        insert cr;
        
        // CashReceipt List
        list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
        receipts.add(cr);
        
        // Post the CashReceipts Service
        AcctSeed.PostResult[] postResultsCR = AcctSeed.CashReceiptPostService.postCashReceipts(receipts);
        
        // Setup Billing Cash Receipts TestData
        AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
        bcr.AcctSeed__Billing__c = bill.Id;
        bcr.AcctSeed__Cash_Receipt__c = cr.Id;
        bcr.AcctSeed__Applied_Amount__c = 100;
        insert bcr;
        
        // Setup Cash Disbursement Batch TestData
        AcctSeed__Cash_Disbursement_Batch__c cdBatch = new AcctSeed__Cash_Disbursement_Batch__c();
        cdBatch.AcctSeed__Starting_Check_Number__c = 2;
        cdBatch.Name = 'Test Batch';
        insert cdBatch;
        
        // Setup Cash Disbursement TestData
        AcctSeed__Cash_Disbursement__c cd = new AcctSeed__Cash_Disbursement__c();
        cd.AcctSeed__Cash_Disbursement_Batch__c = cdBatch.Id;
        cd.AcctSeed__Disbursement_Date__c = AyTestDataSuite.acctPeriods[0].AcctSeed__Start_Date__c;
        cd.AcctSeed__Type__c = 'Check';
        cd.AcctSeed__Amount__c = 10;
        cd.AcctSeed__Source__c = 'Account Payable';
        cd.AcctSeed__Bank_Account__c = AyTestDataSuite.glAccounts[0].Id;
        cd.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        cd.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        cd.AcctSeed__Status__c = 'In Process';
        cd.AcctSeed__Reference__c = 'the reference 0';
        insert cd;
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c  ();
        tActivity.Trust_Balance__c = tb.Id;
        tActivity.Billing__c = bill.Id;
        tActivity.Cash_Receipt__c = cr.Id;
        tActivity.Billing_Cash_Receipt__c = bcr.Id;
        tActivity.Cash_Disbursement__c = cd.Id;
        insert tActivity;
        
        // Call AyTrustBalance_PDF
        PageReference pageRef = Page.AyMonthlyStatementPDF;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('Id', tb.Id);
        
        // Call AyTrustBalancePDF_Controller
        AyMonthlyStatementPDFController cont = new AyMonthlyStatementPDFController();
        
        // Trust Balance List
        list<Trust_Balance__c> tbList = new list<Trust_Balance__c>();
        tbList.add(tb);
        
        // Set AyBatchMonthlyAcctStatement Page
        Test.setCurrentPage(Page.AyBatchMonthlyAcctStatementPDF);
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(tbList);
        stdSetController.setSelected(tbList);
        
        // Call Standard Set Controller 
        AyBatchMonthlyAcctStatementController ext = new AyBatchMonthlyAcctStatementController(stdSetController);
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod void testMonthlyStatementPdf2(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        //Setup Opportunty TestData
        Opportunity opp = new Opportunity();
        opp.Name = 'Testing Opportunity';
        opp.CloseDate = Date.today().addDays(10);
        opp.StageName = 'Prospecting';
        opp.Area_of_Law__c = 'Criminal Defense';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        insert opp;
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = opp.Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.Matter__c = matter.Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = true;
        insert pay;
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;
        
        // Setup Billing TestData Where Payable is availabale
        AcctSeed__Billing__c billing = new AcctSeed__Billing__c();
        billing.AcctSeed__Date__c = Date.today();
        billing.AcctSeed__Due_Date2__c = Date.today().addDays(-20); 
        billing.AcctSeed__Status__c = 'Approved';
        billing.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        billing.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        billing.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        billing.Payable__c = pay.Id;
        billing.Matter__c = matter.Id;
        insert billing;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = billing.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;
        
        // Setup Past Due Billing TestData
        AcctSeed__Billing__c pastDueBilling = new AcctSeed__Billing__c();
        pastDueBilling.AcctSeed__Date__c = Date.today();
        pastDueBilling.AcctSeed__Due_Date2__c = Date.today().addDays(-20); 
        pastDueBilling.AcctSeed__Status__c = 'Approved';
        pastDueBilling.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        pastDueBilling.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pastDueBilling.Payable__c = pay.Id;
        pastDueBilling.Matter__c = matter.Id;
        insert pastDueBilling;
        
        // Setup Past Due Billing Line TestData
        AcctSeed__Billing_Line__c pastDuebillLine = new AcctSeed__Billing_Line__c();
        pastDuebillLine.AcctSeed__Billing__c = pastDueBilling.Id;
        pastDuebillLine.AcctSeed__Date__c = Date.today();
        pastDuebillLine.AcctSeed__Rate__c = 100;
        pastDuebillLine.AcctSeed__Hours_Units__c = 10;
        insert pastDuebillLine;
        
        // Start Test
        Test.startTest();
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Accounting_Period__c = AyTestDataSuite.acctPeriods[2].Id;
        tb.Status__c  = 'Open';
        insert tb;
        
        // Update Past Due Billing TestData
        pastDueBilling.AcctSeed__Accounting_Period__c = tb.Accounting_Period__c;
        
        // Billing List
        List<AcctSeed__Billing__c> bList = new List <AcctSeed__Billing__c> ();
        bList.add(billing);
        bList.add(pastDueBilling);
        
        // Call the post billings service
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(bList);
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c  ();
        tActivity.Trust_Balance__c = tb.Id;
        tActivity.Billing__c = billing.Id;
        tActivity.Billing_Line__c = billLine.Id;
        insert tActivity;
        
        // Call AyTrustBalance_PDF
        PageReference pageRef = Page.AyMonthlyStatementPDF;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('Id', tb.Id);
        
        // Call AyTrustBalancePDF_Controller
        AyMonthlyStatementPDFController cont = new AyMonthlyStatementPDFController();
        
        // Stop Test
        Test.stopTest();
        
    }
}