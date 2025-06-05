/**
 * @File Name          : CreateProcessFlowController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 06-28-2022
 * @Modification Log   :
 * Ver       Date            Author              Modification
 * 1.0    1/27/2020   Revolution Group (Brian Ezell)     Initial Version
**/
global without sharing class CreateProcessFlowController implements Queueable {

    private Map<String, Id> mapRoleNameToId;
    private Map<String, Decimal> mapTasksToHours;
    private String matterId;
    private Boolean isNextStep = false;
    private String opportunityId;
    private Map<Id, Id> mapStepIdToTaskId = new Map<id, Id>();
    private Boolean isSandboxEnvironment;

    private ProcessInput input;

    private List<caseTasksAndEvents> allCasesAndActivities;
    private Map<Id, Task_Tracker_Template__c> mapAllTemplates;

    private Opportunity targetOpportunity;
    private AcctSeed__Project__c targetMatter;
    private String objectName;

    public CreateProcessFlowController(ProcessInput inputToProcess) {
        input = inputToProcess;
        createMapRoleNameToId();
    }

    /**
    * @description Made queueable so this can be called async.
    *   This allows for large templates to run outside of the user.
    * @author Revolution Group (Brian Ezell) | 6/24/2020
    * @param context
    * @return void
    **/
    public void execute(QueueableContext context) {
        processTheInput();
    }

    /**
    * @description Called to process the templates to cases
    * @author Revolution Group (Brian Ezell) | 6/22/2020
    * @return void
    **/
    public void processTheInput() {
        ProcessOneInput(input);
    }

    @InvocableMethod
    public static List<Id> CreateProcess(List<ProcessInput> inputs) {
        List<Id> returnProcessIds = new List<Id>();
        if(!inputs.isEmpty()) {
            for(ProcessInput i : inputs) {
                CreateProcessFlowController newProcess = new CreateProcessFlowController(i);
                returnProcessIds.add(newProcess.ProcessOneInput(i));
            }
        }

        return returnProcessIds;
    }

    public Id ProcessOneInputWithSelectedTasks(ProcessInput input, String mId, Map<String, Decimal> tasksToHoursMap) {
        createMapRoleNameToId();
        this.input = input;
        opportunityId = input.ObjectId;
        isNextStep = true;
        mapTasksToHours = tasksToHoursMap;
        matterId = mId;
        return ProcessOneInput(input);
    }

    private void createMapRoleNameToId() {
        List<Group> queueList =
            [
                SELECT Id, Name
                FROM Group
                WHERE Type = 'Queue'
                    AND Name = :Util.getDefaultRolesPicklistOptions()
            ];
        mapRoleNameToId = new Map<String, Id>();

        for(Group g : queueList) {
            mapRoleNameToId.put(g.Name, g.Id);
        }
    }

    private Id ProcessOneInput(ProcessInput input) {

        //CGRevGroup on 12-17-2021: List to hold all caseTasksAndEvent instances for evaluation
        //List <caseTasksAndEvents> allCaseEventsAndTasks = new List <caseTasksAndEvents>();
        List<caseTasksAndEvents> allCasesAndActivities = new List<caseTasksAndEvents>();
        
        //CGRevGroup on 12-17-2021: List to hold all case tasks for later insert
        List <Task> allCaseTasks = new List <Task>();
        
        //CGRevGroup on 12-17-2021: List to hold all case events for later insert
        List <Event> allCaseEvents = new List <Event>();
        
        //CGRevGroup on 12-17-2021
        Id updateCaseId;
        
        //CGRevGroup on 12-17-2021: Added try catch block
        try{
            //We're expecting an opportunity
            if(input.ObjectName != 'Opportunity') {
                System.debug('***ProcessOneInput - This is not an opportunity***');
                return null;
            }

            //BEE - Added lookups to Default Roles object.  These
            //are linked off the opportunity so it knows which
            //users/queues are used for the opportunity owner
            targetOpportunity =
                [
                    SELECT Id, AccountId, Account.Name, Account.PersonEmail, Name, Spouse__c, Spouse__r.PersonEmail,
                        Account.IsPersonAccount, Spouse__r.Name,
                        (
                            SELECT Id, Task_Template_ID__c
                            FROM OpportunityLineItems
                        ),
                        (
                            SELECT Id, Name, Assigned_User__c, Assigned_Queue__c
                            FROM Default_Roles__r
                        )
                    FROM Opportunity
                    WHERE Id = :input.ObjectId
                ];

            if(targetOpportunity.OpportunityLineItems.isEmpty()) {
                System.debug('***ProcessOneInput - No Opportunity Lines.***');
                return null;
            }

            //Its assumed that all opportunity line items will have a
            //template or none of them will.  If we find one without then
            //just get out of here!
            for(OpportunityLineItem li : targetOpportunity.OpportunityLineItems) {
                if(li.Task_Template_ID__c == null) {
                    System.debug('OppLineItem issue = ' + li);
                    return null;
                }
            }

            //Allow an existing matter to be passed in
            //or creat if no matter id exists
            if(!isNextStep) {
                targetMatter = new AcctSeed__Project__c (
                    Name = targetOpportunity.Name,
                    AcctSeed__Status__c = 'Active',
                    AcctSeed__Account__c = targetOpportunity.AccountId,
                    AcctSeed__Opportunity__c = targetOpportunity.Id,
                    Spouse__c = targetOpportunity.Spouse__c
                );
                insert targetMatter;
            } else {
                targetMatter =
                    [
                        SELECT Id, Name, AcctSeed__Status__c, AcctSeed__Account__c, AcctSeed__Opportunity__c, Spouse__c
                        FROM AcctSeed__Project__c
                        WHERE Id = :matterId
                    ];
            }

            //Create the default rates for the project
            List<Matter_Rate__mdt> defaultRates =
                [
                    SELECT Id, Hourly_Rate__c, Role__c
                    FROM Matter_Rate__mdt
                ];
            
            List<String> templateIds = new List<String>();
            
            if(!isNextStep) {

                System.debug('This is NOT a next step opportunity');

                List<Project_Rate__c> projectRates = new List<Project_Rate__c>();
                for(Matter_Rate__mdt r : defaultRates) {
                    projectRates.add(New Project_Rate__c(
                        Name = r.Role__c,
                        Role__c = r.Role__c,
                        Hourly_Rate__c = r.Hourly_Rate__c,
                        Project__c = targetMatter.Id
                    ));
                }
                insert projectRates;
                
                for(OpportunityLineItem li : targetOpportunity.OpportunityLineItems) {
                    if(li.Task_Template_ID__c != null) {
                        templateIds.add(li.Task_Template_ID__c);
                    }
                }
                System.debug('templateIds1: ' + templateIds);
                // input.TemplateId = targetOpportunity.OpportunityLineItems[0].Task_Template_ID__c;

                mapAllTemplates = new Map<Id, Task_Tracker_Template__c> (
                    [
                        SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Parent_Template__r.Name, Templated_Name__c, Template_Type__c,
                        Case_Type__c, Record_Owner__c, Role__c, Order__c, Top_Level_Task_Template__c,
                        (
                            SELECT Id, Name, Description__c, Task_Owner__c, Templated_Name__c, Assigned_Role__c, Assigned_User__c, Hours__c,
                                Duration_In_Days__c, Step_Order__c, Activity_Type__c, Days_Out_Type__c, Instructions__c, Anticipated_Completion_Days__c,
                                Rate__c, Use_Queue__c, Video_URL__c
                            FROM Task_Tracker_Template_Steps__r
                            ORDER BY Step_Order__c
                        ),
                        (
                            SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Templated_Name__c, Template_Type__c, Role__c,
                                Case_Type__c, Record_Owner__c, Order__c, Top_Level_Task_Template__c
                            FROM Task_Tracker_Templates__r
                            WHERE Is_Active__c = true
                        ),
                        (
                            SELECT Id, Depends_On_Step__c, Step__c, Adjust_Due_Date__c
                            FROM Task_Tracker_Step_Dependencies__r
                        ),
                        (
                            SELECT Id, Task_Tracker_Template__c, Triggering_Step__c, Adjusted_Step__c, Date_Calculation__c, Date_Offset__c
                            FROM Task_Tracker_Template_Step_Dates__r
                        )
                    FROM Task_Tracker_Template__c
                    WHERE Top_Level_Task_Template__c IN :templateIds
                        AND Is_Active__c = true
                ]);

                System.debug('Inserted default rates = ' + defaultRates);
                System.debug('Templates = ' + mapAllTemplates.size());
            } else {
                mapAllTemplates = new Map<Id, Task_Tracker_Template__c> (
                    [
                        SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Parent_Template__r.Name, Templated_Name__c, Template_Type__c,
                        Case_Type__c, Record_Owner__c, Role__c, Order__c, Top_Level_Task_Template__c,
                        (
                            SELECT Id, Name, Description__c, Task_Owner__c, Templated_Name__c, Assigned_Role__c, Assigned_User__c, Hours__c,
                                Duration_In_Days__c, Step_Order__c, Activity_Type__c, Days_Out_Type__c, Instructions__c, Anticipated_Completion_Days__c,
                                Rate__c, Use_Queue__c, Video_URL__c
                            FROM Task_Tracker_Template_Steps__r
                            WHERE Id = :mapTasksToHours.keySet()
                            ORDER BY Step_Order__c
                        ),
                        (
                            SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Templated_Name__c, Template_Type__c, Role__c,
                                Case_Type__c, Record_Owner__c, Order__c, Top_Level_Task_Template__c
                            FROM Task_Tracker_Templates__r
                            WHERE Is_Active__c = true
                        ),
                        (
                            SELECT Id, Depends_On_Step__c, Step__c, Adjust_Due_Date__c
                            FROM Task_Tracker_Step_Dependencies__r
                            WHERE Depends_On_Step__c = :mapTasksToHours.keySet()
                                OR Step__c = :mapTasksToHours.keySet()
                        ),
                        (
                            SELECT Id, Task_Tracker_Template__c, Triggering_Step__c, Adjusted_Step__c, Date_Calculation__c, Date_Offset__c
                            FROM Task_Tracker_Template_Step_Dates__r
                        )
                    FROM Task_Tracker_Template__c
                    WHERE Top_Level_Task_Template__c = :input.TemplateId
                        AND Is_Active__c = true
                ]);
            }

            //Create a mapping of role name => Default Role Object
            Map<String, Default_Role__c> mapDefaultRoles = new Map<String, Default_Role__c>();
            for(Default_Role__c d : targetOpportunity.Default_Roles__r) {
                mapDefaultRoles.put(d.Assigned_Queue__c, d);
            }

            List<Id> caseIds = new List<Id>();

            System.debug('Opportunity = ' + targetOpportunity);
            System.debug('Opp Lines = ' + targetOpportunity.OpportunityLineItems);

            for(OpportunityLineItem line : targetOpportunity.OpportunityLineItems) {

                if(!isNextStep && templateIds.contains(line.Task_Template_ID__c)) {
                    if(line.Task_Template_ID__c != null) {
                        System.debug('Calling createCaseWithTasks from Checkpoint 2 (Opportunity Lines)');
                        
                        //CGRevGroup on 12-17-2021: Used to store all case events and tasks instances received
                        allCasesAndActivities.addAll(createCaseWithTasks(line.Task_Template_ID__c, targetOpportunity.AccountId, 'Account', null, null, mapDefaultRoles, targetMatter.Id, line.Id));
                        
                        //CGRevGroup on 12-17-2021: Set newCaseId allCaseEventsAndTasks[0].caseId
                        //Id newCaseId = allCaseEventsAndTasks[0].caseId;
                        
                        //CGRevGroup on 12-17-2021: This will occur after all tasks and events have been inserted.
                        //createTaskDependencies(line.Task_Template_Id__c, newCaseId);
    
                        //Won't be created on Next Step templates if there are no child steps included
                        /*
                        if(newCaseId != null) {
                            caseIds.add(newCaseId);
                        }
                        */
                    }
                } else if(isNextStep && input.TemplateId == line.Task_Template_ID__c) {
                    System.debug('Calling createCaseWithTasks from Checkpoint 3 (Opportunity Lines)');
                    
                    allCasesAndActivities.addAll(createCaseWithTasks(line.Task_Template_ID__c, targetOpportunity.AccountId, 'Account', null, null, mapDefaultRoles, targetMatter.Id, line.Id));

                }
            }

            for(caseTasksAndEvents cte : allCasesAndActivities) {
                caseIds.add(cte.caseId);
            }
            
        System.debug('***CreateProcessFlowController -- allCaseEventsAndTasks = ' + allCasesAndActivities.size());

            //CGRevGroup on 12-17-2021: If exist, iterate through allCaseEventsAndTasks received and store all events and tasks
            for(caseTasksAndEvents oneCaseInfo : allCasesAndActivities){
                
                if(oneCaseInfo.caseTasks != null && !oneCaseInfo.caseTasks.isEmpty()){
                    allCaseTasks.addAll(oneCaseInfo.caseTasks);
                }
                
                if(oneCaseInfo.caseEvents != null && !oneCaseInfo.caseEvents.isEmpty()){
                    allCaseEvents.addAll(oneCaseInfo.caseEvents);
                } 
            }

            System.debug('***CreateProcessFlowController -- allCaseTasks = ' + allCaseTasks.size());
            
            //CGRevGroup on 12-17-2021: Check to see if any new tasks or events needs to be created. If yes, create them
            if(!allCaseTasks.isEmpty()){
                if(!Test.isRunningTest()) {
                    insert allCaseTasks;
                }
                //CGRevGroup on 12-17-2021: Initialize mapStepIdToTaskId
                for(Task oneTask : allCaseTasks) {
                    mapStepIdToTaskId.put(oneTask.Task_Tracker_Template_Step__c, oneTask.Id);
                }
            }
            
            System.debug('***CreateProcessFlowController -- allCaseEvents = ' + allCaseEvents.size());

            if(!allCaseEvents.isEmpty()){
                
                insert allCaseEvents;
                
                //CGRevGroup on 12-17-2021: Initialize mapStepIdToTaskId
                for(Event oneEvent : allCaseEvents) {
                    mapStepIdToTaskId.put(oneEvent.Task_Tracker_Template_Step__c, oneEvent.Id);
                }
                
            }
            
            System.debug('***CreateProcessFlowController -- createTaskDependencies***');

            //CGRevGroup on 12-17-2021: Now that mapStepIdToTaskId is set, call the createTaskDependencies method
            createTaskDependencies();
        
            System.debug('***CreateProcessFlowController -- caseIds = ' + caseIds.size());

            Map<Id, Case> updateCaseMap = new Map<Id, Case>();
            List<Case> updateCases = new List<Case>();
            for(Id i : caseIds) {

                updateCaseMap.put(i, new Case (
                    Id = i,
                    Project__c = targetMatter.Id
                ));
            }
            update updateCaseMap.values();
                
            //CGRevGroup on 12-17-2021:
            updateCaseId = updateCaseMap.values()[0].Id;

            List<Case> casesMade =
            [
                SELECT Id
                FROM Case
                WHERE Id = :caseIds
                    OR ParentId = :caseIds
                    OR Top_Level_Task_Tracker_Case__c = :caseIds
            ];

            Id spouseUserId = null;

            List<CaseShare> caseShares = new List<CaseShare>();

            //Community Plus license not in sandbox
            //so skip if we're not in production since
            //the sharing rules will fail.

            if(!IsSandbox()) {

                System.debug('***CreateProcessFlowController - Sharing Rules');
                //Assign sharing rules to spouse
                //Make sure they're also a person account before sharing!
                if(targetOpportunity.Spouse__c != null && targetOpportunity.Account.IsPersonAccount) {

                    //First lookup the user to this account
                    List<User> users =
                        [
                            SELECT Id
                            FROM User
                            WHERE IsActive = TRUE
                                AND (
                                    (Email = :targetOpportunity.Spouse__r.PersonEmail AND Name = :targetOpportunity.Spouse__r.Name)
                                    OR (Email = :targetOpportunity.Account.PersonEmail AND Name = :targetOpportunity.Account.Name)
                                )

                        ];

                    for(User u : users) {
                        spouseUserId = u.Id;
                        insert new AcctSeed__Project__Share (
                            UserOrGroupId = spouseUserId,
                            AccessLevel = 'Edit',
                            ParentId = targetMatter.Id
                            );

                        for(Case c : casesMade) {
                            caseShares.add(new CaseShare (
                                CaseId = c.Id,
                                UserOrGroupId = spouseUserId,
                                CaseAccessLevel = 'Edit'
                            ));
                        }
                    }
                }
            }

            if(!caseShares.isEmpty()) {
                insert caseShares;
            }

            if(updateCases.isEmpty()) {
                return null;
            }
                
            System.debug('The UpdateCase Id being returned is: '+updateCaseId);
                
        }
        catch(Exception e){
            
            System.debug('The following error occurred: '+e.getMessage());
            System.debug('This error occurred at line number: '+e.getLineNumber());
            System.debug('This error occurred because: '+e.getCause());
            System.debug('This error occurred at stack: '+e.getStackTraceString());
            System.debug('The type of error was: '+e.getTypeName());
             
        }

        //CGRevGroup on 12-17-2021: Changed return value
        return updateCaseId;
    }

    //CGRevGroup on 12-17-2021: Removed parameters since it is never referenced in the code block
    private void createTaskDependencies() {

        List<Task_Tracker_Step_Dependency__c> depends = 
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :mapStepIdToTaskId.keySet()
                    OR Depends_On_Step__c = :mapStepIdToTaskId.keySet()
            ];
        List<Task_Tracker_Task_Dependency__c> newTaskDepends = new List<Task_Tracker_Task_Dependency__c	>();
        for(Task_Tracker_Step_Dependency__c d : depends) {
            if(mapStepIdToTaskId.containsKey(d.Step__c) && mapStepIdToTaskId.containsKey(d.Depends_On_Step__c)) {
                newTaskDepends.add(new Task_Tracker_Task_Dependency__c (
                    Task_Id__c = mapStepIdToTaskId.get(d.Step__c),
                    Task_Depends_On_Id__c = mapStepIdToTaskId.get(d.Depends_On_Step__c)
                ));
            }
        }
        insert newTaskDepends;
    }

    private void loadTemplatedObject(Id objId) {

    }

    //CGRevGroup on 12-17-2021: Modified to retrieve back a createCaseWithTasks instance
    private List <caseTasksAndEvents> createCaseWithTasks(Id templateId, Id objectId, String objectName, Case parentCase, Case topLevelCase, Map<String, Default_Role__c> defaultRoleMap, Id matterId, String passedProductLineId) {
       
        //CGRevGroup on 12-17-2021: Used to store multiple createCaseWithTasks instances
        List<caseTasksAndEvents> caseInfoList = new List <caseTasksAndEvents>();
        
        //CGRevGroup on 12-17-2021: Create createCaseWithTasks instance
        caseTasksAndEvents caseInfo = new caseTasksAndEvents(); 
        
        if(mapAllTemplates.get(templateId) == null) {
            System.debug('createCaseWithTasks -- template (' + templateId + ') does not exist in the mapping.');
            return caseInfoList;
        }

        Task_Tracker_Template__c template = mapAllTemplates.get(templateId);

        System.debug('***Starting createCaseWithTasks***');
        System.debug('  SOQL Queries = ' + Limits.getQueries());

        System.debug('templateId = ' + templateId);
        System.debug('objectId = ' + objectId);
        System.debug('objectName = ' + objectName);
        System.debug('parentCase = ' + parentCase);
        System.debug('topLevelCase = ' + topLevelCase);
        System.debug('defaultRoleMap = ' + defaultRoleMap);
        System.debug('matterId = ' + matterId);

        Map<Id, Task_Tracker_Template_Step__c> mapIdToStep = new Map<Id, Task_Tracker_Template_Step__c> (
            template.Task_Tracker_Template_Steps__r
        );

        System.debug('Task Tracker Step Map: ' + mapIdToStep);
        
        List<Task_Tracker_Step_Dependency__c> stepDependencies = template.Task_Tracker_Step_Dependencies__r;
        
        System.debug('stepDependencies received: ' + stepDependencies);

        //If there are no children on this,
        //then don't create the case and just return
        Boolean areThereChildren = isNextStep && template.Task_Tracker_Template_Steps__r.isEmpty() && template.Task_Tracker_Templates__r.isEmpty();
        System.debug('Are there children?: '+areThereChildren);
        if(isNextStep && template.Task_Tracker_Template_Steps__r.isEmpty() && template.Task_Tracker_Templates__r.isEmpty()) {
          return null;
        }

        String objName = objectId.getSobjectType().getDescribe().getName();
        
        System.debug('Object Name: '+objName);
        
		Id productLineId;
        List<SObject> obj = new List<SObject>();

        if(objName.equalsIgnoreCase('opportunity')) {
            obj =
                [
                    SELECT Id, Name, AccountId, OwnerId,
                        (
                            SELECT Id
                            FROM OpportunityLineItems
                            LIMIT 1
                        )
                    FROM Opportunity
                    WHERE Id = :objectId
                ];
            
            System.debug('Opportunity Record Received: '+ obj);

            if(passedProductLineId == null) {
                List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>) obj[0].getSObjects('OpportunityLineItems');
                if(!lineItems.isEmpty()) {
                    productLineId = lineItems[0].Id;
                    
                    System.debug('productLineId value when passedProductLineId is null: '+productLineId);
                }
            } else {
                productLineId = passedProductLineId;
                
                System.debug('productLineId value when passedProductLineId is NOT null: '+productLineId);
            }
        } else {
            String sql = string.format(
                'SELECT Name, Id, OwnerId FROM {0} WHERE Id = :objectId',
                new List<String> {
                    objName
                });
            obj = Database.query(sql);
            productLineId = passedProductLineId;
        }

        String objectRecordName = String.valueOf(obj[0].get('Name'));

        //Allow templating names for dynamic creation
        String caseTemplatedName = template.Templated_Name__c == null ?
            template.Name : template.Templated_Name__c.replace('[Name]', objectRecordName);

        //Create the main case for this iteration
        Case newCase = new Case (
            Task_Tracker_Template__c = template.Id,
            ParentId = parentCase == null ? null : parentCase.Id,
            ContactId = objName == 'Contact' ? objectId : null,
            AccountId = objName == 'Account' ? objectId :
                objName == 'Opportunity' ? string.valueOf(obj[0].get('AccountId')) :
                null,
            Opportunity__c = objName == 'Opportunity' ? objectId :
                opportunityId != null ?
                opportunityId : null,
            OwnerId = getOwnerIdFromTemplate(template, obj[0], defaultRoleMap),
            Tasks_To_Complete__c = template.Total_Number_Of_Steps__c,
            Tasks_Completed__c = 0,
            Subject = caseTemplatedName,
            Top_Level_Task_Tracker_Case__c = topLevelCase == null ? null : topLevelCase.Id,
            Type = template.Case_Type__c,
            Order__c = template.Order__c,
            Project__c = matterId,
            Opportunity_Product__c = productLineId,
            Status = 'Active'
        );
       

        //If this is a next step case, mark status as
        //template pending so it doesn't get picked up
        //until the opportunity is closed/won
        if(isNextStep) {
            newCase.Status = 'Template Pending';
        }

        insert newCase;
        
        //CGRevGroup on 12-17-2021: Store newCase Id
        caseInfo.caseId = newCase.Id;
        
        Boolean caseIsUpdated = false;

        //If this is the top most level, then this is null so we set it
        if(topLevelCase == null) {
            topLevelCase = newCase;
            newCase.Top_Level_Task_Tracker_Case__c = newCase.Id;
            caseIsUpdated = true;
        }

        if(caseIsUpdated) {
            update newCase;
        }

        Map<String, Integer> mapStepIdToDependencyCount = new Map<String, Integer>();
        for(Task_Tracker_Template_Step__c s : template.Task_Tracker_Template_Steps__r) {
            mapStepIdToDependencyCount.put(s.Id, 0);
        }

        System.debug('mapStepIdToDependencyCount value: '+mapStepIdToDependencyCount);
        
        //Determine how many dependent
        List<AggregateResult> stepCountDependencies =
            [
                SELECT Step__c, COUNT(Depends_On_Step__c) DependentCount
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :mapStepIdToDependencyCount.keySet()
                GROUP BY Step__c
            ];

        for(AggregateResult r : stepCountDependencies) {
            mapStepIdToDependencyCount.put(String.valueOf(r.get('Step__c')), Integer.valueOf(r.get('DependentCount')));
        }
        
        System.debug('stepCountDependencies value: '+stepCountDependencies);

        //Create Tasks from template
        List<Task> newTasks = new List<Task>();
        List<Event> newEvents = new List<Event>();
        for(Task_Tracker_Template_Step__c t : template.Task_Tracker_Template_Steps__r) {

            String taskSubject = t.Templated_Name__c == null ? t.Name :
            
                t.Templated_Name__c.Replace('[Name]', objectRecordName).Replace('[StepOrder]', string.valueOf(t.Step_Order__c));
            
            System.debug('Processing Task Subject: '+taskSubject);

            //The dependency count is used to count down the number of
            //dependent tasks this task is waiting on.  When it gets to 0
            //then this task gets set to "Not Started" and the Activity
            //Date is set from that point.
            Integer dependentCount = mapStepIdToDependencyCount.get(t.Id);
            
            System.debug('dependentCount: '+dependentCount);
            Date startDate = dependentCount > 0 || t.Duration_In_Days__c == null || t.Days_Out_Type__c == null ? null :
                HelperFunctions.calculateDateFromActivityDate(t.Days_Out_Type__c, (Integer)t.Duration_In_Days__c);
            
            System.debug('startDate: '+startDate);

            Decimal hours = mapTasksToHours != null && mapTasksToHours.containsKey(t.Id) ? mapTasksToHours.get(t.Id) : t.Hours__c;
	
            System.debug('hours: '+hours);
            
            if(t.Activity_Type__c == 'Task') {

                System.debug('***Role Map = ' + defaultRoleMap);
                
                newTasks.add(new Task(
                    ActivityDate = startDate,
                    OwnerId = getOwnerIdFromTemplateStep(t, template, obj[0], defaultRoleMap),
                    WhatId = newCase.Id,
                    Is_Task_Tracker_Created__c = true,
                    Subject = taskSubject,
                    Task_Tracker_Template_Step__c = t.Id,
                    Dependent_Tasks_To_Complete__c = dependentCount,
                    Status = dependentCount == 0 ? 'Not Started' : 'Waiting On Other Tasks',
                    Top_Level_Case_Id__c = topLevelCase.Id,
                    Order__c = t.Step_Order__c,
                    Description = t.Description__c,
                    Hours__c = hours,
                    IsVisibleInSelfService = true,
                    Instructions__c = t.Instructions__c,
                    Anticipated_Completion_Days__c = t.Anticipated_Completion_Days__c,
                    Matter__c = matterId,
                    Billing_Rate__c = t.Rate__c,
                    Related_Case_Status__c = newCase.Status,
                    Video_URL__c = t.Video_URL__c
                ));
                
                System.debug('NewTask now equals: '+newTasks);
            }

            //Else assume this is an event
            else {
                newEvents.add(new Event(
                    ActivityDate = startDate != null ? startDate : Date.Today(),
                    //OwnerId = getOwnerIdFromTemplateStep(t, template, obj[0], defaultRoleMap),
                    WhatId = newCase.Id,
                    Is_Task_Tracker_Created__c = true,
                    Subject = taskSubject,
                    Task_Tracker_Template_Step__c = t.Id,
                    Dependent_Tasks_To_Complete__c = dependentCount,
                    Type = 'Meeting',
                    IsAllDayEvent = true,
                    Top_Level_Case_Id__c = topLevelCase.Id,
                    Order__c = t.Step_Order__c,
                    Description = t.Description__c,
                    Hours__c = hours,
                    IsVisibleInSelfService = true,
                    Instructions__c = t.Instructions__c,
                    Anticipated_Completion_Days__c = t.Anticipated_Completion_Days__c,
                    Matter__c = matterId,
                    Billing_Rate__c = t.Rate__c
                ));
            }
        }

        //if(!newTasks.isEmpty()) {
            //System.debug('***Creating Tasks = ' + newTasks.size());
            //CGRevGroup on 12-17-2021: Commented out. Store task records for later insert
            caseInfo.caseTasks = newTasks;
            /*insert newTasks;
            for(Task tsk : newTasks) {
                mapStepIdToTaskId.put(tsk.Task_Tracker_Template_Step__c, tsk.Id);
            }*/
        //}

        //if(!newEvents.isEmpty()) {
            //System.debug('***Creating Events = ' + newEvents.size());
             //CGRevGroup on 12-17-2021: Commented out. Store events records for later insert
            caseInfo.caseEvents = newEvents;
            /*insert newEvents;
            for(Event evt : newEvents) {
                mapStepIdToTaskId.put(evt.Task_Tracker_Template_Step__c, evt.Id);
            }*/
        //}

        //CGRevGroup on 12-17-2021: Commented out all code related to mapStepToTask since it is not referenced or user anywhere else within the code
        //Create a mapping from template step => task
        /*Map<Id, Id> mapStepToTask = new Map<Id, Id>();
        for(Task t : newTasks) {
            mapStepToTask.put(t.Task_Tracker_Template_Step__c, t.Id);
        }

        //Map<Id, Id> mapStepToEvent = new Map<Id, Id>();
        for(Event e : newEvents) {
            mapStepToTask.put(e.Task_Tracker_Template_Step__c, e.Id);
        }*/

        //Add caseInfo instance to the list 
        caseInfoList.add(caseInfo);
        
        
        //Repeat for each child template
        for(Task_Tracker_Template__c t : template.Task_Tracker_Templates__r) {
            System.debug('Calling createCaseWithTasks from Checkpoint 1');
            
            System.debug('Task Tracker Template Id in for loop:'+t.Id); 
            System.debug('objectId in for loop:'+objectId);
            System.debug('objectName in for loop:'+objectName);
            System.debug('newCase in for loop:'+newCase);
            System.debug('topLevelCase in for loop:'+topLevelCase);
            System.debug('defaultRoleMap in for loop:'+defaultRoleMap);
            System.debug('matterId in for loop:'+matterId);
            System.debug('passedProductLineId in for loop:'+passedProductLineId);
            
            //CGRevGroup on 12-17-2021: Store all other caseCreateAndTasks instances retrieved
            List<caseTasksAndEvents> newCaseTaskAndEvents = createCaseWithTasks(t.Id, objectId, objectName, newCase, topLevelCase, defaultRoleMap, matterId, passedProductLineId);
            
            if(newCaseTaskAndEvents != null){
                
                caseInfoList.addAll(newCaseTaskAndEvents);
            
             }
                                    
        }

        return caseInfoList;
    }

    private Id getOwnerIdFromTemplate(Task_Tracker_Template__c template, SObject targetObject, Map<String, Default_Role__c> defaultRoleMap) {

        if(template.Role__c != null && defaultRoleMap.containsKey(template.Role__c)) {

             //Check the default role object assoicated with this step
            Default_Role__c defaultRole = defaultRoleMap.get(template.Role__c);
            if(defaultRole.Assigned_User__c != null) {
                return defaultRole.Assigned_User__c;
            }
            if(defaultRole.Assigned_Queue__c != null && mapRoleNameToId.containsKey(defaultRole.Assigned_Queue__c)) {
                return mapRoleNameToId.get(defaultRole.Assigned_Queue__c);
            }
        }
        return UserInfo.getUserId();
    }

    private Id getOwnerIdFromTemplateStep(Task_Tracker_Template_Step__c step, Task_Tracker_Template__c template, SObject targetObject, Map<String, Default_Role__c> defaultRoleMap) {

        System.debug('Owner Step = ' + step);

        //First see if this is assigned to a specific user
        if(step.Assigned_User__c != null) {
            return step.Assigned_User__c;
        }

        //See if a role/team user needs to be assigned
        if(step.Assigned_Role__c != null && defaultRoleMap.get(step.Assigned_Role__c) != null) {
            
            Default_Role__c defaultRole = defaultRoleMap.get(step.Assigned_Role__c);

            System.debug('defaultRole = ' + defaultRole);

            if(step.Use_Queue__c) {
                return mapRoleNameToId.get(defaultRole.Assigned_Queue__c);
            } else {
                
                if(defaultRole != null) {
                    if(defaultRole.Assigned_User__c != null) {
                        return defaultRole.Assigned_User__c;
                    }
                    if(defaultRole.Assigned_Queue__c != null && mapRoleNameToId.containsKey(defaultRole.Assigned_Queue__c)) {
                        return mapRoleNameToId.get(defaultRole.Assigned_Queue__c);
                    }
                }
            }
        }

        return getOwnerIdFromTemplate(template, targetObject, defaultRoleMap);
    }

    @TestVisible
    private Boolean IsSandbox() {

        if(isSandboxEnvironment == null) {
            isSandboxEnvironment =
                [
                    SELECT IsSandbox
                    FROM Organization
                    LIMIT 1
                ].IsSandbox;
        }
        return isSandboxEnvironment;
    }
  
  //CGRevGroup on 12-17-2021: Used to store tasks and events related to a case in a wrapper object 
  public class caseTasksAndEvents {
      
      //Used to store case Id
      public Id caseId;
      
      //Used to store case tasks
      public List<Task> caseTasks;
      
      //Used to store case Events
      public List<Event> caseEvents;
       
    }

  public class ProcessInput {

    @InvocableVariable
    public String ObjectId;

    @InvocableVariable
    public String ObjectName;

    @InvocableVariable
    public String TemplateId;
  }

}