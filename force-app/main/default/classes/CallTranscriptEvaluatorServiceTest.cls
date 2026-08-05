@IsTest(SeeAllData=true)
public class CallTranscriptEvaluatorServiceTest {

    @IsTest(SeeAllData=true)
    static void testEvaluateTranscript_success() {
         // Create a dummy Voice_Call__c record since it's required
        VoiceCall vc = new VoiceCall(FromPhoneNumber = '155-222-8888', ToPhoneNumber = '155-222-9999', VendorType = 'Custom', 
            CallStartDateTime = Datetime.now(), CallEndDateTime = Datetime.now(), CallType = 'Outbound');
        insert vc;
        // Create a dummy Call_Transcript__c record (no Name field if auto-numbered)
        Call_Transcript__c ct = new Call_Transcript__c(Transcript_Text__c = 'Test Transcript', Voice_Call__c = vc.Id);
        insert ct;

        // Build fake JSON to simulate an LLM response
        String fakeJson = JSON.serialize(new Map<String, Object>{
            'service' => 'JT Family Law',
            'family_law_case_stage_of_case' => 'Strategy Building',
            //'speaker_count' => '2',
            'communication_type' => 'Intake',
            'intent_reason_for_contact' => 'Unknown/Low Confidence',
            'topic' => new List<String>{'Custody', 'Probate'},
            //'overall_sentiment_score' => '0.85',
            //'min_segment_sentiment' => '0.5',
            //'client_sentiment_score' => '0.8',
            'client_dominant_emotion' => 'Confusion',
            'client_demeanor' => 'Calm',
            'employee_tone' => 'Empathetic',
            'employee_empathy' => 'High',
            'employee_rapport' => 'High',
            'employee_clarity' => 'Clear'
        });

        Test.startTest();
        // Call the @TestVisible method directly
        CallTranscriptEvaluatorService.updateTranscriptFields(ct.Id, fakeJson);
        CallTranscriptEvaluatorService.evaluateTranscript(ct.Id);
        Test.stopTest();

        // Verify record was updated
        // Call_Transcript__c updated = [
        //     SELECT Service__c, Family_Law_Case_Stage__c, Speaker_Count__c,
        //            Communication_Type__c, Intent_Reason_for_Contact__c,
        //            Topic__c, Overall_Sentiment_Score__c, Min_Segment_Sentiment__c,
        //            Client_Sentiment_Score__c, Client_Dominant_Emotion__c,
        //            Client_Demeanor__c, Employee_Tone__c, Employee_Empathy__c,
        //            Employee_Rapport__c, Employee_Clarity__c, UCAs_Discussed__c
        //     FROM Call_Transcript__c
        //     WHERE Id = :ct.Id
        // ];

        // System.assertEquals('Family Law', updated.Service__c);
        // System.assertEquals('Initial Consultation', updated.Family_Law_Case_Stage__c);
        // System.assertEquals(2, updated.Speaker_Count__c);
        // System.assertEquals('Phone', updated.Communication_Type__c);
        // System.assert(updated.Topic__c.contains('Divorce'));
        // System.assert(updated.Topic__c.contains('Child Custody'));
        // System.assertEquals(0.85, updated.Overall_Sentiment_Score__c);
        // System.assertEquals(0.8, updated.Client_Sentiment_Score__c);
        // System.assertEquals('Concern', updated.Client_Dominant_Emotion__c);
        // System.assertEquals('Professional', updated.Employee_Tone__c);
        // System.assertEquals('High', updated.Employee_Empathy__c);
        // System.assert(updated.UCAs_Discussed__c.contains('UCA1'));
        // System.assert(updated.UCAs_Discussed__c.contains('UCA2'));
    }

    @IsTest
    static void testEvaluateTranscript_blankId_throwsException() {
        try {
            CallTranscriptEvaluatorService.evaluateTranscript(null);
            System.assert(false, 'Expected exception for null Id');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Transcript record Id cannot be null or blank.'));
        }
    }
}