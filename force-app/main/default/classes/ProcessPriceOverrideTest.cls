/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 10-12-2021
 * @last modified by  : Revolution Group (Brian Ezell)
**/
@IsTest
private class ProcessPriceOverrideTest {

    @IsTest
    private static void testProcessPriceOverride() {


        Test.startTest();

        testTrackerSettings();

        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp =
            [
                SELECT Id, Amount
                FROM Opportunity
                LIMIT 1
            ];


        List<ProcessPriceOverride.OpportunityPriceOverrideCls> priceOverrides = new List<ProcessPriceOverride.OpportunityPriceOverrideCls>();

        ProcessPriceOverride.OpportunityPriceOverrideCls priceOverride = new ProcessPriceOverride.OpportunityPriceOverrideCls();
        priceOverride.OpportunityId = opp.Id;
        priceOverride.OverridePrice = 5000;

        priceOverrides.add(priceOverride);

        ProcessPriceOverride.processPriceOverride(priceOverrides);

		Test.stopTest();

        Opportunity afterOpp =
        [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertNotEquals(opp.Amount, afterOpp.Amount, 'The price was not updated.');
    }

    private static void testTrackerSettings() {
        insert new Task_Tracker_Settings__c(
            Round_To_Nearest__c = 100,
            Then_Subtract__c = 5
        );
    }
}