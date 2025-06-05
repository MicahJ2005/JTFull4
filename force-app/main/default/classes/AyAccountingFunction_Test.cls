/***************************************************************
@author       :  Shubham@Ayodia
@date         :  27Oct,2020
@description  :  This Test class for AyAccountingFunction Class.
*****************************************************************/
@isTest
private class AyAccountingFunction_Test {
    
    private static testMethod Void testCreateBillsFromOpportunity(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
           
        // get Logged in user
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Update Opportunity
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
        AyTestDataSuite.opportunities[0].StageName = 'Pending Consult';
        AyTestDataSuite.opportunities[0].Create_Billing__c = true;
        AyTestDataSuite.opportunities[0].Case_Commencement_Call__c  = 'No';
        AyTestDataSuite.opportunities[0].Preferred_Office_for_Meeting__c = 'Blaine';
        AyTestDataSuite.opportunities[0].Rate_Type__c = 'Flat Fee';
        AyTestDataSuite.opportunities[0].Send_Statement_Method__c = 'Email';
        AyTestDataSuite.opportunities[0].Urgent__c = 'No';
        update AyTestDataSuite.opportunities[0];
        
        // Setup Product TestData
        Product2 prod = new Product2();
        prod.Name = 'Test Product Adoption';
        prod.ProductCode = 'Adoption';
        prod.IsActive = TRUE;
        prod.Cost__c = -100;
        insert prod;
        
        // Setup Custom Price Book 
        Pricebook2 customPB = new Pricebook2();
        customPB.Name = 'Custom Pricebook';
        customPB.isActive = true;
        insert customPB;
        
        // get Standard Price Book Id    
        Id pricebookId = Test.getStandardPricebookId();
        
        // Setup Standard Price Book Entry
        PricebookEntry standardPrice = new PricebookEntry();
        standardPrice.Pricebook2Id = pricebookId;
        standardPrice.Product2Id = prod.Id;
        standardPrice.UnitPrice = 100;
        standardPrice.IsActive = true;
        insert standardPrice;
        
        // Setup Custom Price Book Entry
        PricebookEntry customPrice = new PricebookEntry();
        customPrice.Pricebook2Id = customPB.Id;
        customPrice.Product2Id = prod.Id;
        customPrice.UnitPrice = 12000;
        customPrice.IsActive = true;
        insert customPrice;
        
        // Setup Opportunity Line Item Test Data
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = AyTestDataSuite.opportunities[0].Id;
        oli.Quantity = 5;
        oli.UnitPrice = 100;
        oli.PricebookEntryId = customPrice.Id;
        oli.Product2Id = prod.Id;
        insert oli;
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Billing_Attorney_LU__c = u.Id;
        matter.Originator_LU__c = u.Id;
        insert matter;
        
        // Query on RecordType to fetch Next Step Opportunity RecordType Id
        Id recordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Next_Step' AND sObjectType = 'Opportunity'].Id;
        
        // Setup Next Step Opportunity TestData
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity Name';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        opp.StageName = 'Pending Consult';
        opp.Conflict_Check_Status__c = 'Pass';
        opp.CloseDate = Date.today().addDays(15);
        opp.Notes_for_Legal_Team_Consult_Notes__c = 'Testing Purpose Only..!';
        opp.Payment_Status__c = 'Paid in Full';
        opp.Area_of_Law__c = 'Family Law';
        opp.Office_that_consult_occurred_in__c = 'Eagan';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.RecordTypeId = recordTypeId;
        opp.Rate_Type__c = 'Flat Fee';
        opp.Send_Statement_Method__c = 'Email';
        opp.Case_Commencement_Call__c  = 'No';
        opp.Create_Billing__c = false;
        insert opp;
        
        // Setup Product TestData
        Product2 product = new Product2();
        product.Name = 'Test Product Adoption';
        product.ProductCode = 'Adoption';
        product.IsActive = TRUE;
        product.Cost__c = 100;
        insert product;
        
        // Setup Custom Price Book 
        Pricebook2 PB = new Pricebook2();
        PB.Name = 'Custom Pricebook';
        PB.isActive = true;
        insert PB;
        
        // get Standard Price Book Id    
        Id stdpricebookId = Test.getStandardPricebookId();
        
        // Setup Standard Price Book Entry
        PricebookEntry stdPrice = new PricebookEntry();
        stdPrice.Pricebook2Id = stdpricebookId;
        stdPrice.Product2Id = product.Id;
        stdPrice.UnitPrice = 100;
        stdPrice.IsActive = true;
        insert stdPrice;
        
        // Setup Custom Price Book Entry
        PricebookEntry cPrice = new PricebookEntry();
        cPrice.Pricebook2Id = PB.Id;
        cPrice.Product2Id = product.Id;
        cPrice.UnitPrice = 12000;
        cPrice.IsActive = true;
        insert cPrice;
        
        // Setup Opportunity Line Item Test Data
        OpportunityLineItem oline = new OpportunityLineItem();
        oline.OpportunityId = opp.Id;
        oline.Quantity = 5;
        oline.UnitPrice = 100;
        oline.PricebookEntryId = cPrice.Id;
        oline.Product2Id = product.Id;
        insert oline;
        
        // Start Test
        Test.startTest();
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = opp.Id;
        c.Project__c = matter.Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Priority = 'High';
        c.Status = 'Terminated';
        c.Subject = 'Adoption';
        c.Previous_Status__c = 'Terminated';
        c.Opportunity_Product__c = oline.Id;
        c.Total_Task__c = 50;
        c.Completed_Task__c = 50;
        c.Tasks_Completed__c = 10;
        insert c;
        
        c.Tasks_Completed__c = 50;
        update c;
        
        // Update Next Step Opportunity
        opp.StageName = 'Closed Won';
        opp.Next_Step_Matter__c = matter.Id;
        opp.Create_Billing__c = true;
        opp.Kapsten_Matter__c = 'Yes';
        opp.Urgent__c = 'No';
        update opp;
        
        // Update Next Step Opportunity Status
        opp.StageName = 'Pending Consult';
        update opp;
        
        // Update Next Step Opportunity Status
        opp.StageName = 'Closed Won';
        update opp;
        
        // Stop Test
        Test.stopTest();
        
    }
        
}