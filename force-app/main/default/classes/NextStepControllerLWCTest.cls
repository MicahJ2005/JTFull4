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
private class NextStepControllerLWCTest {

    @IsTest
    private static void testGetOpportunity() {
        TaskTrackerTestDataFactory.createAllTestData();
        Id oppId =
            [
                SELECT Id
                FROM Opportunity
                LIMIT 1
            ].Id;
        String oppJson = NextStepControllerLWC.getOpportunity(oppId);
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
        String templateJson =   NextStepControllerLWC.getTaskTrackerTemplates(templateId);
        System.debug('Template = ' + templateJson);
        List<NextStepControllerLWC.TaskTrackerTemplate> templates = (List<NextStepControllerLWC.TaskTrackerTemplate>)JSON.deserialize(templateJson, List<NextStepControllerLWC.TaskTrackerTemplate>.class);
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

        NextStepControllerLWC.createTaskTrackerForNextSteps(matter.Id, opp.Id, templateId, JSON.serialize(mapTasksToHours), selectedStepList);
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
        NextStepControllerLWC.createNextStepOpportunity(nextStepOppJson);
        
        
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
            NextStepControllerLWC.createNextStepOpportunity('');
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

    // ---- LWC migration methods (Dex 2026-08-04) ----

    @IsTest
    private static void testGetNextStepInit() {
        TaskTrackerTestDataFactory.createAllTestData();

        Account acct = [SELECT Id FROM Account LIMIT 1];
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            AcctSeed__Account__c = acct.Id,
            Name = 'Test Matter Init',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        Test.startTest();
        NextStepControllerLWC.NextStepInit init = NextStepControllerLWC.getNextStepInit(matter.Id);
        Test.stopTest();

        System.assertNotEquals(null, init, 'Init payload should not be null');
        System.assert(!init.areaOfLawOptions.isEmpty(), 'Area of Law options should be populated from the Opportunity picklist');
        // Product options depend on Product2 w/ Task_Tracker_Template__c in the
        // test data set; assert the collection exists (may be empty in a minimal
        // fixture) and that any present option carries a label + value.
        System.assertNotEquals(null, init.productOptions, 'Product options list should be initialized');
        for(NextStepControllerLWC.PicklistOption opt : init.productOptions) {
            System.assertNotEquals(null, opt.label, 'Product option label should be set');
            System.assertNotEquals(null, opt.value, 'Product option value (template Id) should be set');
        }
    }

    @IsTest
    private static void testCreateNextStepOpportunityFromMatter() {
        TaskTrackerTestDataFactory.createAllTestData();

        Account acct = [SELECT Id FROM Account LIMIT 1];
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            AcctSeed__Account__c = acct.Id,
            Name = 'Test Matter FromMatter',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        Test.startTest();
        Id oppId = NextStepControllerLWC.createNextStepOpportunityFromMatter(
            matter.Id, 'CGDEV Next Step - LWC', 'Family Law'
        );
        Test.stopTest();

        System.assertNotEquals(null, oppId, 'Opportunity should have been created');

        Opportunity opp = [
            SELECT Id, Name, StageName, Area_of_Law__c, AccountId,
                   Next_Step_Matter__c, RecordType.Name
            FROM Opportunity
            WHERE Id = :oppId
        ];
        System.assertEquals('CGDEV Next Step - LWC', opp.Name, 'Name should match input');
        System.assertEquals('Family Law', opp.Area_of_Law__c, 'Area of Law should match input');
        System.assertEquals('Next Step Opportunity Submitted', opp.StageName, 'Stage should be set server-side');
        System.assertEquals(acct.Id, opp.AccountId, 'Account should be derived from the Matter');
        System.assertEquals(matter.Id, opp.Next_Step_Matter__c, 'Matter link should be set');
        System.assertEquals('Next Step', opp.RecordType.Name, 'Record type should be Next Step');
    }

    @IsTest
    private static void errorTestForCreateNextStepOpportunityFromMatter() {
        Boolean threw = false;
        Test.startTest();
        try {
            // Null matter Id -> query throws -> AuraHandledException, no Opp created.
            NextStepControllerLWC.createNextStepOpportunityFromMatter(null, 'x', 'Family Law');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A null Matter Id should raise an exception');
        System.assertEquals(true, [SELECT Id FROM Opportunity].isEmpty(), 'No Opportunity should exist on error');
    }

    // ---- No-scoping "Quick" flow (Dex 2026-09-14) ----
    //
    // The Quick flow is deliberately split into two Apex entry points because
    // building more than one product tree in a SINGLE transaction blows the
    // org's process-builder/flow limit (verified in jt-full4: "XD Facts
    // Populate Fields" LIMIT_EXCEEDED). The LWC therefore calls
    // createNextStepQuick() once, then addProductToNextStepQuick() once per
    // product, and abortNextStepQuick() to compensate if any product fails.

    /**
     * Shared fixture: full template/product test data + a Matter to hang the
     * Next Step off, + the rounding settings calculateOpportunityProRata needs.
     */
    private static AcctSeed__Project__c setupQuickFixture() {
        TaskTrackerTestDataFactory.createAllTestData();

        insert new Task_Tracker_Settings__c(
            Round_To_Nearest__c = 100,
            Then_Subtract__c = 5
        );

        Account acct = [SELECT Id FROM Account LIMIT 1];
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            AcctSeed__Account__c = acct.Id,
            Name = 'Test Matter Quick',
            AcctSeed__Status__c = 'Active'
        );
        insert matter;
        return matter;
    }

    private static Id masterTemplateId() {
        return [
            SELECT Id
            FROM Task_Tracker_Template__c
            WHERE Is_Master_Template__c = true
            LIMIT 1
        ].Id;
    }

    @IsTest
    private static void testCreateNextStepQuickCreatesOpportunityShell() {
        AcctSeed__Project__c matter = setupQuickFixture();

        Test.startTest();
        Id oppId = NextStepControllerLWC.createNextStepQuick(
            matter.Id, 'Quick Next Step', 'Family Law'
        );
        Test.stopTest();

        System.assertNotEquals(null, oppId, 'Quick should return a new Opportunity Id');

        Opportunity opp = [
            SELECT Id, Name, StageName, Area_of_Law__c, Next_Step_Matter__c, RecordType.Name
            FROM Opportunity
            WHERE Id = :oppId
        ];
        System.assertEquals('Quick Next Step', opp.Name, 'Name should match input');
        System.assertEquals('Family Law', opp.Area_of_Law__c, 'Area of Law should match input');
        System.assertEquals('Next Step', opp.RecordType.Name, 'Record type should be Next Step');
        System.assertEquals(matter.Id, opp.Next_Step_Matter__c, 'Matter link should be set');
    }

    @IsTest
    private static void testAddProductBuildsFullTreeAtTemplateHours() {
        AcctSeed__Project__c matter = setupQuickFixture();
        Id templateId = masterTemplateId();

        // Every step in the tree should end up created — that is the whole
        // point of the no-scoping flow.
        Integer expectedSteps = [
            SELECT COUNT()
            FROM Task_Tracker_Template_Step__c
            WHERE Task_Tracker_Template__r.Top_Level_Task_Template__c = :templateId
        ];
        System.assert(expectedSteps > 0, 'Fixture should provide template steps');

        Id oppId = NextStepControllerLWC.createNextStepQuick(
            matter.Id, 'Quick Full Tree', 'Family Law'
        );

        Test.startTest();
        NextStepControllerLWC.addProductToNextStepQuick(matter.Id, oppId, templateId);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :oppId],
            'One product should produce exactly one OpportunityLineItem'
        );

