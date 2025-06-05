/***********************************************
@author       :  Shubham@Ayodia
@date         :  13April,2020
@description  :  TestClass for AyFinanceHandler 
				 AND AyCreateFinanceFromOppExt
************************************************/
@isTest
private class AyFinanceModule_Test {
    
    private static testMethod void testCreateFinanicing(){
        
        // Setup Test DataSuite
        AyTestDataSuite.init();
        
        // SOQL to fetch current Logged In User
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Update AyTestDataSuite opportunity Test Data
        AyTestDataSuite.opportunities[0].Rate_Type__c = 'Hourly';
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eden Prairie';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Child Protection';
        AyTestDataSuite.opportunities[0].StageName = 'Pending Consult';
        update AyTestDataSuite.opportunities[0];
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
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
        
        
        // Setup Finance TestData        
        Finance__c fin = new Finance__c();
        fin.Downpayment__c = 10000;
        fin.Payment_Frequency__c= 'Monthly';
        fin.No_of_Instalments__c = 1;
        fin.Create_Accounting__c = false;
        fin.Parent_Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        fin.Matter__c = matter.Id;
        fin.First_Instalment_Payment_Date__c = date.today();
        insert fin;
        
        // Setup Finance Opportunity TestData
        Finance_Opportunity__c fOpp = new Finance_Opportunity__c();
        fOpp.Finance__c = fin.Id;
        fOpp.Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        fOpp.Billed_Amount__c = 10000;
        fOpp.Received_Amount__c = 5000;
        insert fOpp;
        
        // Start Test
        Test.startTest();
        
        // Update Finance TestData
        fin.Create_Accounting__c = true;
        update fin;
        
        // Update Finance Opportunity TestData
        fOpp.Matter__c = matter.Id;
        fOpp.Waved_Off_Amount__c = 10;
        fOpp.Adjusted_Balance__c = 1000;
        update fOpp;
        
        
        // Set AyCreateFinacneFromOpp Page
        PageReference pageRef = Page.AyCreateFinanceFromOpp;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('oppId', String.valueOf(AyTestDataSuite.opportunities[0].Id));
        ApexPages.StandardController sc = new ApexPages.StandardController(AyTestDataSuite.opportunities[0]);
        
        // Call AyCreateFinanceFromOppExt
        AyCreateFinanceFromOppExt ext = new AyCreateFinanceFromOppExt(sc);
        ext.wrapperList[0].selected = true;
        ext.createFinance();
        
        // Update AyTestDataSuite opportunity
        AyTestDataSuite.opportunities[0].Next_Step_Matter__c = matter.Id;
        update AyTestDataSuite.opportunities[0];
       
        AyCreateFinanceFromOppExt ext1 = new AyCreateFinanceFromOppExt(sc);
        
        Date d = Date.today();
        
        // call AyFinanceHandler
        AyFinanceHandler.getAccountingPeriod(d);
        
        // Stop Test
        Test.stopTest();
        
    }
}