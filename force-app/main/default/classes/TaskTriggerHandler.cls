/**
 * @File Name          : TaskTriggerHandler.cls
 * @Description        : Handles updating task tracker task cases
 *                       by recounting the
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-25-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/27/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public with sharing class TaskTriggerHandler {

    private static Set<Id> caseIds = new Set<Id>();

    @TestVisible
    private static Set<String> lstClosedStatuses = new Set<String> {
        'Completed',
        'Refund',
        'Terminated',
        'Not Applicable',
        'On Hold'
    };
	
    @TestVisible
    private static List<TaskStatus> closedStatus = [SELECT MasterLabel, IsClosed FROM TaskStatus WHERE IsClosed = true];
        
    //Used to determine if this task can be updated.  If its in one of these
    //statuses then it must be moved out of this status in order to
    //have other fields changed.
    @TestVisible
    private static List<String> lockedStatusesLowerCase = new List<String> {
        'on hold',
        'terminated'
    };
    private static Map<String, Schema.SObjectField> mapTaskFields = Schema.SObjectType.Task.fields.getMap(); 
    private static List<String> fieldsToIgnore = new List<String> {
        'Status'
    };

    public static void updateTaskStatuses(List<Task> newTasks, Map<Id, Task> mapOldTasks) {

        for(Task newTask : newTasks) {
            Task oldTask = mapOldTasks.get(newTask.Id);
            SYstem.debug('***Checking Task Status = ' + newTask.Status);

            if (oldTask.Status != null && 
                newTask.Status != null &&
                lockedStatusesLowerCase.contains(oldTask.Status.toLowerCase()) &&
                !lockedStatusesLowerCase.contains(newTask.Status.toLowerCase())
            ) {
                if(newTask.Case_Status__c == 'On Hold' && isTaskRecordChanged(oldTask, newTask, fieldsToIgnore)) {
                    String statusError = String.format('Tasks in ({0}) status(es) cannot be updated.  Current status = {1} going to {2}',
                    new List<Object> { 
                        lockedStatusesLowerCase,
                        oldTask.Status,
                        newTask.Status
                    });
                newTask.Status.addError(statusError);
                System.debug(statusError);
                System.debug('Task Id = ' + newTask.Id);
                }
            }
            if(newTask.ActivityDate > oldTask.ActivityDate) {
                newTask.Count_Of_Nudges__c = newTask.Count_Of_Nudges__c == null ? 1 : newTask.Count_Of_Nudges__c++;
            }
        }

        updateCaseTaskCounts(caseIds, lstClosedStatuses);
        checkTaskDependencies(newTasks, mapOldTasks);
        System.debug('check dependencies');
    }

    @TestVisible
    private static Boolean isTaskRecordChanged(Task oldTask, Task newTask, List<String> fieldsToIgnore) {
        for(String field : mapTaskFields.keySet()) {
            if(!fieldsToIgnore.contains(field)) {
                if(oldTask.get(field) != newTask.get(field)) {
                    return true;
                }
            }
        }

        return false;
    }


    /**
    * @description: Before any tasks can be marked complete, there needs
    *   to be a check to see if dependencies exist to other tasks
    *   and those tasks are not completed already.
    * @author Revolution Group (Brian Ezell) | 4/13/2020
    * @param newTasks
    * @param oldTaskMap
    * @return void
    **/
    public static void checkTaskDependencies(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
		System.debug('checkTaskDependencies');
        //List<Task> tasksMarkedComplete = new List<Task>();
        Set<Id> tasksMarkedCompletedIds = new Set<Id>();
        Set<Id> tasksMarkedUncompletedIds = new Set<Id>();

        //List<Task> tasksMarkedUncomplete = new List<Task>();
        Set<Id> tasksWithChangedDueDates = new Set<Id>();

        for(Task t : newTasks) {
            Task oldTask = oldTaskMap.get(t.Id);
			System.debug('t.Is_Task_Tracker_Created__c: ' + t.Is_Task_Tracker_Created__c);
            System.debug('t.IsClosed: ' + t.IsClosed);
            System.debug('oldTask.IsClosed: ' + oldTask.IsClosed);
            
            if(t.Is_Task_Tracker_Created__c) {
                if(lstClosedStatuses.contains(t.Status) && !oldTask.IsClosed) {
                    tasksMarkedCompletedIds.add(t.Id);
                } else if(!lstClosedStatuses.contains(t.Status) && oldTask.isClosed) {
                    tasksMarkedUncompletedIds.add(t.Id);
                }
                if(!lstClosedStatuses.contains(t.Status) && !oldTask.IsClosed && t.ActivityDate != oldTask.ActivityDate) {
                    tasksWithChangedDueDates.add(t.Id);
                }
            }
        }

        if(!tasksMarkedUncompletedIds.isEmpty()) {
            checkTasksCantBeStartedNow(tasksMarkedUncompletedIds);
        }
		System.debug('tasksMarkedCompletedIds: ' + tasksMarkedCompletedIds);
        if(!tasksMarkedCompletedIds.isEmpty()) {
            //checkTasksWithOutstandingDependencies(tasksMarkedCompletedIds);
            checkTasksCanBeStartedNow(tasksMarkedCompletedIds);
            System.debug('changeDependentDueDates2');
            //changeDependentDueDates(tasksMarkedCompletedIds);
        }
		System.debug('tasksWithChangedDueDates: ' + tasksWithChangedDueDates);
        if(!tasksWithChangedDueDates.isEmpty()) {
            System.debug('changeDependentDueDates1');
            changeDependentDueDates(tasksWithChangedDueDates);
        }
    }

    /**
    * @description If a task due date is changed
    *   and there are dependencies that are marked to
    *   update the due date on changes, then
    *   update those dependent due dates.
    * @author Revolution Group (Brian Ezell) | 10-30-2020
    * @param taskIds
    **/
    @TestVisible
    @Future
    private static void changeDependentDueDates(Set<Id> taskIds) {
		System.debug('changeDependentDueDates');
        
        //Get all tasks that might have dependencies on other tasks/steps
        Map<Id, Task> mapTasks = new Map<Id, Task> (
            [
                SELECT Id, Task_Tracker_Template_Step__c, Top_Level_Case_Id__c,
                    Task_Tracker_Template_Step__r.Top_Level_Task_Tracker_Template__c,
                    Task_Tracker_Template_Step__r.Duration_In_Days__c,
                    Task_Tracker_Template_Step__r.Days_Out_Type__c,
                    ActivityDate
                FROM Task
                WHERE Id = :taskIds
            ]);

        Set<String> taskStepIds = new Set<String>();
        Set<String> topLevelCaseIds = new Set<String>();
        for(Task t : mapTasks.values()) {
            taskStepIds.add(t.Task_Tracker_Template_Step__c);
            topLevelCaseIds.add(t.Top_Level_Case_Id__c);
        }

        //Get all step dependencies from tasks
        List<Task_Tracker_Step_Dependency__c> stepDependencies =
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Depends_On_Step__c = :taskStepIds
                    AND Adjust_Due_Date__c = true
            ];
		System.debug('stepDependencies: ' + stepDependencies);
        //If no adjusted date dependencies then return
        if(stepDependencies.isEmpty()) {
            return;
        }

        //Create a mapping of the depends on step id to a set of step ids that depend on it
        Set<String> dependencyStepIds = new Set<String>();
        Map<String, Set<String>> mapStepIdToDependStepIds = new Map<String, Set<String>>();
        for(Task_Tracker_Step_Dependency__c d :stepDependencies) {
            dependencyStepIds.add(d.Step__c);
            Set<String> tmpStepIds = mapStepIdToDependStepIds.get(d.Depends_On_Step__c);
            if(tmpStepIds == null) {
                tmpStepIds = new Set<String>();
            }
            tmpStepIds.add(d.Step__c);
            mapStepIdToDependStepIds.put(d.Depends_On_Step__c, tmpStepIds);
        }

        //Get the dependent tasks that need the date adjusted
        Map<Id, Task> dependsOnTasks = new Map<Id, Task> (
            [
                SELECT Id, Subject, Task_Tracker_Template_Step__c, Top_Level_Case_Id__c, Task_Tracker_Template_Step__r.Duration_In_Days__c, Task_Tracker_Template_Step__r.Days_Out_Type__c
                FROM Task
                WHERE Top_Level_Case_Id__c = :topLevelCaseIds
                    AND Task_Tracker_Template_Step__c = :dependencyStepIds
            ]);
		System.debug('dependsOnTasks: ' + dependsOnTasks);
        
        //Create as map just in case there are dups
        Map<Id, Task> mapOfUpdateTasks = new Map<Id, Task>();

        for(String stepId : mapStepIdToDependStepIds.keySet()) {
            for(String dStepId : mapStepIdToDependStepIds.get(stepId)) {

                for(Task t : dependsOnTasks.values()) {

                    for(Task origTask : mapTasks.values()) {

                        //Make sure the tasks are on the same master case
                        //and the steps align properly
                        if(t.Top_Level_Case_Id__c == origTask.Top_Level_Case_Id__c &&
                            origTask.Task_Tracker_Template_Step__c == stepId &&
                            t.Task_Tracker_Template_Step__c == dStepId) {
                                System.debug('t.Id: ' + t.Id);
                                /*mapOfUpdateTasks.put(t.Id, new Task (
                                    Id = t.Id,
                                    ActivityDate = HelperFunctions.calculateDateFromActivityDate(
                                        origTask.Task_Tracker_Template_Step__r.Days_Out_Type__c,
                                        (Integer)origTask.Task_Tracker_Template_Step__r.Duration_In_Days__c
                                    )
                                ));*/
                                mapOfUpdateTasks.put(t.Id, new Task (
                                    Id = t.Id,
                                    ActivityDate = HelperFunctions.calculateDateFromActivityDateAdjusted(
                                        t.Task_Tracker_Template_Step__r.Days_Out_Type__c,
                                        (Integer)t.Task_Tracker_Template_Step__r.Duration_In_Days__c,
                                        origTask.ActivityDate
                                    )
                                ));
                        }
                    }
                }
            }
        }

        if(!mapOfUpdateTasks.isEmpty()) {
            update mapOfUpdateTasks.values();
        }
    }

    /**
    * @description If tasks are unmarked as completed,
    *   back out any dependencies that may have been able
    *   to be started.
    * @author Revolution Group (Brian Ezell) | 5/11/2020
    * @param tasksMarkedUncompleted
    * @return void
    **/
    @TestVisible
    //@Future
    private static void checkTasksCantBeStartedNow(Set<Id> taskIds) {
        //Look up the dependencies
        //First lookup the task ids.  Since this
        //is a string field, will have to do a secondary
        List<Task_Tracker_Task_Dependency__c> dependencies =
            [
                SELECT Id, Task_Id__c
                FROM Task_Tracker_Task_Dependency__c
                WHERE Task_Depends_On_Id__c = :taskIds
            ];
        Set<String> dependentTaskIds = new Set<String>();
        for(Task_Tracker_Task_Dependency__c d : dependencies) {
            dependentTaskIds.add(d.Task_Id__c);
        }
        Map<Id, Task> dependentTasks = new Map<Id, Task>(
            [
                SELECT Id, Status, Dependent_Tasks_To_Complete__c
                FROM Task
                WHERE Id = :dependentTaskIds
            ]);

        System.debug('***checkTasksCantBeStartedNow***');
        System.debug('dependencies = ' + dependencies);
        System.debug('dependentTaskIds = ' + dependentTaskIds);
        System.debug('dependentTasks = ' + dependentTasks);
        
        if(!dependentTasks.isEmpty()) {
            List<Task> updateTasks = new List<Task>();
            for(Task t : dependentTasks.values()) {
                Decimal countTasksToComplete = t.Dependent_Tasks_To_Complete__c + 1;
                updateTasks.add(new Task(
                    Id = t.Id,
                    Dependent_Tasks_To_Complete__c = countTasksToComplete,
                    Status = TaskTrackerConstants.TASK_PENDING_STATUS,
                    ActivityDate = null
                ));
            }

            if(!updateTasks.isEmpty()) {
                update updateTasks;
            }
        }
    }

    /**
    * @description Determine if any tasks can be started now
    *   if any of their dependencies have been completed.
    * @author Revolution Group (Brian Ezell) | 5/11/2020
    * @param tasksMarkedComplete
    * @return void
    **/
    @TestVisible
    @Future
    private static void checkTasksCanBeStartedNow(Set<Id> taskIds) {
		System.debug('checkTasksCanBeStartedNow');
        //Look up the dependencies
        //First lookup the task ids.  Since this
        //is a string field, will have to do a secondary
        List<Task_Tracker_Task_Dependency__c> dependencies =
            [
                SELECT Id, Task_Id__c, Task_Depends_On_Id__c
                FROM Task_Tracker_Task_Dependency__c
                WHERE Task_Depends_On_Id__c = :taskIds
            ];
        Map<Id, Task> tasksIdsList = new Map<Id,Task>([SELECT Id, ActivityDate FROM Task WHERE Id IN :taskIds]);
        //Map Dependent Tasks with Parent Task
        Map<Id, Task> taskDependentMap = new Map<Id, Task>();
        System.debug('tasksIdsList: ' + tasksIdsList);
        
		System.debug('dependencies: ' + dependencies);
        Set<String> dependentTaskIds = new Set<String>();
        for(Task_Tracker_Task_Dependency__c d : dependencies) {
            dependentTaskIds.add(d.Task_Id__c);
            System.debug('d.Task_Id__c: ' + d.Task_Id__c);
            if(tasksIdsList.containsKey(d.Task_Depends_On_Id__c)) {
                System.debug('containsKey ');
                taskDependentMap.put(d.Task_Id__c, tasksIdsList.get(d.Task_Depends_On_Id__c));
            }
        }
        System.debug('taskDependentMap: ' + taskDependentMap);
        
        List<Task> dependentTasks = new List<Task> (
            [
                SELECT Id, Status, Dependent_Tasks_To_Complete__c,
                    Task_Tracker_Template_Step__r.Duration_In_Days__c, Task_Tracker_Template_Step__r.Days_Out_Type__c
                FROM Task
                WHERE Id = :dependentTaskIds
                    AND Status = :TaskTrackerConstants.TASK_PENDING_STATUS
            ]);
        System.debug('dependentTasks: ' + dependentTasks);
        if(!dependentTasks.isEmpty()) {

            List<Task> updateTasks = new List<Task>();
            Date thisDate = date.today();
            for(Task t : dependentTasks) {
                
                //Figure out how many days out this task is due.
                Decimal countTasksToComplete = t.Dependent_Tasks_To_Complete__c - 1;
                Integer daysOut = t.Task_Tracker_Template_Step__r.Duration_In_Days__c != null ?
                    Integer.valueOf(t.Task_Tracker_Template_Step__r.Duration_In_Days__c) : null;
                Date dueDate = date.today();
                Date startDate = date.today();
                System.debug('tt.Id: ' + t.Id);
                if(taskDependentMap.containsKey(t.Id)) {
                    System.debug('contains t.Id: ' + t.Id);
                    Task task1 = taskDependentMap.get(t.Id);
                    startDate = task1.ActivityDate;
                    System.debug('contains startDate: ' + startDate);
                }
                
                if(daysOut != null && t.Task_Tracker_Template_Step__r.Days_Out_Type__c != null) {
                    //dueDate = HelperFunctions.calculateDateFromActivityDate(t.Task_Tracker_Template_Step__r.Days_Out_Type__c, daysOut);
                    dueDate = HelperFunctions.calculateDateFromActivityDateAdjusted(t.Task_Tracker_Template_Step__r.Days_Out_Type__c, daysOut, startDate);
                } else {
                    daysOut = null;
                }
                System.debug('dueDate: ' + dueDate);
                updateTasks.add(new Task(
                    Id = t.Id,
                    Dependent_Tasks_To_Complete__c = countTasksToComplete,
                    Status = countTasksToComplete > 0 ? t.Status : TaskTrackerConstants.TASK_START_STATUS,
                    ActivityDate = daysOut == null ? null : dueDate
                ));
            }

            if(!updateTasks.isEmpty()) {
                update updateTasks;
            }
        }
        
        //Get all tasks that might have dependencies on other tasks/steps
        Map<Id, Task> mapTasks = new Map<Id, Task> (
            [
                SELECT Id, Task_Tracker_Template_Step__c, Top_Level_Case_Id__c,
                    Task_Tracker_Template_Step__r.Top_Level_Task_Tracker_Template__c,
                    Task_Tracker_Template_Step__r.Duration_In_Days__c,
                    Task_Tracker_Template_Step__r.Days_Out_Type__c,
                    ActivityDate
                FROM Task
                WHERE Id = :taskIds
            ]);

        Set<String> taskStepIds = new Set<String>();
        Set<String> topLevelCaseIds = new Set<String>();
        for(Task t : mapTasks.values()) {
            taskStepIds.add(t.Task_Tracker_Template_Step__c);
            topLevelCaseIds.add(t.Top_Level_Case_Id__c);
        }

        //Get all step dependencies from tasks
        List<Task_Tracker_Step_Dependency__c> stepDependencies =
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Depends_On_Step__c = :taskStepIds
                    AND Adjust_Due_Date__c = true
            ];
		System.debug('stepDependencies: ' + stepDependencies);
        //If no adjusted date dependencies then return
        if(stepDependencies.isEmpty()) {
            return;
        }

        //Create a mapping of the depends on step id to a set of step ids that depend on it
        Set<String> dependencyStepIds = new Set<String>();
        Map<String, Set<String>> mapStepIdToDependStepIds = new Map<String, Set<String>>();
        for(Task_Tracker_Step_Dependency__c d :stepDependencies) {
            dependencyStepIds.add(d.Step__c);
            Set<String> tmpStepIds = mapStepIdToDependStepIds.get(d.Depends_On_Step__c);
            if(tmpStepIds == null) {
                tmpStepIds = new Set<String>();
            }
            tmpStepIds.add(d.Step__c);
            mapStepIdToDependStepIds.put(d.Depends_On_Step__c, tmpStepIds);
        }

        //Get the dependent tasks that need the date adjusted
        Map<Id, Task> dependsOnTasks = new Map<Id, Task> (
            [
                SELECT Id, Subject, Task_Tracker_Template_Step__c, Top_Level_Case_Id__c, Task_Tracker_Template_Step__r.Duration_In_Days__c, Task_Tracker_Template_Step__r.Days_Out_Type__c
                FROM Task
                WHERE Top_Level_Case_Id__c = :topLevelCaseIds
                    AND Task_Tracker_Template_Step__c = :dependencyStepIds
            ]);
		System.debug('dependsOnTasks: ' + dependsOnTasks);
        
        //Create as map just in case there are dups
        Map<Id, Task> mapOfUpdateTasks = new Map<Id, Task>();

        for(String stepId : mapStepIdToDependStepIds.keySet()) {
            for(String dStepId : mapStepIdToDependStepIds.get(stepId)) {

                for(Task t : dependsOnTasks.values()) {

                    for(Task origTask : mapTasks.values()) {

                        //Make sure the tasks are on the same master case
                        //and the steps align properly
                        if(t.Top_Level_Case_Id__c == origTask.Top_Level_Case_Id__c &&
                            origTask.Task_Tracker_Template_Step__c == stepId &&
                            t.Task_Tracker_Template_Step__c == dStepId) {
                                System.debug('t.Id: ' + t.Id);
                                /*mapOfUpdateTasks.put(t.Id, new Task (
                                    Id = t.Id,
                                    ActivityDate = HelperFunctions.calculateDateFromActivityDate(
                                        origTask.Task_Tracker_Template_Step__r.Days_Out_Type__c,
                                        (Integer)origTask.Task_Tracker_Template_Step__r.Duration_In_Days__c
                                    )
                                ));*/
                                mapOfUpdateTasks.put(t.Id, new Task (
                                    Id = t.Id,
                                    ActivityDate = HelperFunctions.calculateDateFromActivityDateAdjusted(
                                        t.Task_Tracker_Template_Step__r.Days_Out_Type__c,
                                        (Integer)t.Task_Tracker_Template_Step__r.Duration_In_Days__c,
                                        origTask.ActivityDate
                                    )
                                ));
                        }
                    }
                }
            }
        }

        if(!mapOfUpdateTasks.isEmpty()) {
            update mapOfUpdateTasks.values();
        }
    }

    /**
    * @description Check if tasks are marked as completed and there
    *   are other tasks that need to be completed first.
    * @author Revolution Group (Brian Ezell) | 5/11/2020
    * @param tasksMarkedComplete
    * @return void
    **/
    @TestVisible
    private static void checkTasksWithOutstandingDependencies(Set<Id> tasksMarkedCompleteIds) {
        //Look up the dependencies
        List<Task_Tracker_Task_Dependency__c> dependencies =
            [
                SELECT Id, Task_Depends_On_Id__c
                FROM Task_Tracker_Task_Dependency__c
                WHERE Task_Id__c = :tasksMarkedCompleteIds
            ];

        List<Id> dependTaskIds = new List<Id>();
        for(Task_Tracker_Task_Dependency__c d : dependencies) {
            dependTaskIds.add(d.Task_Depends_On_Id__c);
        }

        List<Task> dependentTasks =
            [
                SELECT Id, Subject
                FROM Task
                WHERE Id = :dependTaskIds
                    AND IsClosed = false
            ];

        for(Task t : dependentTasks) {
            Trigger.new[0].addError(string.format(
                'Task {0} needs to be completed before you can close out these task(s).',
                new List<String>{ t.Subject }
            ));
        }
    }

    /**
    * @description updates cases based on a list of tasks
    * @author Revolution Group (Brian Ezell) | 1/30/2020
    * @param newTasks
    * @param oldTasks
    * @return void
    **/
    @TestVisible
    private static void updateCasesFromTasks(List<Task> newTasks, Map<Id, Task> oldTasks) {
        Set<Id> caseIds = new Set<Id>();

        for(Task t : newTasks) {
            //Only look at task tracker created tasks
            if(t.Is_Task_Tracker_Created__c) {

                Task oldTask = oldTasks.get(t.Id);
                Boolean oldStatusClosed = oldTask != null && lstClosedStatuses.contains(oldTask.Status);
                Boolean newStatusClosed = lstClosedStatuses.contains(t.Status);

                //Only look at tasks where the status has changed
                //from or to a status of closed.  If so,
                //we'll update the case's progress
                if (oldStatusClosed != newStatusClosed && t.WhatId != null) {
                    caseIds.add(t.WhatId);
                }
            }
        }

        if(!caseIds.isEmpty()) {
            refreshCountsInitial(caseIds, lstClosedStatuses);
        }
    }

    @Future
    public static void refreshCountsInitial(Set<Id> caseIds, Set<String> closedStatuses) {
        refreshCounts(caseIds, 0, lstClosedStatuses);
    }

    /**
    * @description Refreshes tasks and tasks completed counts
    *   on the related cases.
    * @author Revolution Group (Brian Ezell) | 05-17-2021
    * @param caseIds
    * @param level
    **/
    @TestVisible
    public static void refreshCounts(Set<Id> caseIds, Integer level, Set<String> closedStatuses) {

        if(caseIds.isEmpty()) {
            return;
        }

        List<Case> cases =
            [
                SELECT Id, Subject, Tasks_Completed__c, Tasks_To_Complete__c, ParentId,
                    (
                        SELECT Id, Subject, Tasks_Completed__c, Tasks_To_Complete__c, ParentId
                        FROM Cases
                    ),
                    (
                        SELECT Id, Subject, Status, WhatId
                        FROM Tasks
                    )
                FROM Case
                WHERE Id = :caseIds
            ];

        if(cases.isEmpty()) {
            return;
        }

        Set<Id> parentIds = new Set<Id>();
        List<Case> updateCases = new List<Case>();

        for(Case c : cases) {
            if(c.ParentId != null) {
                parentIds.add(c.ParentId);
            }
            CaseTally currentTally = new CaseTally();

            for(Case childCase : c.Cases) {
                currentTally.TasksCompleted += childCase.Tasks_Completed__c;
                currentTally.TasksToComplete += childCase.Tasks_To_Complete__c;
            }

            for(Task t : c.Tasks) {
                currentTally.TasksCompleted += closedStatuses.contains(t.Status) ? 1 : 0;
                currentTally.TasksToComplete++;
            }

            Case updateCase = new Case(
                Id = c.Id,
                Tasks_To_Complete__c = currentTally.TasksToComplete,
                Tasks_Completed__c = currentTally.TasksCompleted
            );
            if(updateCase.Tasks_To_Complete__c == updateCase.Tasks_Completed__c) {
                updateCase.Status = 'Closed';
            } else {
                updateCase.Status = 'Active';
            }
            updateCases.add(updateCase);
        }

        if(!updateCases.isEmpty()) {
            update updateCases;
        }

        if(!parentIds.isEmpty()) {
            level++;
            refreshCounts(parentIds, level, closedStatuses);
        }
    }


    /**
    * @description Refreshses the completed task count
    *   on a list of cases.
    * @author Revolution Group (Brian Ezell) | 1/30/2020
    * @param caseId
    * @return void
    **/
    public static void refreshCaseCounts(Set<Id> caseId) {

        if(caseId.isEmpty()) {
            return;
        }

        List<Task> tasks =
            [
                SELECT Id, WhatId, Status
                FROM Task
                WHERE WhatId = :caseId
            ];
        List<Case> childCases =
            [
                SELECT Id, Tasks_Completed__c, Tasks_To_Complete__c, ParentId
                FROM Case
                WHERE ParentId = :caseId
            ];

        Map<Id, CaseTally> mapCaseTally = new Map<Id, CaseTally>();

        //For the tasks, add to TasksCompleted (if status is closed)
        //and TasksToComplete
        for(Task t : tasks) {
            if(!mapCaseTally.containsKey(t.WhatId)) {
                mapCaseTally.put(t.WhatId, new CaseTally());
            }
            CaseTally tally = mapCaseTally.get(t.WhatId);
            tally.TasksToComplete++;
            tally.TasksCompleted += lstClosedStatuses.contains(t.Status) ? 1 : 0;
        }

        Set<Id> childIds = new Set<Id>();
        //For the cases, just pull the numbers in and add
        for(Case c : childCases) {
            childIds.add(c.Id);
            CaseTally tally = mapCaseTally.get(c.ParentId);
            if(tally != null) {
                tally.TasksCompleted += (Integer)c.Tasks_Completed__c;
                tally.TasksToComplete += (Integer)c.Tasks_To_Complete__c;
            }
        }

        List<Case> updateCases = new List<Case>();
        for(Id key : mapCaseTally.keySet()) {
            CaseTally tally = mapCaseTally.get(key);
            updateCases.add(new Case (
                Id = key,
                //Tasks_To_Complete__c = tally.TasksToComplete,
                Tasks_Completed__c = tally.TasksCompleted,
                Status = tally.TasksToComplete == tally.TasksCompleted ? 'Closed' : 'Working'
            ));
        }

        update updateCases;

        if(!childIds.isEmpty()) {
            refreshCaseCounts(childIds);
        }
    }

    /**
    * @description Loads a list of close statuses
    *   on the task if it is not already loaded.
    * @author Revolution Group (Brian Ezell) | 1/30/2020
    * @return void
    **/
    private static Set<String> getClosedStatuses() {

        if(lstClosedStatuses != null) {
            return lstClosedStatuses;
        }

        List<TaskStatus> taskStats =
        [
            SELECT MasterLabel
            FROM TaskStatus
            WHERE IsClosed = true
        ];
        Set<String> cStatuses = new Set<String>();
        for(TaskStatus s : taskStats) {
            cStatuses.add(s.MasterLabel);
        }
        lstClosedStatuses = cStatuses;
        return cStatuses;
    }

    /**
    * @description Updates the number of tasks completed count
    *   on the case.
    * @author Revolution Group (Brian Ezell) | 1/30/2020
    * @param caseIds
    * @return void
    **/
    @TestVisible
    private static void updateCaseTaskCounts(Set<Id> caseIds, Set<String> closedStatuses) {

        List<Task> tasksToCount =
            [
                SELECT Id, WhatId, Status
                FROM Task
                WHERE WhatId = :caseIds
            ];
        Map<Id, CaseTally> tallyMap = new Map<Id, CaseTally>();
        for(Task t : tasksToCount) {
            if(t.WhatId != null) {
                if(!tallyMap.containsKey(t.WhatId)) {
                    tallyMap.put(t.WhatId, new CaseTally());
                }
                CaseTally tally = tallyMap.get(t.WhatId);
                tally.TasksToComplete++;
                tally.TasksCompleted += closedStatuses.contains(t.Status) ? 1 : 0;
            }
        }

        List<Case> updateCases = new List<Case>();
        for(Id key : tallyMap.keySet()) {
            Case caseToUpdate = new Case (
                Id = key,
                //Tasks_To_Complete__c = tallyMap.get(key).TasksToComplete,
                Tasks_Completed__c = tallyMap.get(key).TasksCompleted
            );
            if(tallyMap.get(key).TasksToComplete == tallyMap.get(key).TasksCompleted) {
                caseToUpdate.Status = 'Closed';
            } else {
                caseToUpdate.Status = 'In Progress';
            }
            updateCases.add(caseToUpdate);
        }
        update updateCases;
    }

    public class CaseTally {
        public CaseTally() {
            TasksCompleted = 0;
            TasksToComplete = 0;
        }
        public Decimal TasksCompleted;
        public Decimal TasksToComplete;
    }

}