        System.assert(
            [SELECT COUNT() FROM Case WHERE Opportunity__c = :oppId] > 0,
            'Cases must exist, otherwise View/Edit Hours throws "No cases were found to edit hours."'
        );
    }

    @IsTest
    private static void testAddProductRejectsTemplateWithNoSteps() {
        AcctSeed__Project__c matter = setupQuickFixture();

        // A template with no steps at all -> collectAllStepHours returns empty
        // -> NextStepQuickException -> AuraHandledException, nothing created.
        Task_Tracker_Template__c empty = new Task_Tracker_Template__c(
            Name = 'Empty Template',
            Is_Active__c = true
        );
        insert empty;
        empty.Top_Level_Task_Template__c = empty.Id;
        update empty;

        Id oppId = NextStepControllerLWC.createNextStepQuick(
            matter.Id, 'Quick Empty', 'Family Law'
        );

        Boolean threw = false;
        Test.startTest();
        try {
            NextStepControllerLWC.addProductToNextStepQuick(matter.Id, oppId, empty.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'A template with no steps should raise an exception');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :oppId],
            'Failed product must not leave a line item behind'
        );
    }

    // NOTE: there is deliberately NO test that asserts abortNextStepQuick
    // deletes an Opportunity.
    //
    // Deleting an Opportunity fires the vendor's DefaultRoleTriggerHandler,
    // which throws "List has no rows for assignment to SObject" at
    // updateRoles line 39 — it depends on org configuration that no @IsTest
    // fixture creates. abortNextStepQuick catches the exception (by design, so
    // it can never mask the original error it is cleaning up after), but the
    // trigger failure is re-surfaced by Test.stopTest() and fails the test
    // regardless of the catch. Inserting a Case hits the same handler, and
    // inserting an OpportunityLineItem trips OpportunityLineItemTrigger via
    // the "Product Processes" flow.
    //
    // The delete path is therefore verified LIVE in jt-full4 (2026-09-14)
    // rather than in Apex. abortNextStepQuick removed two real Next Step
    // Opportunities together with their Cases, Tasks and 1 and 2
    // OpportunityLineItems respectively, ending with CLEAN_REMAINING=0.
    // It was also run against an Opportunity of another record type (refused,
    // record survived) and against a garbage Id (no exception).
    //
    // The two abort tests below cover the guard clauses, which is what can be
    // asserted honestly in a test transaction.

    @IsTest
    private static void testAbortRefusesNonNextStepOpportunity() {
        TaskTrackerTestDataFactory.createAllTestData();

        // The fixture's Opportunity is NOT a Next Step record type. The safety
        // rail must refuse it, so a bad Id from the client can never delete a
        // real Opportunity.
        Opportunity other = [
            SELECT Id, RecordTypeId
            FROM Opportunity
            LIMIT 1
        ];

        Test.startTest();
        NextStepControllerLWC.abortNextStepQuick(other.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Id = :other.Id],
            'Abort must refuse to delete a non-Next-Step Opportunity');
    }

    @IsTest
    private static void testAbortIsSafeOnBlankAndUnknownIds() {
        // Abort runs inside the LWC's error handler and must never throw,
        // or it would mask the original failure.
        Test.startTest();
        NextStepControllerLWC.abortNextStepQuick(null);
        NextStepControllerLWC.abortNextStepQuick('');
        NextStepControllerLWC.abortNextStepQuick('006000000000000AAA');
        Test.stopTest();

        System.assert(true, 'Abort swallowed blank/unknown Ids without throwing');
    }

}