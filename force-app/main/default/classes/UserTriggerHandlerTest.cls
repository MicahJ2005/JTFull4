/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 04-24-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-21-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class UserTriggerHandlerTest {

    @IsTest
    private static void testCreateUser() {
        TaskTrackerTestDataFactory.createAllTestData();

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();

        Id personAccountId =
            [
                SELECT Id
                FROM RecordType
                WHERE Name = 'Person Account'
                    AND SObjectType = 'Account'
            ].Id;
        Account act = new Account (
            FirstName = 'Scooby',
            LastName = 'Do',
            PersonEmail = 'SDo@nowhere.com',
            RecordTypeId = personAccountId
        );
        insert act;

        opp.Spouse__c = act.Id;
        opp.StageName = 'Closed Won';
        update opp;

        AcctSeed__Project__c matter = new AcctSeed__Project__c (
            Name = 'Test Matter',
            AcctSeed__Account__c = act.Id,
            AcctSeed__Opportunity__c = Opp.Id,
            AcctSeed__Status__c = 'Active'
        );
        insert matter;

        Profile p =
            [
                SELECT Id
                FROM Profile
                WHERE Name = 'Kapsten Community 2 Profile'
                LIMIT 1
            ];

        Blob b = Crypto.GenerateAESKey(128);
        String h = EncodingUtil.ConvertTohex(b);
        String uid = h.SubString(0,8);
        User u = new User
        (
            Alias = uid,
            Email= act.PersonEmail,
            EmailEncodingKey='UTF-8',
            FirstName = act.FirstName,
            LastName=act.LastName,
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/New_York',
            UserName= 'SDo@nowhere.com'
        );
        insert u;

        Test.stopTest();
    }



}