@IsTest
private class ScheduleParalegalControllerTest {

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
        ScheduleParalegalController sch = new ScheduleParalegalController(sc);
        sch.redirectToSchedule();

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

        /*AcctSeed__Project__c project =
            [
                SELECT Id, AcctSeed__Opportunity__c
                FROM AcctSeed__Project__c
                WHERE AcctSeed__Opportunity__c != null
                LIMIT 1
            ];*/
        
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

        Test.stopTest();

        AcctSeed__Project__c p =
            [
                SELECT Id
                FROM AcctSeed__Project__c
                LIMIT 1
            ];
        p.Coach__c = 'Matt Tuttle';
        update p;

        Pagereference ref = Page.ScheduleAppointmentMatter;
        Test.setCurrentPage(ref);
        ApexPages.StandardController sc = new ApexPages.standardController(p);
        ScheduleParalegalController sch = new ScheduleParalegalController(sc);
        sch.redirectToSchedule();
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

        Default_Role__c paralegalRole =
            [
                SELECT Id
                FROM Default_Role__c
                WHERE Name = 'Paralegal'
                    AND Opportunity__c = :opp.Id
            ];
        User paraLegalUser =
            [
                SELECT Id, FirstName, LastName
                FROM User
                WHERE IsActive = true
                	AND Profile.Name = 'Attorney'
                LIMIT 1
            ];

        paralegalRole.Assigned_User__c = paraLegalUser.Id;
        update paraLegalUser;

        /*AcctSeed__Project__c project =
            [
                SELECT Id, AcctSeed__Opportunity__c
                FROM AcctSeed__Project__c
                WHERE AcctSeed__Opportunity__c != null
                LIMIT 1
            ];

        project =
            [
                SELECT Id, AcctSeed__Opportunity__c
                FROM AcctSeed__Project__c
                WHERE AcctSeed__Opportunity__c != null
                LIMIT 1
            ];*/

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
        ScheduleParalegalController sch = new ScheduleParalegalController(sc);
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