/****************************************************
@author       :  Shubham@Ayodia
@date         :  26Apr,2022
@description  :  TestClass for AyBillingPDFController
*****************************************************/
@isTest
private class AyBillingPDFController_Test {
    
    private static testMethod void testBillingPDF(){
        
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
        
        // Start Test
        Test.startTest();
        
        // Call AyTrustBalance_PDF
        PageReference pageRef = Page.AyBillingPDF_HardCost;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('Id', billing.Id);
        
        // Call AyTrustBalancePDF_Controller
        AyBillingPDFController cont = new AyBillingPDFController();
        
        // Stop Test
        Test.stopTest();
        
    }

}