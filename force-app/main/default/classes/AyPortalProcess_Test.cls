/**********************************************
@author       :  Shubham@Ayodia
@date         :  28Oct,2021
@description  :  TestClass for Potal Processes
***********************************************/
@isTest
private class AyPortalProcess_Test {
    
    private static testMethod Void testPortalProcess(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
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
            
            // Update Opportunity
            AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
            AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
            AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = user_1.Id;
            AyTestDataSuite.opportunities[0].Originator_LU__c = user_1.Id;
            AyTestDataSuite.opportunities[0].Rate_Type__c = 'Flat Fee';
            update AyTestDataSuite.opportunities[0];
            
            //Update GL Account
            AyTestDataSuite.glAccounts[0].Is_Trust_Account__c = true;
            update AyTestDataSuite.glAccounts[0];
            
            System.debug('glAccounts='+AyTestDataSuite.glAccounts[0].Is_Trust_Account__c);
          
            
            // Setup Matter TestData
            AcctSeed__Project__c matter = new AcctSeed__Project__c();
            matter.Name = 'Test Matter Name';
            matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
            matter.AcctSeed__Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
            matter.AcctSeed__Status__c = 'Active';
            insert matter;
            
            // Setup Billing TestData
            AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
            bill.AcctSeed__Date__c = Date.today();
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
            
            // Setup Cash receipt TestData
            AcctSeed__Cash_Receipt__c cr = new AcctSeed__Cash_Receipt__c();
            cr.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
            cr.AcctSeed__Bank_Account__c = AyTestDataSuite.glAccounts[0].Id;
            cr.AcctSeed__Amount__c = 100;
            cr.AcctSeed__Payment_Reference__c = 'Cash';
            cr.AcctSeed__Status__c = 'Draft';
            cr.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
            insert cr;
            
            System.debug('receipts='+cr.AcctSeed__Bank_Account__r.Is_Trust_Account__c);
            
            // CashReceipt List
            list<AcctSeed__Cash_Receipt__c> receipts = new list<AcctSeed__Cash_Receipt__c>();
            receipts.add(cr);
            
            // Post the CashReceipts Service
            AcctSeed.PostResult[] postResultsCR = AcctSeed.CashReceiptPostService.postCashReceipts(receipts);
            
            // Setup Cash Disbursement Batch TestData
            AcctSeed__Cash_Disbursement_Batch__c cdBatch = new AcctSeed__Cash_Disbursement_Batch__c();
            cdBatch.AcctSeed__Starting_Check_Number__c = 2;
            cdBatch.Name = 'Test Batch';
            insert cdBatch;
            
            // Setup Cash Disbursement TestData
            AcctSeed__Cash_Disbursement__c cd = new AcctSeed__Cash_Disbursement__c();
            cd.AcctSeed__Cash_Disbursement_Batch__c = cdBatch.Id;
            cd.AcctSeed__Disbursement_Date__c = AyTestDataSuite.acctPeriods[0].AcctSeed__Start_Date__c;
            cd.AcctSeed__Type__c = 'Check';
            cd.AcctSeed__Amount__c = 10;
            cd.AcctSeed__Source__c = 'Account Payable';
            cd.AcctSeed__Bank_Account__c = AyTestDataSuite.glAccounts[0].Id;
            cd.AcctSeed__Vendor__c = AyTestDataSuite.accounts[0].Id;
            cd.AcctSeed__Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
            cd.AcctSeed__Status__c = 'In Process';
            cd.AcctSeed__Reference__c = 'the reference 0';
            insert cd;
            
            System.debug('cashDisbursements='+cd.AcctSeed__Bank_Account__r.Is_Trust_Account__c);
            
            // CashReceipt List
            list<AcctSeed__Cash_Disbursement__c> cashDisbursements = new list<AcctSeed__Cash_Disbursement__c>();
            cashDisbursements.add(cd);
            
            // Post the CashReceipts Service
            AcctSeed.PostResult[] postResults = AcctSeed.CashDisbursementPostService.postCashDisbursements(cashDisbursements);
			
            // Setup Trust Balance TestData
            Trust_Balance__c tb = new Trust_Balance__c ();
            tb.Matter__c  = matter.Id;
            tb.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
            tb.Status__c  = 'Closed';
            insert tb;
            
            // Setup Trust Balance TestData 2
            Trust_Balance__c tBal = new Trust_Balance__c();
            tBal.Matter__c = matter.Id;
            tBal.Status__c = 'Open';
            tBal.Prior_Month_Trust_Balance__c = tb.Id;
            tBal.Accounting_Period__c = AyTestDataSuite.acctPeriods[0].Id;
            insert tBal;
            
            // Setup Billing Cash Receipts TestData
            AcctSeed__Billing_Cash_Receipt__c bcr = new AcctSeed__Billing_Cash_Receipt__c();
            bcr.AcctSeed__Billing__c = bill.Id;
            bcr.AcctSeed__Cash_Receipt__c = cr.Id;
            bcr.AcctSeed__Applied_Amount__c = 100;
            insert bcr;
            
            // Setup Trust Account Activity TestData
            Trust_Account_Activity__c tActivity = new Trust_Account_Activity__c();
            tActivity.Trust_Balance__c = tBal.Id;
            //tActivity.Billing__c = bill.Id;
            //tActivity.Billing_Line__c = billLine.Id;
            tActivity.Cash_Receipt__c = cr.Id;
            tActivity.Billing_Cash_Receipt__c = bcr.Id;
            tActivity.Cash_Disbursement__c = cd.Id;
            insert tActivity;
            
        }
        
        // Start Test
        Test.startTest();
        
        System.runAs(user_1) {
            
            // Call @AuraEnabled Method
            AyPortalBillingController.fetchBills();
            AyPortalTrustAccountStatementController.fetchTrustBalance();
            AyPortalNonTrustPaymentsController.fetchPayments();
            
            /*
            Date : 12 Nov, 2021 
			This try block is used because an (Error - affinipay.MissingConfigurationException: Script-thrown exception) occured while running Test Class 
			*/
            
            try{
                AyPortalPaymentsController.checkExistingPaymentMethods(AyTestDataSuite.accounts[0].Id);
            }catch(Exception e){
                
            }
            
        }
        
        // Stop Test
        Test.stopTest();
        
    }
    
}