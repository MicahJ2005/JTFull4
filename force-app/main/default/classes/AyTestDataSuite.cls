/************************************************
@author       :  Shubham@Ayodia
@date         :  27oct,2020
@description  :  This class is Create Test Data.
*************************************************/
public class AyTestDataSuite {
    
    // Variable Declaration
    public static list<User> sysAdminUser {get;set;}
    public static list<Account> accounts {get;set;}
    public static list<Contact> contacts {get;set;}
    public static list<Opportunity> Opportunities {get;set;}
    public static list<Default_Role__c> roles {get;set;}
    public static list<AcctSeed__GL_Account__c> glAccounts {get;set;}
    public static list<AcctSeed__Accounting_Period__c> acctPeriods {get;set;}
    public static list<AcctSeed__Accounting_Variable__c> acctVariables {get;set;}
    public static list<AcctSeed__Accounting_Variable__c> acctVariables4 {get;set;}
    public static list<AcctSeed__Billing_Format__c> billingFormats {get;set;}
    public static AcctSeed__Ledger__c ledger {get;set;}
    public static AcctSeed__Accounting_Settings__c acctSetting {get;set;}
    public static list<Accounting_Config__c> accountingConfigList {get;set;}
    
    
    public static void init(){
        createAccounts();
        createContacts();
        createOpportunities();
        createDefaultRole();
        createGLAccount();
        createAccoutingPeriods();
        createAccoutingVariables();
        createAccoutingVariables4();
        createBillingFormats();
        createLedger();
        createAccountingSetting();
        createAccountingConfigMapping();
        createSysAdminUser();
        
    }
    
    public static list<User> createSysAdminUser() {
        
        sysAdminUser = new list<User>();
        
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User usr = new User();
        usr.alias = 'sysAdmin';
        usr.email = 'sysAdmin.email@fakemail.com';
        usr.emailencodingkey = 'UTF-8';
        usr.lastname = 'SysAdmin';
        usr.languagelocalekey = Userinfo.getLanguage();
        usr.localesidkey = Userinfo.getLocale();
        usr.profileid = sysAdminProfile.Id;
        usr.timezonesidkey = Userinfo.getTimeZone().getID();
        usr.username = 'acctSeed.sysAdmin.username@as.com.jtltest';
        sysAdminUser.add(usr);

        insert sysAdminUser;
        return sysAdminUser;
    }
    
    // Get Record Type for Sobject
    public static map<String,Id> getRecordTypes(String objectName){
        map<String,Id> recordTypeMap = new map<String,Id>();
        for(RecordType rt:[select Id, DeveloperName from RecordType where SObjectType =:objectName]){
            recordTypeMap.put(rt.DeveloperName, rt.Id);
        }
        return recordTypeMap;
    }
    
    
    public static list<Account> createAccounts(){
        accounts = new list<Account>();
        
        // Get Account Record Type Map
        map<string, Id> accountRTMap = getRecordTypes('Account');
        
        // Setup Business Account Test Data
        Account acc_Insured = new Account();
        acc_Insured.Name = 'Test Business Account';
        acc_Insured.RecordTypeId = accountRTMap.get('Business_Account');
        accounts.add(acc_Insured);
                
        insert accounts;
        return accounts;
    }
    
    public static list<Contact> createContacts(){
        contacts = new list<Contact>();
        
        // Setup Contact Test Data
        Contact con = new Contact();
        con.AccountId = accounts[0].Id;
        con.LastName = 'Test Contact LastName';
        contacts.add(con);
        
        insert contacts;
        return contacts;
    }
    
