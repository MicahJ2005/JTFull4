/******************************************
@author       :  Shubham@Ayodia
@date         :  08April,2022
@description  :  TestClass for AyCPATrigger
*******************************************/
@isTest
private class AyCPATrigger_Test {
    
    private static testmethod void testCPAHandler(){
        
        // Setup TestData Suite
        AyTestDataSuite.init();
        
        AyTestDataSuite.Opportunities[0].Rate_Type__c = 'Flat Fee';
        update AyTestDataSuite.Opportunities[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Customer Products Approval TestData
        Customer_Products_Approval__c cpa = new Customer_Products_Approval__c();
        cpa.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        cpa.Next_Step_Matter__c = matter.Id;
        cpa.Total_Credit_Value__c = 313081;
        cpa.Total_Received_Amount__c = 750;
        cpa.Total_Hard_Cost_Billing_Amount__c = 571.03;
        cpa.Total_Billed_Amount__c = 253.97;
        cpa.Status__c = 'Waiting on Customer';
        cpa.Resulting_Outstanding_Balance__c = -3130.81;
        cpa.Adjusted_Previous_Package_Balance_Due__c = 3130.81;
        cpa.Current_Balance_Refund_Due__c = 7125.81;
        cpa.Pay_In_Full_Discount__c = 199.75;
        cpa.Pay_In_Full_Today_Price__c = 664.44;
        cpa.Minimum_Down_Payment__c = 1997.50;
        cpa.Next_Price__c = 3995;
        cpa.Down_Payment__c = 2000;
        cpa.Payment_Method_Token__c = '******';
        cpa.Financed_Package__c = 'This Next Step Only';
        cpa.Term_in_Months__c = '5';
        insert cpa;

        // Start Test
        Test.startTest();
        
        // Update Customer Products Approval TestData
        //cpa.DocuSign_Signature_Complete__c = true;
        update cpa;
        
        // Setup affinipay Transaction TestData
        affinipay__Transaction__c trans = new affinipay__Transaction__c();
        trans.Matter__c = cpa.Next_Step_Matter__c;
        trans.Opportunity__c = cpa.Opportunity__c;
        insert trans;
		
        // Call chargeDownpayment future method
		AyCPATriggerHandler.chargeDownpayment(cpa.Id);
        AyCPATriggerHandler.handleFinance(cpa.Id);
        
        AyPaymentsComponentController.initAction(cpa.Id);
        AyPaymentsComponentController.addMethodToObject(cpa.Id, 'tokenJsonStr', 'Savings');
        
        // Stop Test
        Test.stopTest();
       
    }

}