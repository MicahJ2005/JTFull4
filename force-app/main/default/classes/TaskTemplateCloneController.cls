/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-12-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-01-2020   Revolution Group (Brian Ezell)   Initial Version
**/
public class TaskTemplateCloneController {

    /**
    * @description Clones a template and all steps/sub-templates
        under it
    * @author Revolution Group (Brian Ezell) | 09-01-2020
    * @param templateId
    * @param templateName - name of the new master template
    * @return string
    **/
    @AuraEnabled
    public static string cloneTemplate(String templateId, String templateName) {
        
        List<Task_Tracker_Template__c> template =
            [
              SELECT Id, Top_Level_Task_Template__c
              FROM Task_Tracker_Template__c
              WHERE Id = :templateId
            ];
        if(template.isEmpty()) {
            throw new AuraHandledException('Template not found.');
        }

        Id topLevelTemplateId = template[0].Top_Level_Task_Template__c;
        List<Task_Tracker_Template__c> allTemplates =
            [
                SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Parent_Template__r.Name, Templated_Name__c, Template_Type__c, Order__c,
                    Case_Type__c, Record_Owner__c, Role__c, Top_Level_Task_Template__c,
                    (
                        SELECT Id, Name, Description__c, Task_Owner__c, Templated_Name__c, Task_Tracker_Template__c,
                            Duration_In_Days__c, Step_Order__c, Activity_Type__c, Assigned_Role__c,
                            Assigned_User__c, Hours__c, Anticipated_Completion_Days__c, Instructions__c,
                            Days_Out_Type__c, Use_Queue__c, Video_URL__c, Template_Step_Name_Client_Facing__c
                        FROM Task_Tracker_Template_Steps__r
                        ORDER BY Step_Order__c
                    ),
                    (
                        SELECT Id, Depends_On_Step__c, Step__c, Task_Tracker_Template__c
                        FROM Task_Tracker_Step_Dependencies__r
                    )
                FROM Task_Tracker_Template__c
                WHERE Top_Level_Task_Template__c = :topLevelTemplateId
                    AND Is_Active__c = true
            ];
        
        Task_Tracker_Template__c masterTemplate = null;
        for(Task_Tracker_Template__c t : allTemplates) {
            if(t.Id == topLevelTemplateId) {
                masterTemplate = t;
            }
        }

        //Create the master template first so we can reference it in the
        //Top_Level_Task_Template__c
        Task_Tracker_Template__c newMasterTemplate = new Task_Tracker_Template__c (
            Case_Type__c = masterTemplate.Case_Type__c,
            Is_Active__c = masterTemplate.Is_Active__c,
            Record_Owner__c = masterTemplate.Record_Owner__c,
            Role__c = masterTemplate.Role__c,
            Template_Type__c = masterTemplate.Template_Type__c,
            Name = templateName,
            Order__c = masterTemplate.Order__c
        );
        insert newMasterTemplate;
        
        newMasterTemplate.Top_Level_Task_Template__c = newMasterTemplate.Id;
        update newMasterTemplate;

        Map<Id, Task_Tracker_Template__c> mapOldTemplateIdToNewTemplate = new Map<Id, Task_Tracker_Template__c>();
        for(Task_Tracker_Template__c t : allTemplates) {

            if(t.Id != topLevelTemplateId) {
                Task_Tracker_Template__c ttt = new Task_Tracker_Template__c (
                    Case_Type__c = t.Case_Type__c,
                    Is_Active__c = t.Is_Active__c,
                    Record_Owner__c = t.Record_Owner__c,
                    Role__c = t.Role__c,
                    Template_Type__c = t.Template_Type__c,
                    Top_Level_Task_Template__c = newMasterTemplate.Id,
                    Templated_Name__c = t.Templated_Name__c,
                    Name = t.Name,
                    Order__c = t.Order__c
                );
                
                if(t.Parent_Template__c == templateId) {
                    System.debug('t: ' + t);
                    ttt.Parent_Template__c = newMasterTemplate.Id;
                }
                
                mapOldTemplateIdToNewTemplate.put(t.Id, ttt);
            }
        }
        insert mapOldTemplateIdToNewTemplate.values();

        //Update parents for new templates
        List<Task_Tracker_Template__c> updateTemplatesWithParents = new List<Task_Tracker_Template__c>();
        //Update the parent template values
        for(Task_Tracker_Template__c t : allTemplates) {
            if(mapOldTemplateIdToNewTemplate.containsKey(t.Id) && 
                t.Parent_Template__c != null && 
                mapOldTemplateIdToNewTemplate.get(t.Id) != null && 
                mapOldTemplateIdToNewTemplate.get(t.Parent_Template__c) != null) {
                
                updateTemplatesWithParents.add(new Task_Tracker_Template__c (
                    Id = mapOldTemplateIdToNewTemplate.get(t.Id).Id,
                    Parent_Template__c = t.Parent_Template__c == t.Top_Level_Task_Template__c ?
                        newMasterTemplate.Id :
                        mapOldTemplateIdToNewTemplate.get(t.Parent_Template__c).Id,
                    Top_Level_Task_Template__c = newMasterTemplate.Id
                ));

            }
        }
        update updateTemplatesWithParents;

        //Copy Template Steps
        //After inserting add the new mater template so we can add steps
        mapOldTemplateIdToNewTemplate.put(masterTemplate.Id, newMasterTemplate);

        Map<Id, Task_Tracker_Template_Step__c> mapOldTemplateStepIdToNewTemplateStep = new Map<Id, Task_Tracker_Template_Step__c>();

        for(Task_Tracker_Template__c t : allTemplates) {
            for(Task_Tracker_Template_Step__c s : t.Task_Tracker_Template_Steps__r) {
                mapOldTemplateStepIdToNewTemplateStep.put(
                    s.Id,
                    new Task_Tracker_Template_Step__c (
                        Activity_Type__c = s.Activity_Type__c,
                        Assigned_User__c = s.Assigned_User__c,
                        Description__c = s.Description__c,
                        Duration_In_Days__c = s.Duration_In_Days__c,
                        Step_Order__c = s.Step_Order__c,
                        Task_Owner__c = s.Task_Owner__c,
                        Task_Tracker_Template__c = mapOldTemplateIdToNewTemplate.get(s.Task_Tracker_Template__c).Id,
                        Templated_Name__c = s.Templated_Name__c,
                        Name = s.Name,
                        Assigned_Role__c = s.Assigned_Role__c,
                        Hours__c = s.Hours__c,
                        Anticipated_Completion_Days__c = s.Anticipated_Completion_Days__c,
                        Instructions__c = s.Instructions__c,
                        Days_Out_Type__c = s.Days_Out_Type__c,
                        Use_Queue__c = s.Use_Queue__c,
                        Template_Step_Name_Client_Facing__c = s.Template_Step_Name_Client_Facing__c,
                        Video_URL__c = s.Video_URL__c
                    )
                );
            }
        }
        insert mapOldTemplateStepIdToNewTemplateStep.values();

        List<Task_Tracker_Step_Dependency__c> newDependencies = new List<Task_Tracker_Step_Dependency__c>();
        //Add Step Dependencies
        for(Task_Tracker_Template__c t : allTemplates) {
            for(Task_Tracker_Step_Dependency__c d : t.Task_Tracker_Step_Dependencies__r) {
                if(mapOldTemplateStepIdToNewTemplateStep.get(d.Step__c) != null) {
                    newDependencies.add(new Task_Tracker_Step_Dependency__c (
                        Depends_On_Step__c = mapOldTemplateStepIdToNewTemplateStep.get(d.Depends_On_Step__c).Id,
                        Step__c = mapOldTemplateStepIdToNewTemplateStep.get(d.Step__c).Id,
                        Task_Tracker_Template__c = mapOldTemplateIdToNewTemplate.get(d.Task_Tracker_Template__c).Id
                    ));
                }
            }
        }
        insert newDependencies;
        return String.valueOf(newMasterTemplate.Id);
    }
}