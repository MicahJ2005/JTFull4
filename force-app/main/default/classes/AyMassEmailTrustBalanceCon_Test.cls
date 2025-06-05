/*********************************************************
@author       :  Shubham@Ayodia
@date         :  17June,2021
@description  :  TestClass for AyMassEmailTrustBalanceCon
				 AND AyBatchEmailTrustBalance
**********************************************************/
@isTest
private class AyMassEmailTrustBalanceCon_Test {
    
    private static testMethod void testMassEmailTrustBalance(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        AyTestDataSuite.contacts[0].Email = 'test@test.com';
        update AyTestDataSuite.contacts[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Trust Balance List
        list<Trust_Balance__c> tbList = new list<Trust_Balance__c>();
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Status__c  = 'Open';
        tb.Billing_Contact__c = AyTestDataSuite.contacts[0].Id;
        tbList.add(tb);
        
        if(tbList.size() > 0){
            insert tbList;
        }
        
        // Start Test
        Test.startTest();
        
        // Set AyTrustBalanceMassClose Page
        PageReference testPage = Page.AyMassEmailTrustBalance; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('S', String.valueOf(1));
        
        // Call StandardSetController
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(tbList);
        stdSetController.setSelected(tbList);
        AyMassEmailTrustBalanceCon ext = new AyMassEmailTrustBalanceCon(stdSetController);
        Integer selectedRecordsCount = ext.selectedRecordsCount;
        ext.processSelectedRecords();
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod void testBatchEmailTrustBalance(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
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
        
        // Start Test
        Test.startTest();
        
        // Set AyTrustBalanceMassClose Page
        PageReference testPage = Page.AyMassEmailTrustBalance; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('S', String.valueOf(1));
        
        // Call StandardSetController
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(tbList);
        stdSetController.setSelected(tbList);
        AyMassEmailTrustBalanceCon ext = new AyMassEmailTrustBalanceCon(stdSetController);
        Integer selectedRecordsCount = ext.selectedRecordsCount;
        ext.processSelectedRecords();
        
        // Stop Test
        Test.stopTest();
        
    }

}