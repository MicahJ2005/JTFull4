// Demo script to run EmailMessageTriggerHandler via Execute Anonymous
// Usage: sfdx force:apex:execute -f scripts/apex/runEmailMessageHandlerDemo.apex
// Or paste into Developer Console > Debug > Open Execute Anonymous Window

/*
This script:
1) Ensures a Person Account record type exists and that Person Accounts are enabled in your org.
2) Creates a Person Account with a PersonEmail.
3) Creates:
   - One AcctSeed__Project__c linked to that Account
   - One Opportunity linked to that Account
4) Creates an EmailMessage with From/To including the PersonEmail (and optionally sets RelatedToId)
5) Invokes the trigger by inserting the EmailMessage
6) Queries and logs created Related_Email_Message__c records
*/

// --------------------------- CONFIG ---------------------------
String demoEmail = 'mosermaaron@gmail.com';
String emailSubject = 'HERE Test Email for Handler Demo 9999999';
Boolean relateEmailToProject = true; // if true, EmailMessage.RelatedToId will be set to the created Project
// --------------------------- CONFIG ---------------------------

Id paRtId;
for (RecordType rt : [SELECT Id, Name, SObjectType FROM RecordType WHERE SObjectType = 'Account' AND Name LIKE '%Person%']) {
    paRtId = rt.Id;
    break;
}
System.assert(paRtId != null, 'No Person Account Record Type found. Ensure Person Accounts are enabled and a Person-type RecordType exists.');

// Create Person Account (if not already existing with same PersonEmail)
Account pa = [SELECT Id, Name, PersonEmail FROM Account WHERE IsPersonAccount = true AND PersonEmail = :demoEmail LIMIT 1];
if (pa == null) {
    pa = new Account(
        RecordTypeId = paRtId,
        LastName = 'Doe',
        FirstName = 'John',
        PersonEmail = demoEmail
    );
    insert pa;
} else {
    System.debug('Reusing existing Person Account: ' + pa.Id);
}

// Create Contact under the same Account to test Contact.Email resolution too
Contact c = [SELECT Id FROM Contact WHERE AccountId = :pa.Id AND Email = :demoEmail LIMIT 1];
if (c == null) {
    c = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = pa.Id, Email = demoEmail);
    insert c;
} else {
    System.debug('Reusing existing Contact: ' + c.Id);
}

// Create a Project (AcctSeed__Project__c) and Opportunity under this account
AcctSeed__Project__c prj = [SELECT Id FROM AcctSeed__Project__c WHERE AcctSeed__Account__c = :pa.Id LIMIT 1];
if (prj == null) {
    prj = new AcctSeed__Project__c(AcctSeed__Account__c = pa.Id, Name = 'Demo Project for ' + pa.Id);
    insert prj;
} else {
    System.debug('Reusing existing Project: ' + prj.Id);
}

Opportunity opp = [SELECT Id FROM Opportunity WHERE AccountId = :pa.Id LIMIT 1];
if (opp == null) {
    opp = new Opportunity(Name = 'Demo Opp for ' + pa.Id, AccountId = pa.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
    insert opp;
} else {
    System.debug('Reusing existing Opp: ' + opp.Id);
}

// Create the EmailMessage - include the demo email in multiple fields to exercise parsing
EmailMessage em = new EmailMessage();
em.Subject = emailSubject;
em.FromAddress = demoEmail;
em.ToAddress = demoEmail + '; pyro73091@gmail.com';
//em.CcAddress = 'pyro73091@gmail.com';
//em.BccAddress = 'allyblue4.at@gmail.com';

// Optionally relate directly to the created Project (tests existing behavior path)
if (relateEmailToProject) {
    em.RelatedToId = opp.Id;
}
// Required fields for EmailMessage
em.Status = '0'; // New
em.FromName = 'John Doe';
// em.ToName = 'John Doe';
em.Incoming = true;
em.TextBody = 'This is a demo email body.';
insert em;

// Query and output Related_Email_Message__c created by the trigger
List<Related_Email_Message__c> related = [
    SELECT Id, Account__c, Matter__c, Opportunity__c, Email_Message_Id__c, Email_Subject__c, Email_Recipients__c
    FROM Related_Email_Message__c
    WHERE Email_Message_Id__c = :em.Id
    ORDER BY CreatedDate DESC
];

System.debug('Created ' + related.size() + ' Related_Email_Message__c records for EmailMessage ' + em.Id);
for (Related_Email_Message__c r : related) {
    System.debug('Related_Email_Message__c => Id=' + r.Id + 
                 ' Account=' + r.Account__c + 
                 ' Matter(Project)=' + r.Matter__c + 
                 ' Opp=' + r.Opportunity__c + 
                 ' Subject=' + r.Email_Subject__c + 
                 ' Recipients=' + r.Email_Recipients__c);
}