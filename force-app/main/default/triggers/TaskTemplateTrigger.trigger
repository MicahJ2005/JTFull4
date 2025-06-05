/**
 * @File Name          : TaskTemplateTrigger.trigger
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-15-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    3/16/2020   Revolution Group (Brian Ezell)     Initial Version
**/
trigger TaskTemplateTrigger on Task_Tracker_Template__c (after insert, after update) {

    if(!System.isFuture())
    {
        TaskTrackerTemplateTriggerController.onInsertOrUpdate(Trigger.new, Trigger.oldMap);
    }
    
}