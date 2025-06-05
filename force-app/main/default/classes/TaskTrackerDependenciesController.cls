/**
 * @File Name          : TaskTrackerDependencyController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 5/14/2020, 1:41:49 PM
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    2/4/2020   Revolution Group (Brian Ezell)     Initial Version
**/

public class TaskTrackerDependenciesController {

    /**
    * @description Gets information on the template step
    * @author Revolution Group (Brian Ezell) | 5/13/2020
    * @param stepId
    * @return string
    **/
    @AuraEnabled
    public static string getTemplateStepInformation(String stepId){
        Task_Tracker_Template_Step__c step =
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                WHERE Id = :stepId
            ];
        return Json.serialize(step);
    }

    /**
    * @description Gets a list of steps under a template
    * @author Revolution Group (Brian Ezell) | 5/12/2020
    * @param templateId
    * @return string
    **/
    @AuraEnabled
    public static string getTemplateSteps(String templateId, String stepId){

        Map<String, TaskTrackerResponse> mapResponses = new Map<String, TaskTrackerResponse>();

        //List of dependencies currently selected
        List<Task_Tracker_Step_Dependency__c> currentDependencies =
            [
                SELECT Id, Step__c, Depends_On_Step__c,
                    Depends_On_Step__r.Name, Depends_On_Step__r.Task_Tracker_Template__r.Name
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :stepId
            ];

        //List of steps currently available based on which template
        //is selected
        List<Task_Tracker_Template_Step__c> templateSteps =
            [
                SELECT Id, Name, Task_Tracker_Template__r.Name
                FROM Task_Tracker_Template_Step__c
                WHERE Task_Tracker_Template__c = :templateId
                    AND Id != :stepId
                ORDER BY Name
            ];

        //Add the template steps first, so
        //if there are selected dependencies the
        //"IsDependency" doesn't get overwritten

        for(Task_Tracker_Template_Step__c t : templateSteps) {
            mapResponses.put(t.Id,
                new TaskTrackerResponse(
                    t.Name,
                    t.Id,
                    false
                )
            );
        }

        for(Task_Tracker_Step_Dependency__c d : currentDependencies) {
            mapResponses.put(d.Depends_On_Step__c,
                new TaskTrackerResponse(
                    d.Depends_On_Step__r.Name,
                    d.Depends_On_Step__c,
                    true
                )
            );
        }

        return JSON.serialize(mapResponses.values());
    }

    /**
    * @description Gets dependencies this step already depends on.
    * @author Revolution Group (Brian Ezell) | 5/12/2020
    * @param stepId
    * @return String
    **/
    @AuraEnabled
    public static String getCurrentDependencies(string templateId, String stepId) {

        Task_Tracker_Template_Step__c currentStep =
            [
                SELECT Id, Name, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                WHERE Id = :stepId
            ];

        List<Task_Tracker_Template_Step__c> allSteps =
            [
                SELECT Id, Name, (
                    SELECT Id, Step__c, Depends_On_Step__c
                    FROM Task_Tracker_Step_Dependencies1__r
                    WHERE Step__c = :stepId
                )
                FROM Task_Tracker_Template_Step__c
                WHERE Task_Tracker_Template__c = :currentStep.Task_Tracker_Template__c
                    AND Id != :stepId
            ];

        System.debug('All Steps = ' + allSteps);
        System.debug('Current Step = ' + currentStep);

        List<TaskTrackerResponse> responses = new List<TaskTrackerResponse>();
        for(Task_Tracker_Template_Step__c s : allSteps) {
            responses.add(new TaskTrackerResponse(
                s.Name,
                s.Id,
                !s.Task_Tracker_Step_Dependencies1__r.isEmpty()
            ));
        }

        System.debug('Responses = ' + responses);

        return Json.serialize(responses);
    }

    /**
    * @description Updates the dependencies of this step
    * @author Revolution Group (Brian Ezell) | 5/12/2020
    * @param stepId
    * @param options
    * @return void
    **/
    @AuraEnabled
    public static void updateDependencies(String stepId, List<String> options){

        List<Task_Tracker_Step_Dependency__c> currentDependencies =
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :stepId
            ];

        Map<Id, Id> currentStepIds = new Map<Id, Id>();
        for(Task_Tracker_Step_Dependency__c d : currentDependencies) {
            currentStepIds.put(d.Depends_On_Step__c, d.Id);
        }
        Set<Id> currentOptionIds = new Set<Id>();
        for(String o : options) {
            currentOptionIds.add(o);
        }

        Set<Id> removeDependencyIds = new Set<Id>();

        List<Task_Tracker_Step_Dependency__c> deleteRecords = new List<Task_Tracker_Step_Dependency__c>();
        List<Task_Tracker_Step_Dependency__c> createRecords = new List<Task_Tracker_Step_Dependency__c>();

        //Add steps not already in system
        for(Id o : currentOptionIds) {
            if(!currentStepIds.containsKey(o)) {
                createRecords.add(new Task_Tracker_Step_Dependency__c(
                    Step__c = stepId,
                    Depends_On_Step__c = o
                ));
            }
        }

        //Remove steps that are in the system
        for(Id s : currentStepIds.keySet()) {
            if(!currentOptionIds.contains(s)) {
                deleteRecords.add(new Task_Tracker_Step_Dependency__c(
                    Id = currentStepIds.get(s)
                ));
            }
        }

        if(!deleteRecords.isEmpty()) {
            delete deleteRecords;
        }
        if(!createRecords.isEmpty()) {
            insert createRecords;
        }
    }

    /**
    * @description Gets all templates associated with this
    * @author Revolution Group (Brian Ezell) | 5/12/2020
    * @param templateStepId
    * @return string
    **/
    @AuraEnabled
    public static string getTemplateList(string templateStepId){
        Task_Tracker_Template_Step__c templateStep =
            [
                SELECT Id, Task_Tracker_Template__r.Top_Level_Task_Template__c
                FROM Task_Tracker_Template_Step__c
                WHERE Id = :templateStepId
            ];

        List<Task_Tracker_Template__c> templates =
            [
                SELECT Id, Name
                FROM Task_Tracker_Template__c
                WHERE Top_Level_Task_Template__c = :templateStep.Task_Tracker_Template__r.Top_Level_Task_Template__c
                ORDER BY Name
            ];
        return Json.serialize(templates);
    }


    public class TaskTrackerResponse {
        public TaskTrackerResponse(String lbl, String val, Boolean dep) {
            Label = lbl;
            Value = val;
            IsDependency = dep;
        }

        public String Label;
        public String Value;
        public Boolean IsDependency;
    }

}