/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-25-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-22-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class TaskTriggerHandlerTest {
	
    @testSetup
    private static void setup(){

        //TaskTrackerTestDataFactory.createPrepopulatedOpportunityAndTemplate();

        System.debug('***setup -- Started Creating Test Data***');

        //TaskTrackerTestDataFactory.createAllTestData();

        System.debug('***setup -- Finished Creating Test Data***');

        //createCasesFromTemplate();

        System.debug('***setup -- Finished Function***');
        
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
            Case_Commencement_Call__c = 'No',
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

        System.debug('After init()');

        AcctSeed__Project__c newProject = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        //insert newProject;

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

    
    @IsTest
    private static void testCheckTasksCantBeStartedNow() {


        test.startTest();

        List<Task> tasks =
            [
                SELECT Id, WhatId
                FROM Task
                WHERE What.Type = 'Case'
                LIMIT 2
            ];

        List<Task_Tracker_Task_Dependency__c> currentDependencies =
            [
                SELECT Id
                FROM Task_Tracker_Task_Dependency__c
            ];
        delete currentDependencies;

        Task_Tracker_Task_Dependency__c dep = new Task_Tracker_Task_Dependency__c (
            Case__c = tasks[0].WhatId,
            Task_Id__c = tasks[1].Id,
            Task_Depends_On_Id__c = tasks[0].Id
        );
        insert dep;

        System.debug('checkTasksCantBeStartedNow param = ' + tasks);

        TaskTriggerHandler.checkTasksCantBeStartedNow((new Map<Id, Task> ( tasks )).keySet());
        test.stopTest();

    }

    @IsTest
    private static void testCheckTasksCanBeStartedNow() {

        test.startTest();


        List<Task> tasks =
        [
            SELECT Id, WhatId
            FROM Task
            WHERE What.Type = 'Case'
            LIMIT 2
        ];

        List<Task_Tracker_Task_Dependency__c> currentDependencies =
            [
                SELECT Id
                FROM Task_Tracker_Task_Dependency__c
            ];
        delete currentDependencies;

        Task_Tracker_Task_Dependency__c dep = new Task_Tracker_Task_Dependency__c (
            Case__c = tasks[0].WhatId,
            Task_Id__c = tasks[1].Id,
            Task_Depends_On_Id__c = tasks[0].Id
        );
        insert dep;

        TaskTriggerHandler.checkTasksCanBeStartedNow((new Map<Id, Task> ( tasks )).keySet());
        
        test.stopTest();
    }

    @IsTest
    private static void testUpdateCasesFromTasks() {

        Test.startTest();
        

        List<Task> tasks = 
            [
                SELECT Id, ActivityDate, Status, Is_Task_Tracker_Created__c, IsClosed
                FROM Task 
            ];

        Map<Id, Task> oldTasks = new Map<Id, Task>();
        for(Task t : tasks) {
            oldTasks.put(t.Id, t);
        }

        tasks[0].Status = 'On Hold';
        tasks[0].ActivityDate = tasks[0].ActivityDate.addDays(3);
        update tasks;

        TaskTriggerHandler.updateCasesFromTasks(tasks, oldTasks);
        Test.stopTest();
    }

    @IsTest
    private static void testRefreshCounts() {

        Test.startTest();
        

        Map<Id, Case> cases = new Map<Id, Case>(
            [
                SELECT Id
                FROM Case
                LIMIT 2
            ]);

        List<Task> tasks = 
            [
                SELECT Id, ActivityDate, Status, Is_Task_Tracker_Created__c, IsClosed
                FROM Task 
            ];

        Map<Id, Task> oldTasks = new Map<Id, Task>();
        for(Task t : tasks) {
            oldTasks.put(t.Id, t);
        }

        tasks[0].Status = 'On Hold';
        tasks[0].ActivityDate = tasks[0].ActivityDate.addDays(3);
        update tasks;

        TaskTriggerHandler.refreshCounts(cases.keySet(), 0, new Set<String> {'On Hold', 'Terminated'});

        Test.stopTest();
    }

    @IsTest
    private static void testChangeDependentDueDates() {

        System.debug('***testChangeDependentDueDates -- Setup Started***');

        test.startTest();


        System.debug('***testChangeDependentDueDates -- Setup Completed***');

        Map<Id, Task> tasks = new Map<Id, Task>(
            [
                SELECT Id, WhatId
                FROM Task
                WHERE What.Type = 'Case'
                LIMIT 2
            ]);

        List<Task_Tracker_Task_Dependency__c> currentDependencies =
            [
                SELECT Id
                FROM Task_Tracker_Task_Dependency__c
            ];
        delete currentDependencies;

        System.debug('***testChangeDependentDueDates -- Dependencies Deleted***');

        Task_Tracker_Task_Dependency__c dep = new Task_Tracker_Task_Dependency__c (
            Case__c = tasks.values()[0].WhatId,
            Task_Id__c = tasks.values()[1].Id,
            Task_Depends_On_Id__c = tasks.values()[0].Id,
            Adjust_Due_Date__c = true
        );
        insert dep;

        System.debug('***testChangeDependentDueDates -- Dependencies Inserted***');

        System.debug('***testChangeDependentDueDates -- Testing Started***');

        TaskTriggerHandler.changeDependentDueDates(tasks.keySet());

        test.stopTest();
        System.debug('***testChangeDependentDueDates -- Testing Completed***');
    }

    @IsTest
    private static void testCallCreateProcess() {

        test.startTest();
        Task_Tracker_Template__c template =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Master_Template__c = true
                LIMIT 1
            ];

        CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
        input.TemplateId = template.Id;

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        input.ObjectName = 'Opportunity';
        input.ObjectId = opp.Id;

        CreateProcessFlowController.CreateProcess(new List<CreateProcessFlowController.ProcessInput> { input });
        
        test.stopTest();

    }

    @IsTest
    private static void testUpdateTaskStatuses() {

        Test.startTest();
        

        List<Task> tasks = 
            [
                SELECT Id, ActivityDate, Status, Is_Task_Tracker_Created__c, IsClosed
                FROM Task 
            ];

        Map<Id, Task> oldTasks = new Map<Id, Task>();
        for(Task t : tasks) {
            oldTasks.put(t.Id, t);
        }

        tasks[0].Status = 'On Hold';
        tasks[0].ActivityDate = tasks[0].ActivityDate.addDays(3);
        update tasks;

        TaskTriggerHandler.updateTaskStatuses(tasks, oldTasks);
        Test.stopTest();
    }

    @IsTest
    private static void testRefreshCaseCounts() {
        
        test.startTest();

        Case masterCase =
            [
                SELECT Id
                FROM Case
                WHERE Is_Task_Tracker_Case__c = true
                    AND ParentId = NULL
                LIMIT 1
            ];
        Set<Id> caseIds = new Set<Id>
            {
                masterCase.Id
            };
        TaskTriggerHandler.refreshCaseCounts(caseIds);
        
        test.stopTest();
    }

    @IsTest
    private static void testRefreshTaskCounts() {

        test.startTest();

        Case masterCase =
            [
                SELECT Id
                FROM Case
                WHERE Is_Task_Tracker_Case__c = true
                    AND ParentId = NULL
                LIMIT 1
            ];
        Set<Id> caseIds = new Set<Id>
            {
                masterCase.Id
            };

        TaskTriggerHandler.updateCaseTaskCounts(caseIds, TaskTriggerHandler.lstClosedStatuses);
        
        test.stopTest();
    }

    @IsTest
    private static void testChangeTaskStatusWhenCaseIsOnHold() {
        test.startTest();
        

        Case masterCase =
            [
                SELECT Id
                FROM Case
                WHERE Is_Task_Tracker_Case__c = true
                    AND ParentId = NULL
                LIMIT 1
            ];
        masterCase.Status = 'On Hold';
        update masterCase;

        Task t = [SELECT Id FROM Task LIMIT 1];
        t.Status = 'On Hold';
        t.ActivityDate = Date.today().addDays(5);
        update t;
        test.stopTest();
    }

    @IsTest
    private static void testIsTaskRecordChanged() {
        Task t = new Task (
            Status = 'New',
            ActivityDate = Date.today()
        );

        Task t2 = new Task (
            Status = 'New',
            ActivityDate = Date.today().addDays(5)
        );

        System.assert(TaskTriggerHandler.isTaskRecordChanged(t, t2, new List<String> { 'Status' }), 'The record should have changed.');
    }

    @IsTest
    private static void testAdjustedDependencyDate() {

        Test.startTest();

        Task_Tracker_Template__c temp = 
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                LIMIT 1
            ];

        Task_Tracker_Step_Dependency__c dependsStep = 
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c 
                LIMIT 1
            ];
        dependsStep.Adjust_Due_Date__c = true;
        update dependsStep;

        test.stopTest();

        /*Task t = 
            [
                SELECT Id, ActivityDate 
                FROM Task 
                WHERE Task_Tracker_Template_Step__c = :dependsStep.Step__c
                LIMIT 1
            ];
        t.ActivityDate = t.ActivityDate.addDays(3);
        update t;*/

    }

    private static void createCasesFromTemplate() {

        Task_Tracker_Template__c template =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Master_Template__c = true
                LIMIT 1
            ];

        CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
        input.TemplateId = template.Id;

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        input.ObjectName = 'Opportunity';
        input.ObjectId = opp.Id;

        CreateProcessFlowController process = new CreateProcessFlowController(input);
        System.enqueueJob(process);
    }
}