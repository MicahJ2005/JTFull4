/**
 * @description       : Test class for OpportunityLineItemTrigger and OpportunityLineItemTriggerHandler
 * @author            : Dextara
**/
@IsTest
private class OpportunityLineItemTriggerTest {

    @IsTest
    private static void testTrigger() {
		OLI_Trigger_Setting__c ats = new OLI_Trigger_Setting__c();
        ats.Disable_Triggers__c = false;
        insert ats;
                
        TaskTrackerTestDataFactory.createOpportunityAndProduct();
        
        Opportunity opp =
            [
                SELECT Id
                FROM Opportunity
                LIMIT 1
            ];

        opp.StageName = 'Closed Won';
        update opp;
        
    }
}