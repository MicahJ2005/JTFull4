public class XDFactsFieldUpdater {

    // ----------------------------------------------------------------
    // OUTPUT WRAPPER
    // ----------------------------------------------------------------
    public class UpdateResult {
        @InvocableVariable
        public XD_Facts__c updatedXDFacts;

        @InvocableVariable
        public Boolean hasChanges;

        @InvocableVariable
        public String errorMessage;
    }

    // ----------------------------------------------------------------
    // INVOCABLE METHOD
    // ----------------------------------------------------------------
    @InvocableMethod(
        label='Update XD Facts Fields from Business Contact'
        description='Updates Attorney fields ALWAYS. Updates Paralegal fields IF present.'
        category='XD Facts'
    )
    public static List<UpdateResult> updateXDFactsFields(List<XD_Facts_Request_Wrapper> requests) {
        
        List<UpdateResult> results = new List<UpdateResult>();
        List<XD_Facts__c> factsToUpdate = new List<XD_Facts__c>();
        Map<Id, Integer> indexMap = new Map<Id, Integer>();

        // ---------------------------------------------------------
        // PRE-PROCESSING: Get Paralegal Info (Bulkified)
        // ---------------------------------------------------------
        Set<Id> paralegalIds = new Set<Id>();

        // Collect Paralegal IDs only if they exist
        for (XD_Facts_Request_Wrapper req : requests) {
            if (req.businessContact != null && req.businessContact.Opposing_Paralegal_Assistant__c != null) {
                paralegalIds.add(req.businessContact.Opposing_Paralegal_Assistant__c);
            }
        }

        // Query Paralegal details (Name, Email)
        Map<Id, Contact> paralegalMap = new Map<Id, Contact>();
        if (!paralegalIds.isEmpty()) {
            paralegalMap = new Map<Id, Contact>([
                SELECT Id, FirstName, LastName, Email 
                FROM Contact 
                WHERE Id IN :paralegalIds
            ]);
        }

        // ---------------------------------------------------------
        // MAIN LOOP: Process Requests
        // ---------------------------------------------------------
        for (Integer i = 0; i < requests.size(); i++) {
            XD_Facts_Request_Wrapper req = requests[i];
            UpdateResult result = new UpdateResult();

            XD_Facts__c xdFact = req.xdFactsRecord;
            Contact bc = req.businessContact;
            
            // Initialize Default Result
            result.updatedXDFacts = xdFact;
            result.hasChanges = false;
            result.errorMessage = null;

            // Safety Check: If inputs are null, skip
            if (xdFact == null || bc == null) {
                results.add(result);
                continue;
            }

            Boolean hasChanges = false;

            // =========================================================
            // SECTION 1: ATTORNEY FIELDS (Always Runs)
            // =========================================================
            // This runs even if Paralegal is null.

            // 1. First Name
            if (String.isNotBlank(bc.FirstName) && xdFact.First_Name_Opp_Atty__c != bc.FirstName) {
                xdFact.First_Name_Opp_Atty__c = bc.FirstName;
                hasChanges = true;
            }
            // 2. Last Name
            if (String.isNotBlank(bc.LastName) && xdFact.Last_Name_Opp_Atty__c != bc.LastName) {
                xdFact.Last_Name_Opp_Atty__c = bc.LastName;
                hasChanges = true;
            }
            // 3. Email
            if (String.isNotBlank(bc.Email) && xdFact.Email_Opp_Atty__c != bc.Email) {
                xdFact.Email_Opp_Atty__c = bc.Email;
                hasChanges = true;
            }
            // 4. Phone
            if (String.isNotBlank(bc.Phone) && xdFact.Phone_Opp_Atty__c != bc.Phone) {
                xdFact.Phone_Opp_Atty__c = bc.Phone;
                hasChanges = true;
            }
            // 5. Street
            if (String.isNotBlank(bc.MailingStreet) && xdFact.Street_Opp_Atty__c != bc.MailingStreet) {
                xdFact.Street_Opp_Atty__c = bc.MailingStreet;
                hasChanges = true;
            }
            // 6. City
            if (String.isNotBlank(bc.MailingCity) && xdFact.City_Opp_Atty__c != bc.MailingCity) {
                xdFact.City_Opp_Atty__c = bc.MailingCity;
                hasChanges = true;
            }
            // 7. State
            if (String.isNotBlank(bc.MailingState) && xdFact.State_Opp_Atty__c != bc.MailingState) {
                xdFact.State_Opp_Atty__c = bc.MailingState;
                hasChanges = true;
            }
            // 8. Zip Code
            if (String.isNotBlank(bc.MailingPostalCode) && xdFact.Zip_Code_Opp_Atty__c != bc.MailingPostalCode) {
                xdFact.Zip_Code_Opp_Atty__c = bc.MailingPostalCode;
                hasChanges = true;
            }
            // 9. Firm Name (Account)
            if (bc.Account != null && String.isNotBlank(bc.Account.Name) && xdFact.Opposing_Atty_Firm_Name__c != bc.Account.Name) {
                xdFact.Opposing_Atty_Firm_Name__c = bc.Account.Name;
                hasChanges = true;
            }

            // =========================================================
            // SECTION 2: PARALEGAL FIELDS (Conditional)
            // =========================================================
            // This ONLY runs if a Paralegal is assigned and found.
            
            if (bc.Opposing_Paralegal_Assistant__c != null && paralegalMap.containsKey(bc.Opposing_Paralegal_Assistant__c)) {
                
                Contact paralegal = paralegalMap.get(bc.Opposing_Paralegal_Assistant__c);

                // 10. Paralegal First Name
                if (String.isNotBlank(paralegal.FirstName) && xdFact.Opp_Paralegal_Asst_name__c != paralegal.FirstName) {
                    xdFact.Opp_Paralegal_Asst_name__c = paralegal.FirstName;
                    hasChanges = true;
                }
                // 11. Paralegal Last Name
                if (String.isNotBlank(paralegal.LastName) && xdFact.Opp_Paralegal_Asst_last_name__c != paralegal.LastName) {
                    xdFact.Opp_Paralegal_Asst_last_name__c = paralegal.LastName;
                    hasChanges = true;
                }
                // 12. Paralegal Email
                if (String.isNotBlank(paralegal.Email) && xdFact.Opp_Paralegal_Asst_Email__c != paralegal.Email) {
                    xdFact.Opp_Paralegal_Asst_Email__c = paralegal.Email;
                    hasChanges = true;
                }
            }

            // =========================================================
            // FINALIZATION: Add to Update List
            // =========================================================

            if (hasChanges) {
                factsToUpdate.add(xdFact);
                indexMap.put(xdFact.Id, i);
            }

            result.updatedXDFacts = xdFact;
            result.hasChanges = hasChanges;
            results.add(result);
        }

        // ---------------------------------------------------------
        // DML OPERATION (Database Update)
        // ---------------------------------------------------------
        if (!factsToUpdate.isEmpty()) {

            // Allow partial success to prevent one error stopping all updates
            Database.SaveResult[] saveResults = Database.update(factsToUpdate, false); 

            // Map errors back to results
            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                XD_Facts__c fact = factsToUpdate[j];

                if (indexMap.containsKey(fact.Id)) {
                    Integer resultIndex = indexMap.get(fact.Id);
                    UpdateResult res = results[resultIndex];

                    if (!sr.isSuccess()) {
                        res.errorMessage = sr.getErrors()[0].getMessage();
                    }
                }
            }
        }

        return results;
    }
}