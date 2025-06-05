/*********************************************************
@author       :  Shubham@Ayodia
@date         :  25Oct,2021
@description  :  TestClass for AyMatterTerminationTrigger
**********************************************************/
@isTest
private class AyMatterTerminationProcess_Test {
    
    private static testMethod Void handleTerminationAccounting_Positive1(){
        
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
        prod.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
        prod.Cost__c = 100;
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
        
        // Update Opportunity Status
        AyTestDataSuite.opportunities[0].StageName = 'Closed Won';
        update AyTestDataSuite.opportunities[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Billing_Attorney_LU__c = u.Id;
        matter.Originator_LU__c = u.Id;
        insert matter;
        
        // Start Test
        Test.startTest();
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.Project__c = matter.Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Priority = 'High';
        c.Status = 'Terminated';
        c.Subject = 'Adoption';
        c.Previous_Status__c = 'Terminated';
        c.Opportunity_Product__c = oli.Id;
        insert c;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = true;
        insert pay;
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Payable__c = pay.Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        billLine.AcctSeed__Product__c = prod.Id;
        insert billLine;
        
        // Setup Matter Termination TestData
        Matter_Termination__c mt = new Matter_Termination__c();
        mt.Matter__c = matter.Id;
        mt.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        mt.Is_Active__c = true;
        mt.Total_Billed_Amount__c = 1000;
        mt.Total_Received__c = 0;
        mt.Value_of_All_Tasks__c = 1935;
        mt.Value_Of_Incomplete_Tasks__c = 1435;
        mt.Approval_Status__c = 'Approved';
        mt.Underpay_Disposition__c = 'Bill';
        mt.Adjusted_Bill_GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        mt.Termination_Status__c = 'In Process';
        mt.Termination_Type__c = 'Standard Opportunity';
        insert mt;
        
        // Setup Case Termination TestData
        Case_Termination__c ct = new Case_Termination__c();
        ct.Matter_Termination__c = mt.Id;
        ct.Case__c = c.Id;
        ct.Total_Open_Task_Hours__c = 2;
        ct.Total_Open_Task_Value__c = 425;
        ct.Product_Total_Task_Value__c = 1275;
        ct.Product_Price__c = 1500;
        ct.Opportunity_Product__c = oli.Id;
        insert ct;
        
        // Update Matter Termination TestData
        mt.Create_Accounting__c = true;
        update mt;
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod Void handleTerminationAccounting_Positive2(){
        
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
        prod.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
        prod.Cost__c = 100;
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
        
        // Query on RecordType to fetch Next Step Opportunity RecordType Id
        Id recordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Next_Step' AND sObjectType = 'Opportunity'].Id;
        
        // Setup Next Step Opportunity TestData
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity Name';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        opp.StageName = 'Closed Won';
        opp.Conflict_Check_Status__c = 'Pass';
        opp.CloseDate = Date.today().addDays(15);
        opp.Notes_for_Legal_Team_Consult_Notes__c = 'Testing Purpose Only..!';
        opp.Payment_Status__c = 'Paid in Full';
        opp.Area_of_Law__c = 'Family Law';
        opp.Office_that_consult_occurred_in__c = 'Eagan';
        opp.Area_of_Law__c = 'Family Law';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.RecordTypeId = recordTypeId;
        insert opp;
        
        // Setup Product TestData
        Product2 product = new Product2();
        product.Name = 'Test Product Adoption';
        product.ProductCode = 'Adoption';
        product.IsActive = TRUE;
        product.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
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
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Billing_Attorney_LU__c = u.Id;
        matter.Originator_LU__c = u.Id;
        insert matter;
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.Project__c = matter.Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Priority = 'High';
        c.Status = 'Terminated';
        c.Subject = 'Adoption';
        c.Previous_Status__c = 'Terminated';
        c.Opportunity_Product__c = oline.Id;
        insert c;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = true;
        insert pay;
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Payable__c = pay.Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        billLine.AcctSeed__Product__c = prod.Id;
        insert billLine;
        
        // Start Test
        Test.startTest();
        
        // Setup Matter Termination TestData
        Matter_Termination__c mt = new Matter_Termination__c();
        mt.Matter__c = matter.Id;
        mt.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        mt.Is_Active__c = true;
        mt.Total_Billed_Amount__c = 2000;
        mt.Total_Received__c = 0;
        mt.Value_of_All_Tasks__c = 1935;
        mt.Value_Of_Incomplete_Tasks__c = 1435;
        mt.Approval_Status__c = 'Approved';
        mt.Underpay_Disposition__c = 'Bill';
        mt.Adjusted_Bill_GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        mt.Termination_Status__c = 'In Process';
        mt.Termination_Type__c = 'Next Step Opportunity';
        mt.Related_Next_Step_Opportunity__c = opp.Id;
        insert mt;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        tsk.Top_Level_Case_Id__c = c.Id;
        insert tsk;
        
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Completed';
        t.Matter__c = matter.Id;
        update t;
        
        // Setup Case Termination TestData
        Case_Termination__c ct = new Case_Termination__c();
        ct.Matter_Termination__c = mt.Id;
        ct.Case__c = c.Id;
        ct.Total_Open_Task_Hours__c = 2;
        ct.Total_Open_Task_Value__c = 425;
        ct.Product_Total_Task_Value__c = 1275;
        ct.Product_Price__c = 1500;
        ct.Opportunity_Product__c = oline.Id;
        insert ct;
        
        // Update Matter Termination TestData
        mt.Create_Accounting__c = true;
        mt.Termination_Status__c = 'Completed';
        update mt;
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod Void handleTerminationAccounting_Positive3(){
        
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
        prod.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
        prod.Cost__c = 100;
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
        
        // Query on RecordType to fetch Next Step Opportunity RecordType Id
        Id recordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Next_Step' AND sObjectType = 'Opportunity'].Id;
        
        // Setup Next Step Opportunity TestData
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity Name';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        opp.StageName = 'Closed Won';
        opp.Conflict_Check_Status__c = 'Pass';
        opp.CloseDate = Date.today().addDays(15);
        opp.Notes_for_Legal_Team_Consult_Notes__c = 'Testing Purpose Only..!';
        opp.Payment_Status__c = 'Paid in Full';
        opp.Area_of_Law__c = 'Family Law';
        opp.Office_that_consult_occurred_in__c = 'Eagan';
        opp.Area_of_Law__c = 'Family Law';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.RecordTypeId = recordTypeId;
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
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Billing_Attorney_LU__c = u.Id;
        matter.Originator_LU__c = u.Id;
        insert matter;
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.Project__c = matter.Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Priority = 'High';
        c.Status = 'Terminated';
        c.Subject = 'Adoption';
        c.Previous_Status__c = 'Terminated';
        c.Opportunity_Product__c = oline.Id;
        insert c;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = true;
        insert pay;
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Payable__c = pay.Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        billLine.AcctSeed__Product__c = prod.Id;
        insert billLine;
        
        // Start Test
        Test.startTest();
        
        // Setup Matter Termination TestData
        Matter_Termination__c mt = new Matter_Termination__c();
        mt.Matter__c = matter.Id;
        mt.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        mt.Is_Active__c = true;
        mt.Total_Billed_Amount__c = 500;
        mt.Total_Received__c = 1000;
        mt.Value_of_All_Tasks__c = 1935;
        mt.Value_Of_Incomplete_Tasks__c = 1435;
        mt.Approval_Status__c = 'Approved';
        mt.Underpay_Disposition__c = 'Bill';
        mt.Adjusted_Bill_GL_Account__c = AyTestDataSuite.glAccounts[0].Id;
        mt.Termination_Status__c = 'In Process';
        mt.Termination_Type__c = 'Next Step Opportunity';
        mt.Related_Next_Step_Opportunity__c = opp.Id;
        insert mt;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        tsk.Top_Level_Case_Id__c = c.Id;
        insert tsk;
        
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Completed';
        t.Matter__c = matter.Id;
        update t;
        
        // Setup Case Termination TestData
        Case_Termination__c ct = new Case_Termination__c();
        ct.Matter_Termination__c = mt.Id;
        ct.Case__c = c.Id;
        ct.Total_Open_Task_Hours__c = 2;
        ct.Total_Open_Task_Value__c = 425;
        ct.Product_Total_Task_Value__c = 1275;
        ct.Product_Price__c = 1500;
        ct.Opportunity_Product__c = oline.Id;
        ct.Total_Credit_Value__c = 100;
        insert ct;
        
        // Update Matter Termination TestData
        mt.Create_Accounting__c = true;
        mt.Termination_Status__c = 'Completed';
        update mt;
        
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod Void handleTerminationAccounting_NegativeCM(){
        
        
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
        prod.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
        prod.Cost__c = 100;
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
        
        // Query on RecordType to fetch Next Step Opportunity RecordType Id
        Id recordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Next_Step' AND sObjectType = 'Opportunity'].Id;
        
        // Setup Next Step Opportunity TestData
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity Name';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        opp.StageName = 'Closed Won';
        opp.Conflict_Check_Status__c = 'Pass';
        opp.CloseDate = Date.today().addDays(15);
        opp.Notes_for_Legal_Team_Consult_Notes__c = 'Testing Purpose Only..!';
        opp.Payment_Status__c = 'Paid in Full';
        opp.Area_of_Law__c = 'Family Law';
        opp.Office_that_consult_occurred_in__c = 'Eagan';
        opp.Area_of_Law__c = 'Family Law';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.RecordTypeId = recordTypeId;
        insert opp;
        
        // Setup Product TestData
        Product2 product = new Product2();
        product.Name = 'Test Product Adoption';
        product.ProductCode = 'Adoption';
        product.IsActive = TRUE;
        product.Cost__c = 100;
        product.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
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
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Billing_Attorney_LU__c = u.Id;
        matter.Originator_LU__c = u.Id;
        insert matter;
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.Project__c = matter.Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Priority = 'High';
        c.Status = 'Terminated';
        c.Subject = 'Adoption';
        c.Previous_Status__c = 'Terminated';
        c.Opportunity_Product__c = oline.Id;
        insert c;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = true;
        insert pay;
        System.debug('Payable='+pay);
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;
        System.debug('PayableLine='+pLine);
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Payable__c = pay.Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        billLine.AcctSeed__Product__c = prod.Id;
        insert billLine;
        
        // Start Test
        Test.startTest();
        
        // Setup Matter Termination TestData
        Matter_Termination__c mt = new Matter_Termination__c();
        mt.Matter__c = matter.Id;
        mt.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        mt.Is_Active__c = true;
        mt.Total_Billed_Amount__c = 1000;
        mt.Total_Received__c = 1100;
        mt.Value_of_All_Tasks__c = 1935;
        mt.Value_Of_Incomplete_Tasks__c = 1435;
        mt.Termination_Status__c = 'In Process';
        mt.Approval_Status__c = 'Approved';
        mt.Overpayment_Disposition__c = 'Credit Memo';
        mt.Termination_Type__c = 'Standard Opportunity';
        insert mt;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        insert tsk;
        
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Completed';
        t.Matter__c = matter.Id;
        update t;
        
        // Setup Case Termination TestData
        Case_Termination__c ct = new Case_Termination__c();
        ct.Matter_Termination__c = mt.Id;
        ct.Case__c = c.Id;
        ct.Total_Open_Task_Hours__c = 2;
        ct.Total_Open_Task_Value__c = 425;
        ct.Product_Total_Task_Value__c = 1275;
        ct.Product_Price__c = 1500;
        ct.Opportunity_Product__c = oline.Id;
        insert ct;
        
        // Update Matter Termination TestData
        mt.Create_Accounting__c = true;
        mt.Termination_Status__c = 'Completed';
        update mt;
        
        Matter_Termination__c mtQuery = [Select Id, Total_Adjusted_Billing_Balance__c from Matter_Termination__c Where Id=: mt.id];
        System.debug('NegativeCM'+mtQuery);
              
        // Stop Test
        Test.stopTest();
        
    }
    
    private static testMethod Void handleTerminationAccounting_Negative(){
        
        
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
        prod.Cost__c = 100;
        prod.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
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
        
        // Query on RecordType to fetch Next Step Opportunity RecordType Id
        Id recordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Next_Step' AND sObjectType = 'Opportunity'].Id;
        
        // Setup Next Step Opportunity TestData
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity Name';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        opp.StageName = 'Closed Won';
        opp.Conflict_Check_Status__c = 'Pass';
        opp.CloseDate = Date.today().addDays(15);
        opp.Notes_for_Legal_Team_Consult_Notes__c = 'Testing Purpose Only..!';
        opp.Payment_Status__c = 'Paid in Full';
        opp.Area_of_Law__c = 'Family Law';
        opp.Office_that_consult_occurred_in__c = 'Eagan';
        opp.Area_of_Law__c = 'Family Law';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.RecordTypeId = recordTypeId;
        insert opp;
        
        // Setup Product TestData
        Product2 product = new Product2();
        product.Name = 'Test Product Adoption';
        product.ProductCode = 'Adoption';
        product.IsActive = TRUE;
        product.Cost__c = 100;
        product.AcctSeed__Revenue_GL_Account__c = AyTestDataSuite.glAccounts[10].Id;
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
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Billing_Attorney_LU__c = u.Id;
        matter.Originator_LU__c = u.Id;
        insert matter;
        
        // Setup Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.Project__c = matter.Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Priority = 'High';
        c.Status = 'Terminated';
        c.Subject = 'Adoption';
        c.Previous_Status__c = 'Terminated';
        c.Opportunity_Product__c = oline.Id;
        insert c;
        
        // Setup Payable TestData
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c  = 'Approved';
        pay.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
        pay.Matter__c = matter.Id;
        pay.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pay.AcctSeed__Payee_Reference__c = 'Cash';
        pay.AcctSeed__Date__c = date.today();
        pay.AcctSeed__Due_Date__c = date.today().addDays(7);
        pay.Hardcost__c = true;
        insert pay;
        System.debug('Payable='+pay);
        
        // Setup Payable Line TestData
        AcctSeed__Account_Payable_Line__c pLine = new AcctSeed__Account_Payable_Line__c();
        pLine.AcctSeed__Account_Payable__c = pay.Id;
        pLine.AcctSeed__Amount__c = 100;
        pLine.AcctSeed__Quantity__c = 10;
        pLine.Hardcost__c = true;
        pLine.AcctSeed__Expense_GL_Account__c = AyTestDataSuite.glAccounts[12].Id;
        insert pLine;
        System.debug('PayableLine='+pLine);
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Payable__c = pay.Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        billLine.AcctSeed__Product__c = prod.Id;
        insert billLine;
        
        // Start Test
        Test.startTest();
        
        // Setup Matter Termination TestData
        Matter_Termination__c mt = new Matter_Termination__c();
        mt.Matter__c = matter.Id;
        mt.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        mt.Is_Active__c = true;
        mt.Total_Billed_Amount__c = 1995;
        mt.Total_Received__c = 1500;
        mt.Value_of_All_Tasks__c = 875;
        mt.Value_Of_Incomplete_Tasks__c = 735;
        mt.Termination_Status__c = 'In Process';
        mt.Approval_Status__c = 'Approved';
        mt.Overpayment_Disposition__c = 'Credit Memo';
        mt.Termination_Type__c = 'Standard Opportunity';
        insert mt;
        
        Matter_Termination__c mtQuery = [Select Id, Total_Adjusted_Billing_Balance__c from Matter_Termination__c Where Id=: mt.id];
        System.debug('Negative'+mtQuery);
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        insert tsk;
        
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Completed';
        t.Matter__c = matter.Id;
        update t;
        
        // Setup Case Termination TestData
        Case_Termination__c ct = new Case_Termination__c();
        ct.Matter_Termination__c = mt.Id;
        ct.Case__c = c.Id;
        ct.Total_Open_Task_Hours__c = 2;
        ct.Total_Open_Task_Value__c = 425;
        ct.Product_Total_Task_Value__c = 1275;
        ct.Product_Price__c = 1500;
        ct.Opportunity_Product__c = oline.Id;
        insert ct;
        
              
        // Stop Test
        Test.stopTest();
        
    }

}