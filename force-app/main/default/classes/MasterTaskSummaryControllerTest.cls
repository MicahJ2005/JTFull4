/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 10-12-2021
 * @last modified by  : Revolution Group (Brian Ezell)
**/
@IsTest
private class MasterTaskSummaryControllerTest {

    @IsTest
    private static void testGetChildTaskSummary() {

        TaskTrackerTestDataFactory.createAllTestData();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.StageName = 'Closed Won';
        update opp;

        Task_Tracker_Template__c template =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                WHERE Is_Active__c = true
                LIMIT 1
            ];

        Test.startTest();

        CreateProcessFlowController.ProcessInput input = new CreateProcessFlowController.ProcessInput();
        input.ObjectId = opp.Id;
        input.ObjectName = 'Opportunity';
        input.TemplateId = template.Id;

        CreateProcessFlowController.CreateProcess(new List<CreateProcessFlowController.ProcessInput>{
            input
        });

        Case c =
            [
                SELECT Id
                FROM Case
                LIMIT 1
            ];

        String responseJson = MasterTaskSummaryController.getChildTasksSummary(c.Id);
        System.debug('responseJson = ' + responseJson);

        Test.stopTest();

        System.assertNotEquals('', responseJson, 'The response should not be blank');

        List<MasterTaskSummaryController.Summary> caseSummaries = (List<MasterTaskSummaryController.Summary>) JSON.deserialize(responseJson, List<MasterTaskSummaryController.Summary>.class);
    }
}