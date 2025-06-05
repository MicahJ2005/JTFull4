/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 04-20-2022
 * @last modified by  : Brian Ezell (Slalom)
**/
@IsTest
private class ProjectOverviewControllerTest {

    private static void setup(){
        //AyTestDataSuite.init();
        //TaskTrackerTestDataFactory.createAllTestData();
        TaskTrackerTestDataFactory.createOpportunityAndProduct();
    }
    
    @IsTest
    private static void testProjectCasesAndTasks() {
     
        Task_Tracker_Template__c masterTemplate = new Task_Tracker_Template__c (
            Name = 'Master Template'
        );
        insert masterTemplate;

        Task_Tracker_Template__c owningTemplate = new Task_Tracker_Template__c (
            Name = 'Ownning Template',
            Parent_Template__c = masterTemplate.Id
        );
        insert owningTemplate;

        Task_Tracker_Template__c dependentTemplate = new Task_Tracker_Template__c (
            Name = 'Dependent Template',
            Parent_Template__c = masterTemplate.Id
        );
        insert dependentTemplate;

        Task_Tracker_Template_Step__c owningTemplateStep = new Task_Tracker_Template_Step__c (
            Name = 'Owning Step',
            Activity_Type__c = 'Task',
            Days_Out_Type__c = 'Calendar',
            Duration_In_Days__c = 10,
            Task_Tracker_Template__c = owningTemplate.Id
        );
        insert owningTemplateStep;

        Task_Tracker_Template_Step__c dependentTemplateStep = new Task_Tracker_Template_Step__c (
            Name = 'Dependent Step',
            Activity_Type__c = 'Task',
            Days_Out_Type__c = 'Calendar',
            Duration_In_Days__c = 3,
            Task_Tracker_Template__c = dependentTemplate.Id
        );
        insert dependentTemplateStep;

        Task_Tracker_Step_Dependency__c newDependency = new Task_Tracker_Step_Dependency__c (
            Adjust_Due_Date__c = true,
            Depends_On_Step__c = owningTemplateStep.Id,
            Step__c = dependentTemplateStep.Id,
            Task_Tracker_Template__c = owningTemplate.Id
        );
        insert newDependency;

        TaskTrackerTestDataFactory.createOpportunityAndProduct();
        AyTestDataSuite.init();

       //Craete the opportunity and the cases from the template.
       //CreateProcess() can be run async so needs to be inside starttest() and stoptest()
        Opportunity opp =
            [
                SELECT Id
                FROM Opportunity
                LIMIT 1
            ];
        OpportunityLineItem lineItem =
            [
                SELECT Product2Id
                FROM OpportunityLineItem
                WHERE OpportunityId = :opp.Id
                LIMIT 1
            ];
        update new Product2 (
            Id = lineItem.Product2Id,
            Task_Tracker_Template__c = masterTemplate.Id
        );

        CreateProcessFlowController.ProcessInput oneInput = new CreateProcessFlowController.ProcessInput();
        oneInput.ObjectId = opp.Id;
        oneInput.ObjectName = 'Opportunity';
        oneInput.TemplateId = masterTemplate.Id;

        test.startTest();
        
        CreateProcessFlowController process = new CreateProcessFlowController(oneInput);
        System.enqueueJob(process);
        
        Test.stopTest();

        //Get the cases and tasks that are involved.
        Case owningCase =
            [
                SELECT Id, Subject, Top_Level_Task_Tracker_Case__c, Project__c
                FROM Case
                WHERE Task_Tracker_Template__c = :owningTemplate.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        
        Task t = new Task();
        t.Subject = 'Test Task';
        t.Status = 'Open';
        t.Priority = 'Medium';
        t.WhatId = owningCase.Id;
        insert t;
        
        Event e = new Event();
        e.WhatId = owningCase.Id;
        e.Subject = 'Test Event';
        e.StartDateTime = DateTime.now();
        e.EndDateTime = DateTime.now() + 1;
        insert e;
        
        Task owningTask =
            [
                SELECT Id, Subject, Task_Tracker_Template_Step__r.Top_Level_Task_Tracker_Template__c
                FROM Task
                //WHERE WhatId = :owningCase.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        
        String jsonStr = ProjectOverviewController.getProjectCasesAndTasks(owningCase.Project__c);
        List<ProjectOverviewController.CaseObject> caseObjs = (List<ProjectOverviewController.CaseObject>)JSON.deserialize(jsonStr, List<ProjectOverviewController.CaseObject>.class);
        System.assertEquals(false, caseObjs.isEmpty());
    }
}