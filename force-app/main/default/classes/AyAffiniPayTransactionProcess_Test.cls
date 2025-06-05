/**********************************************************
@author       :  Shubham@Ayodia
@date         :  13Dec,2021
@description  :  TestClass for AffiniPay & AutoPay Process
***********************************************************/
@isTest
private class AyAffiniPayTransactionProcess_Test {
    
    private static testMethod void testAffiniPayTransactionProcess(){
        
        // Call Accounting TestData
        AyTestDataSuite.init();
        
        // Setup AffiniPay Settings TestData
        affinipay__AffiniPay_Settings__c aff = new affinipay__AffiniPay_Settings__c();
        aff.affinipay__Public_Key__c = 'm_g3C7IrKOQ3SKMKckB1Ct-Q';
        aff.affinipay__Organization_ID__c = 'org_YAssAyLo0OQQ2ATKKqHBO';
        aff.Name = 'affinipay';
        insert aff;
        
        // Setup Matter TestData
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        matter.Auto_Pay__c = true;
        insert matter;
        
        // Setup Billing TestData
        AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
        bill.AcctSeed__Date__c = Date.today();
        bill.AcctSeed__Due_Date2__c = Date.today(); 
        bill.AcctSeed__Status__c = 'Approved';
        bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
        bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
        bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        bill.Matter__c = matter.Id;
        insert bill;
        
        // Setup Billing Line TestData
        AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
        billLine.AcctSeed__Billing__c = bill.Id;
        billLine.AcctSeed__Date__c = Date.today();
        billLine.AcctSeed__Rate__c = 100;
        billLine.AcctSeed__Hours_Units__c = 10;
        insert billLine;
        
        // Billing List
        List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c> ();
        billings.add(bill);
        
        // Call the post billings service
        AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billings);
        
        // Start Test
        Test.startTest();
        
        // Call AyAutoPayWrapper
        AyAutoPayWrapper wrap = new AyAutoPayWrapper();
        wrap.savedPaymentMethods = 'ACH';
        wrap.existingPaymentMethod = 'ACH';
        
        // Call AySetupAutoPayCtrl @AuraEnabled Method
        AySetupAutoPayCtrl.getExistingPaymentMethods(matter.Id);
        AySetupAutoPayCtrl.setupAutoPay(matter.Id, 'tokenStr');
        
        AyManageAutoPayCtrl.setupAutoPay(matter.Id, 'tokenStr');
        
        // Stop Test
        Test.stopTest();
    }
    
    
    private static testMethod Void testPortalTransactionProcess(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // Setup Matter TestData
        AcctSeed__Project__c pro = new AcctSeed__Project__c();
        pro.Name = 'Test Matter Name';
        pro.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        pro.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        pro.AcctSeed__Status__c = 'Active';
        pro.Auto_Pay__c = true;
        pro.Auto_Debit_Method_Token__c = '{"id":"pmtd_**********","type":"card"}';
        insert pro;
        
        
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        
        User admin = [SELECT Id, Username FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        
        User user_1;
        
        System.runAs(admin) {
            
            user_1 = new User( 
                Email = 'community.email@fakemail.com',
                ProfileId = communityProfile.Id, 
                Emailencodingkey = 'UTF-8',
                UserName = 'community.username@as.com', 
                Alias = 'CAdmin',
                TimeZoneSidKey = Userinfo.getTimeZone().getID(),
                LanguageLocaleKey = Userinfo.getLanguage(),
                Localesidkey = Userinfo.getLocale(),
                ContactId = AyTestDataSuite.contacts[0].Id,
                PortalRole = 'Manager',
                FirstName = 'Firstname',
                LastName = 'SysAdmin',
                IsActive = true         
            );
            insert user_1;
            // Setup AffiniPay Settings TestData
            affinipay__AffiniPay_Settings__c aff = new affinipay__AffiniPay_Settings__c();
            aff.affinipay__Public_Key__c = 'm_g3C7IrKOQ3SKMKckB1Ct-Q';
            aff.affinipay__Organization_ID__c = 'org_YAssAyLo0OQQ2ATKKqHBO';
            aff.Name = 'affinipay';
            insert aff;
            
            // Setup Matter TestData
            AcctSeed__Project__c matter = new AcctSeed__Project__c();
            matter.Name = 'Test Matter Name';
            matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
            matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
            matter.AcctSeed__Status__c = 'Active';
            matter.Auto_Pay__c = true;
            matter.Auto_Debit_Method_Token__c = '{"id":"pmtd_**********","type":"card"}';
            insert matter;
            
            // Setup affinipay Transaction TestData
            affinipay__Transaction__c trans = new affinipay__Transaction__c();
            trans.Matter__c = matter.Id;
            trans.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
            trans.affinipay__Link_Object_ID__c = AyTestDataSuite.accounts[0].Id;
            trans.Transaction_Type__c = 'Deposit to Trust';
            insert trans;
            
            // Setup Billing TestData
            AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
            bill.AcctSeed__Date__c = Date.today();
            bill.AcctSeed__Due_Date2__c = Date.today(); 
            bill.AcctSeed__Status__c = 'Approved';
            bill.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
            bill.AcctSeed__Customer__c = AyTestDataSuite.accounts[0].Id;
            bill.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
            bill.Matter__c = matter.Id;
            insert bill;
            
            // Setup Billing Line TestData
            AcctSeed__Billing_Line__c billLine = new AcctSeed__Billing_Line__c();
            billLine.AcctSeed__Billing__c = bill.Id;
            billLine.AcctSeed__Date__c = Date.today();
            billLine.AcctSeed__Rate__c = 100;
            billLine.AcctSeed__Hours_Units__c = 10;
            insert billLine;
            
            // Billing List
            List<AcctSeed__Billing__c> billings = new List <AcctSeed__Billing__c> ();
            billings.add(bill);
            
            // Call the post billings service
            AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billings);
            
        }
        
        // Start Test
        Test.startTest();
        
        System.runAs(user_1) {
            
            // Call AyAffiniPayTransactionCardCont @AuraEnabled Method
            AyAffiniPayTransactionCardCont.initAction(AyTestDataSuite.accounts[0].Id);
            AyAffiniPayTransactionCardCont.makePayment('Account', '001', ''+AyTestDataSuite.accounts[0].Id, 'test@test.com', '500', 'tokenJsonStr', 'relatedType', 'relatedId', 'relatedName', 'reference', 'Deposit to Trust', ''+pro.Id, false, 'test@gmail.com', '9988765678');
            AyAffiniPayTransactionCardCont.addMethodToObject('objectType', 'objectId', 'tokenJsonStr');
            
            // Call @AuraEnabled Class
            AyAffiniPayTransactionCardWrapper cont = new AyAffiniPayTransactionCardWrapper();
            String jsonStr = cont.jsonStr;
            String accountId = cont.accountId;
            
            // Call AyBatchHandleMatterAutoPay Class
            AyBatchHandleMatterAutoPay b = new AyBatchHandleMatterAutoPay();
            Database.executeBatch(b);
            
            // Call @AuraEnabled Method
            AyManageAutoPayCtrl.handleInit();
            
        }
        
        // Stop Test
        Test.stopTest();
        
    }
    
}