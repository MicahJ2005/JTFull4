/**
 * @File Name          : CaseTriggerController.cls
 * @Description        : Updates all parent cases where
 *                          the number of tasks completed
 *                          has changed
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 02-18-2022
 * @Modification Log   :
 * Ver       Date            Author      		           Modification
 * 1.0    1/25/2020   Revolution Group (Brian Ezell)       Initial Version
 * 1.1	  11/17/2021  Revolution Group (Christan Gordon)   Added a filter to the Task SOQL used within the updateCaseTask method. This filter ensures that only
 * 														   non-completed status Task records are updated when its related Case is terminated.
 * 1.2    11/22/2021  Revolution Group (Christan Gordon)   Made updateCases method test visible
**/
public class CaseTriggerController {

    private static Map<Id, Case> updatedCases = new Map<Id, Case>();
    private static Map<Id, Task> updateTasks = new Map<Id, Task>();
    private static List<String> caseHoldStatuses = new List<String> {
        'On Hold',
        'Terminated'
    };

    /**
    * @description Update progress on child and parent cases when
    *   a task is completed or uncompleted
    * @author Revolution Group (Brian Ezell) | 1/28/2020
    * @param newCases
    * @param oldMap
    * @return void
    **/
    public static void updateTaskTrackerCaseProgress(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> modifiedCases = new List<Case>();

        Map<Id, StatusChangeCls> statusChangeMap = new Map<Id, StatusChangeCls>();

        for(Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);

            if(!c.Is_Parent_Process__c &&
                (oldCase == null || c.Tasks_Completed__c != oldCase.Tasks_Completed__c)
             ) {
                modifiedCases.add(c);
            }

            if(c.Status != oldCase.Status) {

                System.debug('Status changed from ' + oldCase.Status + ' to ' + c.Status);
                String strStatus = c.Status != null ? c.Status : '';
                String prevStrStatus = oldCase.Status != null ? oldCase.Status : '';

                //If this was changed to/from a holding status
                if(caseHoldStatuses.contains(strStatus) || caseHoldStatuses.contains(prevStrStatus)) {
                    StatusChangeCls statusChange = new StatusChangeCls();
                    statusChange.OldStatus = oldCase.Status;
                    statusChange.NewStatus = c.Status;
                    statusChangeMap.put(c.Id, statusChange);
                }
            }
        }

        if(!modifiedCases.isEmpty()) {
            updateCases(modifiedCases);
        }

