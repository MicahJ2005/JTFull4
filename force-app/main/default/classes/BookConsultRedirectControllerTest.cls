@isTest
private class BookConsultRedirectControllerTest {
    @isTest
    static void redirectsLeadToBookConsult() {
        Lead l = new Lead(LastName = 'Test', Company = 'Test Co', Book_Consult_With__c = 'Any CES', Area_of_Law__c = 'Bankruptcy');
        insert l;

        ApexPages.StandardController std = new ApexPages.StandardController(l);
        BookConsultRedirectController ctrl = new BookConsultRedirectController(std);

        Test.startTest();
        PageReference ref = ctrl.redirectToBooking();
        Test.stopTest();

        String url = ref.getUrl();
        System.debug('Lead redirect URL: ' + url);
        System.assert(url.startsWith('https://family-law-canvas-dev.johnson-turner-92a.workers.dev/book-consult/Lead/'), 'Lead redirect should target /book-consult/Lead/<id>, got: ' + url);
        // Real bug regression (2026-08-16): the Id in the URL must be the
        // full 18-char case-safe Id, not a truncated 15-char one -- a
        // truncated Id causes FamCanvas's lookup to silently fail.
        String idInUrl = url.substringAfterLast('/');
        System.assertEquals(18, idInUrl.length(), 'Id embedded in the redirect URL must be the full 18-char Id, got: ' + idInUrl);
        System.assertEquals(String.valueOf(l.Id), idInUrl, 'Id embedded in the redirect URL must exactly match the Lead Id');
    }

    @isTest
    static void redirectsOpportunityToBookConsult() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Test Opp', AccountId = acc.Id, StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), Book_Consult_With__c = 'Any CES',
            Area_of_Law__c = 'Bankruptcy'
        );
        insert opp;

        ApexPages.StandardController std = new ApexPages.StandardController(opp);
        BookConsultRedirectController ctrl = new BookConsultRedirectController(std);

        Test.startTest();
        PageReference ref = ctrl.redirectToBooking();
        Test.stopTest();

        String url = ref.getUrl();
        System.debug('Opportunity redirect URL: ' + url);
        System.assert(url.startsWith('https://family-law-canvas-dev.johnson-turner-92a.workers.dev/book-consult/Opportunity/'), 'Opportunity redirect should target /book-consult/Opportunity/<id>, got: ' + url);
        String idInUrl = url.substringAfterLast('/');
        System.assertEquals(18, idInUrl.length(), 'Id embedded in the redirect URL must be the full 18-char Id, got: ' + idInUrl);
        System.assertEquals(String.valueOf(opp.Id), idInUrl, 'Id embedded in the redirect URL must exactly match the Opportunity Id');
    }

    // Real regression test (2026-08-16, live bug found by Chris): the
    // Matter/AcctSeed__Project__c branch had ZERO test coverage before --
    // this is exactly the branch that shipped the 15-char truncation bug
    // undetected. Covering it now closes that real gap.
    @isTest
    static void redirectsMatterToBookCall() {
        AcctSeed__Project__c matter = new AcctSeed__Project__c(Name = 'Test Matter');
        insert matter;

        ApexPages.StandardController std = new ApexPages.StandardController(matter);
        BookConsultRedirectController ctrl = new BookConsultRedirectController(std);

        Test.startTest();
        PageReference ref = ctrl.redirectToBooking();
        Test.stopTest();

        String url = ref.getUrl();
        System.debug('Matter redirect URL: ' + url);
        System.assert(url.startsWith('https://family-law-canvas-dev.johnson-turner-92a.workers.dev/book-call?sfId='), 'Matter redirect should target /book-call?sfId=<id>, got: ' + url);
        String idInUrl = url.substringAfter('sfId=');
        System.assertEquals(18, idInUrl.length(), 'Id embedded in the redirect URL must be the full 18-char Id, got: ' + idInUrl);
        System.assertEquals(String.valueOf(matter.Id), idInUrl, 'Id embedded in the redirect URL must exactly match the Matter Id');
    }
}