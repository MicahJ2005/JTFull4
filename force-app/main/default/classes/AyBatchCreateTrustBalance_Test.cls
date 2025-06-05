/*********************************************************
@author       :  Shubham@Ayodia
@date         :  09march,2020
@description  :  TestClass for AyBatchCreateTrustBalance
**********************************************************/
@isTest
private class AyBatchCreateTrustBalance_Test {
    
    private static testmethod void testBatchCreateTrustBalance(){
        
        // Setup TestData Suite
        AyTestDataSuite.init();
        
        AyTestDataSuite.Opportunities[0].Rate_Type__c = 'Flat Fee';
        update AyTestDataSuite.Opportunities[0];

        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;

        // Setup Project Task TestData
        AcctSeed__Project_Task__c task = new AcctSeed__Project_Task__c();
        task.Name = 'Test Ayodia';
        task.AcctSeed__Project__c = matter.Id;
        task.AcctSeed__Status__c = 'Active';
        insert task;
        
        set<Id> tbIds = new set<Id>();
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        tb.Status__c  = 'Open';
        insert tb;
        tbIds.add(tb.Id);
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Posted';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Project__c = matter.Id;
        billLine.AcctSeed__Project_Task__c = task.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;

        // Billing List
        List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c> ();
        billings.add(bill);
        
        // Post billings service
        AcctSeed.PostResult[] postResultsBill = AcctSeed.BillingPostService.postBillings(billings);
        
        AyTestDataSuite.glAccounts[0].Is_Trust_Account__c = true;
        update AyTestDataSuite.glAccounts[0];
        
        // Setup CashReceipts TestData
        AcctSeed__Cash_Receipt__c cashReceipts = new AcctSeed__Cash_Receipt__c();
        cashReceipts.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cashReceipts.AcctSeed__Amount__c = 200;
        cashReceipts.AcctSeed__Payment_Reference__c = '0000000432';
        cashReceipts.AcctSeed__Status__c = 'Draft';
        cashReceipts.AcctSeed__Receipt_Date__c = AyTestDataSuite.acctPeriods[5].AcctSeed__Start_Date__c;
        cashReceipts.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        cashReceipts.AcctSeed__Project__c = matter.Id;
        cashReceipts.AcctSeed__Project_Task__c = task.Id;
        cashReceipts.AcctSeed__Bank_Account__c = AyTestDataSuite.glAccounts[0].Id;
        cashReceipts.Auto_Apply__c = false;
        insert cashReceipts;
        
        // CashReceipt List
        list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
        receipts.add(cashReceipts);
        
        // Start Test
        Test.startTest();
        
        // Post the CashReceipts Service
        AcctSeed.PostResult[] postResultsCR = AcctSeed.CashReceiptPostService.postCashReceipts(receipts);
       
        // Setup Billing Cash Receipts TestData
        AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
        bcr.AcctSeed__Billing__c = bill.Id;
        bcr.AcctSeed__Cash_Receipt__c = cashReceipts.Id;
        bcr.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        bcr.AcctSeed__Applied_Amount__c = 200;
        insert bcr;

        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        insert pay;
        
        // Setup PayableLine TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Project__c = matter.Id;
        pLine.AcctSeed__Project_Task__c = task.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;

        // Payable List 
        List<AcctSeed__Account_Payable__c> payableList = new List <AcctSeed__Account_Payable__c> ();
        payableList.add(pay);
        
        // Post Payable service
        AcctSeed.PostResult[] postResultsPayable = AcctSeed.AccountPayablePostService.postAccountPayables(payableList);
        
        // Setup JournalEntry TestData
        AcctSeed__Journal_Entry__c je = new AcctSeed__Journal_Entry__c();
        je.Matter__c = matter.Id;
        je.AcctSeed__Status__c = 'Approved';
        je.AcctSeed__Journal_Date__c = Date.today();
        je.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        insert je;
        
        // Setup JournalEntry Line TestData
        AcctSeed__Journal_Entry_Line__c jel = new AcctSeed__Journal_Entry_Line__c();
        jel.AcctSeed__Journal_Entry__c = je.Id;
        jel.AcctSeed__Project__c = matter.Id;
        jel.AcctSeed__Project_Task__c = task.Id;
        jel.AcctSeed__Credit__c = 100;
        jel.AcctSeed__Date__c = system.today();
        jel.AcctSeed__GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        jel.AcctSeed__GL_Account_Variable_1__c = AyTestDataSuite.acctVariables[0].Id;
        insert jel;
        
        // Setup JournalEntry Line TestData
        AcctSeed__Journal_Entry_Line__c je2 = new AcctSeed__Journal_Entry_Line__c();
        je2.AcctSeed__Journal_Entry__c = je.Id;
        je2.AcctSeed__Project__c = matter.Id;
        je2.AcctSeed__Project_Task__c = task.Id;
        je2.AcctSeed__Debit__c = 100;
        je2.AcctSeed__Date__c = system.today();
        je2.AcctSeed__GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        je2.AcctSeed__GL_Account_Variable_1__c = AyTestDataSuite.acctVariables[0].Id;
        insert je2;

        // Journal Entry List
        list<AcctSeed__Journal_Entry__c> journalEntries = new List<AcctSeed__Journal_Entry__c>();
        journalEntries.add(je);
        
        // Call the post journal entry service
        AcctSeed.PostResult[] postResults = AcctSeed.JournalEntryPostService.postJournalEntries(journalEntries);
        
        // Setup Cash Disbursement Batch TestData
        AcctSeed__Cash_Disbursement_Batch__c cdBatch = new AcctSeed__Cash_Disbursement_Batch__c();
        cdBatch.AcctSeed__Starting_Check_Number__c = 2;
        cdBatch.Name = 'Test Batch';
        insert cdBatch;
        
        // Setup Cash Disbursement TestData
        AcctSeed__Cash_Disbursement__c cd = new AcctSeed__Cash_Disbursement__c();
        cd.AcctSeed__Cash_Disbursement_Batch__c = cdBatch.Id;
        cd.AcctSeed__Project__c = matter.Id;
        cd.AcctSeed__Project_Task__c = task.Id;
        cd.AcctSeed__Disbursement_Date__c = AyTestDataSuite.acctPeriods[5].AcctSeed__Start_Date__c;
        cd.AcctSeed__Type__c = 'Check';
        cd.AcctSeed__Amount__c = 10;
        cd.AcctSeed__Source__c = 'Account Payable';
        cd.AcctSeed__Bank_Account__c = AyTestDataSuite.glAccounts[0].Id;
        cd.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        cd.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        cd.AcctSeed__Status__c = 'In Process';
        cd.AcctSeed__Reference__c = 'the reference 0';
        cd.AcctSeed__Debit_GL_Account__c = AyTestDataSuite.glAccounts[1].Id;
        insert cd;
        
        // Cash Disbursement List
        List<AcctSeed__Cash_Disbursement__c > cashDisbursement = new List<AcctSeed__Cash_Disbursement__c >();
        cashDisbursement.add(cd);
        
        // Post  Cash Disbursement Service
        AcctSeed.PostResult[] postResultsCD = AcctSeed.CashDisbursementPostService.postCashDisbursements(cashDisbursement);
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c  ();
        tActivity.Trust_Balance__c = tb.Id;
        tActivity.Billing__c = bill.Id;
        tActivity.Billing_Line__c = billLine.Id;
        tActivity.Payable__c = pay.Id;
        tActivity.Payable_Line__c = pLine.Id;
        tActivity.Cash_Receipt__c = cashReceipts.Id;
        tActivity.Cash_Disbursement__c = cd.Id;
        tActivity.Billing_Cash_Receipt__c = bcr.Id;
        tActivity.Journal_Entry__c = je.Id;
        tActivity.Journal_Entry_Line__c = jel.Id;
        insert tActivity;
        
        // Call AyScheduleBatchCreateTrustBalance
        AyScheduleBatchCreateTrustBalance sh1 = new AyScheduleBatchCreateTrustBalance();
        String sch = '0 0 23 * * ?'; system.schedule('Create Trust Balance', sch, sh1);
        
        AyBatchCreateTrustBalance b = new AyBatchCreateTrustBalance();
        
        // Call the unpost journal entry service
        AcctSeed.PostResult[] unpostResults = AcctSeed.JournalEntryPostService.unpostJournalEntries(journalEntries);
        
        // Call the unpost service
        AcctSeed.PostResult[] unpostResultsCD = AcctSeed.CashDisbursementPostService.unpostCashDisbursements(cashDisbursement);
        
        //delete bcr;
                
        AyTrustBalanceHandler.createTrustActivityStatement(tbIds);
        
        // Stop Test
        Test.stopTest();
       
    }
    
