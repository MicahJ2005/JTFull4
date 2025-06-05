/*********************************************************
@author       :  Shubham@Ayodia
@date         :  19April,2021
@description  :  TestClass for AyRefreshTrustBalanceExt
**********************************************************/
@isTest
private class AyRefreshTrustBalanceExt_Test {
    
    private static testMethod Void testRefreshTrustBalance(){
        
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
        tb.Status__c  = 'Open';
        insert tb;
        
        // Start Test
        Test.startTest();
        
        // Set AyRefreshTrustBalance Page
        PageReference testPage = Page.AyRefreshTrustBalance; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('x', String.valueOf(1));
        ApexPages.StandardController sc = new ApexPages.StandardController(tb);
        
        // Call AyRefreshTrustBalanceExt
        AyRefreshTrustBalanceExt ext = new AyRefreshTrustBalanceExt(sc);
        ext.goBack();
        ext.refreshStatements();
        
        // Stop Test
        Test.stopTest();
    }
    
}