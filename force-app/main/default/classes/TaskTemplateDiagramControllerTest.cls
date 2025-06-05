/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-22-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-22-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class TaskTemplateDiagramControllerTest {

    @TestSetup
    private static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();

    }

    @IsTest
    private static void testGetTemplateNodes() {

        Task_Tracker_Template__c temp = [SELECT Id FROM Task_Tracker_Template__c WHERE Is_Master_Template__c = true LIMIT 1];
        String jsonNodes = TaskTemplateDiagramController.getTemplateNodes(String.valueOf(temp.Id));
        List<TaskTemplateDiagramController.TaskTemplateNode> taskNodes = (List<TaskTemplateDiagramController.TaskTemplateNode>) JSON.deserialize(jsonNodes, List<TaskTemplateDiagramController.TaskTemplateNode>.class);
    }

    @IsTest
    private static void testDeleteTask() {

        Integer allTasksCount = [SELECT Id FROM Task_Tracker_Template_Step__c].size();
        Task_Tracker_Template_Step__c t = [SELECT Id FROM Task_Tracker_Template_Step__c LIMIT 1];

        TaskTemplateDiagramController.deleteTaskRecord(string.valueOf(t.Id));

        System.assertEquals(allTasksCount - 1, [SELECT Id FROM Task_Tracker_Template_Step__c].size());
    }

    @IsTest
    private static void testDeleteTemplate() {
        Integer allTemplateCount = [SELECT Id FROM Task_Tracker_Template__c].size();
        Task_Tracker_Template__c temp = [SELECT Id FROM Task_Tracker_Template__c LIMIT 1];

        Test.startTest();
        TaskTemplateDiagramController.deleteTemplateRecord(String.valueOf(temp.Id));
        Test.stopTest();

        System.assertEquals(allTemplateCount - 1, [SELECT Id FROM Task_Tracker_Template__c].size());
    }

}