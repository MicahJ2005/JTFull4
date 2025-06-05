/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 05-06-2021
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   05-05-2021   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class ScheduleCoachControllerTest {

    @TestSetup
    static void setup(){
        TaskTrackerTestDataFactory.createAllTestData();
    }

    @IsTest
    private static void testRedirectPageOnLead() {

        Test.startTest();

        Lead l = new Lead (
            FirstName = 'First',
            LastName = 'Last',
            Email = 'FLast@nowhere.com',
            Attorney__c = 'Brad Palmer',
            Book_Consult_With__c = 'Any Attorney'
        );
        insert l;
        Test.stopTest();
        Pagereference ref = Page.ScheduleAppointmentLead;
        Test.setCurrentPage(ref);
        ApexPages.StandardController sc = new ApexPages.standardController(l);
        ScheduleCoachController sch = new ScheduleCoachController(sc);
        System.assertNotEquals(null, sch.redirectToSchedule());

    }

    @IsTest
    private static void testRedirectPageOnMatter() {

        Test.startTest();

        Contact businessContact = makeBusinessContact();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id, Name, AccountId, Spouse__c FROM Opportunity LIMIT 1];
        opp.Billing_Attorney__c = 'Brad Palmer';
        opp.StageName = 'Closed Won';
        opp.Contact_Id__c = businessContact.Id;
        update opp;

        Default_Role__c coachRole =
            [
                SELECT Id
                FROM Default_Role__c
                WHERE Name = 'Coach'
                    AND Opportunity__c = :opp.Id
            ];
        User coachUser =
            [
                SELECT Id, FirstName, LastName, Profile.Name
                FROM User
                WHERE IsActive = true
                    AND Profile.Name != null
                LIMIT 1
            ];

        System.debug('Profile Name = ' + coachUser.Profile.Name);
        coachRole.Assigned_User__c = coachUser.Id;
        update coachRole;

        AcctSeed__Project__c project = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        insert project;

        opp =
            [
                SELECT Id
                FROM Opportunity
                WHERE Id = :project.AcctSeed__Opportunity__c
            ];

        Test.stopTest();

        Pagereference ref = Page.ScheduleAppointmentMatter;
        Test.setCurrentPage(ref);
        ApexPages.StandardController sc = new ApexPages.standardController(project);
        ScheduleCoachController sch = new ScheduleCoachController(sc);
        sch.redirectToSchedule();
        //System.assertNotEquals(null, sch.redirectToSchedule());
    }

    @IsTest
    private static void testRedirectPageOnOpportunity() {

        Test.startTest();

        Contact businessContact = makeBusinessContact();

        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id, Name, AccountId, Spouse__c FROM Opportunity LIMIT 1];
        opp.Billing_Attorney__c = 'Brad Palmer';
        opp.StageName = 'Closed Won';
        opp.Contact_Id__c = businessContact.Id;
        update opp;

        Default_Role__c coachRole =
            [
                SELECT Id
                FROM Default_Role__c
                WHERE Name = 'Coach'
                    AND Opportunity__c = :opp.Id
            ];
        User coachUser =
            [
                SELECT Id, FirstName, LastName
                FROM User
                WHERE IsActive = true
                    AND Profile.Name != null
                LIMIT 1
            ];

        coachRole.Assigned_User__c = coachUser.Id;
        update coachRole;

        AcctSeed__Project__c project = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        insert project;


        opp =
            [
                SELECT Id
                FROM Opportunity
                WHERE Id = :project.AcctSeed__Opportunity__c
            ];

        Test.stopTest();

        Pagereference ref = Page.ScheduleAppointmentOpportunity;
        Test.setCurrentPage(ref);
        ApexPages.StandardController sc = new ApexPages.standardController(opp);
        ScheduleCoachController sch = new ScheduleCoachController(sc);
        sch.redirectToSchedule();
        //System.assertNotEquals(null, sch.redirectToSchedule());
    }

    private static Contact makeBusinessContact() {
        Contact businessContact = new Contact(
          FirstName = 'Business',
            LastName = 'Contact'
        );
        insert businessContact;
        return businessContact;
    }

}