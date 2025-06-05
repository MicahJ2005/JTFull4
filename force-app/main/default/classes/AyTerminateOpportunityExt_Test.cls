/*********************************************************
@author       :  Shubham@Ayodia
@date         :  20April,2021
@description  :  TestClass for AyTerminateOpportunityExt
**********************************************************/
@isTest
private class AyTerminateOpportunityExt_Test {
    
    private static testMethod Void testTerminateOpportunity(){
        
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
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Total_Task_Hours__c = 10;
        matter.Total_Task__c = 100;
        insert matter;
        
        // Setup Open Case TestData
        Case c = new Case();
        c.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Opportunity_Product__c = oli.Id;
        c.Project__c = matter.Id;
        c.Priority = 'Normal';
        c.Status = 'On Hold';
        c.Subject = 'Test Case';
        c.ClosedDate = Date.today();
        insert c;
        
        // Setup Open Tasks Data
        Task t = new Task();
        t.Subject = 'Call';
        t.Status = 'on Hold';
        t.Priority = 'Normal';
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.WhatId = c.Id;
        t.Not_Applicable__c = false;
        insert t;
        
        // Setup Terminated Tasks Data
        Task t1 = new Task();
        t1.Subject = 'Call';
        t1.Status = 'Terminated';
        t1.Priority = 'Normal';
        t1.Hours__c = 4;
        t1.Billing_Rate__c = 100;
        t1.WhatId = c.Id;
        t1.Completed_Date__c = Date.today();
        t1.Not_Applicable__c = false;
        insert t1;
        
        // Setup refund Tasks Data
        Task t2 = new Task();
        t2.Subject = 'Call';
        t2.Status = 'Refund';
        t2.Priority = 'Normal';
        t2.Hours__c = 4;
        t2.Billing_Rate__c = 100;
        t2.WhatId = c.Id;
        t2.Completed_Date__c = Date.today();
        t2.Not_Applicable__c = false;
        insert t2;
        
        // Setup NA Tasks Data
        Task t3 = new Task();
        t3.Subject = 'Call';
        t3.Status = 'Not Applicable';
        t3.Priority = 'Normal';
        t3.Hours__c = 4;
        t3.Billing_Rate__c = 100;
        t3.WhatId = c.Id;
        t3.Matter__c = matter.Id;
        t3.Completed_Date__c = Date.today();
        t3.Not_Applicable__c = false;
        insert t3;
        
        // Setup Parent Task Tracker Template TestData
        Task_Tracker_Template__c PTemplate = new Task_Tracker_Template__c();
        PTemplate.Is_Active__c = true;
        PTemplate.Name = 'Parent Template';
        insert PTemplate;
        
        // Setup Task Tracker Template TestData
        Task_Tracker_Template__c temp = new Task_Tracker_Template__c();
        temp.Is_Active__c = true;
        temp.Name = 'template';
        temp.Parent_Template__c = PTemplate.Id;
        insert temp;
        
        // Update Case TestData
        c.Task_Tracker_Template__c = temp.Id;
        update c;
        
        // Start Test
        Test.startTest();
        
        // Set AyTerminateOpportunity Page
        PageReference testPage = Page.AyTerminateOpportunity; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('Id', matter.Id);
        testPage.getParameters().put('i', '0');
        ApexPages.StandardController sc = new ApexPages.StandardController(matter);
        
        // Call AyTerminateOpportunityExt
        AyTerminateOpportunityExt ext = new AyTerminateOpportunityExt(sc);
        ext.onChangeTemplateStatus();
        
        
        for(AyTerminateOpportunityExt.TemplateHeaderWrapper tWrap : ext.mainList){
            for(AyTerminateOpportunityExt.CasesListWrapper cWrap : tWrap.openCasesList){
                cWrap.Status = 'Terminated';
                cWrap.terminate = true;
                cWrap.onHold = true;
                Id caseId = cWrap.caseId;
                Decimal totalTaskHours = cWrap.totalTaskHours;
            }   
        }
                
		ext.redirectToMatterTermination();
        
        // Stop Test
        Test.stopTest();
    }
    
}