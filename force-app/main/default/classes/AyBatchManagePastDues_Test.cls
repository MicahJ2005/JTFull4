/****************************************************
@author       :  Shubham@Ayodia
@date         :  24June,2021
@description  :  TestClass for AyBatchManagePastDues
*****************************************************/
@isTest
private class AyBatchManagePastDues_Test {
    
    private static testmethod void testBatchManagePastDues(){
        
        // Setup TestData Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today().addDays(-10);
        bill.AcctSeed__Status__c = 'Posted';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Project__c = matter.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill2 = new AcctSeed__Billing__c();
        bill2.AcctSeed__Date__c = Date.today().addDays(-10);
        bill2.AcctSeed__Status__c = 'Posted';
        bill2.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill2.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill2.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill2.Matter__c = matter.Id;
        insert bill2;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine2 = new AcctSeed__Billing_Line__c();
        billLine2.AcctSeed__Billing__c = bill2.Id;
        billLine2.AcctSeed__Project__c = matter.Id;
        billLine2.AcctSeed__Date__c = Date.today();
        billLine2.AcctSeed__Rate__c = 100;
        billLine2.AcctSeed__Hours_Units__c = 10;
        insert billLine2;
        
        List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c> ();
        billings.add(bill);
        billings.add(bill2);
        
        // Call the post billings service
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billings);
        
        list<AcctSeed__Billing__c> bQuery = [SELECT Id, Is_Payment_Delayed__c, AcctSeed__Due_Date2__c, Matter__c FROM AcctSeed__Billing__c WHERE Id =: bill.Id];
        system.debug('bQuery*****'+bQuery);
            
        // Start Test
        Test.startTest();
        
        //Call ScheduleBatchAutoApplyCR
        AyScheduleBatchManagePastDues sh1 = new AyScheduleBatchManagePastDues();
        String sch = '0 0 23 * * ?'; system.schedule('Test Manage Past Dues', sch, sh1);    
        
        // Execute Batch AyBatchManagePastDues
        AyBatchManagePastDues b = new AyBatchManagePastDues();
        Database.executeBatch(b);
        
        // Stop Test
        Test.stopTest();
    }
    
}