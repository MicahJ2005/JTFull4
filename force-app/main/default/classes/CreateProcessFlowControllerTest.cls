/**
 * @File Name          : CreateProcessFlowControllerTest.cls
 * @Description        : Tests the CreateProcessFlowController class
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 05-17-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/28/2020   Revolution Group (Brian Ezell)     Initial Version
**/
@IsTest
@TestVisible
private class CreateProcessFlowControllerTest {

    @TestSetup
    static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
       	TaskTrackerTestDataFactory.createOneTemplate();
    }

    @IsTest
    private static void testCreateCases() {

        Test.startTest();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = 
            [
                SELECT Id 
                FROM Opportunity 
                LIMIT 1
            ];
        opp.StageName = 'Closed Won';
        update opp;

        Task_Tracker_Template__c template =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Active__c = true
                LIMIT 1
            ];

        CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
        input.ObjectId = opp.Id;
        input.ObjectName = 'Opportunity';
        input.TemplateId = template.Id;

        CreateProcessFlowController.CreateProcess(new List<CreateProcessFlowController.ProcessInput>{
            input
        });

        List<Case> cases =
            [
                SELECT Id
                FROM Case
                WHERE Is_Task_Tracker_Case__c = true
            ];

        System.assertEquals(false, cases.isEmpty(), 'Cases should have been created for the template');

        List<Task> tasks =
            [
                SELECT Id
                FROM Task
            ];
        System.assertEquals(false, tasks.isEmpty(), 'Tasks should have been created for the template steps.');

        Test.stopTest();

    }

    @IsTest
    private static void testCreateCasesFromInstance() {

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = 
            [
                SELECT Id 
                FROM Opportunity 
                LIMIT 1
            ];
        opp.StageName = 'Closed Won';
        update opp;

        Task_Tracker_Template__c template =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Active__c = true
                LIMIT 1
            ];

        Test.startTest();

        CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
        input.ObjectId = opp.Id;
        input.ObjectName = 'Opportunity';
        input.TemplateId = template.Id;

        CreateProcessFlowController ctrl = new CreateProcessFlowController(input);

        System.enqueueJob(ctrl);

        Test.stopTest();

        List<Case> cases =
            [
                SELECT Id
                FROM Case
                WHERE Is_Task_Tracker_Case__c = true
            ];

        System.assertEquals(false, cases.isEmpty(), 'Cases should have been created for the template');

        List<Task> tasks =
            [
                SELECT Id
                FROM Task
            ];
        System.assertEquals(false, tasks.isEmpty(), 'Tasks should have been created for the template steps.');

    }
    
    @IsTest
    private static void testCreateProcessInput() {
        Map<String, Decimal> tasksToHoursMap = new Map<String, Decimal>();
        tasksToHoursMap.put('Task 1', 1);
        
        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = 
            [
                SELECT Id 
                FROM Opportunity 
                LIMIT 1
            ];
        opp.StageName = 'Closed Won';
        update opp;

        Task_Tracker_Template__c template =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Active__c = true
                LIMIT 1
            ];

        Test.startTest();

            CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
            input.ObjectId = opp.Id;
            input.ObjectName = 'Opportunity';
            input.TemplateId = template.Id;
    
            CreateProcessFlowController ctrl = new CreateProcessFlowController(input);
    		
        	ctrl.ProcessOneInputWithSelectedTasks(input, null, tasksToHoursMap);
        
        Test.stopTest();
        
        List<Case> cases =
            [
                SELECT Id
                FROM Case
                WHERE Is_Task_Tracker_Case__c = true
            ];

        System.assertEquals(false, cases.isEmpty(), 'Cases should have been created for the template');

        List<Task> tasks =
            [
                SELECT Id
                FROM Task
            ];
        System.assertEquals(false, tasks.isEmpty(), 'Tasks should have been created for the template steps.');

    }
}