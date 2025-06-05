/***********************************************
@author       :  Shubham@Ayodia
@date         :  04March,2021
@description  :  TestClass for AyInvoiceTrigger
************************************************/
@isTest
private class AyInvoiceTrigger_Test{
    
    private static testMethod Void invoiceMethod(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in User 
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Criminal Defense';
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
        insert matter;
        
        // Setup Accorto Project TestData
        accorto__Project__c pro = new accorto__Project__c ();
        pro.Name = 'Test Project';
        pro.accorto__IsActive__c = true;
        pro.accorto__Invoiced__c = 'Yes';
        pro.accorto__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pro.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        pro.Matter__c = matter.Id;
        insert pro;
        
        // Setup Project Line TestData
        accorto__Project_Line__c projectLine = new accorto__Project_Line__c();
        projectLine.Name = 'Test Project Line';
        projectLine.accorto__Project__c = pro.Id;
        projectLine.accorto__Product__c = prod.Id;
        projectLine.accorto__Unit_Price__c = 10;
        insert projectLine;
        
        
        
        // Setup DocType TestData
        accorto__DocumentType__c docType = new accorto__DocumentType__c();
        docType.Name = 'AR Invoice';
        docType.accorto__IsReceivables__c = true;
        docType.accorto__IsDefault__c = true;
        docType.accorto__DocNo_Current__c = 1003;
        docType.accorto__DocNo_Increment__c = 1;
        docType.accorto__DocNo_Format__c = '{0}';
        insert docType;       
        
        // Setup Invoice TestData
        accorto__Invoice__c inv = new accorto__Invoice__c();
        inv.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        //inv.accorto__Contact__c = AyTestDataSuite.contacts[0].Id;
        inv.accorto__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        inv.accorto__DocumentType__c = docType.Id;
        inv.accorto__Project__c = pro.Id;
        inv.accorto__Status__c = 'New';
        //inv.accorto__Start_Date__c = Date.today();
        //inv.accorto__End_Date__c = Date.today().addDays(15);
        inv.accorto__Invoice_Date__c = Date.today();
        inv.accorto__Accounting_Date__c = Date.today();
        //inv.accorto__DueDate__c = Date.today().addDays(20);
        inv.Create_Billing__c = false;
        inv.accorto__BillingStreet2__c = '2408  Olen Thomas Drive';
        inv.accorto__BillingCity__c = 'Dallas';
        inv.accorto__BillingCountry__c = 'US';
        inv.accorto__BillingState__c = 'TX';
        inv.accorto__BillingPostalCode__c = '75248';
        insert inv;
        
        // Setup Invoice Line TestData
        accorto__InvoiceLine__c invLine = new accorto__InvoiceLine__c();
        invLine.accorto__Invoice__c = inv.Id;
        invLine.accorto__Project__c = pro.Id;
        invLine.accorto__ListPrice__c = 200;
        invLine.accorto__UnitPrice__c = 200;
        invLine.accorto__Quantity__c = 40;
        invLine.accorto__Hours__c = 10;
        insert invLine;
        
        // Start Test
        Test.startTest();
        
        // Update Invoice TestData
        inv.Create_Billing__c = true;
        update inv;
       
        // Query on Billing to fetch data
        AcctSeed__Billing__c bList = [Select Id from AcctSeed__Billing__c Where Accorto_Invoice__c =: inv.Id];
       
        // Create billing records to unpost
		List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c>();
        billings.add(bList);

        // Call the unpost billings service
		AcctSeed.PostResult[] unpostResults = AcctSeed.BillingPostService.unpostBillings(billings);

        // Update Invoice TestData for Reverse Billings
        inv.Create_Billing__c = false;
        update inv;
        
        // Stop Test
        test.stopTest();     
    }
    
}