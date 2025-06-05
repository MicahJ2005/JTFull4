/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 12-21-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-04-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class ScheduleAppointmentControllerTest {

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

        Pagereference ref = Page.ScheduleAppointmentLead;
        Test.setCurrentPage(ref);
        ApexPages.StandardController sc = new ApexPages.standardController(l);
        ScheduleAppointmentController sch = new ScheduleAppointmentController(sc);
        System.assertNotEquals(null, sch.redirectToSchedule());

        Test.stopTest();
    }

    @IsTest
    private static void testRedirectPageOnMatter() {

        Test.startTest();

        Contact businessContact = makeBusinessContact();
        
        //Mark Opportunity as Closed/Won which triggers the
        //creation of the templates
        Opportunity opp = [SELECT Id, Name, AccountId, Spouse__c FROM Opportunity LIMIT 1];
        opp.Book_Consult_With__c = 'Any Attorney';
        opp.StageName = 'Closed Won';
        opp.Contact_ID__c = businessContact.Id;
        update opp;
        
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

        opp.Billing_Attorney__c = 'Brad Palmer';
        opp.StageName = 'Closed Won';
        update opp;
        
		User userAttorney = 
            [
            	SELECT Id, Name
                FROM User
                WHERE Name = 'Brad Palmer'
            ];
        Default_Role__c defaultRole = new Default_Role__c (
        	Opportunity__c = opp.Id,
            Assigned_User__c = userAttorney.Id,
            Role__c = 'Attorney'
        );


        Test.stopTest();

        AcctSeed__Project__c p =
            [
                SELECT Id
                FROM AcctSeed__Project__c
                LIMIT 1
            ];
  
        Pagereference ref = Page.ScheduleAppointmentMatter;
        Test.setCurrentPage(ref);
        ApexPages.StandardController sc = new ApexPages.standardController(p);
        ScheduleAppointmentController sch = new ScheduleAppointmentController(sc);
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
        opp.Book_Consult_With__c = 'Any Attorney';
        opp.Contact_Id__c = businessContact.Id;
        update opp;

        AcctSeed__Project__c project = new AcctSeed__Project__c (
            Name = opp.Name,
            AcctSeed__Status__c = 'Active',
            AcctSeed__Account__c = opp.AccountId,
            AcctSeed__Opportunity__c = opp.Id,
            Spouse__c = opp.Spouse__c
        );

        insert project;
        
        Default_Role__c attorneyRole =
            [
                SELECT Id
                FROM Default_Role__c
                WHERE Name = 'Attorney'
                    AND Opportunity__c = :opp.Id
            ];
        User attorneyUser =
            [
                SELECT Id, FirstName, LastName
                FROM User
                WHERE Profile.Name = 'Attorney'
                    AND IsActive = true
                LIMIT 1
            ];

        attorneyRole.Assigned_User__c = attorneyUser.Id;
        update attorneyRole;

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
        ScheduleAppointmentController sch = new ScheduleAppointmentController(sc);
        sch.redirectToSchedule();
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