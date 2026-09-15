public with sharing class BookConsultRedirectController {
    private final Id objectId;
    private final Schema.SObjectType objectType;

    public BookConsultRedirectController(ApexPages.StandardController std) {
        // Real bug found + fixed 2026-08-16 (live test with Chris):
        // std.getId() can return the 15-CHARACTER case-sensitive Id in
        // some contexts (confirmed live -- a Matter button produced a
        // truncated 15-char sfId in the redirect URL, causing FamCanvas's
        // getFirmMatterBySfId lookup to fail and fall through to a
        // misleading "could not be synced" error even though the matter
        // was already synced). Casting through Apex's Id type normalizes
        // this to the real 18-character case-SAFE Id (confirmed via a
        // direct Apex test: a 15-char Id cast to Id then back to String
        // via String.valueOf() correctly expands to 18 chars) -- do this
        // ONCE here in the constructor so every caller gets the safe
        // value, not per-branch.
        objectId = (Id) std.getId();
        objectType = std.getRecord().getSObjectType();
    }

    // Same real pattern as ScheduleAppointmentController (the existing
    // OnceHub "Book Consult"/"Book With Attorney" buttons) -- a
    // server-side PageReference redirect, not client-side window.open().
    // This navigates the quick-action panel's OWN content directly to
    // the target -- no popup, no separate tab, no dismiss-click step
    // (Chris, 2026-08-16: match the existing buttons' auto-disappearing
    // behavior exactly).
    public PageReference redirectToBooking() {
        String idStr = String.valueOf(objectId);
        String url;
        // Host updated 2026-09-10 (Chris): Fam Canvas DEV/UAT/PROD Workers
        // moved Cloudflare accounts on 2026-09-04 (fixing a cross-account
        // DNS/Custom-Domain issue) -- the OLD family-law-canvas-dev.
        // johnsonturner.workers.dev host now 404s outright (confirmed live,
        // 2026-09-10). This button was still pointing at the dead host
        // until this fix -- same failure mode ops-hub's own dashboard hit
        // for its Fam Canvas tab links (see ops-hub-status-integration
        // skill's "after any Cloudflare account migration" section).
        if (objectType == Schema.Lead.getSObjectType()) {
            url = 'https://family-law-canvas-dev.johnson-turner-92a.workers.dev/book-consult/Lead/' + idStr;
        } else if (objectType == Schema.Opportunity.getSObjectType()) {
            url = 'https://family-law-canvas-dev.johnson-turner-92a.workers.dev/book-consult/Opportunity/' + idStr;
        } else {
            // AcctSeed__Project__c (Matter) -- the separate attorney/matter
            // deep-link ask, reuses the existing /book-call?sfId= route.
            url = 'https://family-law-canvas-dev.johnson-turner-92a.workers.dev/book-call?sfId=' + idStr;
        }
        PageReference pageRef = new PageReference(url);
        pageRef.setRedirect(true);
        return pageRef;
    }
}