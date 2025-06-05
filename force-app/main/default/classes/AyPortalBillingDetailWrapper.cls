/*** 
    @DESC        : wrapper class to show billing on Portal
    @AUTHOR      : Bhupesh Jindal (bhupesh@ayodia.com)
    @AUDITED BY  :
    @REVISION(S) :
***/
public class AyPortalBillingDetailWrapper {
    @AuraEnabled public list<BillingDetail> pastBillings {get;set;}
    @AuraEnabled public list<BillingDetail> futureBillings {get;set;}
    @AuraEnabled public string errorMessage {get;set;}
    @AuraEnabled public Decimal pastTotalBalance {get;set;}
    @AuraEnabled public Decimal upcomingTotalBalance {get;set;}
    @AuraEnabled public Decimal totalPastDue {get;set;}
    @AuraEnabled public Decimal dueWithin15Days {get;set;}

    public class BillingDetail{
        @AuraEnabled public String billingNumber {get;set;}
        @AuraEnabled public String billingId {get;set;}
        @AuraEnabled public String matterName {get;set;}
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public Date dueDate {get;set;}
        @AuraEnabled public Decimal amount {get;set;}
        @AuraEnabled public Decimal balance {get;set;}

    }
}