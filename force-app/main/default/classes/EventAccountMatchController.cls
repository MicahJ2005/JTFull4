public without sharing class EventAccountMatchController {

    public class AccountMatchWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String richTextNotes { get; set; }
        @AuraEnabled public String recordType { get; set; }

        public AccountMatchWrapper(Account acc) {
            this.id = acc.Id;
            this.name = acc.Name;
            this.email = acc.PersonEmail;
            this.richTextNotes = acc.Description;
            this.recordType = 'PersonAccount';
        }

        public AccountMatchWrapper(Lead leadRec) {
            this.id = leadRec.Id;
            this.name = leadRec.Name;
            this.email = leadRec.Email;
            this.richTextNotes = leadRec.Description;
            this.recordType = 'Lead';
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
        
        Event evt = [
            SELECT Id, Subject, Description, WhatId 
            FROM Event 
            WHERE Id = :eventId 
            LIMIT 1
        ];

        if (evt.WhatId != null) {
            return new List<AccountMatchWrapper>();
        }

        // Call the Prompt Template using Agentforce / Einstein LLM API
        PromptResponseWrapper nameDetails = getNameUsingAgentforce(evt.Subject);
        if (nameDetails == null || (String.isBlank(nameDetails.firstName) && String.isBlank(nameDetails.lastName))) {
            return new List<AccountMatchWrapper>();
        }

        return findPotentialMatches(nameDetails);
    }

    /**
     * Queries Accounts and Leads for potential matches given extracted name details.
     * Split out from getPotentialMatches so the matching logic can be unit tested
     * without depending on a live Agentforce/Einstein LLM callout.
     */
    @TestVisible
    private static List<AccountMatchWrapper> findPotentialMatches(PromptResponseWrapper nameDetails) {
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

        return results;
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