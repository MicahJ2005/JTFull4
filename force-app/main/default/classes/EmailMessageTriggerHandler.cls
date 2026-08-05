public class EmailMessageTriggerHandler {

    public static void handleAfterInsert(List<EmailMessage> newList) {
        System.debug( 'EmailMessageTriggerHandler.handleAfterInsert start. Batch size=' + (newList != null ? newList.size() : 0));
        // Re-query to ensure address fields are available in trigger context
        Set<Id> newIds = new Map<Id, EmailMessage>(newList).keySet();
        List<EmailMessage> emails = [
            SELECT Id, Subject, RelatedToId, FromAddress, ToAddress, CcAddress, BccAddress
            FROM EmailMessage
            WHERE Id IN :newIds
        ];
        System.debug( 'Fetched EmailMessage records. Count=' + emails.size());

        // Collect IDs for direct RelatedToId matches (Project or Opportunity only)
        Set<Id> directProjectIds = new Set<Id>();
        Set<Id> directOppIds = new Set<Id>();

        for (EmailMessage em : emails) {
            System.debug( 'Processing EmailMessage Id=' + em.Id + ', Subject=' + em.Subject + ', RelatedToId=' + em.RelatedToId);
            if (em.RelatedToId != null) {
                String sObjName = em.RelatedToId.getSObjectType().getDescribe().getName();
                System.debug(LoggingLevel.DEBUG, 'RelatedTo SObjectType for Email ' + em.Id + ' is ' + sObjName);
                if (sObjName == 'AcctSeed__Project__c') {
                    directProjectIds.add(em.RelatedToId);
                } else if (sObjName == 'Opportunity') {
                    directOppIds.add(em.RelatedToId);
                }
            }
        }
        System.debug( 'Direct related counts => Projects=' + directProjectIds.size() + ', Opportunities=' + directOppIds.size());

        // Query direct Projects and Opportunities (for account info on the record)
        Map<Id, AcctSeed__Project__c> directProjectMap = new Map<Id, AcctSeed__Project__c>();
        if (!directProjectIds.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Querying direct Projects. Count=' + directProjectIds.size());
            for (AcctSeed__Project__c p : [
                SELECT Id, AcctSeed__Account__c
                FROM AcctSeed__Project__c
                WHERE Id IN :directProjectIds
            ]) {
                directProjectMap.put(p.Id, p);
                System.debug( 'Direct Project loaded: ' + p.Id + ' Account=' + p.AcctSeed__Account__c);
            }
        }

        Map<Id, Opportunity> directOppMap = new Map<Id, Opportunity>();
        if (!directOppIds.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Querying direct Opportunities. Count=' + directOppIds.size());
            for (Opportunity o : [
                SELECT Id, AccountId
                FROM Opportunity
                WHERE Id IN :directOppIds
            ]) {
                directOppMap.put(o.Id, o);
                System.debug('Direct Opportunity loaded: ' + o.Id + ' Account=' + o.AccountId);
            }
        }

        // Build address set from all email fields for person-account resolution
        Map<Id, Set<String>> emIdToAddresses = new Map<Id, Set<String>>();
        Set<String> allAddresses = new Set<String>();
        for (EmailMessage em : emails) {
            Set<String> addrs = collectAddresses(em);
            System.debug(LoggingLevel.DEBUG, 'Email ' + em.Id + ' collected addresses: ' + addrs);
            if (!addrs.isEmpty()) {
                emIdToAddresses.put(em.Id, addrs);
                allAddresses.addAll(addrs);
            }
        }
        System.debug( 'All addresses across batch: ' + allAddresses);

        Set<String> normalizedAll = new Set<String>();
        for (String a : allAddresses) {
            if (!String.isBlank(a)) normalizedAll.add(a.toLowerCase());
        }

        // Resolve email addresses to Person Accounts (may be multiple accounts per email)
        Map<String, Set<Id>> emailToPersonAccountIds = new Map<String, Set<Id>>();
        if (!normalizedAll.isEmpty()) {
            System.debug( 'Resolving Person Accounts by PersonEmail. Count=' + normalizedAll.size());
            for (Account a : [
                SELECT Id, PersonEmail
                FROM Account
                WHERE IsPersonAccount = true AND PersonEmail IN :normalizedAll
            ]) {
                if (!String.isBlank(a.PersonEmail)) {
                    String keyEmail = a.PersonEmail.toLowerCase();
                    if (!emailToPersonAccountIds.containsKey(keyEmail)) {
                        emailToPersonAccountIds.put(keyEmail, new Set<Id>());
                    }
                    emailToPersonAccountIds.get(keyEmail).add(a.Id);
                    System.debug( 'Matched Person Account ' + a.Id + ' for email ' + keyEmail);
                }
            }
        } else {
            System.debug( 'No normalized email addresses to resolve to Person Accounts.');
        }
        System.debug( 'Total unique emails matched to Person Accounts: ' + emailToPersonAccountIds.size());

        // Collect all Person Account IDs resolved from email addresses
        Set<Id> personAccountIds = new Set<Id>();
        for (Set<Id> idsForEmail : emailToPersonAccountIds.values()) {
            personAccountIds.addAll(idsForEmail);
        }
        personAccountIds.remove(null);

        // Query all Projects and Opportunities tied to matched Person Accounts
        Map<Id, List<AcctSeed__Project__c>> accToProjects = new Map<Id, List<AcctSeed__Project__c>>();
        Map<Id, List<Opportunity>> accToOpps = new Map<Id, List<Opportunity>>();

        if (!personAccountIds.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Querying Projects for matched Person Accounts. Count=' + personAccountIds.size());
            for (AcctSeed__Project__c p : [
                SELECT Id, AcctSeed__Account__c
                FROM AcctSeed__Project__c
                WHERE AcctSeed__Account__c IN :personAccountIds
            ]) {
                if (!accToProjects.containsKey(p.AcctSeed__Account__c)) {
                    accToProjects.put(p.AcctSeed__Account__c, new List<AcctSeed__Project__c>());
                }
                accToProjects.get(p.AcctSeed__Account__c).add(p);
            }
            System.debug( 'accToProjects accounts=' + accToProjects.keySet());

            System.debug( 'Querying Opportunities for matched Person Accounts.');
            for (Opportunity o : [
                SELECT Id, AccountId
                FROM Opportunity
                WHERE AccountId IN :personAccountIds
            ]) {
                if (!accToOpps.containsKey(o.AccountId)) {
                    accToOpps.put(o.AccountId, new List<Opportunity>());
                }
                accToOpps.get(o.AccountId).add(o);
            }
            System.debug( 'accToOpps accounts=' + accToOpps.keySet());
        } else {
            System.debug( 'No Person Accounts matched from email addresses.');
        }

        // Build Related_Email_Message__c records — 1 per EmailMessage per Project/Opportunity across all eligible Accounts
        List<Related_Email_Message__c> relatedMsgsToInsert = new List<Related_Email_Message__c>();
        Set<String> dedupeKeys = new Set<String>(); // (EmailMessageId + Type + TargetId)

        for (EmailMessage em : emails) {
            System.debug( 'Building Related_Email_Message__c for Email ' + em.Id);
            // 1. Direct RelatedToId → Project: create exactly 1 record for that project
            // 2. Direct RelatedToId → Opportunity: create exactly 1 record for that opportunity
            if (em.RelatedToId != null) {
                String sObjName = em.RelatedToId.getSObjectType().getDescribe().getName();
                if (sObjName == 'AcctSeed__Project__c') {
                    AcctSeed__Project__c proj = directProjectMap.get(em.RelatedToId);
                    if (proj != null) {
                        String key = em.Id + ':P:' + proj.Id;
                        if (dedupeKeys.add(key)) {
                            Related_Email_Message__c rec = buildRelatedMsg(em, proj.AcctSeed__Account__c, proj.Id, null);
                            relatedMsgsToInsert.add(rec);
                            System.debug( 'Prepared direct Project relation rec=' + rec + ' key=' + key);
                        } else {
                            System.debug( 'Duplicate skipped for direct Project. Key=' + key);
                        }
                    } else {
                        System.debug( 'Direct Project not found for Id=' + em.RelatedToId);
                    }
                } else if (sObjName == 'Opportunity') {
                    Opportunity opp = directOppMap.get(em.RelatedToId);
                    if (opp != null) {
                        String key = em.Id + ':O:' + opp.Id;
                        if (dedupeKeys.add(key)) {
                            Related_Email_Message__c rec = buildRelatedMsg(em, opp.AccountId, null, opp.Id);
                            relatedMsgsToInsert.add(rec);
                            System.debug( 'Prepared direct Opportunity relation rec=' + rec + ' key=' + key);
                        } else {
                            System.debug('Duplicate skipped for direct Opportunity. Key=' + key);
                        }
                    } else {
                        System.debug( 'Direct Opportunity not found for Id=' + em.RelatedToId);
                    }
                }
            }

            // 3. Person Accounts matched via email addresses → all related Projects and Opportunities
            Set<String> addrs = emIdToAddresses.get(em.Id);
            System.debug(LoggingLevel.DEBUG, 'Email ' + em.Id + ' addresses for Person Account matching: ' + addrs);
            if (addrs != null) {
                Set<Id> matchedPersonAccounts = new Set<Id>();
                for (String a : addrs) {
                    String k = a != null ? a.toLowerCase() : null;
                    if (String.isBlank(k)) continue;
                    Set<Id> accSet = emailToPersonAccountIds.get(k);
                    if (accSet != null && !accSet.isEmpty()) {
                        matchedPersonAccounts.addAll(accSet);
                        System.debug( 'Email ' + em.Id + ' matched Person Accounts ' + accSet + ' for address ' + k);
                    }
                }

                for (Id accId : matchedPersonAccounts) {
                    if (accToProjects.containsKey(accId)) {
                        for (AcctSeed__Project__c proj : accToProjects.get(accId)) {
                            String key = em.Id + ':P:' + proj.Id;
                            if (dedupeKeys.add(key)) {
                                Related_Email_Message__c rec = buildRelatedMsg(em, accId, proj.Id, null);
                                relatedMsgsToInsert.add(rec);
                                System.debug('Prepared related Project rec=' + rec + ' key=' + key + ' for Account=' + accId);
                            } else {
                                System.debug('Duplicate skipped for related Project. Key=' + key);
                            }
                        }
                    } else {
                        System.debug( 'No Projects found for matched Person Account ' + accId);
                    }
                    if (accToOpps.containsKey(accId)) {
                        for (Opportunity opp : accToOpps.get(accId)) {
                            String key = em.Id + ':O:' + opp.Id;
                            if (dedupeKeys.add(key)) {
                                Related_Email_Message__c rec = buildRelatedMsg(em, accId, null, opp.Id);
                                relatedMsgsToInsert.add(rec);
                                System.debug('Prepared related Opp rec=' + rec + ' key=' + key + ' for Account=' + accId);
                            } else {
                                System.debug('Duplicate skipped for related Opp. Key=' + key);
                            }
                        }
                    } else {
                        System.debug( 'No Opportunities found for matched Person Account ' + accId);
                    }
                }
            }
        }

        System.debug( 'Total Related_Email_Message__c to insert: ' + relatedMsgsToInsert.size());
        if (!relatedMsgsToInsert.isEmpty()) {
            insert relatedMsgsToInsert;
            System.debug( 'Inserted Related_Email_Message__c records. Count=' + relatedMsgsToInsert.size());
        } else {
            System.debug('No Related_Email_Message__c records to insert.');
        }
    }

    private static Set<String> collectAddresses(EmailMessage em) {
        Set<String> results = new Set<String>();
        addAddresses(results, em.FromAddress);
        addAddresses(results, em.ToAddress);
        addAddresses(results, em.CcAddress);
        addAddresses(results, em.BccAddress);
        System.debug( 'collectAddresses for Email ' + em.Id + ' => ' + results);
        return results;
    }

    private static void addAddresses(Set<String> results, String fieldVal) {
        if (String.isBlank(fieldVal)) return;
        for (String raw : fieldVal.split('[,;]')) {
            String v = raw != null ? raw.trim().toLowerCase() : null;
            if (String.isBlank(v)) continue;
            if (v.contains('<') && v.contains('>')) {
                Integer start = v.indexOf('<');
                Integer endInt = v.indexOf('>');
                if (start != -1 && endInt != -1 && endInt > start + 1) {
                    v = v.substring(start + 1, endInt).trim().toLowerCase();
                }
            }
            results.add(v);
        }
        System.debug('addAddresses appended. Current set size=' + results.size());
    }

    private static Related_Email_Message__c buildRelatedMsg(EmailMessage em, Id accId, Id projectId, Id oppId) {
        // Combine all To and Cc addresses to ensure Email_Recipients__c includes both sets
        String toPart = String.isBlank(em.ToAddress) ? '' : em.ToAddress.trim();
        String ccPart = String.isBlank(em.CcAddress) ? '' : em.CcAddress.trim();
        String combinedRecipients;
        if (!String.isBlank(toPart) && !String.isBlank(ccPart)) {
            combinedRecipients = toPart + ', ' + ccPart;
        } else if (!String.isBlank(toPart)) {
            combinedRecipients = toPart;
        } else {
            combinedRecipients = ccPart; // may be blank if both were blank
        }

        Related_Email_Message__c rec = new Related_Email_Message__c(
            Account__c = accId,
            Email_Message_Id__c = em.Id,
            Email_Subject__c = em.Subject,
            Email_Recipients__c = combinedRecipients,
            Matter__c = projectId,
            Opportunity__c = oppId
        );
        System.debug( 'buildRelatedMsg created: ' + rec);
        return rec;
    }
}