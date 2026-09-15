public with sharing class DocReviewQueueController {
    /**
     * Controller for the Document Review Queue LWC.
     *
     * SCOPE (2026-08-07, Chris): surfaces redaction-pipeline documents that need staff
     * review, grouped CSS -> Matter -> aging (oldest first). Data lives in Supabase
     * (public.documents), NOT Salesforce -- the redaction pipeline (jt-box-ingestion)
     * writes there. This controller reads Supabase via the DIYvorce_Edge_Functions named
     * credential (or a dedicated documents endpoint TBD).
     *
     * STATUS: SCAFFOLD. getReviewQueue() returns MOCK data behind the final interface shape
     * so the LWC UI can be built + reviewed in full4 NOW, before two upstream deps land:
     *   1. Supabase matters.css_name / css_user_id columns (handoff to FamCanvas session).
     *   2. The authed Supabase read path from Apex (named credential + documents endpoint).
     * Swap the mock block in getReviewQueue() for the real callout once both are ready; the
     * DTO shape + the two write methods (approveAndFile / reject) are the stable contract.
     */

    // ── DTOs (the stable contract the LWC binds to) ──────────────────────────────
    public class ReviewDoc {
        @AuraEnabled public String documentId;      // Supabase documents.id (uuid)
        @AuraEnabled public String fileName;        // proposed/target filename
        @AuraEnabled public String matterName;      // matters.name
        @AuraEnabled public String matterSfId;      // AcctSeed__Project__c Id (for deep-link)
        @AuraEnabled public String cssName;         // Client Support Specialist (grouping)
        @AuraEnabled public String documentType;    // classified leaf/category
        @AuraEnabled public String holdReason;      // review_reason (why it's held)
        @AuraEnabled public String redactionDecision; // approved/hold/etc
        @AuraEnabled public Integer ageDays;        // days since received (aging sort)
        @AuraEnabled public String boxFileUrl;      // link to the redacted file in Box
        @AuraEnabled public String targetFolder;    // proposed destination (e.g. Documents/Tax Returns)
    }

    @AuraEnabled(cacheable=true)
    public static List<ReviewDoc> getReviewQueue() {
        // TODO(real): callout to Supabase documents WHERE needs_review=true AND reviewed=false,
        //   join matters for matterName/cssName, sort css_name, matter_name, received_date ASC.
        //   Auth via named credential. See MatterCommunicationAnalysisBatch for the org's
        //   callout idiom (Database.AllowsCallouts + Http()).
        return buildMockQueue();
    }

    @AuraEnabled(cacheable=true)
    public static ReviewDoc getReviewDoc(String documentId) {
        // TODO(real): SELECT one Supabase documents row by id (+ join matter). For scaffold,
        //   return the matching mock row (or the first) so the review SCREEN can be built now.
        for (ReviewDoc d : buildMockQueue()) {
            if (d.documentId == documentId) return d;
        }
        List<ReviewDoc> all = buildMockQueue();
        return all.isEmpty() ? null : all[0];
    }

    @AuraEnabled
    public static void approveAndFile(String documentId, String correctedType,
                                      String correctedFolder) {
        // TODO(real): PATCH Supabase documents SET reviewed=true, reviewed_at=now(),
        //   reviewed_by=<current user>, document_type=correctedType, lifecycle_status='approved';
        //   then trigger the pipeline's file-to-destination action (move from _Needs Review
        //   to correctedFolder). For now: no-op scaffold.
        System.debug('approveAndFile(scaffold): ' + documentId + ' -> ' + correctedFolder);
    }

    @AuraEnabled
    public static void reject(String documentId, String reason) {
        // TODO(real): PATCH Supabase documents SET reviewed=true, reviewed_at=now(),
        //   reviewed_by=<current user>, lifecycle_status='rejected', review_reason=reason.
        System.debug('reject(scaffold): ' + documentId + ' reason=' + reason);
    }

    // ── Mock data (scaffold only — remove when the real callout lands) ────────────
    private static List<ReviewDoc> buildMockQueue() {
        List<ReviewDoc> out = new List<ReviewDoc>();
        out.add(makeMock('doc-1', 'IRS Federal Tax Return (1040).pdf', 'Smith v. Smith',
            'Jane Paralegal', 'Federal Tax Return (1040)', 'ocr_low_confidence_page_3',
            'hold', 5, 'Documents/Tax Returns'));
        out.add(makeMock('doc-2', 'WF Bank Statement 2026-03.pdf', 'Smith v. Smith',
            'Jane Paralegal', 'Bank Statement', 'possible_account_near_threshold',
            'hold', 2, 'Documents/Bank Accounts'));
        out.add(makeMock('doc-3', 'Child Support Order 2026-01-10.pdf', 'Doe Custody',
            'Bob CSS', 'Child Support Order', 'classification_low_confidence',
            'hold', 8, 'Pleadings Official'));
        return out;
    }

    private static ReviewDoc makeMock(String id, String fn, String matter, String css,
            String dtype, String reason, String decision, Integer age, String folder) {
        ReviewDoc d = new ReviewDoc();
        d.documentId = id; d.fileName = fn; d.matterName = matter; d.cssName = css;
        d.documentType = dtype; d.holdReason = reason; d.redactionDecision = decision;
        d.ageDays = age; d.targetFolder = folder; d.matterSfId = null; d.boxFileUrl = '#';
        return d;
    }
}