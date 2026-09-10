public without sharing class EventAccountMatchController {

    public class AccountMatchWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String richTextNotes { get; set; }
        @AuraEnabled public String recordType { get; set; }
        @AuraEnabled public Boolean isTopMatchCandidate { get; set; }
        @AuraEnabled public List<MatterMatchWrapper> activeMatterMatches { get; set; }

        public AccountMatchWrapper(Account acc) {
            this.id = acc.Id;
            this.name = acc.Name;
            this.email = acc.PersonEmail;
            this.richTextNotes = acc.Description;
            this.recordType = 'PersonAccount';
            this.isTopMatchCandidate = false;
            this.activeMatterMatches = new List<MatterMatchWrapper>();
        }

        public AccountMatchWrapper(Lead leadRec) {
            this.id = leadRec.Id;
            this.name = leadRec.Name;
            this.email = leadRec.Email;
            this.richTextNotes = leadRec.Description;
            this.recordType = 'Lead';
            this.isTopMatchCandidate = false;
            this.activeMatterMatches = new List<MatterMatchWrapper>();
        }
    }

    // Represents an Active Matter (AcctSeed__Project__c) where the Event Owner holds
    // one of the team-assignment roles, surfaced to flag a Person Account as a top match.
    public class MatterMatchWrapper {
        @AuraEnabled public String matterId { get; set; }
        @AuraEnabled public String matterName { get; set; }
        @AuraEnabled public String role { get; set; }
        @AuraEnabled public String matterUrl { get; set; }

        public MatterMatchWrapper(AcctSeed__Project__c matter, String role) {
            this.matterId = matter.Id;
            this.matterName = matter.Name;
            this.role = role;
            this.matterUrl = '/' + matter.Id;
        }
    }

    // Inner class to deserialize the JSON response from the prompt
    public class PromptResponseWrapper {
        public String firstName;
        public String lastName;
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountMatchWrapper> getPotentialMatches(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('Event ID is required.');
        }
        System.debug('Fetching potential matches for Event ID: ' + eventId);
        
        List<Event> events = [
            SELECT Id, Subject, Description, WhatId, OwnerId
            FROM Event
            WHERE Id = :eventId
            LIMIT 1
        ];

        // The Event can be gone by the time this runs if another process (e.g. a calendar
        // sync integration) deletes or replaces it in a separate transaction right after
        // insert. Since this is called from EventTriggerHandler.handleAfterInsert, an unhandled
        // exception here would roll back the entire insert DML for every Event in the batch -
        // so skip gracefully instead of throwing.
        if (events.isEmpty()) {
            System.debug('getPotentialMatches: Event ' + eventId + ' no longer exists - skipping.');
            return new List<AccountMatchWrapper>();
        }

        Event evt = events[0];

        if (evt.WhatId != null) {
            return new List<AccountMatchWrapper>();
        }

        // Call the Prompt Template using Agentforce / Einstein LLM API
        PromptResponseWrapper nameDetails = getNameUsingAgentforce(evt.Subject);
        if (nameDetails == null || (String.isBlank(nameDetails.firstName) && String.isBlank(nameDetails.lastName))) {
            return new List<AccountMatchWrapper>();
        }

        return findPotentialMatches(nameDetails, evt.OwnerId);
    }

    /**
     * Queries Accounts and Leads for potential matches given extracted name details.
     * Split out from getPotentialMatches so the matching logic can be unit tested
     * without depending on a live Agentforce/Einstein LLM callout.
     */
    @TestVisible
    private static List<AccountMatchWrapper> findPotentialMatches(PromptResponseWrapper nameDetails) {
        return findPotentialMatches(nameDetails, null);
    }

    @TestVisible
    private static List<AccountMatchWrapper> findPotentialMatches(PromptResponseWrapper nameDetails, Id eventOwnerId) {
        List<Account> accountMatches;
        List<Lead> leadMatches;

        // Dynamic wildcards based on extracted name parts
        String firstNamePattern = String.isNotBlank(nameDetails.firstName) ? '%' + String.escapeSingleQuotes(nameDetails.firstName) + '%' : null;
        String lastNamePattern = String.isNotBlank(nameDetails.lastName) ? '%' + String.escapeSingleQuotes(nameDetails.lastName) + '%' : null;

        if (String.isNotBlank(firstNamePattern) && String.isNotBlank(lastNamePattern)) {
            // Both First and Last Name extracted
            accountMatches = [
                SELECT Id, Name, FirstName, LastName, PersonEmail, Description 
                FROM Account 
                WHERE IsPersonAccount = TRUE 
                  AND FirstName LIKE :firstNamePattern 
                  AND LastName LIKE :lastNamePattern 
                LIMIT 10
            ];

            leadMatches = [
                SELECT Id, Name, FirstName, LastName, Email, Description 
                FROM Lead 
                WHERE IsConverted = FALSE 
                  AND FirstName LIKE :firstNamePattern 
                  AND LastName LIKE :lastNamePattern 
                LIMIT 10
            ];
        } else if (String.isNotBlank(lastNamePattern)) {
            // Only Last Name extracted
            accountMatches = [
                SELECT Id, Name, FirstName, LastName, PersonEmail, Description 
                FROM Account 
                WHERE IsPersonAccount = TRUE 
                  AND LastName LIKE :lastNamePattern 
                LIMIT 10
            ];

            leadMatches = [
                SELECT Id, Name, FirstName, LastName, Email, Description 
                FROM Lead 
                WHERE IsConverted = FALSE 
                  AND LastName LIKE :lastNamePattern 
                LIMIT 10
            ];
        } else {
            // Fallback: Only First Name or Single Term extracted
            accountMatches = [
                SELECT Id, Name, FirstName, LastName, PersonEmail, Description 
                FROM Account 
                WHERE IsPersonAccount = TRUE 
                  AND (FirstName LIKE :firstNamePattern OR LastName LIKE :firstNamePattern) 
                LIMIT 10
            ];

            leadMatches = [
                SELECT Id, Name, FirstName, LastName, Email, Description 
                FROM Lead 
                WHERE IsConverted = FALSE 
                  AND (FirstName LIKE :firstNamePattern OR LastName LIKE :firstNamePattern) 
                LIMIT 10
            ];
        }

        List<AccountMatchWrapper> results = new List<AccountMatchWrapper>();
        for (Account acc : accountMatches) {
            results.add(new AccountMatchWrapper(acc));
        }
        for (Lead leadRec : leadMatches) {
            results.add(new AccountMatchWrapper(leadRec));
        }

        if (!accountMatches.isEmpty()) {
            applyActiveMatterMatches(results, accountMatches, eventOwnerId);
        }

        return sortTopMatchesFirst(results);
    }

    /**
     * Attaches every Active Matter (AcctSeed__Project__c) belonging to each Person Account match,
     * so the reviewer can see all open matters regardless of who is assigned. A match is flagged as
     * a "Top Match Candidate" only when the Event Owner holds one of the team-assignment roles
     * (Attorney One, Attorney Two, Paralegal, CSS, Coach, CES, Originator) on at least one of them.
     */
    private static void applyActiveMatterMatches(List<AccountMatchWrapper> results, List<Account> accountMatches, Id eventOwnerId) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accountMatches) {
            accountIds.add(acc.Id);
        }

        List<AcctSeed__Project__c> activeMatters = [
            SELECT Id, Name, AcctSeed__Account__c,
                   Billing_Attorney_LU__c, Attorney_Two__c, Paralegal_LU__c,
                   CSS__c, Coach_LU__c, CES__c, Originator_LU__c
            FROM AcctSeed__Project__c
            WHERE AcctSeed__Account__c IN :accountIds
              AND AcctSeed__Status__c = 'Active'
        ];

        if (activeMatters.isEmpty()) {
            return;
        }

        Map<Id, List<MatterMatchWrapper>> matterMatchesByAccountId = new Map<Id, List<MatterMatchWrapper>>();
        for (AcctSeed__Project__c matter : activeMatters) {
            String role = eventOwnerId != null ? getMatchingRole(matter, eventOwnerId) : null;
            if (!matterMatchesByAccountId.containsKey(matter.AcctSeed__Account__c)) {
                matterMatchesByAccountId.put(matter.AcctSeed__Account__c, new List<MatterMatchWrapper>());
            }
            matterMatchesByAccountId.get(matter.AcctSeed__Account__c).add(new MatterMatchWrapper(matter, role));
        }

        for (AccountMatchWrapper wrapper : results) {
            if (wrapper.recordType == 'PersonAccount' && matterMatchesByAccountId.containsKey(wrapper.id)) {
                List<MatterMatchWrapper> matterMatches = matterMatchesByAccountId.get(wrapper.id);
                wrapper.activeMatterMatches = matterMatches;
                wrapper.isTopMatchCandidate = hasMatchingRole(matterMatches);
            }
        }
    }

    // True when at least one of the Account's Active Matters has the Event Owner in a team-assignment role.
    private static Boolean hasMatchingRole(List<MatterMatchWrapper> matterMatches) {
        for (MatterMatchWrapper matterMatch : matterMatches) {
            if (String.isNotBlank(matterMatch.role)) {
                return true;
            }
        }
        return false;
    }

    // Determines which team-assignment role (if any) the Event Owner holds on the given Matter.
    private static String getMatchingRole(AcctSeed__Project__c matter, Id eventOwnerId) {
        if (matter.Billing_Attorney_LU__c == eventOwnerId) {
            return 'Attorney One';
        }
        if (matter.Attorney_Two__c == eventOwnerId) {
            return 'Attorney Two';
        }
        if (matter.Paralegal_LU__c == eventOwnerId) {
            return 'Paralegal';
        }
        if (matter.CSS__c == eventOwnerId) {
            return 'CSS';
        }
        if (matter.Coach_LU__c == eventOwnerId) {
            return 'Coach';
        }
        if (matter.CES__c == eventOwnerId) {
            return 'CES';
        }
        if (matter.Originator_LU__c == eventOwnerId) {
            return 'Originator';
        }
        return null;
    }

    // Moves Top Match Candidates to the front of the list while preserving relative order otherwise.
    private static List<AccountMatchWrapper> sortTopMatchesFirst(List<AccountMatchWrapper> results) {
        List<AccountMatchWrapper> topMatches = new List<AccountMatchWrapper>();
        List<AccountMatchWrapper> otherMatches = new List<AccountMatchWrapper>();
        for (AccountMatchWrapper wrapper : results) {
            if (wrapper.isTopMatchCandidate) {
                topMatches.add(wrapper);
            } else {
                otherMatches.add(wrapper);
            }
        }
        topMatches.addAll(otherMatches);
        return topMatches;
    }

    /**
     * Executes the Prompt Template "Extract_Name_From_Subject" via ConnectApi
     */
    public static PromptResponseWrapper getNameUsingAgentforce(String subjectLine) {
        if (String.isBlank(subjectLine)) {
            return null;
        }
        System.debug('Calling Prompt Template with subject line: ' + subjectLine);

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.isPreview = false;

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue subjectValue = new ConnectApi.WrappedValue();
            subjectValue.value = subjectLine;

            inputParams.put('Input:SubjectLine', subjectValue);
            promptInput.inputParams = inputParams;

            // Execute the Prompt Template
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Extract_Name_From_Subject', promptInput);

            List<ConnectApi.EinsteinLLMGenerationItemOutput> generations = response.generations;
            if (generations != null && !generations.isEmpty() && String.isNotBlank(generations[0].text)) {
                return parsePromptResponseText(generations[0].text);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error calling Prompt Template: ' + ex.getMessage());
        }

        return null;
    }

    /**
     * Parses the raw text generated by the Prompt Template into a PromptResponseWrapper,
     * stripping Markdown code block markers if present. Split out from getNameUsingAgentforce
     * so the parsing logic can be unit tested without depending on a live callout.
     */
    @TestVisible
    private static PromptResponseWrapper parsePromptResponseText(String generationText) {
        String rawResponseText = generationText.trim();

        // Strip Markdown code block markers if returned
        if (rawResponseText.startsWith('```')) {
            rawResponseText = rawResponseText.substringBetween('```json', '```');
            if (rawResponseText == null) {
                rawResponseText = generationText.substringBetween('```', '```');
            }
            rawResponseText = rawResponseText != null ? rawResponseText.trim() : generationText.trim();
        }

        return (PromptResponseWrapper) JSON.deserialize(
            rawResponseText,
            PromptResponseWrapper.class
        );
    }
}