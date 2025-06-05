/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 04-26-2022
 * @last modified by  : Brian Ezell (Slalom)
**/
@IsTest
private class OpportunityTriggerHandlerTest {

    @IsTest
    private static void testCreateDefaultRoles() {

        Test.startTest();

        Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                LIMIT 1
            ];

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId
        );
        insert act;

        System.debug('After insert act');

        Opportunity opp = new Opportunity (
            Name = 'Opp 001',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Call',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id
        );
        insert opp;

        Test.stopTest();

        List<Default_Role__c> roles = [SELECT Id FROM Default_Role__c];

        System.assertNotEquals(0, roles.size(), 'There shouold be roles on this opportunity now.');
    }

    //NOTE!!! THERE ARE CONFLICTS WITH THE PROCESS BUILDER "PROJECT PROCESS".  
    //THIS WILL NEED TO BE DISABLED BEFORE RUNNING THSI UNIT TEST

    @IsTest
    private static void testCreateProjectOnClosedWonOpportunityHourly() {
        Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                LIMIT 1
            ];

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId
        );
        insert act;

        System.debug('After insert act');

        Opportunity opp = new Opportunity (
            Name = 'Opp 001',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Hourly',
            Case_Commencement_Call__c = 'Yes- Call',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id
        );
        insert opp;

        opp.StageName = 'Closed Won';
        update opp;

        List<AcctSeed__Project__c> projects = [SELECT Id FROM AcctSeed__Project__c];

        System.assertNotEquals(0, projects.size(), 'A project should be created.');

    }

    @IsTest
    private static void testCreateProjectOnClosedWonOpportunityNextStep() {

        //Flat fee projecst are queued so we need to set the context for the queue to run.
        Test.startTest();

        Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                LIMIT 1
            ];

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId
        );
        insert act;

        System.debug('After insert act');

        Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();

        Opportunity opp = new Opportunity (
            RecordTypeId = nextStepRecordTypeId,
            Name = 'Opp 001',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Call',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id
        );
        insert opp;

        opp.StageName = 'Closed Won';
        update opp;

        Test.stopTest();
    }

    @IsTest
    private static void testCreateCommunityUser() {

        //Flat fee projecst are queued so we need to set the context for the queue to run.
        Test.startTest();

        Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                LIMIT 1
            ];

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId,
            PersonEmail = '123@nowhere.com'
        );
        insert act;

        System.debug('After insert act');

        Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();

        Opportunity opp = new Opportunity (
            RecordTypeId = nextStepRecordTypeId,
            Name = 'Opp 001',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Call',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id,
            Term_Options__c = 'C'
        );
        insert opp;

        opp.StageName = 'Proposal Made';
        update opp;

        Test.stopTest();
    }

    @IsTest
    private static void testCreateProductForApproval() {

        //Flat fee projecst are queued so we need to set the context for the queue to run.
        Test.startTest();

        Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                    AND UserName != NULL
                    AND Email != NULL
                LIMIT 1
            ];

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId,
            PersonEmail = '123@nowhere.com'
        );
        insert act;

        System.debug('After insert act');

        Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();

        Opportunity opp = new Opportunity (
            RecordTypeId = nextStepRecordTypeId,
            Name = 'Opp 001',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Call',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id,
            Term_Options__c = 'C'
        );
        insert opp;

        AyTestDataSuite.init();

        AcctSeed__Project__c newProject = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        insert newProject;

        opp.Next_Step_Matter__c = newProject.Id;
        update opp;

        Product2 prod = new Product2 (
            IsActive = true,
            ProductCode = 'Prod1',
            Name = 'Prod1'
        );
        insert prod;

        System.debug('After insert prod');

        Id pricebookId = Test.getStandardPricebookId();

        PricebookEntry standardPrice = new PricebookEntry (
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert standardPrice;
        
        System.debug('After insert standardPrice');

        OpportunityLineItem orderLine1 = new OpportunityLineItem (
            OpportunityId = opp.Id,
            UnitPrice = 1,
            Quantity = 1,
            PricebookEntryId = standardPrice.Id
        );
        insert orderLine1;


        opp.StageName = 'Closed Won';
        update opp;

        OpportunityTriggerHandler.createProductsToApprove(opp.Id, u.Id);
        
        Test.stopTest();
    }

}