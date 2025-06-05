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
public class DefaultRoleTriggerHandler {
    public static void updateRolesOnTasks() {

        List<Default_Role__c> newRoles = Trigger.New;
        Map<Id, Default_Role__c> oldRoleMap = Trigger.IsInsert ? new Map<Id, Default_Role__c>() : (Map<Id, Default_Role__c>)Trigger.oldMap;

        Set<Id> assignedToUserId = new Set<Id>();

        for(Default_Role__c r : newRoles) {
            Default_Role__c oldRole = oldRoleMap.get(r.Id);
            if((oldRole == null ||(r.Assigned_User__c != oldRole.Assigned_User__c)) && r.Assigned_User__c != null) {
                assignedToUserId.add(r.Id);
            }
        }
        if(!assignedToUserId.isEmpty()) {
            updateRoles(assignedToUserId);
        }
    }

    @Future
    private static void updateRoles(Set<Id> assignedToUserId) {

        List<Task> updateTasks = new List<Task>();

        for(Id rId : assignedToUserId) {

             //Find the opps/matters that are assoicatd with these
            //matter roles
            Default_Role__c defaultRole =
                [
                    SELECT Id, Opportunity__c, Name, Assigned_User__c, Assigned_Queue__c, Assigned_User__r.Name
                    FROM Default_Role__c
                    WHERE Id = :rId
                ];
            System.debug('Default Role = ' + defaultRole);

            //Grab the matter(s) from
            //this default role
            List<AcctSeed__Project__c> matters =
                [
                    SELECT Id,
                        (
                            SELECT Id, Subject
                            FROM Cases__r
                        )
                    FROM AcctSeed__Project__c
                    WHERE AcctSeed__Opportunity__c = :defaultRole.Opportunity__c
                ];

            //Grab a list of the cases directly under the matter
            Set<Id> topLevelCaseIds = new Set<Id>();
            for(AcctSeed__Project__c m : matters) {
                for(Case c : m.Cases__r) {
                    topLevelCaseIds.add(c.Id);
                }
            }

            //Get all of the cases where they are associated to either the matter
            //or cases under the matter
            List<Case> allCases =
                [
                    SELECT Id, Subject, Top_Level_Task_Tracker_Case__c
                    FROM Case
                    WHERE Top_Level_Task_Tracker_Case__c = :topLevelCaseIds
                ];

            //Get a list of all tasks that need to be re-assigned to
            //this user.
            List<Task> allTask =
                [
                    SELECT Id, Subject
                    FROM Task
                    WHERE WhatId = :allCases
                        AND Use_Queue__c = false
                        AND Task_Tracker_Template_Step__r.Assigned_Role__c = :defaultRole.Name
                ];

            for(Task t : allTask) {

                System.debug('Looking at task ' + t.Subject);
                System.debug('Using role ' + defaultRole.Assigned_User__r.Name);

                if(defaultRole.Assigned_User__c != null) {
                    updateTasks.add(new Task(
                        Id = t.Id,
                        OwnerId = defaultRole.Assigned_User__c
                    ));
                }
            }
        }

        if(!updateTasks.isEmpty()) {
            update updateTasks;
        }
    }
}