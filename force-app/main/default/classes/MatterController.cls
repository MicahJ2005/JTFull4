public with sharing class MatterController {
    
    @AuraEnabled(cacheable=true)
    public static List<AcctSeed__Project__c> getMyMatters() {
        Id userId = UserInfo.getUserId();

        return [
            SELECT Id, Name, CreatedDate, AcctSeed__Status__c
            FROM AcctSeed__Project__c 
            WHERE OwnerId = :userId
            ORDER BY CreatedDate DESC 
            LIMIT 3
        ];


    }
}