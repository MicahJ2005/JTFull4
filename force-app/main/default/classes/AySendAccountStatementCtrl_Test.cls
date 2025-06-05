/*********************************************************
@author       :  Shubham@Ayodia
@date         :  07July,2021
@description  :  TestClass for AySendAccountStatementCtrl
**********************************************************/
@isTest
private class AySendAccountStatementCtrl_Test {
    
    private static testMethod void testSendAccountStatement(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Update Contact
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
        
        // Set AySendAccountStatement Page
        PageReference testPage = Page.AySendAccountStatement; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('S', String.valueOf(1));
        
        // Call StandardSetController
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(tbList);
        stdSetController.setSelected(tbList);
        AySendAccountStatementCtrl ext = new AySendAccountStatementCtrl(stdSetController);
        Integer selectedRecordsCount = ext.selectedRecordsCount;
        ext.proceedToSend();
        ext.back();
        
        // Stop Test
        Test.stopTest();
        
    }

}