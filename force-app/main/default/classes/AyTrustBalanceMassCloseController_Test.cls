/****************************************************************
@author       :  Shubham@Ayodia
@date         :  11march,2020
@description  :  TestClass for AyTrustBalanceMassCloseController
AND AyBatchCreateTrustBalance
*****************************************************************/
@isTest
private class AyTrustBalanceMassCloseController_Test {
    
    private static testMethod void testTrustBalanceMassClose(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Cash receipt TestData
        AcctSeed__Cash_Receipt__c cashReceipts = new AcctSeed__Cash_Receipt__c();
        cashReceipts.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        cashReceipts.AcctSeed__Amount__c = 400;
        cashReceipts.AcctSeed__Payment_Reference__c = '0000000432';
        cashReceipts.AcctSeed__Status__c = 'Draft';
        cashReceipts.AcctSeed__Receipt_Date__c = AyTestDataSuite.acctPeriods[0].AcctSeed__Start_Date__c;
        cashReceipts.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        insert cashReceipts;
        
        // Trust Balance List
        list<Trust_Balance__c> tbList = new list<Trust_Balance__c>();
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Status__c  = 'Open';
        tbList.add(tb);
        if(tbList.size() > 0){
            insert tbList;
        }
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c  ();
        tActivity.Trust_Balance__c = tb.Id;
        tActivity.Cash_Receipt__c = cashReceipts.Id; 
        insert tActivity;
        
        // Start Test
        Test.startTest();
        
        // Set AyTrustBalanceMassClose Page
        PageReference testPage = Page.AyTrustBalanceMassClose; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('S', String.valueOf(1));
        
        // Call StandardSetController
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(tbList);
        stdSetController.setSelected(tbList);
        AyTrustBalanceMassCloseController ext = new AyTrustBalanceMassCloseController(stdSetController);
        ext.massCloseTrustBalance();
        
        // Stop Test
        Test.stopTest();
        
    }
}