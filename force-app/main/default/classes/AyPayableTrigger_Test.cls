/************************************************
@author       :  Shubham@Ayodia
@date         :  10March,2021
@description  :  TestClass for AyPayableTrigger
*************************************************/
@isTest
private class AyPayableTrigger_Test {
    
    private static testMethod void testPayableAfterUpdate(){
        
        // Setup TestData Suite
        AyTestDataSuite.init();
        
        // get Logged in user
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Update Opportunity
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
        update AyTestDataSuite.opportunities[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = false;
        insert pay;
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        pLine.AcctSeed__GL_Account_Variable_1__c = AyTestDataSuite.acctVariables[0].Id;
        pLine.AcctSeed__GL_Account_Variable_4__c = AyTestDataSuite.acctVariables4[0].Id;
        insert pLine;
        
        // Update payable TestData
        pay.Hardcost__c = true;
        update pay;
        
        // Setup Trust Balance TestData
        Trust_Balance__c tb = new Trust_Balance__c ();
        tb.Matter__c  = matter.Id;
        tb.Status__c  = 'Open';
        insert tb;
        
        // Setup Trust Account Activity TestData
        Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c  ();
        tActivity.Trust_Balance__c = tb.Id;
        tActivity.Payable__c = pay.Id;
        tActivity.Payable_Line__c = pLine.Id;
        insert tActivity;
        
        // Payable List 
        List<AcctSeed__Account_Payable__c> payableList = new List <AcctSeed__Account_Payable__c> ();
        payableList.add(pay);
        
        // Payable List Id
        List<Id> payableListIds = new List <Id> ();
        payableListIds.add(pay.Id);
        
        // Call the post service
        AcctSeed.PostResult[] postResults = AcctSeed.AccountPayablePostService.postAccountPayables(payableList);
        
        AyPayablePostController.postPayable(payableListIds);
        
        // Call the unpost service
        AcctSeed.PostResult[] unpostResults = AcctSeed.AccountPayablePostService.unpostAccountPayables(payableList);
        
    }
}