    public static list<Opportunity> createOpportunities(){
        
        // Setup Opportunity Test Data
        Opportunities = new list<Opportunity>();
        
        // 0 (Setup Opportunity Test Data for Create Billing TRUE)
        Opportunities.add(
            new Opportunity(
                Name = 'Test Opportunity Name',
                AccountId = accounts[0].Id,
                StageName = 'Closed Won',
                Conflict_Check_Status__c = 'Pass',
                CloseDate = Date.today().addDays(15),
                Notes_for_Legal_Team_Consult_Notes__c = 'Testing Purpose Only..!',
                Payment_Status__c = 'Paid in Full',
                Kapsten_Matter__c = 'Yes',
                Area_of_Law__c = 'Family Law',
                Opposing_Party_s_Full_Name__c = 'Test Opposing',
                Minor_Children_Y_N__c = 'Yes',
                Type_of_Case__c = 'Divorce', 
                Type_of_Questionnaire__c = 'Client Questionnaire'
            )
        );
        
        insert Opportunities;
        return Opportunities;
        
    }
    
    public static list<Default_Role__c> createDefaultRole(){
        
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Setup Default Role TestData
        roles = new list<Default_Role__c>();
        
        // 0 (Setup Default Role TestData)
        roles.add(
            new Default_Role__c(
                Name = 'CES',
                Opportunity__c = Opportunities[0].Id,
                Assigned_User__c = u.Id,
                Assigned_Queue__c = 'CES',
                Role__c = 'CES'
            )
        );
        
        insert roles;
        return roles;
        
    }
    
