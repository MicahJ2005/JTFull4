/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 11-24-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-24-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class ContentDocumentLinkTriggerHandlerTest {

    @IsTest
    private static void testDocumentLink() {
		Content_DL_Trigger__c cdlt = new Content_DL_Trigger__c();
        cdlt.Is_Enabled__c = true;
        insert cdlt;
        
        TaskTrackerTestDataFactory.createAllTestData();
        
        Opportunity opp =
            [
                SELECT Id
                FROM Opportunity
                LIMIT 1
            ];

        opp.StageName = 'Closed Won';
        update opp;
        
        /*AcctSeed__Project__c matter =
            [
                SELECT Id
                FROM AcctSeed__Project__c
                LIMIT 1
            ];*/

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Penguins',
            PathOnClient = 'Penguins.jpg',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion;
        List<ContentDocument> documents =
            [
                SELECT Id, Title, LatestPublishedVersionId
                FROM ContentDocument
            ];

        //create ContentDocumentLink  record
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = opp.id;
        cdl.ContentDocumentId = documents[0].Id;
        insert cdl;


        /*ContentDocumentLink afterLink =
            [
                SELECT Id, Visibility, ShareType
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :documents[0].Id
                    AND LinkedEntityId = :opp.Id
                    AND Visibility = 'AllUsers'
                LIMIT 1
            ];*/

        //System.assertEquals('AllUsers', afterLink.Visibility);
        //System.assertEquals('I', afterLink.ShareType);
    }

}


/*
Account acct = new Account(Name='TEST_ACCT');
insert acct;

ContentVersion contentVersion = new ContentVersion(
  Title = 'Penguins',
  PathOnClient = 'Penguins.jpg',
  VersionData = Blob.valueOf('Test Content'),
  IsMajorVersion = true
);
insert contentVersion;
List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];

//create ContentDocumentLink  record
ContentDocumentLink cdl = New ContentDocumentLink();
cdl.LinkedEntityId = acct.id;
cdl.ContentDocumentId = documents[0].Id;
cdl.shareType = 'V';
insert cdl;

*/