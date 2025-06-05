/*** 
    @DESC        : wrapper class to make payment from portal
    @AUTHOR      : Prateek@ayodia
    @AUDITED BY  :
    @REVISION(S) :
***/
public class AyAffiniPayTransactionCardWrapper {
    @AuraEnabled public String publicKey {get;set;}
    @AuraEnabled public String jsonStr{get;set;}
    @AuraEnabled public String depositAccountId {get;set;}
    @AuraEnabled public map<String, String> matters {get;set;}
    @AuraEnabled public map<String, String> transactionType {get;set;}   
    @AuraEnabled public String accountId {get;set;}
    @AuraEnabled public String contactId {get;set;}
    @AuraEnabled public String contactEmail{get;set;}
}