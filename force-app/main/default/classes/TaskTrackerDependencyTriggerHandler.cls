/**
 * @File Name          : TaskTrackerDependencyTriggerHandler.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 1/31/2020, 2:27:40 PM
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/31/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public with sharing class TaskTrackerDependencyTriggerHandler {

    /**
    * @description Add the template id to the dependency
    *   from the depends on step id
    * @author Revolution Group (Brian Ezell) | 1/31/2020
    * @param dependencies
    * @return void
    **/
    public static void UpdateTaskTemplate(List<Task_Tracker_Step_Dependency__c> dependencies) {
        Set<Id> stepIds = new Set<Id>();
        for(Task_Tracker_Step_Dependency__c d : dependencies) {
            stepIds.add(d.Depends_On_Step__c);
        }

        Map<Id, Task_Tracker_Template_Step__c> steps = new Map<Id, Task_Tracker_Template_Step__c> (
            [
                SELECT Id, Task_Tracker_Template__c
                FROM Task_Tracker_Template_Step__c
                WHERE Id = :stepIds
            ]);

        for(Task_Tracker_Step_Dependency__c d : dependencies) {
            d.Task_Tracker_Template__c = steps.get(d.Depends_On_Step__c).Task_Tracker_Template__c;
        }

    }

}