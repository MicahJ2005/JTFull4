@isTest
private class CESAvailabilityActionTest {

    @TestSetup
    static void setup() {
        UserRole cesRole = new UserRole(Name = 'Client Engagement Specialist');
        insert cesRole;

        User cesUser = new User(
            FirstName    = 'CES',
            LastName     = 'Test',
            Email        = 'ces.test@testorg.com',
            Username     = 'ces.test@testorg.com.sandbox',
            Alias        = 'cestest',
            ProfileId    = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            UserRoleId   = cesRole.Id,
            TimeZoneSidKey    = 'America/El_Salvador',
            LocaleSidKey      = 'es_SV',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'es'
        );
        insert cesUser;

        Lead testLead = new Lead(
            FirstName = 'Cliente',
            LastName  = 'Test',
            Company   = 'Test Co',
            Email     = 'cliente@test.com'
        );
        insert testLead;
    }

    @isTest
    static void testAvailabilityNoExistingAppointment() {
        Lead lead = [SELECT Id FROM Lead LIMIT 1];

        CESAvailabilityAction.AvailabilityRequest req = 
            new CESAvailabilityAction.AvailabilityRequest();
        req.leadId = lead.Id;

        Test.startTest();
        List<CESAvailabilityAction.AvailabilityResult> results = 
            CESAvailabilityAction.getAvailability(
                new List<CESAvailabilityAction.AvailabilityRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].clientHasActiveAppointment);
    }

    @isTest
    static void testAvailabilityWithExistingAppointment() {
        Lead lead     = [SELECT Id FROM Lead LIMIT 1];
        User cesUser  = [SELECT Id FROM User WHERE LastName = 'Test' LIMIT 1];

        Event existing = new Event(
            Subject            = 'Cita existente',
            OwnerId            = cesUser.Id,
            WhoId              = lead.Id,
            StartDateTime      = DateTime.now().addDays(2),
            EndDateTime        = DateTime.now().addDays(2).addHours(1),
            CES_Appointment__c = true
        );
        insert existing;

        CESAvailabilityAction.AvailabilityRequest req = 
            new CESAvailabilityAction.AvailabilityRequest();
        req.leadId = lead.Id;

        Test.startTest();
        List<CESAvailabilityAction.AvailabilityResult> results = 
            CESAvailabilityAction.getAvailability(
                new List<CESAvailabilityAction.AvailabilityRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].clientHasActiveAppointment);
    }
}