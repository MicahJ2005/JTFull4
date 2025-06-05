/************************************************
@author       :  Shubham@Ayodia
@date         :  10March,2020
@description  :  TestClass for AyBillingTrigger
*************************************************/
@isTest
private class AyBillingTrigger_Test {
    
    private static testMethod void testhandleBillingUnpost(){
        
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
        bill.AcctSeed__Due_Date2__c = Date.today().addDays(-20); 
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
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Status__c  = 'Open';
        insert tb;
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c  ();
        tActivity.Trust_Balance__c = tb.Id;
        tActivity.Billing__c = bill.Id;
        tActivity.Billing_Line__c = billLine.Id;
        insert tActivity;
        
        // Start Test
        Test.startTest();
        
        // Billing List
        List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c> ();
        billings.add(bill);
        
        // Call the post billings service
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billings);
        
        // Call the unpost billings service
        AcctSeed.PostResult[] unpostResults = AcctSeed.BillingPostService.unpostBillings(billings);
        
        // Delete Bill
        delete bill;
        
        // Stop Test
        Test.stopTest();
        
    }    
}