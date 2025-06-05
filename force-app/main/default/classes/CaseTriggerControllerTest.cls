/**
 * @File Name          : CaseTriggerControllerTest.cls
 * @Description        : Unit tests for CaseTriggerController
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-24-2022
 * @Modification Log   :
 * Ver       Date            Author      		         Modification
 * 1.0    1/28/2020   Revolution Group (Brian Ezell)     Initial Version
 * 1.1    11/22/2021  Revolution Group (Christan Gordon) Added testUpdateCases test method to add test coverage for the updateCases method CaseTriggerController
**/
@IsTest
private class CaseTriggerControllerTest {

    private static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testTaskProgressChildCase() {

        setup();
        
        Test.startTest();

        createCase();

        Case childCase =
        [
            SELECT Id, Tasks_Completed__c, Tasks_To_Complete__c
            FROM Case
            WHERE ParentId != null
            LIMIT 1
        ];

        List<Task> tasks =
            [
                SELECT Id
                FROM Task
                WHERE WhatId = :childCase.Id
            ];

        for(Task t : tasks) {
            
            t.Status = 'Completed';
            
        }
        update tasks;
        
        //Added By Christan Gordon (Revolution Group): Showcases all task records related to the case.
        System.debug('Case Related Tasks: '+tasks);
        
        childCase =
            [
                SELECT Id, Tasks_Completed__c, Tasks_To_Complete__c, ParentId
                FROM Case
                WHERE Id = :childCase.Id
            ];

        List<Event> events =
            [
                SELECT Id
                FROM Event
                WHERE WhatId = :childCase.Id
            ];
        for(Event e : events) {
            e.StartDateTime = Date.today().addDays(1);
        }
        update events;

        Test.stopTest();

        Case masterCase =
            [
                SELECT Id, Tasks_Completed__c, Tasks_To_Complete__c
                FROM Case
                WHERE Id = :childCase.ParentId
            ];

       // System.assertNotEquals(0, masterCase.Tasks_Completed__c, 'Some tasks should have been marked as completed.');
    }

    @IsTest
    private static void testSetCaseToTerminated() {
        TaskTrackerTestDataFactory.createPrepopulatedOpportunityAndTemplate();
        
        Test.startTest();

        Case masterCase =
            [
                SELECT Id
                FROM Case
                WHERE Is_Parent_Process__c = true
            ];


        update new Case(
            Id = masterCase.Id,
            Status = 'On Hold'
        );


        Test.stopTest();


        System.assertEquals(0, [SELECT Id, Status FROM Task WHERE Status != 'On Hold' AND Top_Level_Case__c = :masterCase.Id].size());

    }


    @IsTest
    private static void testSetCaseToTerminatedAndBack() {

        TaskTrackerTestDataFactory.createPrepopulatedOpportunityAndTemplate();

        Test.startTest();
    
        Case masterCase =
            [
                SELECT Id
                FROM Case
                WHERE Is_Parent_Process__c = true
            ];

        update new Case(
            Id = masterCase.Id,
            Status = 'On Hold'
        );

        update new Case(
            Id = masterCase.Id,
            Status = 'New'
        );

        Test.stopTest();


        System.assertEquals(0, [SELECT Id, Status FROM Task WHERE Status = 'On Hold' AND Top_Level_Case__c = :masterCase.Id].size());

    }
        
    //Added by Christan Gordon (Revolution Group) on 11-22-2021: Added to provide additional test coverage and
    //test the updateCases method
    @isTest
    public static void testUpdateCases() {
            
        setup();
        
        //Prepare Test Data
        //Create test Parent Case record
        Case testParentCase = new Case(
        	
            //Field Values
            Status = 'On Hold',
            Origin = 'Web'
        
        );
        
        insert testParentCase;
        
        
        ////Used to store list of modified child cases
        List <Case> childCases = new List <Case>();
        
        //Create 200 child test cases
        for (Integer i = 0; i < 200; i++){
            
            childCases.add(new Case (
            
            	//Field Values
            	ParentId = testParentCase.id,
                Tasks_Completed__c = 3,
                Tasks_To_Complete__c = 10
            
            ));
                    
        }
        
        //Create child cases  
        insert childCases;
        
        //Start Test
        System.Test.startTest();
        
       		//Invoke updateCases method within the CaseTriggerController class
       		CaseTriggerController.updateCases(childCases);
        
        //End Test
        System.Test.stopTest();
        Case testParentCaseResult = [SELECT Id, Status, ParentId, Tasks_Completed__c, Tasks_To_Complete__c FROM Case WHERE Id = :testParentCase.id LIMIT 1];
        
        //Evaluate Results 
        //If the test was successful, the parent case status should be working since the task to complete and task completed field values are different
        //The number of total # of tasks completed should be 600 since 3 tasks were completed for each child case related to the parent case. There are 200 child cases
        //The number of total # of tasks to be completed is 2000 since 10 tasks were completed for each child case related to the parent case. There are 200 child cases
        System.assertEquals('Working', testParentCaseResult.Status);
        System.assertEquals(600, testParentCaseResult.Tasks_Completed__c);
        System.assertEquals(2000, testParentCaseResult.Tasks_To_Complete__c);
                 
        }

        private static void createCase() {

            Opportunity opp = 
                [
                    SELECT Id 
                    FROM Opportunity 
                    LIMIT 1
                ];

            Task_Tracker_Template__c template =
                [
                    SELECT Id
                    FROM Task_Tracker_Template__c
                    WHERE Is_Active__c = true
                    LIMIT 1
                ];
    
            CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
            input.ObjectId = opp.Id;
            input.ObjectName = 'Opportunity';
            input.TemplateId = template.Id;
    
            CreateProcessFlowController flowController = new CreateProcessFlowController(input);
            flowController.processTheInput();

        }

}