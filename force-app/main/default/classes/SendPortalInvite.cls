public with sharing class SendPortalInvite {
    // Invocable action behind the "Send Portal Invite" button/Flow on the Matter.
    // Calls the DIYvorce sf-trigger-invite edge function (auth + endpoint via the
    // DIYvorce_Edge_Functions Named Credential), which provisions the portal invite and
    // writes both link fields back onto the Matter. Returns the links for the Flow to display.
    //
    // CROSS-ORG FIELD DRIFT: this build targets the full4 SANDBOX, where the client link is
    // Contact__c (Lookup->Contact) and email is Contact__r.Email. PRODUCTION uses
    // AcctSeed__Account__c (Person Account) + PersonEmail. To promote to prod, change the two
    // marked lines below (SOQL field + email source). Documented in the build-instructions doc.

    public class Request {
        @InvocableVariable(required=true label='Matter Id')
        public Id matterId;
    }

    public class Result {
        @InvocableVariable public Boolean invited;
        @InvocableVariable public String inviteLink;
        @InvocableVariable public String staffLink;
        @InvocableVariable public Boolean sfLinkWritten;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send DIYvorce Portal Invite'
        description='Provisions a DIYvorce portal invite for the Matter\'s client and populates the two link fields.')
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request req : requests) {
            out.add(invite(req.matterId));
        }
        return out;
    }

    private static Result invite(Id matterId) {
        Result res = new Result();
        try {
            // --- SANDBOX field mapping (see prod note in header) ---
            AcctSeed__Project__c m = [
                SELECT Id, Contact__c, Contact__r.Email          // PROD: AcctSeed__Account__c, AcctSeed__Account__r.PersonEmail
                FROM AcctSeed__Project__c
                WHERE Id = :matterId
                LIMIT 1
            ];
            String clientId = m.Contact__c;                       // PROD: m.AcctSeed__Account__c
            String email = m.Contact__r != null ? m.Contact__r.Email : null;  // PROD: m.AcctSeed__Account__r.PersonEmail

            if (String.isBlank(clientId)) {
                res.invited = false;
                res.errorMessage = 'This Matter has no client (Contact) set — cannot send an invite.';
                return res;
            }
            if (String.isBlank(email)) {
                res.invited = false;
                res.errorMessage = 'The client has no email address on file — add one, then retry.';
                return res;
            }

            Map<String, Object> body = new Map<String, Object>{
                'sf_matter_id' => matterId,
                'sf_contact_id' => clientId,
                'email' => email
            };

            HttpRequest hreq = new HttpRequest();
            hreq.setEndpoint('callout:DIYvorce_Edge_Functions/functions/v1/sf-trigger-invite');
            hreq.setMethod('POST');
            hreq.setHeader('Content-Type', 'application/json');
            hreq.setTimeout(60000);
            hreq.setBody(JSON.serialize(body));

            HttpResponse hres = new Http().send(hreq);
            Integer sc = hres.getStatusCode();
            Map<String, Object> parsed;
            try {
                parsed = (Map<String, Object>) JSON.deserializeUntyped(hres.getBody());
            } catch (Exception parseEx) {
                parsed = new Map<String, Object>();
            }

            if (sc == 200 && parsed.get('invited') == true) {
                res.invited = true;
                res.inviteLink = (String) parsed.get('invite_link');
                res.staffLink = (String) parsed.get('staff_link');
                res.sfLinkWritten = (parsed.get('sf_link_written') == true);
            } else {
                res.invited = false;
                Object errObj = parsed.get('error');
                res.errorMessage = 'Edge function returned HTTP ' + sc
                    + (errObj != null ? ': ' + String.valueOf(errObj) : '');
            }
        } catch (Exception e) {
            res.invited = false;
            res.errorMessage = 'Callout failed: ' + e.getMessage();
        }
        return res;
    }
}