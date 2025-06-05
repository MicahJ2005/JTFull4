/**
 * @File Name          : TaskTemplateDiagramController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 11-19-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    2/14/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public class TaskTemplateDiagramController {

    @AuraEnabled
    public static string getTemplateNodes(String templateId){
        Set<Id> templateIdList = new Set<Id>();
        templateIdList.add(templateId);

        List<TaskTemplateNode> templateNodes = getTemplateNodes(templateIdList);
        return Json.serialize(templateNodes);
    }

    @AuraEnabled
    public static void deleteTaskRecord(String recordId) {
        try {

            List<Task_Tracker_Step_Dependency__c> dependencies =
                [
                    SELECT Id
                    FROM Task_Tracker_Step_Dependency__c
                    WHERE Depends_On_Step__c = :recordId
                        OR Step__c = :recordId
                ];
            delete dependencies;

            List<Task_Tracker_Template_Step_Date__c> dates =
                [
                    SELECT Id
                    FROM Task_Tracker_Template_Step_Date__c
                    WHERE Triggering_Step__c = :recordId
                        OR Adjusted_Step__c = :recordId
                ];
            delete dates;

            Task_Tracker_Template_Step__c t =
            [
                SELECT Id
                FROM Task_Tracker_Template_Step__c
                WHERE Id = :recordId
            ];

            System.debug('Task = ' + t);

            delete t;
        } catch (Exception e) {
            System.debug('Error = ' + e);
            throw new AuraHandledException(Util.getExceptionError(e));
        }
    }

    @AuraEnabled
    public static void deleteTemplateRecord(String recordId) {
        try {
            Task_Tracker_Template__c t =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Id = :recordId
            ];

            System.debug('Task = ' + t);

            delete t;
        } catch (Exception e) {
            System.debug('Error = ' + e);
            throw new AuraHandledException(Util.getExceptionError(e));
        }
    }

    private static List<TaskTemplateNode> getTemplateNodes(Set<Id> templateIds) {
        Map<Id, TaskTemplateNode> newTemplates = new Map<Id, TaskTemplateNode>();

        List<Task_Tracker_Template__c> templates =
            [
                SELECT Id, Name, Number_of_Child_Steps__c, Number_Of_Child_Template_Steps__c, Parent_Template__c, Order__c,
                    (
                        SELECT Id, Name, Step_Order__c, Anticipated_Completion_Days__c
                        FROM Task_Tracker_Template_Steps__r
                        ORDER BY Step_Order__c, Name
                    ),
                    (
                        SELECT Id, Name, Number_of_Child_Steps__c, Number_Of_Child_Template_Steps__c, Parent_Template__c
                        FROM Task_Tracker_Templates__r
                        ORDER BY Order__c, Name
                    )
                FROM Task_Tracker_Template__c
                WHERE Id = :templateIds
                ORDER BY Order__c, Name
            ];

        if(templates.isEmpty()) {
            return newTemplates.values();
        }

        Set<Id> templateStepIds = new Set<Id>();
        for(Task_Tracker_Template__c t : templates) {
            TaskTemplateNode templateNode = new TaskTemplateNode();
            templateNode.Id = t.Id;
            templateNode.Name = t.Name;
            templateNode.ParentId = t.Parent_Template__c;
            templateNode.NumberOfChildSteps = t.Number_of_Child_Steps__c;
            templateNode.NumberOfChildTemplateSteps = t.Number_Of_Child_Template_Steps__c;

            Map<Id, Task_Tracker_Template__c> childTemplates = new Map<Id, Task_Tracker_Template__c>(t.Task_Tracker_Templates__r);

            templateNode.ChildTemplateList = getTemplateNodes(childTemplates.keySet());
            templateNode.ChildStepList = getTemplateStepNodes(t);

            newTemplates.put(t.Id, templateNode);
        }

        return newTemplates.values();
    }

    private static List<TaskTemplateStepNode> getTemplateStepNodes(Task_Tracker_Template__c template) {

        Set<Id> templateStepIds = new Set<Id>();
        for(Task_Tracker_Template_Step__c step : template.Task_Tracker_Template_Steps__r) {
            templateStepIds.add(step.Id);
        }

        //Have to re-query since we need dependencies which we can't get
        //2 levels down from SOQL
        List<TaskTemplateStepNode> stepNodes = new List<TaskTemplateStepNode>();
        List<Task_Tracker_Template_Step__c> steps =
            [
                SELECT Id, Name, Hours__c, Step_Order__c, Anticipated_Completion_Days__c,
                    (
                        SELECT Id, Name, Step__r.Name, Depends_On_Step__r.Name, Description__c
                        FROM Task_Tracker_Step_Dependencies__r
                    )
                FROM Task_Tracker_Template_Step__c
                WHERE Id = :templateStepIds
                ORDER BY Step_Order__c, Name
            ];

        //Add each step to the return list
        for(Task_Tracker_Template_Step__c s : steps) {
            TaskTemplateStepNode stepNode = new TaskTemplateStepNode();
            stepNode.Id = s.Id;
            stepNode.Name = s.Name;
            stepNode.Hours = s.Hours__c;
            stepNode.Order = (Integer)s.Step_Order__c;
            stepNode.AnticipatedCompletitionDays = s.Anticipated_Completion_Days__c;

            //Add each dependency to the step dependency list
            for(Task_Tracker_Step_Dependency__c d : s.Task_Tracker_Step_Dependencies__r) {
                TaskTemplateStepDependencyNode depNode = new TaskTemplateStepDependencyNode();
                depNode.StepName = d.Step__r.Name;
                depNode.DependsOnName = d.Depends_On_Step__r.Name;
                depNode.Description = d.Description__c;
                stepNode.DependencyList.add(depNode);
            }

            stepNodes.add(stepNode);
        }

        return stepNodes;
    }

    /*
    private static List<TaskTemplateNode> getTaskTemplateChildNodes(Task_Tracker_Template__c template) {

        List<TaskTemplateNode> childTemplates = new List<TaskTemplateNode>();
        if(!template.Task_Tracker_Templates__r.isEmpty()) {
            for(Task_Tracker_Template__c t : template.Task_Tracker_Templates__r) {
                TaskTemplateNode currentNode = new TaskTemplateNode();
                currentNode.Id = t.Id;
                currentNode.Name = t.Name;
                childTemplates.addAll(getTemplateNodes(t));
            }
        }
        return childTemplates;
    }
    */

    public class TaskTemplateNode {
        public TaskTemplateNode() {
            ChildTemplateList = new List<TaskTemplateNode>();
            ChildStepList = new List<TaskTemplateStepNode>();
            NumberOfChildSteps = 0;
            NumberOfChildTemplateSteps = 0;
        }

        public String Id;
        public String Name;
        public String ParentId;
        public Decimal NumberOfChildSteps;
        public Decimal NumberOfChildTemplateSteps;
        public List<TaskTemplateNode> ChildTemplateList;
        public List<TaskTemplateStepNode> ChildStepList;
    }

    public class TaskTemplateStepNode {

        public TaskTemplateStepNode() {
            DependencyList = new LIst<TaskTemplateStepDependencyNode>();
        }

        public String Id;
        public String Name;
        public Decimal Hours;
        public Integer Order;
        public Decimal AnticipatedCompletitionDays;
        public List<TaskTemplateStepDependencyNode> DependencyList;
    }

    public class TaskTemplateStepDependencyNode {
        public String StepName;
        public string DependsOnName;
        public String Description;
    }

}