    public static list<AcctSeed__GL_Account__c> createGLAccount(){
        
        // Setup GL Accounts
        glAccounts = new List<AcctSeed__GL_Account__c>();
        
        // 0
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '1000-Cash',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Bank__c = true,
                AcctSeed__Sub_Type_1__c = 'Assets',
                AcctSeed__Sub_Type_2__c = 'Cash'                                 
            )
        );
        
        // 1
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '1205-Unapplied A/R',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Assets',
                AcctSeed__Sub_Type_2__c = 'Cash'
            )
        );
        
        // 2
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '1200-Accounts Receivable',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Assets',
                AcctSeed__Sub_Type_2__c = 'Current Assets'
            )
        );
        
        // 3
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '1600-Work In Process',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Assets',
                AcctSeed__Sub_Type_2__c = 'Current Assets'
            )
        );
        
        // 4
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '2000-Accounts Payable',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Liabilities',
                AcctSeed__Sub_Type_2__c = 'Current Liabilities'
            )
        );
        
        // 5
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '2010-Vouchers Payable',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Liabilities',
                AcctSeed__Sub_Type_2__c = 'Current Liabilities'
            )
        );
        
        // 6
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '2020-Accrued Expenses',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Liabilities',
                AcctSeed__Sub_Type_2__c = 'Current Liabilities'
            )
        );
        
        
        // 7
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '3000-Owners Equity',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Owners Equity',
                AcctSeed__Sub_Type_2__c = 'Equity'
            )
        );
        
        // 8
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '3050-Retained Earnings',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Owners Equity',
                AcctSeed__Sub_Type_2__c = 'Equity'
            )
        );
        
        // 9
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '3060-Current Year Earnings',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Balance Sheet',
                AcctSeed__Sub_Type_1__c = 'Owners Equity',
                AcctSeed__Sub_Type_2__c = 'Equity'
            )
        );
        
        // 10
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '4000-Product Revenue',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Revenue',
                AcctSeed__Sub_Type_1__c = 'Product Revenue',
                AcctSeed__Sub_Type_2__c = 'Product Family 1'
            )
        );
        
        // 11
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '4010-Services Revenue',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Revenue',
                AcctSeed__Sub_Type_1__c = 'Service Revenue',
                AcctSeed__Sub_Type_2__c = 'Service Family 1'
            )
        );
        
        // 12
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '5000-Cost of Goods Sold',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Expense',
                AcctSeed__Sub_Type_1__c = 'Cost of Goods Sold',
                AcctSeed__Sub_Type_2__c = 'Materials'
            )
        );
        
        // 13
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '5010-Inventory Cost Variance',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Expense',
                AcctSeed__Sub_Type_1__c = 'Cost of Goods Sold',
                AcctSeed__Sub_Type_2__c = 'Materials'
            )
        );
        
        // 14
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '5040-Vendor Payment Discounts',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Expense',
                AcctSeed__Sub_Type_1__c = 'Cost of Goods Sold',
                AcctSeed__Sub_Type_2__c = 'Materials'
            )
        );
        
        // 15
        glAccounts.add(
            new AcctSeed__GL_Account__c(
                Name = '5050-Labor',
                AcctSeed__Active__c = true,
                AcctSeed__Type__c = 'Expense',
                AcctSeed__Sub_Type_1__c = 'Cost of Goods Sold',
                AcctSeed__Sub_Type_2__c = 'Salaries & Wages'
            )
        );
        
        insert glAccounts;
        return glAccounts;
    }
    
    public static list<AcctSeed__Accounting_Period__c> createAccoutingPeriods(){
        
        // Setup Accouting Periods
        acctPeriods = new List<AcctSeed__Accounting_Period__c>();
        
        for(Integer i = 1 ; i <= 12 ; i++){
            
            Date currentDate = date.today();
            Integer currentYear = currentDate.year();
            Integer daysInMonth_temp = date.daysInMonth(currentYear, i);
            Date firstDate = date.newInstance(currentYear, i, 1);
            Date lastDate = date.newInstance(currentYear, i, daysInMonth_temp);
            
            AcctSeed__Accounting_Period__c aPeriod = new AcctSeed__Accounting_Period__c();
            if(i < 10 ){
                aPeriod.Name = currentYear + '-0' + i;
                
            }else{
                aPeriod.Name = currentYear + '-' + i;
            }
            
            aPeriod.AcctSeed__Start_Date__c = firstDate;
            aPeriod.AcctSeed__End_Date__c = lastDate;
            aPeriod.AcctSeed__Status__c = 'Open';
            acctPeriods.add(aPeriod);
        }
        
        
        insert acctPeriods;
        return acctPeriods;
    }
    
    public static list<AcctSeed__Accounting_Variable__c> createAccoutingVariables(){
        
        acctVariables = new list<AcctSeed__Accounting_Variable__c>();
        
        // Setup Accounting Variable
        AcctSeed__Accounting_Variable__c aVar1 = new AcctSeed__Accounting_Variable__c(
            Name = 'Sales',
            AcctSeed__Active__c = true,
            AcctSeed__Type__c = 'GL Account Variable 1'
        );
        acctVariables.add(aVar1);
        
        insert acctVariables;
        return acctVariables;
        
    }
    
    public static list<AcctSeed__Accounting_Variable__c> createAccoutingVariables4(){
        
        acctVariables4 = new list<AcctSeed__Accounting_Variable__c>();
        
        // Setup Accounting Variable
        AcctSeed__Accounting_Variable__c aVar4 = new AcctSeed__Accounting_Variable__c(
            Name = 'Sales',
            AcctSeed__Active__c = true,
            AcctSeed__Type__c = 'GL Account Variable 4'
        );
        acctVariables4.add(aVar4);
        
        insert acctVariables4;
        return acctVariables4;
        
    }
    
    public static list<AcctSeed__Billing_Format__c> createBillingFormats(){
        
        // Setup Billing Format Test Data
        billingFormats = new list<AcctSeed__Billing_Format__c>();
        
        string defaultEmailTemplate = [Select Id, DeveloperName From EmailTemplate Limit 1].DeveloperName;
        
        AcctSeed__Billing_Format__c billFormat = new AcctSeed__Billing_Format__c(
            Name = 'Default Billing Product',
            AcctSeed__Visualforce_PDF_Page__c = 'BillingProductPDF',
            AcctSeed__Default_Email_Template__c = defaultEmailTemplate,
            AcctSeed__Type__c = 'Billing',
            AcctSeed__Sort_Field__c = 'Name'
        );
        billingFormats.add(billFormat);
        
        insert billingFormats;
        return billingFormats;
    }
    
    
    public static AcctSeed__Ledger__c createLedger(){
        
        // Setup Ledger Test Data
        ledger = new AcctSeed__Ledger__c(
            Name = 'Actual',
            AcctSeed__Type__c = 'Transactional',
            AcctSeed__Default_Bank_Account__c = glAccounts[0].Id,
            AcctSeed__Default_Billing_Format__c = billingFormats[0].Id,
            AcctSeed__Billing_Outstanding_Statement_Format__c = billingFormats[0].Id,
            AcctSeed__Billing_Activity_Statement_Format__c = billingFormats[0].Id,
            AcctSeed__Default_Purchase_Order_Format__c = billingFormats[0].Id,
            AcctSeed__Default_Packing_Slip_Format__c = billingFormats[0].Id
        );
        
        insert ledger;
        return ledger;
    }
    
    public static AcctSeed__Accounting_Settings__c createAccountingSetting(){
        
        // Setup Accounting Setting Test Data
        acctSetting = new AcctSeed__Accounting_Settings__c(
            AcctSeed__AR_Control_GL_Account__c = glAccounts[2].Id,
            AcctSeed__AP_Control_GL_Account__c = glAccounts[4].Id,
            AcctSeed__Labor_GL_Account__c = glAccounts[15].Id,
            AcctSeed__Payment_Discount_GL_Account__c = glAccounts[7].Id,
            AcctSeed__Unapplied_Cash_GL_Account__c = glAccounts[1].Id,
            AcctSeed__Retained_Earnings_GL_Account__c = glAccounts[8].Id,
            AcctSeed__Default_Ledger__c = ledger.Id,
            AcctSeed__Legacy_Default_Ledger__c = ledger.Id,
            AcctSeed__Revenue_GL_Account__c = glAccounts[10].Id,
            AcctSeed__Default_Project_Task_Labor_GL_Account__c = glAccounts[14].Id,
            AcctSeed__Current_Year_Earnings_GL_Account__c = glAccounts[9].Id,
            AcctSeed__Enable_Product_Costing__c = true,
            AcctSeed__Work_in_Process_GL_Account__c = glAccounts[3].Id,
            AcctSeed__Vouchers_Payable_GL_Account__c = glAccounts[5].Id,
            AcctSeed__Inventory_Variance_GL_Account__c =  glAccounts[13].Id,
            AcctSeed__Customer_Payment_Adjustment_GL_Account__c = glAccounts[12].Id,
            AcctSeed__Display_Billable_Flag_in_Time_Card_Entry__c = true,
            AcctSeed__Enable_Billing_Period_Sensitive_Aging__c = true,
            AcctSeed__Enable_AP_Period_Sensitive_Aging__c = true,
            AcctSeed__Prepaid_Expense_GL_Account__c = glAccounts[11].Id,
            AcctSeed__Default_Bank_Account__c = glAccounts[0].Id
        );
        
        insert acctSetting;
        return acctSetting;
    }
    
    public static list<Accounting_Config__c> createAccountingConfigMapping(){
        
        // Setup Accounting Config Mapping
        accountingConfigList = new list<Accounting_Config__c>();
        
        accountingConfigList.add(
            new Accounting_Config__c(
                Name = 'JTL Trust Account ID',
                Key__c = 'JTL_Trust_Account_ID ',
                Value__c = '0015w00002MjSoqAAF',
                Description__c = 'SF Account ID of JTL/Kapsten trust account' 
            )
        );
       /* 
        accountingConfigList.add(
            new Accounting_Config__c(
                Name = 'Revenue GL Account',
                Key__c = 'Revenue_GL_Account',
                Value__c = 'a0ZS0000009Y5C2MAK',
                Description__c = 'GL Account used for billing of Time' 
            )
        ); */
       
        accountingConfigList.add(
            new Accounting_Config__c(
                Name = 'JTL Revenue GL Id',
                Key__c = 'JTL_Revenue_GL_Id',
                Value__c = 'a0Z5w00000VcS47EAF',
                Description__c = 'Revenue GL Account Id for JTL sales'
            )
        );
        
        accountingConfigList.add(
            new Accounting_Config__c(
                Name = 'Kapsten Revenue GL Id',
                Key__c = 'Kapsten_Revenue_GL_Id',
                Value__c = 'a0Z5w00000VcS46EAF',
                Description__c = 'Revenue GL Account ID for Kapsten Sales' 
            )
        );
        
        insert accountingConfigList;
        return accountingConfigList;
    }
}