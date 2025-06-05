/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-10-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-10-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class TaskTrackerDependenciesControllerTest {

    @TestSetup
    static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testGetTemplateStepInformation() {

        Task_Tracker_Template_Step__c step =
            [
                SELECT Id
                FROM Task_Tracker_Template_Step__c
                LIMIT 1
            ];

        String jsonResult = TaskTrackerDependenciesController.getTemplateStepInformation(step.Id);
        Task_Tracker_Template_Step__c jsonToStep = (Task_Tracker_Template_Step__c)JSON.deserialize(jsonResult, Task_Tracker_Template_Step__c.class);
    }

    @IsTest
    private static void testGetTemplateSteps() {
        Task_Tracker_Template_Step__c step =
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                LIMIT 1
            ];

        String jsonResult = TaskTrackerDependenciesController.getTemplateSteps(step.Task_Tracker_Template__c, step.Id);
        List<TaskTrackerDependenciesController.TaskTrackerResponse> responses =
            (List<TaskTrackerDependenciesController.TaskTrackerResponse>)JSON.deserialize(jsonResult, List<TaskTrackerDependenciesController.TaskTrackerResponse>.class);
    }

    @IsTest
    private static void testGetCurrentDependencies() {
        Task_Tracker_Template_Step__c step =
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                LIMIT 1
            ];

        String jsonResult = TaskTrackerDependenciesController.getCurrentDependencies(step.Task_Tracker_Template__c, step.Id);
        List<TaskTrackerDependenciesController.TaskTrackerResponse> responses =
            (List<TaskTrackerDependenciesController.TaskTrackerResponse>)JSON.deserialize(jsonResult, List<TaskTrackerDependenciesController.TaskTrackerResponse>.class);
    }

    @IsTest
    private static void testUpdateDependencies() {
        Task_Tracker_Template_Step__c step =
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                LIMIT 1
            ];

        Task_Tracker_Template_Step__c otherStep =
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                WHERE Id != :step.Id AND Task_Tracker_Template__c = :step.Task_Tracker_Template__c
                LIMIT 1
            ];

        List<String> otherStepList = new List<String> { otherStep.Id };

        System.debug('otherStepList = ' + otherStepList);

        TaskTrackerDependenciesController.updateDependencies(step.Id, otherStepList);
        List<Task_Tracker_Step_Dependency__c> dep =
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :step.Id
            ];

        System.assertEquals(1, dep.size());
    }

    @IsTest
    private static void testGetTemplateList() {
        Task_Tracker_Template_Step__c step =
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                LIMIT 1
            ];

        String jsonResult = TaskTrackerDependenciesController.getTemplateList(step.Id);
        List<Task_Tracker_Template__c> responses =
            (List<Task_Tracker_Template__c>)JSON.deserialize(jsonResult, List<Task_Tracker_Template__c>.class);
    }

}