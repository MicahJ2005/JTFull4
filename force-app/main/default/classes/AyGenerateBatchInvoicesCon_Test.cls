/*********************************************************
@author       :  Shubham@Ayodia
@date         :  09march,2020
@description  :  TestClass for AyGenerateBatchInvoicesCon 
				 And AyBatchCreateInvoicesForTime
**********************************************************/
@isTest
private class AyGenerateBatchInvoicesCon_Test{
    
    private static testMethod void testCreateInvoiceBatch(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Total_Task_Hours__c = 10;
        matter.Total_Task__c = 100;
        insert matter;
		
        // Soql to fetch Current User
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Setup Project TestData
        accorto__Project__c pro = new accorto__Project__c();
        pro.Name = 'City of Hugo';
        pro.accorto__IsActive__c  = true;
        pro.Matter__c = matter.Id;
        pro.accorto__Manager__c = u.Id;
        pro.accorto__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        insert pro;
        
        // Setup Resource TestData
        accorto__Resource__c res = new accorto__Resource__c();
        res.Name = 'Kunal Sharma';
        res.accorto__IsActive__c = true;
        res.accorto__Code__c = 'KS';
        insert res;

        // Setup Document Type TestData
        accorto__DocumentType__c docType = new accorto__DocumentType__c();
        docType.Name = 'AR Invoice';
        docType.accorto__IsReceivables__c = true;
        docType.accorto__IsDefault__c = true;
        insert docType;
        
        // Setup Invoice TestData
        accorto__Invoice__c inv = new accorto__Invoice__c();
        inv.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        inv.accorto__Contact__c = AyTestDataSuite.contacts[0].Id;
        inv.accorto__DocumentType__c = docType.Id;
        inv.accorto__Project__c = pro.Id;
        inv.accorto__Status__c = 'New';
        inv.accorto__Start_Date__c = Date.today();
        inv.accorto__End_Date__c = Date.today().addDays(15);
        inv.accorto__Invoice_Date__c = Date.today().addDays(25);
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
        invLine.accorto__ListPrice__c = 200;
        invLine.accorto__UnitPrice__c = 200;
        invLine.accorto__Quantity__c = 40;
        invLine.accorto__Hours__c = 10;
        invLine.accorto__Resource__c = res.Id;
        insert invLine;

        // Setup Accounting Config TestData
        Accounting_Config__c config = new Accounting_Config__c();
        config.Name = 'AR Invoice Document ID';
        config.Key__c = 'AR_Invoice_Document_ID';
        config.Value__c = docType.Id;
        insert config;
        
        // Setup T&E Report TestData
        accorto__TE_Report__c teReport = new accorto__TE_Report__c();
        teReport.accorto__TE_Date__c = Date.today();
        teReport.accorto__Manager__c = u.Id;
        teReport.accorto__Resource__c = res.Id;
        teReport.accorto__Project__c = pro.Id;
        teReport.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        teReport.accorto__Status__c = 'Approved';
        insert teReport;

        // Setup T&E Item TestData
        accorto__TE_Item__c te = new accorto__TE_Item__c();
        te.accorto__Status__c = 'New';
        te.accorto__Hours__c = 0.25;
        te.accorto__EstimatedBillingRate__c = 350;
        te.accorto__TE_Date__c = Date.today().addDays(-1);
        te.accorto__Resource__c = res.Id;
        te.accorto__Project__c = pro.Id;
        te.accorto__TE_Report__c = teReport.Id;
        te.accorto__Account__c = AyTestDataSuite.accounts[0].Id;
        te.accorto__IsTimeOnly__c = true;
        insert te;
        
        // Start Test
        Test.startTest();
        
        // Update TE Item Status 
        te.accorto__Status__c = 'Submitted';
        update te;

        te.accorto__Status__c = 'Approved';
        update te;
        
        // Call AyGenerateBatchInvoicesCon Controller
        System.currentPageReference().getParameters().put('S', String.valueOf(1));
        AyGenerateBatchInvoicesCon con = new AyGenerateBatchInvoicesCon();
        con.forResourceLookup.accorto__Manager__c = res.Id;
        con.executeBatch();
        
        AyGenerateBatchInvoicesCon con1 = new AyGenerateBatchInvoicesCon();
        con1.opp.CloseDate = Date.today();
        con1.executeBatch();
		
        Date d = Date.today();
        
        // Call AyBatchCreateInvoicesForTime
        AyBatchCreateInvoicesForTime b = new AyBatchCreateInvoicesForTime(d);
        Database.executeBatch(b, 1);
        
        // Call AyBatchCreateInvoicesForTime
        AyBatchCreateInvoicesForTime b1 = new AyBatchCreateInvoicesForTime();
        Database.executeBatch(b1, 1);
        
        // Call @AuraEnabled Method
        AyDisplayUnbilledHoursOnMatterController.getUnbilledHours(matter.id);

        // Stop Test
        Test.stopTest();
        
    }

}