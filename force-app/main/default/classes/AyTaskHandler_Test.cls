/***************************************************
@author       :  Shubham@Ayodia
@date         :  28Oct,2020
@description  :  TestClass for AyTaskHandler Class.
****************************************************/
@isTest
private class AyTaskHandler_Test {
    /*
    private static testMethod void testHandleTaskHourCalculations(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in user
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
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
        
        // Setup Matter Test Data 1
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Case Test Data
        Case c = new Case();
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        c.Opportunity_Product__c = oli.Id;
        c.Status = 'Working';
        c.Origin = 'Phone'; 
        c.Project__c = matter.Id;
        insert c;
        
        // Setup Task Tracker Template Test Data
        Task_Tracker_Template__c tmp = new Task_Tracker_Template__c();
        tmp.Name = 'Signing';
        tmp.Is_Active__c  = True;
        tmp.Template_Type__c = 'Case';
        insert tmp;         
        
        // Setup Task Tracker Template Step Test Data
        Task_Tracker_Template_Step__c tmpStep = new Task_Tracker_Template_Step__c ();
        tmpStep.Name = 'Test Task Tracker Template Step';
        tmpStep.Activity_Type__c = 'Task';
        tmpStep.Task_Tracker_Template__c = tmp.Id;
        tmpStep.Hours__c = 1;
        tmpStep.Assigned_Role__c = 'Attorney ';
        insert tmpStep;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        insert tsk;
        
        // start Test
        test.startTest();
        
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Not Applicable';
        t.Task_Tracker_Template_Step__c = tmpStep.Id;
        update t;
        
        // Delete Task
        delete t;
        
        // stop Test
        test.stopTest();
        
    }*/
    
    private static testMethod void testHandleTaskHourCalculations2(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in user
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Update Opportunity
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
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
        
        // Setup Matter Test Data 1
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Completed';
        insert matter;
        
        // Setup Project Rate Test Data
        Project_Rate__c pr = new Project_Rate__c();
        pr.Name = 'Test Project Rate Name';
        pr.Hourly_Rate__c = 100;
        pr.Project__c = matter.Id;
        pr.Role__c = 'Attorney';
        insert pr;
        
        // Setup Case Test Data
        Case c = new Case();
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        c.Opportunity_Product__c = oli.Id;
        c.Status = 'Working';
        c.Origin = 'Phone'; 
        c.Project__c = matter.Id;
        insert c;
        
        // Start Test
        Test.startTest();
        
        // Setup Task Tracker Template Test Data
        Task_Tracker_Template__c tmp = new Task_Tracker_Template__c();
        tmp.Name = 'Signing';
        tmp.Is_Active__c  = True;
        tmp.Template_Type__c = 'Case';
        insert tmp;         
        
        // Setup Task Tracker Template Step Test Data
        Task_Tracker_Template_Step__c tmpStep = new Task_Tracker_Template_Step__c ();
        tmpStep.Name = 'Test Task Tracker Template Step';
        tmpStep.Activity_Type__c = 'Task';
        tmpStep.Task_Tracker_Template__c = tmp.Id;
        tmpStep.Hours__c = 1;
        tmpStep.Assigned_Role__c = 'Attorney ';
        insert tmpStep;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        insert tsk;
        
        // Update Task TestData
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Completed';
        t.Task_Tracker_Template_Step__c = tmpStep.Id;
        t.Matter__c = matter.Id;
        t.Top_Level_Case_Id__c = c.Id;
        update t;
       
        // Delete Task
        delete t;
        
        // Stop Test
        Test.stopTest();
        
    }  
    
    private static testMethod void testTaskHandler(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        //Setup Opportunty
        Opportunity opp = new Opportunity();
        opp.Name = 'Testing Opportunity';
        opp.CloseDate = Date.today().addDays(10);
        opp.StageName = 'Prospecting';
        opp.Area_of_Law__c = 'Criminal Defense';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        insert opp;
        
        // Setup Matter Test Data 1
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = opp.Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Start Test
        Test.startTest();
        
        // Setup Case Test Data
        Case c = new Case();
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Status = 'Working';
        c.Origin = 'Phone'; 
        c.Project__c = matter.Id;
        insert c;
        
        // Setup Case Test Data
        Case c2 = new Case();
        c2.ContactId = AyTestDataSuite.contacts[0].Id;
        c2.AccountId = AyTestDataSuite.accounts[0].Id;
        c2.Status = 'Working';
        c2.Origin = 'Phone'; 
        c2.Project__c = matter.Id;
        c2.ParentId = c.Id;
        insert c2;
        
        // Setup TaskData
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        tsk.Matter__c = matter.Id;
        tsk.Top_Level_Case_Id__c = c.Id;
        insert tsk;

        // Update Task TestData
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Not Applicable';
        t.Matter__c = matter.Id;
        t.Top_Level_Case_Id__c = c.Id;
        update t;
        
        Task t1 = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t1.Hours__c = 4;
        t1.Billing_Rate__c = 100;
        t1.Status = 'Terminated';
        t1.Matter__c = matter.Id;
        t1.Top_Level_Case_Id__c = c.Id;
        update t1;
        
        // Stop Test
        Test.stopTest();
        
    }
}