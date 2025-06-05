/**
 * @File Name          : HelperFunctionsTest.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 11-05-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    6/10/2020   Revolution Group (Brian Ezell)     Initial Version
**/
@IsTest
private class HelperFunctionsTest {

    @TestSetup
    static void setup(){

        Case masterCase = new Case (
            Subject = 'Test Master Case'
        );
        insert masterCase;

        masterCase.Top_Level_Task_Tracker_Case__c = masterCase.Id;
        update masterCase;

        Case childCase = new Case (
            Subject = 'Test Child Case',
            Top_Level_Task_Tracker_Case__c = masterCase.Id
        );
        insert childCase;
    }

    @IsTest
    private static void testGetAssociatedCases() {
        Case c =
            [
                SELECT Id
                FROM Case
                LIMIT 1
            ];
        List<Case> allCases = HelperFunctions.getAssociatedCases(c.Id);
        System.assertEquals(2, allCases.size());
    }

    @IsTest
    private static void testUpdateCaseCount() {
        Case c =
            [
                SELECT Id
                FROM Case
                LIMIT 1
            ];
        Set<Id> caseIds = new Set<Id> { c.Id };
        HelperFunctions.updateCaseCounts(caseIds);
    }

    @IsTest
    private static void testCalculateDate() {
        String dateType = 'Business';
        Integer daysOut = 10;
        Date dte = HelperFunctions.calculateDateFromActivityDate(dateType, daysOut);
        System.assert(Date.today() < dte);
    }
}