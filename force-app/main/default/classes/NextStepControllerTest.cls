/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-20-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   02-09-2021   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class NextStepControllerTest {

    @IsTest
    private static void testGetOpportunity() {
        TaskTrackerTestDataFactory.createAllTestData();
        Id oppId =
            [
                SELECT Id
                FROM Opportunity
                LIMIT 1
            ].Id;
        String oppJson = NextStepController.getOpportunity(oppId);
        List<Opportunity> oppsDeserialized = (List<Opportunity>)JSON.deserialize(oppJson, List<Opportunity>.class);
    }

    @IsTest
    private static void testGetTaskTrackerTemplates() {
        TaskTrackerTestDataFactory.createAllTestData();

        Id templateId =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                LIMIT 1
            ].Id;
        String templateJson = NextStepController.getTaskTrackerTemplates(templateId);
        System.debug('Template = ' + templateJson);
        List<NextStepController.TaskTrackerTemplate> templates = (List<NextStepController.TaskTrackerTemplate>)JSON.deserialize(templateJson, List<NextStepController.TaskTrackerTemplate>.class);
    }
    
    @IsTest
    private static void testCreateTasksForNextStep() {

        TaskTrackerTestDataFactory.createAllTestData();

        Task_Tracker_Settings__c settings = new Task_Tracker_Settings__c (
            Round_To_Nearest__c = 100,
            Then_Subtract__c = 5
        );
        insert settings;

        Opportunity opp =
            [
                SELECT Id, AccountId
                FROM Opportunity
                LIMIT 1
            ];
        Id templateId =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Master_Template__c = true
                LIMIT 1
            ].Id;

        List<Task_Tracker_Template_Step__c> selectedSteps =
            [
                SELECT Id
                FROM Task_Tracker_Template_Step__c
                WHERE Task_Tracker_Template__r.Top_Level_Task_Template__c = :templateId
            ];

        Test.startTest();

        Map<String, Decimal> mapTasksToHours = new Map<String, Decimal>();

        List<String> selectedStepList = new List<String>();
        //Don't add the last item in the list so we can verify
        //that it only creates the selected tasks
        for(Integer i = 0; i < (selectedSteps.size() - 1); i++) {
            selectedStepList.add(selectedSteps[i].Id);
            mapTasksToHours.put(selectedSteps[i].Id, 2);
        }

        AcctSeed__Project__c matter = new AcctSeed__Project__c (
            AcctSeed__Account__c = opp.AccountId,
            Name = 'Test Matter',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        NextStepController.createTaskTrackerForNextSteps(matter.Id, opp.Id, templateId, JSON.serialize(mapTasksToHours), selectedStepList);
        Test.stopTest();

        List<Case> newCases =
            [
                SELECT Id
                FROM Case
                WHERE Project__c = :matter.Id
            ];
        List<Task> tasks =
            [
                SELECT Id
                FROM Task
            ];
    }
    
    //Added By Christan Gordon (Revolution Group) on 02-02-2022: Added to provide success test for the createNextStepOpportunity method
    @isTest
    public static void successTestForCreateNextStepOpportunity() {
        
        //Create an Account record to associate the Next Step Opportunity to
        Account testAccount = new Account(
            Name = 'Test Account'  
        );
        
        //Insert test Account record
        insert testAccount;
        
        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                LIMIT 1
            ];

        //Create a JSON String of a Next Step Opportunity
        Opportunity nextStepOpportunity = new Opportunity (
            Name = 'Opp 001',
            StageName = 'Next Step Opportunity Submitted',
            CloseDate = Date.today().addDays(5),
            AccountId = testAccount.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'No',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId()
        );
        //String nextStepOppJson = '{\"AccountId\":\"'+testAccount.id+'\",\"Area_of_Law__c\":\"Mediation\",\"CloseDate\":\"2022-02-02\",\"Kapsten_Matter__c\":null,\"Name\":\"CGDEV Test #3 - Mediation\",\"Pricebook2Id\":\"01s5w000003PA1tAAG\",\"RecordTypeId\":\"012S0000002PJ1IIAW\",\"Spouse__c\":null,\"StageName\":\"Next Step Opportunity Submitted\"}';
        String nextStepOppJson = JSON.serialize(nextStepOpportunity);

       	//START TEST
       	System.Test.startTest();
        
        //Invoke the createNextStepOpportunity method to test creating the opportunity record
        NextStepController.createNextStepOpportunity(nextStepOppJson);
        
        
        //END TEST
        System.Test.stopTest();
        
        //Evaluate Result
        //If success, there should be at least one opportunity record created
        //For extra assurance, evaluate also that the accountid it is associated to is equal to the testAccount record Id
		List<Opportunity> testOpps = [SELECT ID, AccountId FROM Opportunity];
        
        System.assertEquals(true, !testOpps.isEmpty(),'No Opportunity Record Exists!');
        
        System.assertEquals(testAccount.id, testOpps[0].AccountId, 'The Account record associated to the Opportunity is Different!');
        
    }
    
    //Added By Christan Gordon (Revolution Group) on 02-02-2022: Added to provide error test for the createNextStepOpportunity method
    @isTest
    public static void errorTestForCreateNextStepOpportunity(){
        
       	//START TEST
       	System.Test.startTest();
        
        //Need try-catch blocks catch execution errors
        try{
        //Invoke the createNextStepOpportunity method to test creating the opportunity record
        //To produce and an error, pass an empty string
            NextStepController.createNextStepOpportunity('');
        }
        catch(Exception e){
            System.debug('EXCEPTION!!! ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
       
        //END TEST
        System.Test.stopTest();
        
        //Evaluate Result
        //If error, no opportunity record should have been created
		List<Opportunity> testOpps = [SELECT ID, AccountId FROM Opportunity];
        
        System.assertEquals(true, testOpps.isEmpty(),'An Opportunity Record Exists!');
        
    }
    
}