@isTest
private class SendPortalInviteTest {

    private class Mock implements HttpCalloutMock {
        Integer code; String body;
        Mock(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code);
            r.setHeader('Content-Type', 'application/json');
            r.setBody(body);
            return r;
        }
    }

    // Build a Matter with a Contact that has an email. Uses the sandbox field mapping.
    private static Id makeMatter(String email) {
        Contact c = new Contact(LastName = 'Test Client', Email = email);
        insert c;
        AcctSeed__Project__c m = new AcctSeed__Project__c(
            Name = 'Test Matter',
            Contact__c = c.Id
        );
        insert m;
        return m.Id;
    }

    @isTest static void happyPath() {
        Id mId = makeMatter('client@example.com');
        Test.setMock(HttpCalloutMock.class, new Mock(200,
            '{"invited":true,"invite_link":"https://x/invite/abc","staff_link":"https://x/staff/matter/' + mId + '","sf_link_written":true}'));
        Test.startTest();
        SendPortalInvite.Request req = new SendPortalInvite.Request();
        req.matterId = mId;
        List<SendPortalInvite.Result> res = SendPortalInvite.run(new List<SendPortalInvite.Request>{ req });
        Test.stopTest();
        System.assertEquals(true, res[0].invited, 'should be invited');
        System.assertEquals('https://x/invite/abc', res[0].inviteLink);
        System.assertEquals(true, res[0].sfLinkWritten);
    }

    @isTest static void noEmail() {
        Id mId = makeMatter(null);
        Test.startTest();
        SendPortalInvite.Request req = new SendPortalInvite.Request();
        req.matterId = mId;
        List<SendPortalInvite.Result> res = SendPortalInvite.run(new List<SendPortalInvite.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, res[0].invited);
        System.assert(res[0].errorMessage.contains('email'), 'should complain about missing email');
    }

    @isTest static void functionError() {
        Id mId = makeMatter('client@example.com');
        Test.setMock(HttpCalloutMock.class, new Mock(500, '{"error":"boom"}'));
        Test.startTest();
        SendPortalInvite.Request req = new SendPortalInvite.Request();
        req.matterId = mId;
        List<SendPortalInvite.Result> res = SendPortalInvite.run(new List<SendPortalInvite.Request>{ req });
        Test.stopTest();
        System.assertEquals(false, res[0].invited);
        System.assert(res[0].errorMessage.contains('500'), 'should surface HTTP 500');
    }
}