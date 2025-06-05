/**
 * @File Name          : TaskTrackerTasksCompletedController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 10-12-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/28/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public with sharing class TaskTrackerTasksCompletedController {

    @AuraEnabled
    public static String getTaskList(String caseId) {

        TaskListResponse response = getTaskListResponse(caseId);
        return JSON.serialize(response);
    }

    //Needed to kick off the notifications to fill in the event dates
    @AuraEnabled
    public static string getTaskInformation(String caseId, String taskName) {
        Task t =
            [
                SELECT Id, Task_Tracker_Template_Step__c, Owner.Name
                FROM Task
                WHERE WhatId = :caseId
                    AND Subject = :taskName
                LIMIT 1
            ];
        return JSON.serialize(t);
    }

    @AuraEnabled
    public static string getEventList(String caseId){

        List<Event> events =
            [
                SELECT Id, Subject, StartDateTime, Owner.Name
                FROM Event
                WHERE WhatId = :caseId
                    AND Is_Completed__c = false
            ];
        return JSON.serialize(events);

    }

    @AuraEnabled
    //Completed list is passed back as a comma seperated list of values
    public static String updateTaskList(String caseId, String jsonTaskList) {

        TaskTrackerTasksCompletedController.TaskListResponse response = new TaskTrackerTasksCompletedController.TaskListResponse();

        List<TaskItem> taskItems = (List<TaskItem>) JSON.deserialize(jsonTaskList, List<TaskItem>.class);
        List<String> completedList = new List<String>();
        for(TaskItem i : taskItems) {
            if(i.IsComplete == true) {
                completedList.add(i.Name);
            }
        }
        updateTasksCompleted(caseId, completedList);

        response = getTaskListResponse(caseId);

        return JSON.serialize(response);
    }
    
    /**
    * @description Gets Closed Statuses on Task
    * @author Revolution Group (Albert Liu) | 6/8/2022
    * @param 
    * @return Map<String, TaskStatus>
    **/
    private static Map<String, TaskStatus> getClosedStatus() {
        List<TaskStatus> closedStatus = [SELECT MasterLabel, IsClosed FROM TaskStatus WHERE IsClosed = true];
                
        Map<String, TaskStatus> mapStatus = new Map<String, TaskStatus>();
        for(TaskStatus ts : closedStatus) {
            mapStatus.put(ts.MasterLabel, ts);
        }
        
        return mapStatus;
    }
    
    /**
    * @description Gets list of tasks on the case
    * @author Revolution Group (Brian Ezell) | 2/5/2020
    * @param caseId
    * @return TaskListResponse
    **/
    private static TaskListResponse getTaskListResponse(String caseId) {
       List<Task> tasks =
            [
                SELECT Id, Subject, Status, Owner.Name, Owner.Id
                FROM Task
                WHERE WhatId = :caseId
                    AND Status != :TaskTrackerConstants.TASK_PENDING_STATUS
            ];

        List<Task_Tracker_Task_Dependency__c> dependencies =
            [
                SELECT Id, Task_Id__c, Task_Depends_On_Id__c
                FROM Task_Tracker_Task_Dependency__c
                WHERE Case__c = :caseId
            ];

        Map<Id, Task> mapTasks = new Map<Id, Task>(tasks);
        Map<String, List<String>> mapTaskDependencies = new Map<String, List<String>>();

        for(Task t : tasks) {
            for(Task_Tracker_Task_Dependency__c d : dependencies) {
                if(d.Task_Id__c == t.Id) {
                    if(!mapTaskDependencies.containsKey(t.Id)) {
                        mapTaskDependencies.put(t.Id, new List<String>());
                    }
                    String subject = mapTasks.get(t.Id).Subject;
                    mapTaskDependencies.get(t.Id).add(subject);
                }
            }
        }

        //Get the profile name - if this is a community user
        //they can only mark this task complete if
        //they own the task
        String profileName = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;
        Id userId = UserInfo.getUserId();
		
		Map<String, TaskStatus> mapStatus = getClosedStatus();
        
        //Get a list of completed tasks first
        Set<String> completedTasks = new Set<String>();
        for(Task t : tasks) {
            if(mapStatus.containsKey(t.Status)) {
                completedTasks.add(t.Subject);
            }
        }

        //Get a list of all tasks with completed status to return
        TaskListResponse response = new TaskListResponse();
        for(Task t : tasks) {
            response.TaskItems.add(new TaskItem(
                t.Owner.Name,
                t.Subject,
                completedTasks.contains(t.Subject),
                mapTaskDependencies.containsKey(t.Id) ? mapTaskDependencies.get(t.Id) : new List<String>(),
                !profileName.containsIgnoreCase('Community')  ? true : t.OwnerId == userId
            ));
        }

        return response;
    }

    /**
    * @description Updates tasks to completed or not completed
    * @author Revolution Group (Brian Ezell) | 2/5/2020
    * @param caseId
    * @param completedList
    * @return void
    **/
    private static void updateTasksCompleted(String caseId, List<String> completedList) {

        List<Task> tasks =
            [
                SELECT Id, Status, Subject
                FROM Task
                WHERE WhatId = :caseId
            ];
        
		Map<String, TaskStatus> mapStatus = getClosedStatus();
        
        List<Task> updateTasks = new List<Task>();
        for(Task t : tasks) {
            if(completedList.contains(t.Subject)) {
                if(t.Status != 'Completed') {
                    updateTasks.add(new Task(
                        ID = t.Id,
                        Status = 'Completed'
                    ));
                }
            } else if(mapStatus.containsKey(t.Status)) {
                updateTasks.add(new Task(
                    Id = t.Id,
                    Status = 'Not Started'
                ));
            }
        }
        if(!updateTasks.isEmpty()) {
            update updateTasks;
        }
    }

    public class TaskListResponse {
        public TaskListResponse() {
            Messages = new List<String>();
            TaskItems = new List<TaskItem>();
        }

        public List<String> Messages {get;set;}
        public List<TaskItem> TaskItems{get;set;}
        public Boolean IsSuccessful {
            get {
                return Messages.size() == 0;
            }
        }
    }

    public class TaskItem{

        public TaskItem() {

        }

        public TaskItem(String oName, String nm, Boolean comp, List<String> dep, Boolean enabled) {
            OwnerName = oName;
            Name = nm;
            IsComplete = comp;
            Dependencies = dep;
            IsEnabled = enabled;
        }

        public String OwnerName {get;set;}
        public String Name {get;set;}
        public Boolean IsComplete {get;set;}

        //Used to determine if this user can mark this completed
        public Boolean IsEnabled {get;set;}
        public List<String> Dependencies {get;set;}
    }
}