/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-22-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-21-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class TaskTemplateCloneControllerTest {

    @TestSetup
    private static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testClone() {

        Task_Tracker_Template__c temp = [SELECT Id, Top_Level_Task_Template__c FROM Task_Tracker_Template__c LIMIT 1];
        Test.startTest();
        TaskTemplateCloneController.cloneTemplate(temp.Id, 'Template Copy');
        Test.stopTest();

        System.assertEquals(1, [SELECT Id FROM Task_Tracker_Template__c WHERE Name = 'Template Copy'].size());
    }
}