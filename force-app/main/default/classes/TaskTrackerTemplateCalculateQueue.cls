/**
 * @description       : This updates ONLY the Master Template
 *  with a sum of paralegal and attorney hours
 *  from all of the template steps.
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-29-2021
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   04-29-2021   Revolution Group (Brian Ezell)   Initial Version
**/
public class TaskTrackerTemplateCalculateQueue implements Queueable {

    private Set<Id> templateIds;

    private static Map<Id, Map<String, Decimal>> mapTemplateToTotals = new Map<Id, Map<String, Decimal>>();
    private static Map<Id, Set<Id>> mapParentToChildIds = new Map<Id, Set<Id>>();
    private static Map<Id, Task_Tracker_Template__c> allTemplates = new Map<Id, Task_Tracker_Template__c>();

    public TaskTrackerTemplateCalculateQueue(Set<Id> tIds) {
        templateIds = tIds;
    }

    public void execute(QueueableContext ctx) {
        recalculateTotals(templateIds);
    }

    /**
    * @description Gets master templates and then calls
    *   the calculate recurisvely to get sub totals.
    * @author Revolution Group (Brian Ezell) | 04-29-2021
    * @param templateIds
    **/
    private static void recalculateTotals(Set<Id> templateIds) {

        //Ensure we have the top level master template
        List<Task_Tracker_Template__c> temps =
            [
                SELECT Id, Top_Level_Task_Template__c
                FROM Task_Tracker_Template__c
                WHERE Id = :templateIds
            ];
        Set<Id> topLevelTemplateIds = new Set<Id>();
        for(Task_Tracker_Template__c t : temps) {
            topLevelTemplateIds.add(t.Top_Level_Task_Template__c);
        }

        System.debug('Top Level Ids = ' + topLevelTemplateIds);

        allTemplates = new Map<Id, Task_Tracker_Template__c> (
            [
                SELECT Id, Parent_Template__c, Top_Level_Task_Template__c,
                    (
                        SELECT Id, Hours__c, Assigned_Role__c
                        FROM Task_Tracker_Template_Steps__r
                        ORDER BY Step_Order__c
                    ),
                    (
                        SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Templated_Name__c, Template_Type__c, Role__c,
                            Case_Type__c, Record_Owner__c, Order__c
                        FROM Task_Tracker_Templates__r
                        WHERE Is_Active__c = true
                    )
                FROM Task_Tracker_Template__c
                WHERE Top_Level_Task_Template__c = :topLevelTemplateIds
                    AND Is_Active__c = true
            ]);

        System.debug('All Templates = ' + allTemplates.size());

        //First pass:
        //  Add the first level of child Id's and sum up the tasks directly under
        //  each of the templates.
        for(Task_Tracker_Template__c t : allTemplates.values()) {
            //First update the map of template to set of child template ids - this will be
            //used later to determine what values need to roll up.
            if(!t.Task_Tracker_Templates__r.isEmpty()) {
                mapParentToChildIds.put(t.Id, new Map<Id, Task_Tracker_Template__c> (t.Task_Tracker_Templates__r).keySet());
            } else {
                mapParentToChildIds.put(t.Id, new Set<Id>());
            }

            Map<String, Decimal> mapRoleToHours = new Map<String, Decimal>();
            //Sum up the step hours

            if(t.Task_Tracker_Template_Steps__r != null) {
                for(Task_Tracker_Template_Step__c s : t.Task_Tracker_Template_Steps__r) {
                    if(s.Assigned_Role__c != null && s.Hours__c != null) {
                        System.debug('Assigned Role = ' + s.Assigned_Role__c);
                        System.debug('currHours = ' + s.Hours__c);
                        System.debug('Map = ' + mapRoleToHours);


                        if(!mapRoleToHours.containsKey(s.Assigned_Role__c)) {
                            mapRoleToHours.put(s.Assigned_Role__c, 0);
                        }
                        Decimal currHours = (mapRoleToHours.get(s.Assigned_Role__c) == null ? 0 : mapRoleToHours.get(s.Assigned_Role__c)) + s.Hours__c;
                        mapRoleToHours.put(s.Assigned_Role__c, currHours);
                    }
                }
            }

            mapTemplateToTotals.put(t.Id, mapRoleToHours);
        }

        System.debug('mapTemplateToTotals = ' + mapTemplateToTotals);
        System.debug('mapParentToChildIds = ' + mapParentToChildIds);

        List<Task_Tracker_Template__c> updateTemplates = new List<Task_Tracker_Template__c>();
        //Pass 2:
        //  recurisvely call a function to calculate the
        //  totals for each template.
        for(Task_Tracker_Template__c t : allTemplates.values()) {
            Map<String, Decimal> mapHoursToAssignedRole = getTemplateTotals(t.Id);
            System.debug('Template = ' + t.Id + '||' + mapHoursToAssignedRole);
            updateTemplates.add(new Task_Tracker_Template__c (
                Id = t.Id,
                Total_Attorney_Hours__c = mapHoursToAssignedRole.containsKey('Attorney') ? mapHoursToAssignedRole.get('Attorney') : 0,
                Total_Paralegal_Hours__c = mapHoursToAssignedRole.containsKey('Paralegal') ? mapHoursToAssignedRole.get('Paralegal') : 0
            ));
        }

        update updateTemplates;
    }


    /**
    * @description Recursively go through and figure out each template
    *   based on template and child templates hours.
    * @author Revolution Group (Brian Ezell) | 04-29-2021
    * @param currentTemplateId
    * @return Map<String, Decimal>
    **/
    private static Map<String, Decimal> getTemplateTotals(Id currentTemplateId) {

        System.debug('Current Template = ' + currentTemplateId);

        Map<String, Decimal> mapAssignedRoleToHours = new Map<String, Decimal>();
        Set<Id> childIds = mapParentToChildIds.get(currentTemplateId);
        if(childIds != null && !childIds.isEmpty()) {
            for(Id cId : childIds) {
                if(mapParentToChildIds.containsKey(cId)) {
                    System.debug('Calling for template = ' + cId);
                    Map<String, Decimal> mapChildTotals = getTemplateTotals(cId);
                    mapAssignedRoleToHours = getMergedHourTotals(mapAssignedRoleToHours, mapChildTotals);
                }
            }
        }
        if(mapTemplateToTotals.containsKey(currentTemplateId)) {
            mapAssignedRoleToHours = getMergedHourTotals(mapAssignedRoleToHours, mapTemplateToTotals.get(currentTemplateId));
        }

        System.debug('Returning = ' + mapAssignedRoleToHours);
        return mapAssignedRoleToHours;
    }

    /**
    * @description Adds two sets of totals for a map
    * @author Revolution Group (Brian Ezell) | 04-29-2021
    * @param total1
    * @param total2
    * @return Map<String, Decimal>
    **/
    private static Map<String, Decimal> getMergedHourTotals(Map<String, Decimal> total1, Map<String, Decimal> total2) {

        Map<String, Decimal> meregedValues = new Map<String, Decimal>();
        for(String s : total1.keySet()) {
            meregedValues.putAll(total1);
        }
        for(String s : total2.keySet()) {
            if(meregedValues.containsKey(s)) {
                Decimal currValue = meregedValues.get(s);
                meregedValues.put(s, currValue + total2.get(s));
            } else {
                meregedValues.put(s, total2.get(s));
            }
        }
        return meregedValues;
    }
}