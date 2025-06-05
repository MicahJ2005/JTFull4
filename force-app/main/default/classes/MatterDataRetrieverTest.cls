@isTest
private class MatterDataRetrieverTest {
    
    // Helper: Return the RecordType ID for "Fixed Fee" on acctseed__Project__c
    private static Id getFixedFeeRecordTypeId() {
        RecordType rt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'acctseed__Project__c'
              AND Name = 'Fixed Fee'
            LIMIT 1
        ];
        return rt.Id;
    }

    @isTest
    static void testSingleMatterWithUpcomingTaskEvent() {
            // Create an Account
            Account acct = new Account(Name = 'Single Test Account');
            insert acct;

            // RecordType ID for "Fixed Fee"
            Id fixedFeeRTId = getFixedFeeRecordTypeId();

            // Create ONE Matter with upcoming tasks & events
            acctseed__Project__c matter = new acctseed__Project__c(
                Name = 'Single Matter with Upcoming',
                AcctSeed__Account__c = acct.Id,
                AcctSeed__Status__c = 'Active',
                RecordTypeId = fixedFeeRTId,
                Billing_Attorney_LU__c = UserInfo.getUserId()
            );
            insert matter;

            // Create an upcoming Task in next 2 weeks
            Task upcomingTask = new Task(
                Subject = 'Upcoming Task',
                WhatId = matter.Id,
                ActivityDate = Date.today().addDays(5)  // 5 days from now
            );
            insert upcomingTask;

            // Create an upcoming Event in next 2 weeks
            Event upcomingEvent = new Event(
                Subject = 'Upcoming Event',
                WhatId = matter.Id,
                StartDateTime = Datetime.now().addDays(10),
                EndDateTime   = Datetime.now().addDays(10).addHours(1)
            );
            insert upcomingEvent;

            // Create a FeedItem (Chatter post)
            FeedItem feed = new FeedItem(
                ParentId = matter.Id,
                Body = 'Chatter post for Single Matter'
            );
            insert feed;

            // Create an EmailMessage
            EmailMessage email = new EmailMessage(
                RelatedToId = matter.Id,
                Subject = 'Single Matter Email',
                FromName = 'tester@example.com',
                MessageDate = DateTime.now()
            );
            insert email;

            // Invoke the method
            Test.startTest();
            List<MatterDataRetriever.Response> responseList = MatterDataRetriever.getMatterData();
            Test.stopTest();

            // We expect exactly one Response
            System.assertEquals(1, responseList.size(), 'Should return exactly one Response');

            // The JSON string in that single Response
            String jsonOutput = responseList[0].Prompt;
            System.debug('JSON output: ' + jsonOutput);

    }
}