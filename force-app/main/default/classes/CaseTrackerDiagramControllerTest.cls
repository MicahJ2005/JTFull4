/**
 * @File Name          : CaseTrackerDiagramControllerTest.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 09-10-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    3/18/2020   Revolution Group (Brian Ezell)     Initial Version
**/
@IsTest
private class CaseTrackerDiagramControllerTest {

    @TestSetup
    static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testGetCaseSummary() {

        Test.startTest();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.StageName = 'Closed Won';
        update opp;

        Test.stopTest();

        Case masterCase =
            [
                SELECT Id
                FROM Case
                LIMIT 1
            ];

        String cJson = CaseTrackerDiagramController.getCaseSummary(masterCase.Id);
    }
}