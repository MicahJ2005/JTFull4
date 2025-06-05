/**
 * @File Name          : TaskTrackerStepDependencyTrigger.trigger
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 1/31/2020, 2:28:08 PM
 * @Modification Log   :
 * Ver       Date            Author                 Modification
 * 1.0    1/31/2020   Revolution Group (Brian Ezell)     Initial Version
**/
trigger TaskTrackerStepDependencyTrigger on Task_Tracker_Step_Dependency__c(before insert) {

    TaskTrackerDependencyTriggerHandler.UpdateTaskTemplate(Trigger.new);

}