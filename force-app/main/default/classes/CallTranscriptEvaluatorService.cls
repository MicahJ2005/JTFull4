public with sharing class CallTranscriptEvaluatorService {

    /**
     * Evaluates a Call_Transcript__c record using the "Call_Transcript_Evaluator" Prompt Template,
     * parses the JSON response, and updates the related Call_Transcript__c fields.
     *
     * @param transcriptId The Id of the Call_Transcript__c record to evaluate.
     * @return The raw AI-generated response text.
     */
    public static String evaluateTranscript(String transcriptId) {
        if (String.isBlank(transcriptId)) {
            throw new IllegalArgumentException('Transcript record Id cannot be null or blank.');
        }

        // Prepare Prompt Template input
        Map<String, String> experienceSession = new Map<String, String>{ 'id' => transcriptId };
        ConnectApi.WrappedValue experienceSessionValue = new ConnectApi.WrappedValue();
        experienceSessionValue.value = experienceSession;

        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
            'Input:Call_Transcript' => experienceSessionValue
        };

        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
                // Check if the "Call_Transcript_Evaluator" Prompt Template exists)
            // Call the Prompt Template
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Call_Transcript_Evaluator',
                    executeTemplateInput
                );

            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            String responseText = response.text;

            // --- Parse JSON and update record ---
            if (!String.isBlank(responseText)) {
                updateTranscriptFields(transcriptId, responseText);
            }

            return responseText;
            

        } catch (Exception e) {
            System.debug('Error during transcript evaluation: ' + e.getMessage());
            throw e;
        }
    }

    /**
     * Parses the JSON response and updates the corresponding Call_Transcript__c fields.
     */
    @TestVisible
    private static void updateTranscriptFields(String transcriptId, String jsonResponse) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

           Call_Transcript__c ct = new Call_Transcript__c(
                Id = transcriptId,
                Service__c = (String) parsed.get('service'),
                Family_Law_Case_Stage__c = (String) parsed.get('family_law_case_stage_of_case'),
                Speaker_Count__c = (parsed.containsKey('speaker_count') ? (Integer) parsed.get('speaker_count') : null),
                Communication_Type__c = (String) parsed.get('communication_type'),
                Intent_Reason_for_Contact__c = (String) parsed.get('intent_reason_for_contact'),
                // Topic__c = (String) parsed.get('topic'),
                Topic__c = convertToMultiSelectValue(parsed.get('topic')),
                Overall_Sentiment_Score__c = (parsed.containsKey('overall_sentiment_score') ? (Decimal) parsed.get('overall_sentiment_score') : null),
                Min_Segment_Sentiment__c = (parsed.containsKey('min_segment_sentiment') ? (Decimal) parsed.get('min_segment_sentiment') : null),
                Client_Sentiment_Score__c = (parsed.containsKey('client_sentiment_score') ? (Decimal) parsed.get('client_sentiment_score') : null),
                Client_Dominant_Emotion__c = (String) parsed.get('client_dominant_emotion'),
                Client_Demeanor__c = (String) parsed.get('client_demeanor'),
                Employee_Tone__c = (String) parsed.get('employee_tone'),
                Employee_Empathy__c = (String) parsed.get('employee_empathy'),
                Employee_Rapport__c = (String) parsed.get('employee_rapport'),
                Employee_Clarity__c = (String) parsed.get('employee_clarity'),
                // UCAs_Discussed__c = (String) parsed.get('ucas_discussed')
                UCAs_Discussed__c = convertToMultiSelectValue(parsed.get('ucas_discussed'))
            );
            system.debug('ct = ' + ct);
            update ct;
        } catch (Exception e) {
            System.debug('Error parsing JSON or updating Call_Transcript__c: ' + e.getMessage());
            throw e;
        }
    }

    private static String convertToMultiSelectValue(Object val) {
        if (val == null) return null;

        if (val instanceof List<Object>) {
            // JSON array → semicolon string
            List<String> items = new List<String>();
            for (Object o : (List<Object>) val) {
                if (o != null) items.add(String.valueOf(o).trim());
            }
            return items.isEmpty() ? null : String.join(items, ';');
        }

        // comma-separated or single string → normalize to semicolons
        String s = String.valueOf(val).trim();
        if (s == '') return null;
        s = s.replaceAll('\\s*,\\s*', ';'); // commas to semicolons
        s = s.replaceAll('\\s*;\\s*', ';'); // normalize spaces
        return s;
    }
}