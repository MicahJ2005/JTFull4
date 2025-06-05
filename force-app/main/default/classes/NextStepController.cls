/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 06-06-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   02-02-2021   Revolution Group (Brian Ezell)   Initial Version
**/

public with sharing class NextStepController {

    private static Id priceBookId = Test.isRunningTest() ? 
        Test.getStandardPricebookId() :
        [
            SELECT Id
            FROM Pricebook2
            WHERE IsActive = true
            LIMIT 1
        ].Id;

    //Added By Christan Gordon (Revolution Group) on 12/29/2021: Used to create a Next Step Opportunity
    @AuraEnabled
    public static Id createNextStepOpportunity(String oppObj) {
        try {

            System.debug('Opportunity Object String: '+oppObj);

            Opportunity newNextStepOpp = (Opportunity) JSON.deserialize(oppObj, Opportunity.class);
            newNextStepOpp.Pricebook2Id = priceBookId;

            insert newNextStepOpp;

            return newNextStepOpp.Id;
            
        } catch (Exception e) {
            System.debug('***Exception = ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Gets Opportunity Information for Opp
    * @author Revolution Group (Brian Ezell) | 02-02-2021
    * @param oppId
    * @return string
    **/
    @AuraEnabled
    public static string getOpportunity(String oppId){
        try {
            return Json.serialize(
                [
                    SELECT Id, Has_Next_Step_Template_Created__c
                    FROM Opportunity
                    WHERE Id = :oppId
                ]
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Gets a TaskTrackerTemplate object from the templates
    * @author Revolution Group (Brian Ezell) | 02-02-2021
    * @param templateId
    * @return string
    **/
    @AuraEnabled
    public static string getTaskTrackerTemplates(String templateId) {
        try {
            System.debug('getTaskTrackerTemplates - templateId = ' + templateId);
            System.debug('user = ' + UserInfo.getFirstName());
            System.debug('Field Access = ' + Schema.sObjectType.Task_Tracker_Template__c.fields.Top_Level_Task_Template__c.isAccessible());

            Task_Tracker_Template__c template =
                [
                    SELECT Id, Top_Level_Task_Template__c
                    FROM Task_Tracker_Template__c
                    WHERE Id = :templateId
                ];

            System.debug('Past the template lookup');

            List<Task_Tracker_Template__c> templates =
                [
                    SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Parent_Template__r.Name, Templated_Name__c, Template_Type__c,
                        Case_Type__c, Record_Owner__c, Role__c, Order__c,Parent_Template__c,
                        (
                            SELECT Id, Name, Description__c, Task_Owner__c, Task_Tracker_Template__r.Id, Task_Tracker_Template__r.Name, Templated_Name__c, Assigned_Role__c, Assigned_User__c, Hours__c,
                                Duration_In_Days__c, Step_Order__c, Activity_Type__c, Days_Out_Type__c, Instructions__c, Anticipated_Completion_Days__c
                            FROM Task_Tracker_Template_Steps__r
                            ORDER BY Step_Order__c
                        ),
                        (
                            SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Templated_Name__c, Template_Type__c, Role__c,
                                Case_Type__c, Record_Owner__c, Order__c, Parent_Template__c
                            FROM Task_Tracker_Templates__r
                            WHERE Is_Active__c = true
                            ORDER BY Order__c
                        )
                    FROM Task_Tracker_Template__c
                    WHERE Top_Level_Task_Template__c = :template.Top_Level_Task_Template__c
                    ORDER BY Parent_Template__c NULLS FIRST, Order__c, Name
                ];

			//Added By Christan Gordon (Revolution Group) on 1/18/2021: Used to retrieve child task tracker templates related to a task tracker template            
            
            //Used to store all task tracker template subchild records
            //Step #1: Iterate through all the templates and store which records have the same Parent Template field value in a map. Store their Ids
            List<Id> taskTrackerTemplateIds = new List <Id>();
            
            for(Task_Tracker_Template__c oneTemplate : templates){
                    
                    taskTrackerTemplateIds.addAll(new Map<Id, Task_Tracker_Template__c>(oneTemplate.Task_Tracker_Templates__r).keyset());
                
            }
            
            //Re-query these records to see if any of them have child task tracker templates associated to them. Store these records into a map
            Map<Id,Task_Tracker_Template__c> childOfChildTaskTrackerTemplates = new Map<Id,Task_Tracker_Template__c>([
                    SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Parent_Template__r.Name, Parent_Template__c, Templated_Name__c, Template_Type__c,
                        Case_Type__c, Record_Owner__c, Role__c, Order__c,
                        (
                            SELECT Id, Name, Description__c, Task_Tracker_Template__r.Id, Task_Tracker_Template__r.Name, Task_Owner__c, Templated_Name__c, Assigned_Role__c, Assigned_User__c, Hours__c,
                                Duration_In_Days__c, Step_Order__c, Activity_Type__c, Days_Out_Type__c, Instructions__c, Anticipated_Completion_Days__c
                            FROM Task_Tracker_Template_Steps__r
                            ORDER BY Step_Order__c
                        ),
                        (
                            SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Templated_Name__c, Template_Type__c, Role__c,
                                Case_Type__c, Record_Owner__c, Order__c, Parent_Template__c
                            FROM Task_Tracker_Templates__r
                            WHERE Is_Active__c = true
                            ORDER BY Order__c
                        )
                    FROM Task_Tracker_Template__c
                    WHERE Id In :taskTrackerTemplateIds
                    ORDER BY Parent_Template__c NULLS FIRST, Order__c, Name
                ]);
            //Pass this map into getTaskTrackerChildTemplate method for evaluation
            
            TaskTrackerTemplate masterTaskTrackerTemplate = new TaskTrackerTemplate();

            masterTaskTrackerTemplate = getTaskTrackerChildTemplate(templates[0], templates, childOfChildTaskTrackerTemplates);

            List<TaskTrackerTemplate> returnTemplates = new List<TaskTrackerTemplate>{
                masterTaskTrackerTemplate
            };
            //_children is what the lightning tree looks for to find
            //subordinates.
            //
            String result = JSON.serializePretty(returnTemplates).replace('Children', '_children');
            
            System.debug('getTaskTrackerTemplates Output Result: '+result);
            
            return result;
        } catch (Exception e) {
            printException(0, e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void printException(Integer level, Exception e) {
        System.debug('  Exception level = ' + level);
        System.debug('  ' + e.getStackTraceString());
        System.debug('  ' + e.getMessage());

        if(e.getCause() != null) {
            printException(level + 1, e.getCause());
        }
    }

    @AuraEnabled
    public static string createTaskTrackerForNextSteps(String matterId, String oppId, String templateId, String strMap, List<String> selectedTaskIds) {
        //try {

            System.debug('Opportunity Id: '+oppId);
            System.debug('createTaskTrackerForNextSteps - templateId = ' + templateId);

            System.debug('strMap = ' + strMap);
            System.debug('selectedTaskIds = ' + selectedTaskIds);

            //First, we need to add the opportunity line item.
            Product2 prod =
                [
                    SELECT Id
                    FROM Product2
                    WHERE Task_Tracker_Template__c = :templateId
                ];

            System.debug('Product = ' + prod);

            OpportunityLineItem newLineItem = new OpportunityLineItem (
                Product2Id = prod.Id,
                OpportunityId = oppId
            );

            insert newLineItem;

            CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
            input.ObjectName = 'Opportunity';
            input.ObjectId = oppId;
            input.TemplateId = templateId;
            Map<String, Object> mapTaskToString = (Map<String, Object>)JSON.deserializeUntyped(strMap);
            Map<String, Decimal> mapTasksToHours = new Map<String, Decimal>();
            for(String key : mapTaskToString.keySet()) {
                if(selectedTaskIds.contains(key)) {
                    //Modified By Christan Gordon (Revolution Group) on 02/02/2022: Noticed that certain tasks didn't have an associated hour value. Thus, those would return null and not be included created. To resolve this, I modified the criteria so that if the value is null, sets the value for that key to 0.00 to prevent null exception.
                    /*if(mapTaskToString.get(key) != null) {
                        mapTasksToHours.put(key, Decimal.valueOf(String.valueOf(mapTaskToString.get(key))));
                    }*/
                    if(mapTaskToString.get(key) == null) {
                     
                        mapTaskToString.put(key, 0.00);
                    }

                mapTasksToHours.put(key, Decimal.valueOf(String.valueOf(mapTaskToString.get(key))));

            }
        }

            System.debug('Map = ' + mapTasksToHours);
            System.debug('Selected Tasks = ' + selectedTaskIds);

            CreateProcessFlowController processController = new CreateProcessFlowController(input);
            String createProcessResults = processController.ProcessOneInputWithSelectedTasks(input, matterId, mapTasksToHours);

            calculateOpportunityProRata(oppId, templateId, matterId);

            return createProcessResults;
        /*
        } catch (Exception e) {
            System.debug('Error Messsage: '+e.getMessage());
            System.debug('Error Line Number: '+e.getLineNumber());
            System.debug('Error Type: '+e.getTypeName());
            System.debug('Error Stack Track: '+e.getStackTraceString());
            throw new AuraHandledException('Following Error Occurred: '+e.getMessage());
        }
        */
    }

    /**
    * @description Calculates the pro rata price for a next
    *   step opportunity based on how many steps were selected
    *   and the ratio to the oriignal price.
    * @author Revolution Group (Brian Ezell) | 02-25-2021
    * @param oppId
    * @param masterTemplateId
    * @param matterId
    **/
    public static void calculateOpportunityProRata(String oppId, String masterTemplateId, String matterId) {

        List<Task_Tracker_Template__c> templates =
            [
                SELECT Id, Sum_Net_Price__c, Name
                FROM Task_Tracker_Template__c
                WHERE Top_Level_Task_Template__c = :masterTemplateId
            ];
        
        //Added By Christan Gordon (Revolution Group): Added to output task tracker template received
        System.debug('Task Tracker Template Record Recevied: '+templates);

        Decimal sumTemplateNetPrice = 0;
        for(Task_Tracker_Template__c t : templates) {
            System.debug('Task Tracker Template: '+t.Name+' has the following sum net price: '+t.Sum_Net_Price__c);
            sumTemplateNetPrice += t.Sum_Net_Price__c;
            //Added By Christan Gordon (Revolution Group) on 12-20-2021: Used to track the Template Net Price Sum
            System.debug('Total Sum Template Net Price Now Equals: '+sumTemplateNetPrice);
        }

        List<Case> cases =
            [
                SELECT Id
                FROM Case
                WHERE Opportunity__c = :oppId
                    AND Task_Tracker_Template__c = :templates
            ];
        
        //Added By Christan Gordon (Revolution Group) on 12-20-2021: Used to track which cases were retrieved from this above SOQL
        System.debug('Cases Retrieved: '+cases);

        List<Task> tasks =
            [
                SELECT Id, Net_Amount__c, Subject
                FROM Task
                WHERE Matter__c = :matterId
                    And WhatId = :cases
            ];
        
        //Added By Christan Gordon (Revolution Group) on 12-20-2021: Used to track related tasks to the queried case
        System.debug('Related Tasks to Case: '+tasks);

        Decimal sumTaskNetPrice = 0;
        for(Task t : tasks) {
            System.debug('Task: '+t.Subject+' has the following net amount: '+t.Net_Amount__c);
                        
            sumTaskNetPrice += t.Net_Amount__c;
            //Added By Christan Gordon (Revolution Group) on 12-20-2021: Used to track the Sum Task Net Price as it is being added
            System.debug('Sum Task Net Price Now Equals: '+sumTaskNetPrice);
            //
        }

        System.debug('OppId = ' + oppId);
        System.debug('masterTemplateId = ' + masterTemplateId);

        //Brian Ezell (RevGroup)
        //2022.05.25
        //Updated to include all pricing on line item.  ListPrice is showing
        //as the price on the default price book even though it isn't active any more.
        //Using unit price for now - may need total price?

        OpportunityLineItem item =
            [
                SELECT Id, ListPrice, UnitPrice, TotalPrice
                FROM OpportunityLineItem
                WHERE OpportunityId = :oppId
                    AND Task_Template_ID__c = :masterTemplateId
                LIMIT 1
            ];

        System.debug('sumTemplateNetPrice = ' + sumTemplateNetPrice);
        System.debug('sumTaskNetPrice = ' + sumTaskNetPrice);
        System.debug('item.ListPrice = ' + item.ListPrice);

        Decimal initialUpdatePrice = sumTemplateNetPrice == 0 ? 1 : ((sumTaskNetPrice / sumTemplateNetPrice) * item.ListPrice);
        Decimal finalUpdatePrice = OpportunityLineItemHelper.getUpdatedPricing(new List<Decimal> { initialUpdatePrice })[0];

        System.debug('initialUpdatePrice = ' + initialUpdatePrice);
        System.debug('finalUpdatePrice = ' + finalUpdatePrice);

        update new OpportunityLineItem (
            Id = item.Id,
            UnitPrice = finalUpdatePrice
        );
    }

    /**
    * @description Get the TaskTrackerTemplate object from the task tracker template
    * @author Revolution Group (Brian Ezell) | 02-02-2021
    * @param template
    * @return TaskTrackerTemplate
    **/
    private static TaskTrackerTemplate getTaskTrackerChildTemplate(Task_Tracker_Template__c template, List<Task_Tracker_Template__c> allTemplates, Map<Id, Task_Tracker_Template__c> subChildTaskTrackerTemplates) {

        TaskTrackerTemplate trackerTemplate = new TaskTrackerTemplate();
        trackerTemplate.Name = template.Name;
        trackerTemplate.Id = template.Id;
        trackerTemplate.IsSelected = false;
        trackerTemplate.Type = 'Case';
        trackerTemplate.Hours = null;
        
        //Collection to store already processed task tracker templates
        Set <Id> processedTaskIds = new Set <Id>();

        Boolean hasSubTasks = false;
        
        for(Task_Tracker_Template__c t : allTemplates) {
            if(t.Parent_Template__c == template.Id){
                    
                TaskTrackerTemplate subCaseTask = getTaskTrackerChildTemplate(t, new List<Task_Tracker_Template__c>(), new Map<Id,Task_Tracker_Template__c>());
                
                //Check if sub task tracker case template has child task tracker case templates within it
                if(subChildTaskTrackerTemplates.containsKey(t.Id) && subChildTaskTrackerTemplates.get(t.Id).Task_Tracker_Templates__r.size() > 0){
                    
                    //If it does, iterate through it and retrieve their related tasks and steps to include
                    List<TaskTrackerTemplate> subChildTasks = new List<TaskTrackerTemplate>();
                    
                    for(Task_Tracker_Template__c oneSubCaseTask : subChildTaskTrackerTemplates.get(t.Id).Task_Tracker_Templates__r){
                        
                        subCaseTask.Children.addAll(getSubTaskTrackerTask(oneSubCaseTask, subChildTaskTrackerTemplates.values()));
                        
 
                    }
                    
                }    
                
             trackerTemplate.Children.add(subCaseTask); }      
        }
        

        for(Task_Tracker_Template_Step__c s : template.Task_Tracker_Template_Steps__r) {
            
            trackerTemplate.Children.add(
                getTaskTrackerTask(s)
            );
        }
   
        return trackerTemplate;
    }

    /**
    * @description Gets an individual Task Tracker
    * @author Revolution Group (Brian Ezell) | 02-02-2021
    * @param step
    * @return TaskTrackerTask
    **/
    private static TaskTrackerTemplate getTaskTrackerTask(Task_Tracker_Template_Step__c step) {
        TaskTrackerTemplate trackerTask = new TaskTrackerTemplate();
        trackerTask.Id = step.Id;
        trackerTask.IsSelected = false;
        trackerTask.Name = step.Name;
        trackerTask.Type = step.Activity_Type__c;
        trackerTask.Hours = step.Hours__c;
        return trackerTask;
    }
    
    private static List<TaskTrackerTemplate> getSubTaskTrackerTask(Task_Tracker_Template__c subTask, List<Task_Tracker_Template__c> allSubTemplates){
                    
        List<TaskTrackerTemplate> trackerTemplates = new List<TaskTrackerTemplate>();
        
        /*
        List<TaskTrackerTemplate> testTrackerList = new List<TaskTrackerTemplate>();
        List<TaskTrackerTemplate> testTrackerList2 = new List<TaskTrackerTemplate>();
        
        TaskTrackerTemplate trackerTemplate1 = new TaskTrackerTemplate();
        trackerTemplate1.Name = 'Test 1';
        trackerTemplate1.Id = allTemplates[0].Id;
        trackerTemplate1.IsSelected = false;
        trackerTemplate1.Type = 'Case';
        trackerTemplate1.Hours = null;
        
        TaskTrackerTemplate trackerTemplate2 = new TaskTrackerTemplate();
        trackerTemplate2.Name = 'Test 2';
        trackerTemplate2.Id = allTemplates[1].Id;
        trackerTemplate2.IsSelected = false;
        trackerTemplate2.Type = 'Case';
        trackerTemplate2.Hours = null;
        
        testTrackerList.add(trackerTemplate2);
        
        testTrackerList2.add(trackerTemplate1);
        
        trackerTemplate1.Children.addAll(testTrackerList);
        
        trackerTemplate.Children.addAll(testTrackerList2); */
        
        //Collection to store already processed task tracker templates

        for(Task_Tracker_Template__c t : allSubTemplates) {
            if(t.id == subTask.Id){
                trackerTemplates.add(
                		getTaskTrackerChildTemplate(t, allSubTemplates, new Map<Id,Task_Tracker_Template__c>())
            		);
              }       
        }

        for(Task_Tracker_Template_Step__c s : subTask.Task_Tracker_Template_Steps__r) {
            
            trackerTemplates.add(
                getTaskTrackerTask(s)
            );
        }
   
        return trackerTemplates;           
        
    }

    public class TaskTrackerTemplate {
        public TaskTrackerTemplate() {
            Children = new List<TaskTrackerTemplate>();
        }
        public String Name;
        public String Id;
        public String Type;
        public Boolean IsSelected;
        public Decimal Hours;
        public List<TaskTrackerTemplate> Children;
    }
}