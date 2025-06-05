/**
 * @description       : Test class for dex_VideoPlayerLWCController
 * @author            : Dextara (Albert Liu)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   07/24/2024   Dextara (Albert Liu)			   Initial Version
**/
@isTest
public class dex_VideoPlayerLWCControllerTest {
    @TestSetup
    static void setup(){
          Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Lead l = new Lead (
            FirstName = 'John',
            LastName = 'Smith'
        );
        insert l;

        l =
            [
                SELECT Id, FirstName, LastName, OwnerId
                FROM Lead
                LIMIT 1
            ];

        User u =
            [
                SELECT Id
                FROM User
                WHERE IsActive = True
                    AND Profile.Name = 'System Administrator'
                    AND UserName != NULL
                    AND Email != NULL
                LIMIT 1
            ];

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId,
            PersonEmail = '123@nowhere.com'
        );
        insert act;

        System.debug('After insert act');

        Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();

        Opportunity opp = new Opportunity (
            RecordTypeId = nextStepRecordTypeId,
            Name = 'Opp 001',
            StageName = 'Pending Consult',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Call',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            New_Opp_Owner_from_Lead__c = l.OwnerId,
            Area_of_Law__c = 'Family Law',
            Originator_LU__c = u.Id,
            Term_Options__c = 'C'
        );
        insert opp;
        AyTestDataSuite.init();

        AcctSeed__Project__c newProject = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        insert newProject;
        
        XD_Facts__c xf = new XD_Facts__c();
        xf.Name = 'Test XD Fact';
        xf.Matter__c = newProject.Id;
        insert xf;
            
        Case_Strategy__c cs = new Case_Strategy__c();
        cs.XD_Facts__c = xf.Id;
        cs.Matter__c = newProject.Id;
        cs.Name = 'Test CS';
        cs.Status_Child_Support__c = 'Resolved';
        cs.Status_Spousal_Maintenance__c = 'Resolved';
        insert cs;
    }

    @isTest
    public static void testShowTasks() {
        AcctSeed__Project__c matter = [SELECT Id FROM AcctSeed__Project__c LIMIT 1];
        String jsonResult = dex_VideoPlayerLWCController.getTaskList(matter.Id);
        System.Assert(jsonResult != '');
    }
}