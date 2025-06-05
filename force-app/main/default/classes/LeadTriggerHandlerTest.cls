@isTest
public class LeadTriggerHandlerTest {

    @isTest
    static void testHandleAfterUpdate_withConvertedLead() {
        // Step 1: Create supporting data
        Account acct = new Account(Name = 'Test Converted Account');
        insert acct;

        Opportunity opp = new Opportunity(
            Name = 'Converted Opportunity',
            AccountId = acct.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Area_Of_Law__c = 'Business Services'
        );
        insert opp;

        // Step 2: Create the lead
        Lead lead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Co',
            Email = 'test@example.com',
            Status = 'Open - Not Contacted',
            Area_Of_Law__c = 'Business Services'
        );
        insert lead;

        // Step 3: Create related child records pointing to the Lead
        Related_Call_Transcript__c callTranscript = new Related_Call_Transcript__c(
            // Name = 'Call',
            Lead__c = lead.Id
        );

        SMS_Session__c smsSession = new SMS_Session__c(SMS_Session_Text__c = 'Session');
        insert smsSession;

        SMS_Session_Individual__c smsIndividual = new SMS_Session_Individual__c(
            // Name = 'SMS',
            Lead__c = lead.Id,
            SMS_Session__c = smsSession.Id
        );

        Related_Meeting_Transcript__c meeting = new Related_Meeting_Transcript__c(
            // Name = 'Meeting',
            Lead__c = lead.Id
        );

        insert new List<SObject> { callTranscript, smsIndividual, meeting };

        // Create a Campaign
        Campaign camp = new Campaign(
            Name = 'Test Campaign',
            IsActive = true
        );
        insert camp;

        // Add Lead to Campaign as CampaignMember
        CampaignMember cm = new CampaignMember(
            LeadId = lead.Id,
            CampaignId = camp.Id,
            Status = 'Sent' // make sure this status exists in your org
        );
        insert cm;

        // Step 4: Convert the lead
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(lead.Id);
        lc.setAccountId(acct.Id);
        lc.setDoNotCreateOpportunity(true); // we'll link manually later
        lc.setConvertedStatus('Appointment Set/Converted'); // Make sure this status exists in your org

        Database.LeadConvertResult result = Database.convertLead(lc);
        System.assert(result.isSuccess());

        // Step 5: Create the Opportunity manually linked to the converted Account
        Opportunity newOpp = new Opportunity(
            Name = 'Linked Opportunity',
            AccountId = acct.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Area_Of_Law__c = 'Business Services'
        );
        insert newOpp;

        // Step 6: Verify updates were applied by the trigger
        List<Related_Call_Transcript__c> updatedCalls = [
            SELECT Id, Lead__c, Account__c, Opportunity__c
            FROM Related_Call_Transcript__c
            WHERE Id = :callTranscript.Id
        ];

        List<SMS_Session_Individual__c> updatedSMS = [
            SELECT Id, Lead__c, Account__c
            FROM SMS_Session_Individual__c
            WHERE Id = :smsIndividual.Id
        ];

        List<Related_Text_Message__c> insertedTexts = [
            SELECT Id, Opportunity__c, Text_Message_Session__c
            FROM Related_Text_Message__c
            WHERE Text_Message_Session__c = :smsSession.Id
        ];

        List<Related_Meeting_Transcript__c> updatedMeetings = [
            SELECT Id, Lead__c, Account__c, Opportunity__c
            FROM Related_Meeting_Transcript__c
            WHERE Id = :meeting.Id
        ];

        // Step 7: Assertions
        System.assertEquals(null, updatedCalls[0].Lead__c);
        System.assertEquals(acct.Id, updatedCalls[0].Account__c);
        System.assertNotEquals(null, updatedCalls[0].Opportunity__c);

        System.assertEquals(null, updatedSMS[0].Lead__c);
        System.assertEquals(acct.Id, updatedSMS[0].Account__c);

        System.assertEquals(1, insertedTexts.size());
        System.assertEquals(smsSession.Id, insertedTexts[0].Text_Message_Session__c);

        System.assertEquals(null, updatedMeetings[0].Lead__c);
        System.assertEquals(acct.Id, updatedMeetings[0].Account__c);
        System.assertNotEquals(null, updatedMeetings[0].Opportunity__c);
    }
}
