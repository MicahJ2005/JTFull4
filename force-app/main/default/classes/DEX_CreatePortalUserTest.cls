@isTest
public class DEX_CreatePortalUserTest {
    @testSetup
    public static void setup() {
        String personId = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        System.debug('personId: ' + personId);
        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'LastName';
        acc.PersonEmail = 'test@dextara.com';
        acc.RecordTypeId = personId;
        insert acc;
    }
    
    @isTest
    public static void testCreateUser() {
        List<Account> testAcc = [SELECT Id, IsPersonAccount FROM Account];
        List<Id> accIds = new List<Id>();
        
        for(Account acc : testAcc) {
            accIds.add(acc.Id);
        }
        
        List<String> res = DEX_CreatePortalUser.createUsers(accIds);
        System.Assert(res.size() == testAcc.size());
        List<String> resError = new List<String>();
        try {
            resError = DEX_CreatePortalUser.createUsers(accIds);
        } catch(CreatePortalUserException e) {
            System.Assert(resError.size() == 0);
        }
    }
}