/**********************************************************
@author       :  Shubham@Ayodia
@date         :  23May,2022
@description  :  TestClass for AyBatchHandleMatterAutoPay
***********************************************************/
@isTest
private class AyScheduleBatchHandleMatterAutoPay_Test {
    
    private static testMethod void testScheduleBatchHandleMatterAutoPay(){ 
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c pro = new AcctSeed__Project__c();
        pro.Name = 'Test Matter Name';
        pro.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        pro.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pro.AcctSeed__Status__c = 'Active';
        pro.Auto_Pay__c = true;
        pro.Auto_Debit_Method_Token__c = '{"id":"pmtd_**********","type":"card"}';
        insert pro;
        
        
        // Start Test
        Test.startTest();
        
        //Call AyScheduleBatchHandleMatterAutoPay
        AyScheduleBatchHandleMatterAutoPay sh1 = new AyScheduleBatchHandleMatterAutoPay();
        String sch = '0 0 23 * * ?'; system.schedule('Test Manage Auto Pay', sch, sh1);    
        
        // Execute Batch AyBatchManagePastDues
        AyBatchHandleMatterAutoPay b = new AyBatchHandleMatterAutoPay();
        Database.executeBatch(b);
        
        // Stop Test
        Test.stopTest();
    
    }

}