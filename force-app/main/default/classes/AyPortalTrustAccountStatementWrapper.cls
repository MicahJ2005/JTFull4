/*** 
    @DESC        : wrapper class to show trust account statement and statement activities on Portal
    @AUTHOR      : Bhupesh Jindal (bhupesh@ayodia.com)
    @AUDITED BY  :
    @REVISION(S) :
***/
public class AyPortalTrustAccountStatementWrapper {
    @AuraEnabled public list<TrustBalanceDetail> trustBalance {get;set;}
    @AuraEnabled public list<TrustStatememtActivities> trustActivities {get;set;}
    @AuraEnabled public list<Matter> matterList {get;set;}
    @AuraEnabled public String errorMessage {get;set;}

    public class TrustBalanceDetail{
        @AuraEnabled public String statementNum {get;set;}
        @AuraEnabled public String statementId {get;set;}
        @AuraEnabled public String matterName {get;set;}
        @AuraEnabled public String month {get;set;}
        @AuraEnabled public Decimal total {get;set;}
        @AuraEnabled public Decimal dueAmount {get;set;}
        @AuraEnabled public Decimal balance {get;set;}

    }
    public class TrustStatememtActivities{
        @AuraEnabled public String activityNum {get;set;}
        @AuraEnabled public Date transactionDate {get;set;}
        @AuraEnabled public String description {get;set;}
        @AuraEnabled public Decimal amount {get;set;}
        @AuraEnabled public String matterName {get;set;}
    }
    public class Matter{
        @AuraEnabled public Decimal amount {get;set;}
        @AuraEnabled public String matterName {get;set;}

    }
}