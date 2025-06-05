/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 05-09-2022
 * @last modified by  : Brian Ezell (Slalom)
**/

//Run Batch
/*
    Id batchJobId = Database.executeBatch(new ImportTaskTrackerBatchable(), 200);
    System.debug('Job Id = ' + batchJobId);
*/

public with sharing class ImportTaskTrackerBatchable implements Database.Batchable<Prolaw_Conversion__c> {
    
    private static List<Matter_Rate__mdt> defaultRates =
        [
            SELECT Id, Hourly_Rate__c, Role__c
            FROM Matter_Rate__mdt
        ];

    private static Group paralegalQueue = [SELECT Id, Name, Type from Group WHERE Type = 'Queue' AND Name = 'Paralegal' LIMIT 1];

    //Gets loaded before creating cases/tasks
    private Map<Id, Task_Tracker_Template__c> mapMatterIdToTopLevelTemplate = new Map<Id, Task_Tracker_Template__c>();
    private Map<Id, CalculatedTemplateParameters> mapTopLevelTemplateIdToCalculatedTemplateParams = new Map<Id, CalculatedTemplateParameters>();
    private Map<Id, Id> mapProductIdToTopLevelTemplateId = new Map<Id, Id>();
    private Map<Id, Task_Tracker_Template__c> mapTemplateIdToTemplate = new Map<Id, Task_Tracker_Template__c>();
    private Map<Id, Integer> mapStepIdToDependencyCount = new Map<Id, Integer>();
    private List<Task_Tracker_Task_Dependency__c> newTaskDepends = new List<Task_Tracker_Task_Dependency__c	>();

    private Map<Id, AcctSeed__Project__c> mapProlawConversionIdToMatter = new Map<Id, AcctSeed__Project__c>();
    private Map<Id, Prolaw_Conversion__c> mapProlawConversionIdToProlawConversion = new Map<Id, Prolaw_Conversion__c>();

    public System.Iterable<Prolaw_Conversion__c> start(Database.BatchableContext ctx) {
        return 
            [
                SELECT Id, Assigned_Attorney_Id__c, Assigned_Paralegal_Id__c, CES_Id__c, Matter_Name__c, Product_Lookup__c,
                    Product_Id__c, Product_Name__c, Related_Matter__c, Total_Attorney_Hrs__c, 
                    Total_Matter_Prices__c, Total_Paralegal_Hrs__c,
                    Related_Matter__r.Name, Related_Matter__r.AcctSeed__Account__c, 
                    Related_Matter__r.OwnerId
                FROM Prolaw_Conversion__c
                WHERE Related_Matter__r.AcctSeed__Status__c = 'Conversion'
                    AND Was_Processed__c = false
            ];
     }

    public void execute(Database.BatchableContext  ctx, List<Prolaw_Conversion__c> scope) {

        System.debug('scope = ' + scope);
        System.debug('defaultRates = ' + defaultRates.size());

        Map<Id, Id> mapMatterIdToTopCaseId = new Map<Id, Id>(); 
        List<Prolaw_Conversion__c> updateConversions = new List<Prolaw_Conversion__c>();
        loadMatterToTemplateMap(scope);

        System.debug('Executing prolaw conversions count = ' + scope.size());

        for(Id pcId : mapProlawConversionIdToMatter.keySet()) {
            createOneTaskTracker(pcId);
            updateConversions.add(new Prolaw_Conversion__c (
                Id = pcId,
                Was_Processed__c = true
            ));
        }
        update updateConversions;
    }

    public void finish(Database.BatchableContext ctx) {
        insert newTaskDepends;
    }
    
    /**
    * @description Loads a map of matter id => top level task tracker template ids
    * @author Brian Ezell (Slalom) | 11-27-2021 
    * @param matters 
    **/
    private void loadMatterToTemplateMap(List<Prolaw_Conversion__c> scope) {

        //Need to look up products
        //Then, map from product to the lookup of the 
        //template id.
        Set<Id> productIds  = new Set<Id>();
        Map<Id, AcctSeed__Project__c> mapMatterIdToMatter = new Map<Id, AcctSeed__Project__c>();

        for(Prolaw_Conversion__c pc : scope) {
            productIds.add(pc.Product_Id__c);
            mapProlawConversionIdToMatter.put(pc.Id, new AcctSeed__Project__c(
                Id = pc.Related_Matter__c,
                Name = pc.Related_Matter__r.Name,
                AcctSeed__Account__c = pc.Related_Matter__r.AcctSeed__Account__c,
                OwnerId = pc.Related_Matter__r.OwnerId
            ));
            mapProlawConversionIdToProlawConversion.put(pc.Id, pc);
        }

        Map<Id, Product2> mapProductIdToProduct = new Map<Id, Product2> (
            [
                SELECT Id, Task_Tracker_Template__c
                FROM  Product2
                WHERE Id = :productIds
            ]);

        Set<Id> templateIds = new Set<Id>();
        for(Product2 p : mapProductIdToProduct.values()) {
            mapProductIdToTopLevelTemplateId.put(p.Id, Id.valueOf(p.Task_Tracker_Template__c));
            templateIds.add(p.Task_Tracker_Template__c);
        }

        //Now we have a list of products
        mapTemplateIdToTemplate = new Map<Id, Task_Tracker_Template__c> (
            [
                SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Parent_Template__c, Parent_Template__r.Name, Templated_Name__c, Template_Type__c,
                    Case_Type__c, Record_Owner__c, Role__c, Order__c, Top_Level_Task_Template__c, 
                    (
                        SELECT Id, Name, Description__c, Task_Owner__c, Templated_Name__c, Assigned_Role__c, Assigned_User__c, Hours__c,
                            Duration_In_Days__c, Step_Order__c, Activity_Type__c, Days_Out_Type__c, Instructions__c, Anticipated_Completion_Days__c,
                            Rate__c, Attorney_Hours__c, Paralegal_Hours__c
                        FROM Task_Tracker_Template_Steps__r
                        ORDER BY Step_Order__c
                    )
                    , (
                        SELECT Id, Name, Is_Active__c, Total_Number_Of_Steps__c, Templated_Name__c, Template_Type__c, Role__c,
                            Case_Type__c, Record_Owner__c, Order__c
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
                WHERE Top_Level_Task_Template__c = :templateIds
        ]);

        //Map each matter to the top level template
        for(Prolaw_Conversion__c s : scope) {
            Id productId = mapProductIdToProduct.get(s.Product_Id__c).Task_Tracker_Template__c;
            mapMatterIdToTopLevelTemplate.put(s.Related_Matter__c, mapTemplateIdToTemplate.get(productId));
        }

        Set<String> stepIds = new Set<String>();

        //Calculate the total hours and assignments for the templates
        for(Task_Tracker_Template__c t : mapTemplateIdToTemplate.values()) {
            Id topLevelTemplateId = t.Top_Level_Task_Template__c;
            CalculatedTemplateParameters calcParams = mapTopLevelTemplateIdToCalculatedTemplateParams.get(Id.valueOf(topLevelTemplateId));
            if(calcParams == null) {
                calcParams = new CalculatedTemplateParameters();
            }
            for(Task_Tracker_Template_Step__c s : t.Task_Tracker_Template_Steps__r) {
                
                calcParams.totalAttorneyHours += s.Attorney_Hours__c == null ? 
                    0 : 
                    s.Attorney_Hours__c;
                calcParams.totalParalegalHours += s.Paralegal_Hours__c == null ? 
                    0 : 
                    s.Paralegal_Hours__c;
                stepIds.add(s.Id);
            }

            mapTopLevelTemplateIdToCalculatedTemplateParams.put(Id.valueOf(topLevelTemplateId), calcParams);
        }

        //Calculate the pro rata pct for attorney and paralegal
        //These will get related to each of the prolaw conversion objects
        for(Prolaw_Conversion__c s : scope) {
            Id templateId = mapProductIdToProduct.get(s.Product_Id__c).Task_Tracker_Template__c;
            CalculatedTemplateParameters calcParams = mapTopLevelTemplateIdToCalculatedTemplateParams.get(templateId);

            if(calcParams != null) {
                calcParams.attorneyHoursPct = calcParams.totalAttorneyHours == 0 ? 
                    0 : 
                    s.Total_Attorney_Hrs__c / calcParams.totalAttorneyHours;
                calcParams.paraLegalHoursPct = calcParams.totalParalegalHours == 0 ? 
                    0 :
                    s.Total_Paralegal_Hrs__c / calcParams.totalParalegalHours;
            } 
        }

        //Determine how many dependencies
        List<AggregateResult> stepCountDependencies =
            [
                SELECT Step__c, COUNT(Depends_On_Step__c) DependentCount
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :stepIds
                GROUP BY Step__c
            ];

        for(AggregateResult r : stepCountDependencies) {
            mapStepIdToDependencyCount.put(String.valueOf(r.get('Step__c')), Integer.valueOf(r.get('DependentCount')));
        }
    }

    private void createOneTaskTracker(Id pcId) {

        AcctSeed__Project__c matter = mapProlawConversionIdToMatter.get(pcId);
        Prolaw_Conversion__c prolawConversion = mapProlawConversionIdToProlawConversion.get(pcId);

        System.debug('matter = ' + matter);
        System.debug('prolawConversion = ' + prolawConversion);

        //1) Create the roles/rates
        List<Project_Rate__c> projectRates = new List<Project_Rate__c>();
        for(Matter_Rate__mdt r : defaultRates) {
            projectRates.add(New Project_Rate__c(
                Name = r.Role__c,
                Role__c = r.Role__c,
                Hourly_Rate__c = r.Hourly_Rate__c,
                Project__c = matter.Id
            ));
        }
        insert projectRates;

        System.debug('Conversion = ' + matter);

        Id topLevelTemplateId = mapProductIdToTopLevelTemplateId.get(Id.valueOf(prolawConversion.Product_Id__c));
        List<Task> allTasks = new List<Task>();
        Map<Id, Task> mapStepIdToTasks = new Map<Id, Task>();
        CalculatedTemplateParameters calcParams = mapTopLevelTemplateIdToCalculatedTemplateParams.get(topLevelTemplateId);

        System.debug('mapTopLevelTemplateIdToCalculatedTemplateParams = ' + mapTopLevelTemplateIdToCalculatedTemplateParams);
        System.debug('mapTemplateIdToTemplate = ' + mapTemplateIdToTemplate);

        //Create the map so we can insert all the records at once and keep track of
        //parent/child relationships
        Map<Case, List<Task>> mapCaseToTasks = new Map<Case, List<Task>>();

        //Map the template to the case so we can look these up after inserting
        //to get parent/child relationships setup
        Map<Id, Case> mapTaskTrackerTemplateIdToCase = new Map<Id, Case>();
        
        System.debug('mapTemplateIdToTemplate = ' + mapTemplateIdToTemplate.values().size());

        for(Task_Tracker_Template__c t : mapTemplateIdToTemplate.values()) {
            String caseTemplatedName = t.Templated_Name__c == null ?
                t.Name : t.Templated_Name__c.replace('[Name]', matter.Name);

            Case newCase = new Case (
                Task_Tracker_Template__c = t.Id,
                AccountId = matter.AcctSeed__Account__c,
                OwnerId = matter.OwnerId,
                Tasks_To_Complete__c = t.Total_Number_Of_Steps__c,
                Tasks_Completed__c = 0,
                Subject = caseTemplatedName,
                Type = t.Case_Type__c,
                Order__c = t.Order__c,
                Project__c = matter.Id
            );
            mapTaskTrackerTemplateIdToCase.put(t.Id, newCase);
        }

        System.debug('Inserting mapTaskTrackerTemplateIdToCase.values() = ' + mapTaskTrackerTemplateIdToCase.size());

        insert mapTaskTrackerTemplateIdToCase.values();
        Id topLevelCaseId = null;

        List<Case> updateCases = new List<Case>();
        for(Id tId : mapTaskTrackerTemplateIdToCase.keySet()) {

            Task_Tracker_Template__c currentTemplate = mapTemplateIdToTemplate.get(tId);

            if(topLevelCaseId == null) {
                topLevelCaseId = mapTaskTrackerTemplateIdToCase.get(currentTemplate.Top_Level_Task_Template__c).Id;
            }

            Case currentCase = mapTaskTrackerTemplateIdToCase.get(tId);

            //For case updates (parent case, top level case, etc.)
            Case updateCase = new Case (
                Id = currentCase.Id
            );  

            System.debug('currentTemplate = ' + currentTemplate);
            System.debug('topLevelCaseId = ' + topLevelCaseId);

            System.debug('currentTemplate.Parent_Template__c = ' + currentTemplate.Parent_Template__c);
            System.debug('mapTaskTrackerTemplateIdToCase = ' + mapTaskTrackerTemplateIdToCase.keySet());

            //Update the case parents.
            if(currentTemplate.Parent_Template__c != null && mapTaskTrackerTemplateIdToCase.get(Id.valueOf(currentTemplate.Parent_Template__c)) != null) {
                updateCase.ParentId = mapTaskTrackerTemplateIdToCase.get(Id.valueOf(currentTemplate.Parent_Template__c)).Id;
            }
            updateCase.Top_Level_Task_Tracker_Case__c = topLevelCaseId;

            updateCases.add(updateCase);

            for(Task_Tracker_Template_Step__c s : currentTemplate.Task_Tracker_Template_Steps__r) {
                String taskSubject = s.Templated_Name__c == null ? s.Name :
                    s.Templated_Name__c.Replace('[Name]', matter.Name).Replace('[StepOrder]', string.valueOf(s.Step_Order__c));

                //The dependency count is used to count down the number of
                //dependent tasks this task is waiting on.  When it gets to 0
                //then this task gets set to "Not Started" and the Activity
                //Date is set from that point.
                Integer dependentCount = mapStepIdToDependencyCount.get(s.Id);
                Date startDate = dependentCount > 0 || s.Duration_In_Days__c == null || s.Days_Out_Type__c == null ? null :
                    HelperFunctions.calculateDateFromActivityDate(s.Days_Out_Type__c, (Integer)s.Duration_In_Days__c);

                System.debug('topLevelTemplateId = ' + topLevelTemplateId);
                System.debug('calcParams = ' + calcParams);
                System.debug('s = ' + s);
                System.debug('prolawConversion = ' + prolawConversion);

                // Default Paralegal Queue
                Task newTask = new Task(
                    ActivityDate = startDate,
                    OwnerId = s.Attorney_Hours__c != null && prolawConversion.Assigned_Attorney_Id__c != null ? 
                        prolawConversion.Assigned_Attorney_Id__c :
                            prolawConversion.Assigned_Paralegal_Id__c != null ? 
                            prolawConversion.Assigned_Paralegal_Id__c : 
                        paralegalQueue.Id,
                    Is_Task_Tracker_Created__c = true,
                    Subject = taskSubject,
                    Task_Tracker_Template_Step__c = s.Id,
                    Dependent_Tasks_To_Complete__c = dependentCount,
                    Status = dependentCount == 0 ? 'Not Started' : 'Waiting On Other Tasks',
                    Order__c = s.Step_Order__c,
                    Description = s.Description__c,
                    WhatId = currentCase.Id,
                    Hours__c = s.Attorney_Hours__c != null ? 
                        s.Attorney_Hours__c * calcParams.attorneyHoursPct :
                        s.Paralegal_Hours__c != null ? 
                            s.Paralegal_Hours__c * calcParams.paraLegalHoursPct :
                            0,
                    IsVisibleInSelfService = true,
                    Instructions__c = s.Instructions__c,
                    Anticipated_Completion_Days__c = s.Anticipated_Completion_Days__c,
                    Matter__c = matter.Id,
                    Billing_Rate__c = s.Rate__c
                );

                mapStepIdToTasks.put(s.Id, newTask);
            }
        }
        update updateCases;
        System.debug('insert mapStepIdToTasks.values(); = ' + mapStepIdToTasks.values().size());
        insert mapStepIdToTasks.values();

        createTaskDependencies(mapStepIdToTasks);
    }

    private void createTaskDependencies(Map<Id, Task> mapStepIdToTasks) {
        List<Task_Tracker_Step_Dependency__c> depends =
            [
                SELECT Id, Step__c, Depends_On_Step__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c = :mapStepIdToTasks.keySet()
                    OR Depends_On_Step__c = :mapStepIdToTasks.keySet()
            ];
        for(Task_Tracker_Step_Dependency__c d : depends) {
            if(mapStepIdToTasks.containsKey(d.Step__c) && mapStepIdToTasks.containsKey(d.Depends_On_Step__c)) {
                newTaskDepends.add(new Task_Tracker_Task_Dependency__c (
                    Task_Id__c = mapStepIdToTasks.get(d.Step__c).Id,
                    Task_Depends_On_Id__c = mapStepIdToTasks.get(d.Depends_On_Step__c).Id
                ));
            }
        }
        //The newTaskDepends get inserted inside the finish() statement of the batch to avoid
        //excessive DML statements
    }

    public class CalculatedTemplateParameters {
        public CalculatedTemplateParameters() {
            attorneyHoursPct = 0;
            paraLegalHoursPct = 0;
            totalAttorneyHours = 0;
            totalParalegalHours = 0;
        }

        public Decimal attorneyHoursPct;
        public Decimal paraLegalHoursPct;

        public Decimal totalAttorneyHours;
        public Decimal totalParalegalHours;
    }
}