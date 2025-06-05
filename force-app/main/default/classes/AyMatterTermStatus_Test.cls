/*********************************************************
@author       :  Shubham@Ayodia
@date         :  21May,2021
@description  :  TestClass for AyMatterTermStatusCancelled
				 AND AyMatterTermStatusCompleted
**********************************************************/
@isTest
private class AyMatterTermStatus_Test {
    
    private static testMethod Void testMatterTermStatus(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        list<Id> mtIdList = new list<Id>();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Matter Termination TestData
        Matter_Termination__c mt = new Matter_Termination__c();
        mt.Matter__c = matter.Id;
        mt.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        mt.Is_Active__c = true;
        mt.Total_Billed_Amount__c = 1000;
        mt.Total_Received__c = 1000;
        mt.Value_of_All_Tasks__c = 1935;
        mt.Value_Of_Incomplete_Tasks__c = 1435;
        mt.Approval_Status__c = 'Approved';
        mt.Overpayment_Disposition__c = 'Credit Memo';
        mt.Termination_Type__c = 'Standard Opportunity';
        mt.Termination_Status__c = 'In Process';
        insert mt;
        mtIdList.add(mt.Id);
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.Project__c = matter.Id;
        c.Priority = 'High';
        c.Status = 'On Hold';
        c.Subject = 'Test Case';
        insert c;
        
        // Setup Case Termination TestData
        Case_Termination__c ct = new Case_Termination__c();
        ct.Matter_Termination__c = mt.Id;
        ct.Case__c = c.Id;
        ct.Total_Open_Task_Hours__c = 2;
        ct.Total_Open_Task_Value__c = 200;
        insert ct; 
        
        // Start Test
        Test.startTest();
        
        // Update Matter Termination Status
        mt.Termination_Status__c = 'Completed';
        update mt;
        
        // Call @InvocableMethod
        AyMatterTermStatusCancelled.setPriorCaseStatus(mtIdList);
        AyMatterTermStatusCompleted.populateCaseTerminationOnCase(mtIdList);
        
        // Stop Test
        Test.stopTest();
    }
}