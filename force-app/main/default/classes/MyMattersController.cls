/**
 * MyMattersController
 * -------------------
 * Read-only service for the matterList LWC. Returns the logged-in user's
 * most recent Matters (AcctSeed__Project__c) with phase, questionnaire
 * link, and Box folder access.
 *
 * @Date July 2026
 */
public with sharing class MyMattersController {

    /** Base URL used to build an embeddable Box folder view from its folder ID. */
    private static final String BOX_EMBED_BASE = 'https://app.box.com/embed/folder/';

    /** Returns the 3 most recent Matters owned by the current user. */
    @AuraEnabled(cacheable=true)
    public static List<MatterWrapper> getMyMatters() {
        List<MatterWrapper> result = new List<MatterWrapper>();

        for (AcctSeed__Project__c m : [
            SELECT Id, Name, CreatedDate,
                   AcctSeed__Status__c,
                   Matter_Phase__c,
                   Current_Phase_Title__c,
                   Current_Phase_Description__c,
                   Client_Questionnaire_Link__c,
                   Assets_Debts_Questionnaire_link__c,
                   OFPHRO_Questionnaire_Link__c,
                   SENE_Prep_Questionnaire_Link__c,
                   Box_Matter_Folder_ID__c,
                   Box_Client_Upload_Link__c
            FROM AcctSeed__Project__c
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 3
        ]) {
            result.add(new MatterWrapper(m));
        }
        return result;
    }

    /** UI-ready projection of a Matter record. */
    public class MatterWrapper {
        @AuraEnabled public Id       matterId;
        @AuraEnabled public String   name;
        @AuraEnabled public String   status;
        @AuraEnabled public Datetime createdDate;

        // Current phase
        @AuraEnabled public String phaseValue;
        @AuraEnabled public String currentPhaseTitle;
        @AuraEnabled public String currentPhaseDescription;

        // Highest-priority questionnaire link that is populated
        @AuraEnabled public String questionnaireUrl;

        // Box integration
        @AuraEnabled public String boxFolderEmbedUrl;
        @AuraEnabled public String boxUploadUrl;

        public MatterWrapper(AcctSeed__Project__c m) {
            this.matterId    = m.Id;
            this.name        = m.Name;
            this.status      = m.AcctSeed__Status__c;
            this.createdDate = m.CreatedDate;

            this.phaseValue              = m.Matter_Phase__c;
            this.currentPhaseTitle       = m.Current_Phase_Title__c;
            this.currentPhaseDescription = m.Current_Phase_Description__c;

            // First populated questionnaire link, in priority order
            this.questionnaireUrl = firstNonBlank(new List<String>{
                m.Client_Questionnaire_Link__c,
                m.Assets_Debts_Questionnaire_link__c,
                m.OFPHRO_Questionnaire_Link__c,
                m.SENE_Prep_Questionnaire_Link__c
            });

            // Embed URL derived from the stored Box folder ID
            this.boxFolderEmbedUrl = String.isNotBlank(m.Box_Matter_Folder_ID__c)
                ? BOX_EMBED_BASE + m.Box_Matter_Folder_ID__c
                : null;
            this.boxUploadUrl = m.Box_Client_Upload_Link__c;
        }
    }

    /** Returns the first non-blank value from the given list, or null. */
    private static String firstNonBlank(List<String> values) {
        for (String v : values) {
            if (String.isNotBlank(v)) return v;
        }
        return null;
    }
}