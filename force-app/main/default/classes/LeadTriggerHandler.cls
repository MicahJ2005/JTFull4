public class LeadTriggerHandler {

    public static void handleAfterUpdate(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        Set<Id> convertedLeadIds = new Set<Id>();
        Map<Id, Id> leadToAccountMap = new Map<Id, Id>();

        for (Lead l : newLeads) {
            if (l.IsConverted && l.ConvertedAccountId != null &&
                (!oldMap.get(l.Id).IsConverted || oldMap.get(l.Id).ConvertedAccountId == null)) {
                convertedLeadIds.add(l.Id);
                leadToAccountMap.put(l.Id, l.ConvertedAccountId);
            }
        }

        if (convertedLeadIds.isEmpty()) return;

        // Query Opportunities by Converted Account Ids
        Map<Id, Opportunity> accountToOpportunity = new Map<Id, Opportunity>();
        for (Opportunity opp : [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE AccountId IN :leadToAccountMap.values()
        ]) {
            accountToOpportunity.put(opp.AccountId, opp);
        }

        // Query all related records
        List<Related_Call_Transcript__c> callTranscripts = [
            SELECT Id, Name, Account__c, Lead__c
            FROM Related_Call_Transcript__c
            WHERE Lead__c IN :convertedLeadIds
        ];

        List<SMS_Session_Individual__c> smsIndividuals = [
            SELECT Id, Name, Account__c, Lead__c, SMS_Session__c
            FROM SMS_Session_Individual__c
            WHERE Lead__c IN :convertedLeadIds
        ];

        List<Related_Meeting_Transcript__c> meetingTranscripts = [
            SELECT Id, Name, Account__c, Lead__c
            FROM Related_Meeting_Transcript__c
            WHERE Lead__c IN :convertedLeadIds
        ];

        List<SObject> recordsToUpsert = new List<SObject>();
        List<Related_Text_Message__c> textMessagesToInsert = new List<Related_Text_Message__c>();

        for (Related_Call_Transcript__c r : callTranscripts) {
            Id accountId = leadToAccountMap.get(r.Lead__c);
            Opportunity opp = accountToOpportunity.get(accountId);
            r.Account__c = accountId;
            r.Lead__c = null;
            if (opp != null) r.Opportunity__c = opp.Id;
            recordsToUpsert.add(r);
        }

        for (SMS_Session_Individual__c s : smsIndividuals) {
            Id accountId = leadToAccountMap.get(s.Lead__c);
            Opportunity opp = accountToOpportunity.get(accountId);
            s.Account__c = accountId;
            s.Lead__c = null;
            recordsToUpsert.add(s);

            if (opp != null) {
                Related_Text_Message__c text = new Related_Text_Message__c();
                text.Opportunity__c = opp.Id;
                text.Text_Message_Session__c = s.SMS_Session__c;
                textMessagesToInsert.add(text);
            }
        }

        for (Related_Meeting_Transcript__c m : meetingTranscripts) {
            Id accountId = leadToAccountMap.get(m.Lead__c);
            Opportunity opp = accountToOpportunity.get(accountId);
            m.Account__c = accountId;
            m.Lead__c = null;
            if (opp != null) m.Opportunity__c = opp.Id;
            recordsToUpsert.add(m);
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert;
        }

        if (!textMessagesToInsert.isEmpty()) {
            insert textMessagesToInsert;
        }
    }
}
