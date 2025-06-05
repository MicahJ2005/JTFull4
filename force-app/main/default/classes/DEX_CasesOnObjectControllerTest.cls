/**
 * @File Name          : CasesOnObjectControllerTest.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 09-10-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    3/20/2020   Revolution Group (Brian Ezell)     Initial Version
**/
@IsTest
private class DEX_CasesOnObjectControllerTest {

    @TestSetup
    static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testGetCasesOffObject() {

        Test.startTest();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.StageName = 'Closed Won';
        update opp;

        Test.stopTest();

        Account act =
            [
                SELECT Id, Name
                FROM Account
                LIMIT 1
            ];
        String summaryJson = DEX_CasesOnObjectController.getCaseSummaries(act.Id, 'AccountId');
        List<DEX_CasesOnObjectController.ObjectSummaryByCases> summaries = (List<DEX_CasesOnObjectController.ObjectSummaryByCases>)JSON.deserialize(summaryJson, List<DEX_CasesOnObjectController.ObjectSummaryByCases>.class);
        System.assertEquals(1, summaries.size());
    }
}