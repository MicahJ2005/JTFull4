/**
 * @File Name          : VisualCaseTrackerControllerTest.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 09-10-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    6/10/2020   Revolution Group (Brian Ezell)     Initial Version
**/
@IsTest
private class VisualCaseTrackerControllerTest {

    @TestSetup
    static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testGetMermaidMarkUp() {

        Test.startTest();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.StageName = 'Closed Won';
        update opp;

        Test.stopTest();

        Case c =
            [
                SELECT Id
                FROM Case
                LIMIT 1
            ];

        PageReference pageRef = Page.VisualCaseTracker; // Add your VF page Name here
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('id', c.Id);

        VisualCaseTrackerController control = new VisualCaseTrackerController();
        control.getMermaidForTemplate(c.Id);

    }

}