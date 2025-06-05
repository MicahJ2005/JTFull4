/**
 * @File Name          : TaskTrackerTemplateTriggerController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 3/18/2020, 9:55:35 AM
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    3/16/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public with sharing class TaskTrackerTemplateTriggerController {

    public static void onInsertOrUpdate(List<Task_Tracker_Template__c> newTemplates, Map<Id, Task_Tracker_Template__c> oldTemplates) {

        List<Task_Tracker_Template__c> changedTemplates = new List<Task_Tracker_Template__c>();

        if(oldTemplates == null) {
            changedTemplates = newTemplates;
        } else {
            for(Task_Tracker_Template__c t : newTemplates) {
                Task_Tracker_Template__c oldTemplate = oldTemplates.get(t.Id);
                if(t.Parent_Template__c != oldTemplate.Parent_Template__c) {
                    changedTemplates.add(t);
                }
            }
        }
        List<Task_Tracker_Template__c> updateTemplates = new List<Task_Tracker_Template__c>();

        if(!changedTemplates.isEmpty()) {
            updateTopLevelParent(changedTemplates);
        }
    }

    private static void updateTopLevelParent(List<Task_Tracker_Template__c> changedTemplates) {

        Set<Id> parentIds = new Set<Id>();
        for(Task_Tracker_Template__c t : changedTemplates) {
            parentIds.add(t.Parent_Template__c);
        }

        Map<Id, Task_Tracker_Template__c> parentTemplateMap = new Map<Id, Task_Tracker_Template__c> (
            [
                SELECT Id, Top_Level_Task_Template__c, Parent_Template__c
                FROM Task_Tracker_Template__c
                WHERE Id = :parentIds
            ]
        );

        List<Task_Tracker_Template__c> updateTemplates = new List<Task_Tracker_Template__c>();

        for(Task_Tracker_Template__c t : changedTemplates) {
            if(t.Parent_Template__c == null) {
                updateTemplates.add(new Task_Tracker_Template__c(
                    Id = t.Id,
                    Top_Level_Task_Template__c = t.Id
                ));
            } else {
                Task_Tracker_Template__c parent = parentTemplateMap.get(t.Parent_Template__c);
                if(parent != null) {

                    updateTemplates.add(new Task_Tracker_Template__c(
                        Id = t.Id,
                        Top_Level_Task_Template__c = parent.Top_Level_Task_Template__c
                    ));
                }
            }
        }
        update updateTemplates;
    }
}