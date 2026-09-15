public with sharing class RelatedPartiesController {

    // ─── READ ───────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static String getMatterName(Id matterId) {
        AcctSeed__Project__c m = [SELECT Name FROM AcctSeed__Project__c WHERE Id = :matterId LIMIT 1];
        return m.Name;
    }

    @AuraEnabled(cacheable=true)
    public static List<Related_People__c> getRelatedPeople(Id matterId) {
        return [
            SELECT Id,
                   Person_Account_Name__c,
                   Person_Account_Name__r.Name,
                   Person_Account_Name__r.Phone,
                   Person_Account_Name__r.PersonMobilePhone,
                   Person_Account_Name__r.PersonEmail,
                   Related_People_Class__c
            FROM Related_People__c
            WHERE Matter_Name__c = :matterId
            ORDER BY Related_People_Class__c, Person_Account_Name__r.Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Related_Professionals__c> getRelatedProfessionals(Id matterId) {
        return [
            SELECT Id,
                   Business_Contact__c,
                   Business_Contact__r.Name,
                   Business_Contact__r.Phone,
                   Business_Contact__r.Email,
                   Business_Contact__r.Account.Name,
                   Business_Contact__r.Opposing_Paralegal_Assistant__c,
                   Business_Contact__r.Opposing_Paralegal_Assistant__r.Name,
                   Business_Contact__r.Opposing_Paralegal_Assistant__r.Phone,
                   Business_Contact__r.Opposing_Paralegal_Assistant__r.Email,
                   Related_Professional_Type__c,
                   Professional_Service_Provider__c
            FROM Related_Professionals__c
            WHERE Matter_Name__c = :matterId
            ORDER BY Related_Professional_Type__c, Business_Contact__r.Name
        ];
    }

    // ─── SEARCH ─────────────────────────────────────────────

    @AuraEnabled
    public static List<Account> searchPersonAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Account>();
        }
        String likeStr = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, Phone, PersonMobilePhone, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
              AND Name LIKE :likeStr
            ORDER BY Name
            LIMIT 20
        ];
    }

    @AuraEnabled
    public static List<Contact> searchBusinessContacts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Contact>();
        }
        String likeStr = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, Phone, Email, Account.Name,
                   Opposing_Paralegal_Assistant__c,
                   Opposing_Paralegal_Assistant__r.Name,
                   Opposing_Paralegal_Assistant__r.Phone,
                   Opposing_Paralegal_Assistant__r.Email
            FROM Contact
            WHERE Account.IsPersonAccount = false
              AND Name LIKE :likeStr
            ORDER BY Name
            LIMIT 20
        ];
    }

    @AuraEnabled
    public static List<Account> searchOrganizationAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Account>();
        }
        String likeStr = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name
            FROM Account
            WHERE IsPersonAccount = false
              AND Name LIKE :likeStr
            ORDER BY Name
            LIMIT 20
        ];
    }

    // ─── CREATE (Link Existing) ─────────────────────────────

    @AuraEnabled
    public static Id createRelatedPerson(Id matterId, Id personAccountId, String relationship) {
        Related_People__c rp = new Related_People__c(
            Matter_Name__c = matterId,
            Person_Account_Name__c = personAccountId,
            Related_People_Class__c = relationship
        );
        insert rp;
        return rp.Id;
    }

    @AuraEnabled
    public static Id createRelatedProfessional(Id matterId, Id businessContactId, String relationship) {
        Related_Professionals__c rp = new Related_Professionals__c(
            Matter_Name__c = matterId,
            Business_Contact__c = businessContactId,
            Related_Professional_Type__c = relationship
        );
        insert rp;
        return rp.Id;
    }

    // ─── CREATE (New Record + Link) ─────────────────────────

    @AuraEnabled
    public static Id createPersonAndLink(Id matterId, String firstName, String lastName,
                                          String phone, String email, String relationship) {
        // Create Person Account
        // Note: Person Accounts require a specific record type. Adjust the RecordTypeId
        // to match your org's Person Account record type.
        Id personAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')?.getRecordTypeId();

        Account pa = new Account(
            FirstName = firstName,
            LastName = lastName,
            PersonMobilePhone = phone,
            PersonEmail = email
        );
        if (personAccountRtId != null) {
            pa.RecordTypeId = personAccountRtId;
        }
        insert pa;

        // Create junction
        Related_People__c rp = new Related_People__c(
            Matter_Name__c = matterId,
            Person_Account_Name__c = pa.Id,
            Related_People_Class__c = relationship
        );
        insert rp;
        return rp.Id;
    }

    @AuraEnabled
    public static Id createProfessionalAndLink(Id matterId, String firstName, String lastName,
                                                 String phone, String email, String organization,
                                                 Id organizationAccountId, String relationship) {
        // Prefer an explicitly-picked existing Account. Fall back to name-based
        // find-or-create only when no picker selection was made (free-typed org name).
        Id accountId = organizationAccountId;
        if (accountId == null && String.isNotBlank(organization)) {
            List<Account> existingOrgs = [
                SELECT Id FROM Account
                WHERE Name = :organization AND IsPersonAccount = false
                LIMIT 1
            ];
            if (!existingOrgs.isEmpty()) {
                accountId = existingOrgs[0].Id;
            } else {
                Account orgAccount = new Account(Name = organization);
                insert orgAccount;
                accountId = orgAccount.Id;
            }
        }

        // Create Contact
        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Phone = phone,
            Email = email
        );
        if (accountId != null) {
            c.AccountId = accountId;
        }
        insert c;

        // Create junction
        Related_Professionals__c rp = new Related_Professionals__c(
            Matter_Name__c = matterId,
            Business_Contact__c = c.Id,
            Related_Professional_Type__c = relationship
        );
        insert rp;
        return rp.Id;
    }

    // ─── DELETE ──────────────────────────────────────────────

    @AuraEnabled
    public static void removeRelatedPerson(Id junctionId) {
        delete [SELECT Id FROM Related_People__c WHERE Id = :junctionId LIMIT 1];
    }

    @AuraEnabled
    public static void removeRelatedProfessional(Id junctionId) {
        delete [SELECT Id FROM Related_Professionals__c WHERE Id = :junctionId LIMIT 1];
    }
}