    private static testmethod void testBatchCreateTrustBalance2(){
        
        // Setup TestData Suite
        AyTestDataSuite.init();
        
        AyTestDataSuite.Opportunities[0].Rate_Type__c = 'Flat Fee';
        update AyTestDataSuite.Opportunities[0];

        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;

        // Setup Project Task TestData
        AcctSeed__Project_Task__c task = new AcctSeed__Project_Task__c();
        task.Name = 'Test Ayodia';
        task.AcctSeed__Project__c = matter.Id;
        task.AcctSeed__Status__c = 'Active';
        insert task;

        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Posted';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Project__c = matter.Id;
        billLine.AcctSeed__Project_Task__c = task.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;

        // Billing List
        List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c> ();
        billings.add(bill);
        
        // Post billings service
        AcctSeed.PostResult[] postResultsBill = AcctSeed.BillingPostService.postBillings(billings);
        
        // Setup CashReceipts TestData
        AcctSeed__Cash_Receipt__c cashReceipts = new AcctSeed__Cash_Receipt__c();
        cashReceipts.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cashReceipts.AcctSeed__Amount__c = 200;
        cashReceipts.AcctSeed__Payment_Reference__c = '0000000432';
        cashReceipts.AcctSeed__Status__c = 'Draft';
        cashReceipts.AcctSeed__Receipt_Date__c = AyTestDataSuite.acctPeriods[5].AcctSeed__Start_Date__c;
        cashReceipts.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        cashReceipts.AcctSeed__Project__c = matter.Id;
        cashReceipts.AcctSeed__Project_Task__c = task.Id;
        cashReceipts.Auto_Apply__c = false;
        insert cashReceipts;
        
        // CashReceipt List
        list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
        receipts.add(cashReceipts);
        
        // Post the CashReceipts Service
        AcctSeed.PostResult[] postResultsCR = AcctSeed.CashReceiptPostService.postCashReceipts(receipts);
       
        // Setup Billing Cash Receipts TestData
        AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
        bcr.AcctSeed__Billing__c = bill.Id;
        bcr.AcctSeed__Cash_Receipt__c = cashReceipts.Id;
        bcr.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        bcr.AcctSeed__Applied_Amount__c = 200;
        insert bcr;

        // Start Test
        Test.startTest();
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        insert pay;
        
        // Setup PayableLine TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Project__c = matter.Id;
        pLine.AcctSeed__Project_Task__c = task.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;

        // Payable List 
        List<AcctSeed__Account_Payable__c> payableList = new List <AcctSeed__Account_Payable__c> ();
        payableList.add(pay);
        
        // Post Payable service
        AcctSeed.PostResult[] postResultsPayable = AcctSeed.AccountPayablePostService.postAccountPayables(payableList);
        
        // Setup JournalEntry TestData
        AcctSeed__Journal_Entry__c je = new AcctSeed__Journal_Entry__c();
        je.Matter__c = matter.Id;
        je.AcctSeed__Status__c = 'Approved';
        je.AcctSeed__Journal_Date__c = Date.today();
        je.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        insert je;
        
        // Setup JournalEntry Line TestData
        AcctSeed__Journal_Entry_Line__c jel = new AcctSeed__Journal_Entry_Line__c();
        jel.AcctSeed__Journal_Entry__c = je.Id;
        jel.AcctSeed__Project__c = matter.Id;
        jel.AcctSeed__Project_Task__c = task.Id;
        jel.AcctSeed__Credit__c = 10;
        jel.AcctSeed__Date__c = system.today();
        jel.AcctSeed__GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        jel.AcctSeed__GL_Account_Variable_1__c = AyTestDataSuite.acctVariables[0].Id;
        insert jel;

        // Journal Entry List
        list<AcctSeed__Journal_Entry__c> jeListToPost = new List<AcctSeed__Journal_Entry__c>();
        jeListToPost.add(je);
        
        // Post JournalEntry Service
        AcctSeed.PostResult[] postResultsJE = AcctSeed.JournalEntryPostService.postJournalEntries(jeListToPost);
        
        // Setup Cash Disbursement Batch TestData
        AcctSeed__Cash_Disbursement_Batch__c cdBatch = new AcctSeed__Cash_Disbursement_Batch__c();
        cdBatch.AcctSeed__Starting_Check_Number__c = 2;
        cdBatch.Name = 'Test Batch';
        insert cdBatch;
        
        // Setup Cash Disbursement TestData
        AcctSeed__Cash_Disbursement__c cd = new AcctSeed__Cash_Disbursement__c();
        cd.AcctSeed__Cash_Disbursement_Batch__c = cdBatch.Id;
        cd.AcctSeed__Project__c = matter.Id;
        cd.AcctSeed__Project_Task__c = task.Id;
        cd.AcctSeed__Disbursement_Date__c = AyTestDataSuite.acctPeriods[5].AcctSeed__Start_Date__c;
        cd.AcctSeed__Type__c = 'Check';
        cd.AcctSeed__Amount__c = 10;
        cd.AcctSeed__Source__c = 'Account Payable';
        cd.AcctSeed__Bank_Account__c = AyTestDataSuite.glAccounts[0].Id;
        cd.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        cd.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[5].Id;
        cd.AcctSeed__Status__c = 'In Process';
        cd.AcctSeed__Reference__c = 'the reference 0';
        insert cd;
        
        // Cash Disbursement List
        List<AcctSeed__Cash_Disbursement__c > cashDisbursement = new List<AcctSeed__Cash_Disbursement__c >();
        cashDisbursement.add(cd);
        
        // Post  Cash Disbursement Service
        AcctSeed.PostResult[] postResultsCD = AcctSeed.CashDisbursementPostService.postCashDisbursements(cashDisbursement);
        
        
        // Call AyScheduleBatchCreateTrustBalance
        AyScheduleBatchCreateTrustBalance sh1 = new AyScheduleBatchCreateTrustBalance();
        String sch = '0 0 23 * * ?'; system.schedule('Create Trust Balance', sch, sh1);
        
        // Stop Test
        Test.stopTest();
       
    }

}