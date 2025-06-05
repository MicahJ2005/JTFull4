/***********************************************************
@author       :  Shubham@Ayodia
@date         :  02July,2021
@description  :  TestClass for AyTrustAccountActivityTrigger
************************************************************/
@isTest
private class AyTrustAccountActivityTrigger_Test {
    
    private static testMethod Void testTrustAccountActivity(){
        
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
        
        // Setup Trust Balance TestData 2
        Trust_Balance__c tBal = new Trust_Balance__c();
        tBal.Matter__c = matter.Id;
        tBal.Status__c = 'Open';
        tBal.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        insert tBal;
        
        // Setup Trust Account Activity TestData 1
        Trust_Account_Activity__c tActivity1 = new Trust_Account_Activity__c();
        tActivity1.Trust_Balance__c = tBal.Id;
        tActivity1.Billing__c = bill.Id;
        tActivity1.Billing_Line__c = billLine.Id;
        tActivity1.Cash_Receipt__c = cr.Id;
        tActivity1.Withdrawal__c = -100;
        insert tActivity1;
        
        // Setup Trust Account Activity TestData 2
        Trust_Account_Activity__c tActivity2 = new Trust_Account_Activity__c();
        tActivity2.Trust_Balance__c = tBal.Id;
        tActivity2.Billing__c = bill.Id;
        tActivity2.Billing_Line__c = billLine.Id;
        tActivity2.Cash_Receipt__c = cr.Id;
        tActivity2.Deposit__c = -100;
        insert tActivity2;
        
    }

}