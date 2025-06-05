/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-10-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-10-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class VisualForceTrackerControllerTest {
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

        Task_Tracker_Template__c t =
            [
                SELECT Id
                FROM Task_Tracker_Template__c
                LIMIT 1
            ];

        PageReference pageRef = Page.VisualForceTracker; // Add your VF page Name here
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('id', t.Id);

        VisualForceTrackerController control = new VisualForceTrackerController();
        control.getMermaidForTemplate(t.Id);

    }
}