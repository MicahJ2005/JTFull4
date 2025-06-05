/**
 * @File Name          : TaskTrakcerTemplateStepTriggerHandler.trigger
 * @Description        : Handles updates of counts on steps and templates
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 04-29-2021
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    2/7/2020   Revolution Group (Brian Ezell)     Initial Version
**/
trigger TaskTrackerTemplateStepTrigger on Task_Tracker_Template_Step__c (after insert, after delete, after update) {
    if(Trigger.IsInsert) {
        TaskTrackerTemplateStepTriggerHandler.updateTemplateStepCount(Trigger.New, Trigger.oldMap);
    } else if(Trigger.isDelete) {
        TaskTrackerTemplateStepTriggerHandler.updateTemplateStepCount(Trigger.Old, Trigger.newMap);
    }

    Set<Id> templateIds = new Set<Id>();
    if(Trigger.isDelete) {
        for(Task_Tracker_Template_Step__c s : Trigger.old) {
            templateIds.add(s.Task_Tracker_Template__c);
        }
    } else {
        for(Task_Tracker_Template_Step__c s : Trigger.new) {
            templateIds.add(s.Task_Tracker_Template__c);
        }
    }

    TaskTrackerTemplateCalculateQueue queue = new TaskTrackerTemplateCalculateQueue(templateIds);
    System.enqueueJob(queue);
}