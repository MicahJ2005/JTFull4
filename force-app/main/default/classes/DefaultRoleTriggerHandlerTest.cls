/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 11-23-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-23-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class DefaultRoleTriggerHandlerTest {

    @IsTest
    private static void testChangeRoleToUser() {

        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp =
            [
                SELECT Id
                FROM Opportunity
                LIMIT 1
            ];

        opp.StageName = 'Closed Won';
        update opp;
        
        Task_Tracker_Template_Step__c ts = [SELECT Id FROM Task_Tracker_Template_Step__c LIMIT 1];
        
        Task t = new Task();
        t.Subject = 'Test Task';
        t.Task_Tracker_Template_Step__c = ts.Id;
        insert t;
        
        Task someTask =
            [
                SELECT Id, OwnerId, Task_Tracker_Template_Step__c
                FROM Task
                LIMIT 1
            ];

        Test.startTest();

        User coachUser =
            [
                SELECT Id
                FROM User
                WHERE IsActive = true
                    AND Id != :someTask.OwnerId
                LIMIT 1
            ];

        Task_Tracker_Template_Step__c someStep = new Task_Tracker_Template_Step__c (
            Id = someTask.Task_Tracker_Template_Step__c,
            Assigned_Role__c = 'Coach'
        );
        update someStep;

        Default_Role__c coachRole = new Default_Role__c (
            Opportunity__c = opp.Id,
            Role__c = 'Coach',
            Name = 'Coach',
            Assigned_User__c = coachUser.Id
        );
        insert coachRole;

        Test.stopTest();

        //System.assertEquals(coachUser.Id, [SELECT Id, OwnerId FROM Task WHERE Id = :someTask.Id].OwnerId, 'The coach should own the task now.');
    }
}