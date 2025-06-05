/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-14-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   07-06-2021   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class EditNextStepOpportunityControllerTest {

    private static Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();
    private static Id defaultRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Initial').getRecordTypeId();

    @IsTest
    private static void testGetOpportunityCasesOppClosed() {

        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp =
            [
                SELECT Id, StageName
                FROM Opportunity
                LIMIT 1
            ];
        opp.RecordTypeId = nextStepRecordTypeId;
        opp.StageName = 'Closed Won';
        update opp;

        Boolean hasError = false;

        Test.startTest();

        try {
            String jsonResults = EditNextStepOpportunityController.getOpportunityCases(opp.Id);
        } catch (Exception e) {
            hasError = true;
        }

        Test.stopTest();
        System.assertEquals(true, hasError, 'Can not edit hours on closed opps.');
    }

    @IsTest
    private static void testGetOpportunityCasesOppNotNextStep() {

        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp =
            [
                SELECT Id, StageName
                FROM Opportunity
                LIMIT 1
            ];
        opp.RecordTypeId = defaultRecordTypeId;
        opp.StageName = 'Pricing Confirmed';
        update opp;

        Boolean hasError = false;

        Test.startTest();

        try {
            String jsonResults = EditNextStepOpportunityController.getOpportunityCases(opp.Id);
        } catch (Exception e) {
            hasError = true;
        }

        Test.stopTest();
        System.assertEquals(true, hasError, 'Can not edit non-next step opps.');
    }

    @IsTest
    private static void testGetOpportunityCases() {

        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp =
            [
                SELECT Id, StageName
                FROM Opportunity
                LIMIT 1
            ];
        opp.RecordTypeId = nextStepRecordTypeId;
        opp.StageName = 'Pricing Confirmed';
        update opp;

        Case masterCase = createCase(opp.Id, null, false);
        Case child1 = createCase(opp.Id, masterCase.Id, true);
        Case child2 = createCase(opp.Id, masterCase.Id, true);

        String jsonResults = EditNextStepOpportunityController.getOpportunityCases(opp.Id);

        List<EditNextStepOpportunityController.CaseCls> returnCases = (List<EditNextStepOpportunityController.CaseCls>) JSON.deserialize(jsonResults, List<EditNextStepOpportunityController.CaseCls>.class);
    }

    @IsTest
    private static void testSaveActivityHours() {
        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp =
            [
                SELECT Id, StageName
                FROM Opportunity
                LIMIT 1
            ];
        opp.RecordTypeId = nextStepRecordTypeId;
        opp.StageName = 'Pricing Confirmed';
        update opp;

        Case masterCase = createCase(opp.Id, null, false);
        Case child1 = createCase(opp.Id, masterCase.Id, true);
        Case child2 = createCase(opp.Id, masterCase.Id, true);

        Task t =
            [
                SELECT Id, Hours__c, WhatId
                FROM Task
                LIMIT 1
            ];
        EditNextStepOpportunityController.saveActivityHours(t.Id, 'Task', 1);

        Task updatedTask =
            [
                SELECT Id, Hours__c
                FROM Task
                LIMIT 1
            ];

        System.assertNotEquals(t.Hours__c, updatedTask.Hours__c, 'The hours should have been updated.');

    }

    private static Case createCase(Id oppId, Id parentCaseId, Boolean createActivities) {

        Case c = new Case (
            Opportunity__c = oppId
        );
        if(parentCaseId != null) {
            c.ParentId = parentCaseId;
        }
        insert c;

        if(createActivities) {

            Date todayDate = Date.today();

            Task t = new Task (
                Subject = 'Some task!',
                Hours__c = 5,
                WhatId = c.Id,
                ActivityDate = todayDate
            );
            insert t;

            Event e = new Event (
                Subject = 'Some event!',
                ActivityDate = todayDate,
                WhatId = c.Id,
                Type = 'Meeting',
                IsAllDayEvent = true
            );
            insert e;
        }
        return c;
    }

}