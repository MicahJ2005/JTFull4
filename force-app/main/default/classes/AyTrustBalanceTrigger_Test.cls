/****************************************************
@author       :  Shubham@Ayodia
@date         :  04March,2021
@description  :  TestClass for AyTrustBalanceTrigger
*****************************************************/
@isTest
private class AyTrustBalanceTrigger_Test{
    
    private static testMethod Void trustBalanceInsert(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;
        
        // Setup Cash receipt TestData
        AcctSeed__Cash_Receipt__c cr = new AcctSeed__Cash_Receipt__c();
        cr.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cr.AcctSeed__Amount__c = 100;
        cr.AcctSeed__Payment_Reference__c = 'Cash';
        cr.AcctSeed__Status__c = 'Draft';
        cr.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        insert cr;
        
        // CashReceipt List
        list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
        receipts.add(cr);
        
        // Post the CashReceipts Service
        AcctSeed.PostResult[] postResultsCR = AcctSeed.CashReceiptPostService.postCashReceipts(receipts);
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        tb.Status__c  = 'Closed';
        insert tb;
        
        // Setup Trust Balance TestData 2
        Trust_Balance__c tBal = new Trust_Balance__c();
        tBal.Matter__c = matter.Id;
        tBal.Status__c = 'Open';
        tBal.Prior_Month_Trust_Balance__c = tb.Id;
        tBal.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        insert tBal;
        
        // Setup Billing Cash Receipts TestData
        AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
        bcr.AcctSeed__Billing__c = bill.Id;
        bcr.AcctSeed__Cash_Receipt__c = cr.Id;
        bcr.AcctSeed__Applied_Amount__c = 100;
        insert bcr;
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c();
        tActivity.Trust_Balance__c = tBal.Id;
        tActivity.Billing__c = bill.Id;
        tActivity.Billing_Line__c = billLine.Id;
        tActivity.Cash_Receipt__c = cr.Id;
        tActivity.Billing_Cash_Receipt__c = bcr.Id;
        insert tActivity;
        
        // Start Test
        Test.startTest();
        
        // Update Trust Balance Status
        tBal.Status__c = 'Closed';
        update tBal;
        
        // Call @AuraEnabled applyCashBalance
        AyApplyCashBalanceController.applyCashBalance(tBal.Id);
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod Void trustBalanceAfterUpdate(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        tb.Status__c  = 'Closed';
        insert tb;
        
        //Create Journal Entry
        AcctSeed__Journal_Entry__c je = new AcctSeed__Journal_Entry__c();
        je.Matter__c = matter.Id;
        je.Trust_Balance__c = tb.Id;
        je.AcctSeed__Status__c = 'Posted';
        je.AcctSeed__Journal_Date__c = Date.today();
        insert je;
        
        // Credit JE Line
        AcctSeed__Journal_Entry_Line__c jel = new AcctSeed__Journal_Entry_Line__c();
        jel.AcctSeed__Journal_Entry__c = je.Id;
        jel.AcctSeed__Credit__c = 10;
        jel.AcctSeed__Date__c = system.today();
        jel.AcctSeed__GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        jel.AcctSeed__GL_Account_Variable_1__c = AyTestDataSuite.acctVariables[0].Id;
        insert jel;
        
        // Debit JE Line
        AcctSeed__Journal_Entry_Line__c jel2 = new AcctSeed__Journal_Entry_Line__c();
        jel2.AcctSeed__Journal_Entry__c = je.Id;
        jel2.AcctSeed__Debit__c = 10;
        jel2.AcctSeed__Date__c = system.today();
        jel2.AcctSeed__GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        jel2.AcctSeed__GL_Account_Variable_1__c = AyTestDataSuite.acctVariables[0].Id;
        insert jel2;
        
        List<AcctSeed__Journal_Entry__c> journalEntries = new List <AcctSeed__Journal_Entry__c>();
        journalEntries.add(je);
        
        // Call the post journal entry service
		//AcctSeed.PostResult[] postResults = AcctSeed.JournalEntryPostService.postJournalEntries(journalEntries);

        
        // Start Test
        Test.startTest();
        
        // Update Trust Balance Status
        tb.Status__c = 'Open';
        update tb;
        
        // Stop Test
        Test.stopTest();       
    }
    
}