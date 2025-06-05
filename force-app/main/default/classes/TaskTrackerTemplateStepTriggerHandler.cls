/**
 * @File Name          : TaskTrackerTemplateStepTriggerHandler.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 2/10/2020, 3:05:41 PM
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    2/7/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public class TaskTrackerTemplateStepTriggerHandler {
    /**
    * @description Update count of steps on templates. Because its allowing
    *   multiple level of roll-ups, where templates can have child templates
    *   and steps off the template need to keep track of total number of tasks.
    * @author Revolution Group (Brian Ezell) | 2/7/2020
    * @param newSteps
    * @param oldSteps
    * @return void
    **/
    public static void updateTemplateStepCount(List<Task_Tracker_Template_Step__c> newSteps, Map<Id, Task_Tracker_Template_Step__c> oldSteps) {
        Set<Id> parentTemplateIds = new Set<Id>();
        for(Task_Tracker_Template_Step__c s : newSteps) {
            parentTemplateIds.add(s.Task_Tracker_Template__c);
        }

        updateTemplateLevelCount(parentTemplateIds, 0);
    }

    /**
    * @description Recursively update the templates' step counts
    *   starting at the bottom and working up
    * @author Revolution Group (Brian Ezell) | 2/7/2020
    * @param templateIds
    * @return void
    **/
    private static void updateTemplateLevelCount(Set<Id> templateIds, Integer level) {
        if(templateIds.isEmpty()) {
            return;
        }

        //Start with counting at this level.
        //We'll start rolling up from here.
        List<Task_Tracker_Template__c> templates =
        [
            SELECT Id, Parent_Template__c, Number_Of_Child_Template_Steps__c, Total_Number_Of_Steps__c, Number_of_Child_Steps__c,
                (
                    SELECT Id, Number_Of_Child_Template_Steps__c, Total_Number_Of_Steps__c, Number_of_Child_Steps__c
                    FROM Task_Tracker_Templates__r
                ),
                (
                    SELECT Id
                    FROM Task_Tracker_Template_Steps__r
                )
            FROM Task_Tracker_Template__c
            WHERE Id = :templateIds
        ];

        System.debug('   templates = ' + templates);
        System.debug('   level = ' + level);

        Set<Id> parentTemplates = new Set<Id>();
        List<Task_Tracker_Template__c> updateTemplates = new List<Task_Tracker_Template__c>();
        for(Task_Tracker_Template__c t : templates) {
            Decimal rollupStepCount = 0;

            if(t.Parent_Template__c != null) {
                parentTemplates.add(t.Parent_Template__c);
            }

            for(Task_Tracker_Template__c childTemp : t.Task_Tracker_Templates__r) {
                rollupStepCount += childTemp.Total_Number_Of_Steps__c;
            }

            updateTemplates.add(new Task_Tracker_Template__c(
                Id = t.Id,
                Number_Of_Child_Template_Steps__c = rollupStepCount,
                Number_of_Child_Steps__c = t.Task_Tracker_Template_Steps__r.size()
            ));
        }

        System.debug('   updateTemplates = ' + updateTemplates);

        if(!updateTemplates.isEmpty()) {
            update updateTemplates;
        }

        if(!parentTemplates.isEmpty()) {
            level++;
            updateTemplateLevelCount(parentTemplates, level);
        }
    }
}