        if(!statusChangeMap.isEmpty() && !System.isFuture()) {
            updateCaseTask(statusChangeMap);
        }
    }

    /**
    * @description Updates the status of cases to termed or untermed
    *   along with the tasks/events under them.
    * @author Revolution Group (Brian Ezell) | 05-10-2021
    * @param casesTerminatededOrUnterminated
    **/
    private static void updateCaseTask(Map<Id, StatusChangeCls> statusChangeMap) {
        //private static void updateCaseTask(Set<Id> caseIdsWithStatusChange) {
        Map<Id, String> mapCaseIdToStatus = new Map<Id, String>();

        List<Case> cases =
            [
                SELECT Id, Status, Previous_Status__c, ParentId,
                    (
                        SELECT Id, Status, ParentId, Previous_Status__c
                        FROM Cases
                    ),
                    (
                        SELECT Id, Status, Previous_Task_Status__c, WhatId
                        FROM Tasks
                        //Modified By Christan Gordon (Revolution Group) on 11-17-2021: Added a filter to task SOQL to ensure
                        //already completed tasks aren't affected.
                        WHERE Status != 'Completed'
                    )
                FROM Case
                WHERE Id = :statusChangeMap.keySet()
            ];

        processCaseStatusChanges(cases, statusChangeMap);
        if(!updatedCases.isEmpty()) {
            update updatedCases.values();
        }
        if(!updateTasks.isEmpty()) {
            update updateTasks.values();
        }
    }

    /**
    * @description Populates the cases and task update lists. Process recusrively to ensure
    *   child tasks/cases are updated as well.
    *
    * @author Revolution Group (Brian Ezell) | 05-10-2021
    * @param casesTermedOrUntermed
    * @param mapCaseIdToStatus
    **/
    @TestVisible
    private static void processCaseStatusChanges(List<Case> caseStatusChanges, Map<Id, StatusChangeCls> mapCaseIdToStatus) {

        Set<Id> childCaseIds = new Set<Id>();
        for(Case c : caseStatusChanges) {

            StatusChangeCls statusChange = new StatusChangeCls();

            statusChange.NewStatus = mapCaseIdToStatus.containsKey(c.ParentId) ? mapCaseIdToStatus.get(c.ParentId).NewStatus : c.Status;
            statusChange.OldStatus = mapCaseIdToStatus.containsKey(c.ParentId) ? mapCaseIdToStatus.get(c.ParentId).OldStatus : c.Previous_Status__c;

            System.debug('Case Id = ' + c.Id);
            System.debug('Case Previous Status = ' + statusChange.OldStatus);
            System.debug('Case Current Status = ' + c.Status);
            System.debug('Case New Status = ' + statusChange.NewStatus);

            Case caseToUpdate = new Case(
                Id = c.Id,
                Status = statusChange.NewStatus,
                Previous_Status__c = statusChange.OldStatus
            );
            updatedCases.put(c.Id, caseToUpdate);

            mapCaseIdToStatus.put(c.Id, statusChange);

            for(Case cChild : c.Cases) {
                childCaseIds.add(cChild.Id);
            }
            for(Task t : c.Tasks) {

                StatusChangeCls taskStatusChange = new StatusChangeCls();

                if(t.Status == null || !t.Status.equalsIgnoreCase('Not Applicable')) {
                    taskStatusChange.NewStatus = mapCaseIdToStatus.containsKey(t.WhatId) ? mapCaseIdToStatus.get(t.WhatId).NewStatus : t.Status;
                    taskStatusChange.OldStatus = mapCaseIdToStatus.containsKey(t.WhatId) ? mapCaseIdToStatus.get(t.WhatId).OldStatus : t.Status;

                    System.debug('Task old status = ' + taskStatusChange.OldStatus);
                    System.debug('Task current status = ' + t.Status);
                    System.debug('Task updated status = ' + taskStatusChange.NewStatus);

                    Task updatedTask = new Task (
                        Id = t.Id,
                        Status = taskStatusChange.NewStatus,
                        Previous_Task_Status__c = taskStatusChange.OldStatus
                    );
                    updateTasks.put(updatedTask.Id, updatedTask);
                }
            }
        }

        //Recursively call for child cases.
        List<Case> cases =
            [
                SELECT Id, Status, Previous_Status__c, ParentId,
                    (
                        SELECT Id, Status, ParentId
                        FROM Cases
                    ),
                    (
                        SELECT Id, Status, Previous_Task_Status__c, WhatId
                        FROM Tasks 
                        //Modified By Christan Gordon (Revolution Group) on 11-17-2021: Added a filter to task SOQL to ensure
                        //already completed tasks aren't affected.
                        WHERE Status != 'Completed'
                    )
                FROM Case
                WHERE Id = :childCaseIds
            ];
        if(!cases.isEmpty()) {
            processCaseStatusChanges(cases, mapCaseIdToStatus);
        }

        if(!updateTasks.isEmpty()) {
            update updateTasks.values();
        }
    }

    /**
    * @description Updates the progress
    * @author Revolution Group (Brian Ezell) | 1/28/2020
    * @param modifiedCases
    * @return void
    **/
    @TestVisible
    private static void updateCases(List<Case> modifiedCases) {

        Set<Id> parentIds = new Set<Id>();
        for(Case c : modifiedCases) {
            parentIds.add(c.ParentId);
        }

        List<Case> caseList =
            [
                SELECT Id, ParentId, Tasks_Completed__c, Tasks_To_Complete__c
                FROM Case
                WHERE parentId = :parentIds
            ];


        Map<Id, CaseTally> mapTally = new Map<Id, CaseTally>();
        for(Case c : caseList) {
            if(!mapTally.containsKey(c.ParentId)) {
                mapTally.put(c.ParentId, new CaseTally());
            }
            CaseTally tally = mapTally.get(c.ParentId);
            tally.TasksCompleted += (Integer)c.Tasks_Completed__c;
            tally.TasksToComplete += (Integer)c.Tasks_To_Complete__c;
        }

        List<Case> updateCases = new List<Case>();
        for(Id key : mapTally.keySet()) {
            CaseTally tally = mapTally.get(key);
            updateCases.add(new Case (
                Id = key,
                Tasks_Completed__c = tally.TasksCompleted,
                Tasks_To_Complete__c = tally.TasksToComplete,
                Status = tally.TasksCompleted == tally.TasksToComplete ? 'Closed' : 'Working'
            ));
        }
        update updateCases;
    }


    public class CaseTally {
        public CaseTally() {
            TasksCompleted = 0;
            TasksToComplete = 0;
        }
        public Integer TasksCompleted;
        public Integer TasksToComplete;
    }

    public class StatusChangeCls {
        public String NewStatus;
        public String OldStatus;
    }
}