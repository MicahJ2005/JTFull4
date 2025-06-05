/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-18-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-22-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class TaskTrackerTasksCompletedControllerTest {

    private static void setup(){

        TaskTrackerTestDataFactory.createAllTestData();

        Test.startTest();

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

        Test.stopTest();

    }

    @IsTest
    private static void testGetTaskList() {

        setup();

        Case c = [SELECT Id FROM Case LIMIT 1];
        String caseJson = TaskTrackerTasksCompletedController.getTaskList(String.valueOf(c.Id));
        TaskTrackerTasksCompletedController.TaskListResponse response = (TaskTrackerTasksCompletedController.TaskListResponse) JSON.deserialize(caseJson, TaskTrackerTasksCompletedController.TaskListResponse.class);
    }

    @IsTest
    private static void testGetTaskInformation() {
        setup();
        Task t = [SELECT Id, Subject, WhatId FROM Task LIMIT 1];
        String jsonInfo = TaskTrackerTasksCompletedController.getTaskInformation(String.valueOf(t.WhatId), t.Subject);
        Task response = (Task)JSON.deserialize(jsonInfo, Task.class);
    }
	
    @IsTest
    private static void testTaskItem() {
		setup();
        Task t = [SELECT Id, Subject, WhatId, Owner.Name FROM Task LIMIT 1];
        Case c = new Case();
        insert c;
        t.WhatId = c.Id;
        update t;
        List<String> listTask = new List<String>();
        listTask.add(t.Subject);
        
        List<TaskTrackerTasksCompletedController.TaskItem> taskItems = new List<TaskTrackerTasksCompletedController.TaskItem>();
        
        TaskTrackerTasksCompletedController.TaskItem item = new TaskTrackerTasksCompletedController.TaskItem(
            t.Owner.Name,
            t.Subject,
            true,
            new List<String>(),
            true
        );
        taskItems.add(item);

        TaskTrackerTasksCompletedController.updateTaskList(c.Id, JSON.serialize(taskItems));
        
    }
    
    @IsTest
    private static void testGetEventList() {

        setup();
        Event e = [SELECT Id, WhatId FROM Event WHERE What.Type = 'Case' LIMIT 1];
        String jsonEvent = TaskTrackerTasksCompletedController.getEventList(String.valueOf(e.WhatId));
        List<Event> events = (List<Event>)JSON.deserialize(jsonEvent, List<Event>.class);
    }

    @IsTest
    private static void testUpdateTaskList() {

        setup();
        Case c =
            [
                SELECT Id, Subject,
                (
                    SELECT Id, Subject, Owner.Name
                    FROM Tasks
                )
                FROM Case
                WHERE ParentId != null
                LIMIT 1
            ];
        List<TaskTrackerTasksCompletedController.TaskItem> taskItems = new List<TaskTrackerTasksCompletedController.TaskItem>();
        for(Task t : c.Tasks) {
            TaskTrackerTasksCompletedController.TaskItem item = new TaskTrackerTasksCompletedController.TaskItem(
                t.Owner.Name,
                t.Subject,
                false,
                new List<String>(),
                true
            );
            taskItems.add(item);
        }

        String request = JSON.serialize(taskItems);

        String jsonResponse = TaskTrackerTasksCompletedController.updateTaskList(String.valueOf(c.Id), request);

        TaskTrackerTasksCompletedController.TaskListResponse response = (TaskTrackerTasksCompletedController.TaskListResponse) JSON.deserialize(jsonResponse, TaskTrackerTasksCompletedController.TaskListResponse.class);
    }
}