/**
 * @File Name          : TaskTrackerTestDataFactory.cls
 * @Description        : Creates test data for unit tests
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-25-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/28/2020   Revolution Group (Brian Ezell)     Initial Version
**/
@IsTest
public class TaskTrackerTestDataFactory {

    public static void createOneTemplate() {
        Task_Tracker_Template__c masterTemplate = createMasterTemplate();
        List<Task_Tracker_Template_Step__c> steps = createTemplateSteps(masterTemplate, 1);
    }

    public static void createAllTestData() {
        createAllTemplatesAndSteps();
        createOpportunityAndProduct();

        //Needed to add since Ay has Triggers that require this or they fail!
        AyTestDataSuite.init();

        Task_Tracker_Template__c masterTemplate = [SELECT Id FROM Task_Tracker_Template__c WHERE Parent_Template__c = null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        prod.Task_Tracker_Template__c = masterTemplate.Id;
        update prod;
    }

    private static void createAllTemplatesAndSteps() {
        Task_Tracker_Template__c mastertemplate = createMasterTemplate();
        List<Task_Tracker_Template__c> childTemplates = createChildTemplates(mastertemplate, 2);
        for(Task_Tracker_Template__c t : childTemplates) {
            List<Task_Tracker_Template_Step__c> steps = createTemplateSteps(t, 3);
            createTemplateStepDependencies(t, steps);
            createTemplateStepDates(t, steps);
        }
    }

    @TestVisible
    private static void createOpportunityAndProduct() {

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

        Opportunity opp = new Opportunity (
            Name = 'Opp 001',
            StageName = 'Consult Completed',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Zoom',
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
            Opposing_Party_s_Full_Name__c = 'Test Opposing',
            Minor_Children_Y_N__c = 'Yes',
            Type_of_Case__c = 'Divorce', 
            Type_of_Questionnaire__c = 'Client Questionnaire'
        );
        insert opp;

        Product2 prod = new Product2 (
            IsActive = true,
            ProductCode = 'Prod1',
            Name = 'Prod1'
        );
        insert prod;
        Id pricebookId = Test.getStandardPricebookId();

        PricebookEntry standardPrice = new PricebookEntry (
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert standardPrice;

        OpportunityLineItem orderLine = new OpportunityLineItem (
            OpportunityId = opp.Id,
            UnitPrice = 1,
            Quantity = 1,
            PricebookEntryId = standardPrice.Id
        );
        insert orderLine;
    }

    private static Task_Tracker_Template__c createMasterTemplate() {
        Task_Tracker_Template__c masterTemplate = new Task_Tracker_Template__c (
            Is_Active__c = true,
            Name = 'Master Test Template'
        );
        insert masterTemplate;
        return masterTemplate;

    }

    private static List<Task_Tracker_Template__c> createChildTemplates(Task_Tracker_Template__c masterTemplate, Integer numberOfTemplates) {
        List<Task_Tracker_Template__c> childTemplates = new List<Task_Tracker_Template__c>();

        for(Integer i = 0; i < numberOfTemplates; i++) {
        childTemplates.add(new Task_Tracker_Template__c (
            Is_Active__c = true,
            Name = 'Child Test Template ' + string.valueOf(i),
            Parent_Template__c = masterTemplate.Id,
            Role__c = 'Paralegal'
        ));
        }

        insert childTemplates;
        return childTemplates;
    }

    private static List<Task_Tracker_Template_Step__c> createTemplateSteps(Task_Tracker_Template__c template, Integer numberOfSteps) {
        List<Task_Tracker_Template_Step__c> steps = new List<Task_Tracker_Template_Step__c>();
        String taskType = 'On Boarding';
        for(Integer i = 0; i < numberOfSteps; i++) {
            steps.add(new Task_Tracker_Template_Step__c(
                Task_Tracker_Template__c = template.Id,
                Step_Order__c = i,
                Duration_In_Days__c = i,
                Activity_Type__c = Math.Mod(i, 2) == 0 ? 'Task' : 'Event'
            ));
        }

        insert steps;
        return steps;
    }

    @TestVisible
    private static List<Task_Tracker_Step_Dependency__c> createTemplateStepDependencies(Task_Tracker_Template__c template, List<Task_Tracker_Template_Step__c> steps) {

        List<Task_Tracker_Step_Dependency__c> depends = new List<Task_Tracker_Step_Dependency__c>();
        for(Integer i = 0; i < steps.size() - 1; i++) {
            Task_Tracker_Template_Step__c step = steps[i];
            Task_Tracker_Template_Step__c dependsOnStep = steps[i+1];
            depends.add(new Task_Tracker_Step_Dependency__c (
                Step__c = step.Id,
                Depends_On_Step__c = dependsOnStep.Id,
                Task_Tracker_Template__c = template.Id
            ));
        }
        insert depends;
        return depends;
    }

    private static List<Task_Tracker_Template_Step_Date__c> createTemplateStepDates(Task_Tracker_Template__c template, List<Task_Tracker_Template_Step__c> steps) {

        List<Task_Tracker_Template_Step_Date__c> templateDates = new List<Task_Tracker_Template_Step_Date__c>();
        String picklistValue = 'Calendar Days';
        for(Integer i = 0; i < steps.size() - 1; i++) {
            Task_Tracker_Template_Step__c step = steps[i];
            Task_Tracker_Template_Step__c dependsOnStep = steps[i+1];

            templateDates.add(new Task_Tracker_Template_Step_Date__c (
                Triggering_Step__c = step.Id,
                Adjusted_Step__c = dependsOnStep.Id,
                Task_Tracker_Template__c = template.Id,
                Date_Offset__c = 5,
                Date_Calculation__c = picklistValue
            ));
            picklistValue = picklistValue == 'Calendar Days' ? 'Business Days' : 'Calendar Days';
        }

        insert templateDates;
        return templateDates;
    }


    public static void createPrepopulatedOpportunityAndTemplate() {

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
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Zoom',
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
            Opposing_Party_s_Full_Name__c = 'Test Opposing',
            Minor_Children_Y_N__c = 'Yes',
            Type_of_Case__c = 'Divorce', 
            Type_of_Questionnaire__c = 'Client Questionnaire'
        );
        insert opp;

        System.debug('After insert opp');

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

        System.debug('After insert orderLine1');

        Task_Tracker_Template__c masterTemplate = new Task_Tracker_Template__c (
            Is_Active__c = true,
            Name = 'Master Test Template'
        );
        insert masterTemplate;

        System.debug('After insert masterTemplate');

        masterTemplate.Top_Level_Task_Template__c = masterTemplate.Id;
        prod.Task_Tracker_Template__c = masterTemplate.Id;
        update prod;

        System.debug('After update prod');

        Task_Tracker_Template__c owningTemplate = new Task_Tracker_Template__c (
            Name = 'Ownning Template',
            Parent_Template__c = masterTemplate.Id,
            Top_Level_Task_Template__c = masterTemplate.Id,
            Is_Active__c = true
        );
        insert owningTemplate;

        System.debug('After insert owningTemplate');

        Task_Tracker_Template__c dependentTemplate = new Task_Tracker_Template__c (
            Name = 'Dependent Template',
            Parent_Template__c = masterTemplate.Id,
            Top_Level_Task_Template__c = masterTemplate.Id,
            Is_Active__c = true
        );
        insert dependentTemplate;

        System.debug('After insert dependentTemplate');

        Task_Tracker_Template_Step__c owningTemplateStep = new Task_Tracker_Template_Step__c (
            Name = 'Owning Step',
            Activity_Type__c = 'Task',
            Days_Out_Type__c = 'Calendar',
            Duration_In_Days__c = 10,
            Task_Tracker_Template__c = owningTemplate.Id
        );
        insert owningTemplateStep;

        System.debug('After insert owningTemplateStep');

        Task_Tracker_Template_Step__c dependentTemplateStep = new Task_Tracker_Template_Step__c (
            Name = 'Dependent Step',
            Activity_Type__c = 'Task',
            Days_Out_Type__c = 'Calendar',
            Duration_In_Days__c = 3,
            Task_Tracker_Template__c = dependentTemplate.Id
        );
        insert dependentTemplateStep;

        System.debug('After insert dependentTemplateStep');

        Task_Tracker_Step_Dependency__c newDependency = new Task_Tracker_Step_Dependency__c (
            Adjust_Due_Date__c = true,
            Depends_On_Step__c = owningTemplateStep.Id,
            Step__c = dependentTemplateStep.Id,
            Task_Tracker_Template__c = owningTemplate.Id
        );
        insert newDependency;

        AyTestDataSuite.init();

        System.debug('After init()');

        AcctSeed__Project__c newProject = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        insert newProject;

        System.debug('After insert newProject');

        Case newCase = new Case (
            Task_Tracker_Template__c = masterTemplate.Id,
            Opportunity__c = opp.Id,
            Tasks_To_Complete__c = 1,
            Tasks_Completed__c = 0,
            Subject = 'Test Template Case',
            Top_Level_Task_Tracker_Case__c = masterTemplate.Id,
            Order__c = 1,
            Project__c = newProject.Id,
            Opportunity_Product__c = orderLine1.Id
        );

        insert newCase;

        System.debug('After insert newCase');

        Task t1 = new Task (
            ActivityDate = Date.today(),
            WhatId = newCase.Id,
            Is_Task_Tracker_Created__c = true,
            Subject = 'Task 1',
            Task_Tracker_Template_Step__c = owningTemplateStep.Id,
            Dependent_Tasks_To_Complete__c = 0,
            Status = 'Not Started',
            Top_Level_Case_Id__c = newCase.Id,
            Order__c = 1,
            Description = 'Desc 1',
            Hours__c = 1,
            IsVisibleInSelfService = true,
            Instructions__c = 'Desc 1',
            Anticipated_Completion_Days__c = 3,
            Matter__c = newProject.Id,
            Billing_Rate__c = 55
        );
        insert t1;

        System.debug('After insert t1');

        Task t2 = new Task (
            ActivityDate = Date.today(),
            WhatId = newCase.Id,
            Is_Task_Tracker_Created__c = true,
            Subject = 'Task 2',
            Task_Tracker_Template_Step__c = dependentTemplateStep.Id,
            Dependent_Tasks_To_Complete__c = 1,
            Status = 'Waiting On Other Tasks',
            Top_Level_Case_Id__c = newCase.Id,
            Order__c = 2,
            Description = 'Desc 1',
            Hours__c = 1,
            IsVisibleInSelfService = true,
            Instructions__c = 'Desc 2',
            Anticipated_Completion_Days__c = 2,
            Matter__c = newProject.Id,
            Billing_Rate__c = 55
        );
        insert t2;

        System.debug('After insert t2');

        Task_Tracker_Task_Dependency__c depends = new Task_Tracker_Task_Dependency__c (
            Adjust_Due_Date__c = true,
            Case__c = newCase.Id,
            Task_Depends_On_Id__c = t2.Id,
            Task_Id__c = t1.Id
        );
        insert depends;

        System.debug('After insert depends');

    }

}