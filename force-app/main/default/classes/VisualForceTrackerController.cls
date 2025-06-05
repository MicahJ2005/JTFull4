/**
 * @File Name          : VisualForceTrackerController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-04-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    6/2/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public with sharing class VisualForceTrackerController {

    public String mermaidFlow {get;set;}

    //ApexPages.StandardController controller

    public VisualForceTrackerController() {
        String currentId = ApexPages.currentPage().getParameters().get('id');
        mermaidFlow  = getMermaidForTemplate(currentId);
    }

    public String getMermaidForTemplate(String id) {

        Task_Tracker_Template__c currentTemplate =
            [
                SELECT Id, Top_Level_Task_Template__c
                FROM Task_Tracker_Template__c
                WHERE Id = :id
            ];

        //Get all assoicated templates
        List<Task_Tracker_Template__c> allTemplates =
            [
                SELECT Id, Name, Parent_Template__c,
                    Number_of_Child_Steps__c,
                    (
                        SELECT Id, Name, Activity_Type__c
                        FROM Task_Tracker_Template_Steps__r
                    ),
                    (
                        SELECT Id, Name, Step__c, Depends_On_Step__c
                        FROM Task_Tracker_Step_Dependencies__r
                    )
                FROM Task_Tracker_Template__c
                WHERE Top_Level_Task_Template__c = :currentTemplate.Top_Level_Task_Template__c
                    AND Is_Active__c = true
                ORDER BY Parent_Template__c NULLS FIRST
            ];

        //Get the top level master template, then work
        //downwards
        Task_Tracker_Template__c masterTemplate;
        for(Task_Tracker_Template__c t : allTemplates) {
            if(currentTemplate.Top_Level_Task_Template__c == t.Id) {
                masterTemplate = t;
                break;
            }
        }
        List<String> flowList = new List<String>();
        //flowList.add('graph TB');
        flowList.add('graph LR');

        flowList.addAll(getTemplateFlow(allTemplates, masterTemplate));

        for(Task_Tracker_Template__c t : allTemplates) {
            for(Task_Tracker_Step_Dependency__c d : t.Task_Tracker_Step_Dependencies__r) {
                flowList.add(d.Depends_On_Step__c + '-.->' + d.Step__c);
            }
        }

        for(String s : flowList) {
            System.debug(s);
        }


        return String.join(flowList, '\n\r');
    }

    private List<String> getTemplateFlow(List<Task_Tracker_Template__c> allTemplates, Task_Tracker_Template__c currentTemplate) {
        List<String> flowSteps = new List<String>();

        List<Task_Tracker_Template__c> childTemplates = new List<Task_Tracker_Template__c>();
        for(Task_Tracker_Template__c t : allTemplates) {
            if(t.Parent_Template__c == currentTemplate.Id) {
                childTemplates.add(t);
            }
        }

        flowSteps.add('subgraph ' + cleanStringForMermaid(currentTemplate.Name));

        for(Task_Tracker_Template__c t : childTemplates) {
            flowSteps.addAll(getTemplateFlow(allTemplates, t));
        }

        for(Task_Tracker_Template_Step__c step : currentTemplate.Task_Tracker_Template_Steps__r) {

            if(step.Activity_Type__c == 'Task') {
                flowSteps.add(step.Id + '(' + cleanStringForMermaid(step.Name) + ')');
            } else {
                flowSteps.add(step.Id + '[/' + cleanStringForMermaid(step.Name) + '/]');
            }
        }

        /*
        for(Task_Tracker_Step_Dependency__c d : currentTemplate.Task_Tracker_Step_Dependencies__r) {
            flowSteps.add(d.Depends_On_Step__c + '-->' + d.Step__c);
        }
        */

        flowSteps.add('end');

        return flowSteps;
    }

    private static String cleanStringForMermaid(String str) {
        if (str == null) return null;
        return str.replace('(', '**').
            replace(')', '**').
            replace(';', ' ');
    }
}