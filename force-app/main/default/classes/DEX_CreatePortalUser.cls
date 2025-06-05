/**
 * @description       : Used by "Matter: Create Portal User" Flow to create new portal users, based on Matter's Account.
 * @author            : Dextara (Albert Liu)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   10/31/2023   Dextara (Albert Liu)			   Initial Version
**/
public class DEX_CreatePortalUser {
    @InvocableMethod(label='Create Portal User')
    public static List<String> createUsers(List<Id> accIds) {
        List<String> result = new List<String>();
        List<User> usersToCreate = new List<User>();
        List<Account> accounts = [SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, IsPersonAccount
                                  FROM Account WHERE Id IN :accIds];
        Profile pf = [SELECT Id, Name FROM Profile WHERE Name = 'Kapsten Customer Community Login User' LIMIT 1];
        // Loop through Accounts and create users to insert
        for(Account acc : accounts) {
            if(acc.IsPersonAccount) {
                User newUser = new User(ContactId=acc.PersonContactId, FirstName=acc.FirstName,
                                        LastName=acc.LastName, Email=acc.PersonEmail,
                                        Alias = String.valueOf(acc.FirstName.substring(0,1) + acc.LastName.substring(0,1)), ProfileId = pf.Id, EmailEncodingKey='UTF-8',
                                        LanguageLocaleKey='en_US', LocalesIdKey='en_US', TimezonesIdKey='America/Chicago');
                Double ran = Math.random();
                String uniqueId = ran.toString();
                newUser.communityNickname = acc.FirstName + ' ' + uniqueId.right(5);
                newUser.Username=acc.PersonEmail + '.kapsten';
                usersToCreate.add(newUser);
            }
            result.add(acc.Id);
        }
        
        // Create Users
        if(usersToCreate.size() > 0) {
            Database.DMLOptions dlo = new Database.DMLOptions();
            dlo.EmailHeader.triggerUserEmail= true;
            System.debug('usersToCreate: ' + usersToCreate);
            List<Database.SaveResult> sr = Database.insert(usersToCreate,dlo);
            for(Database.SaveResult s : sr) {
                if(!s.isSuccess()) {
                    System.debug(s.getErrors());
                    throw new CreatePortalUserException('Error: The username already exists in this or another Salesforce organization. Usernames must be unique across all Salesforce organizations. To resolve, use a different username (it doesn\'t need to match the user\'s email address).');
                }
            }
            System.debug('sr: ' + sr);
        }
        return result;
    }
}