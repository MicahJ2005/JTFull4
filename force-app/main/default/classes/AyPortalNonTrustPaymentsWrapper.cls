/*** 
    @DESC        : wrapper class to show payments on Portal
    @AUTHOR      : Bhupesh Jindal (bhupesh@ayodia.com)
    @AUDITED BY  :
    @REVISION(S) :
***/
public class AyPortalNonTrustPaymentsWrapper {
    @AuraEnabled public list<PaymentDetail> paymentsList {get;set;}
    @AuraEnabled public string errorMessage {get;set;}
    @AuraEnabled public Decimal totalAmount {get;set;}

    public class PaymentDetail{
        @AuraEnabled public String matterName {get;set;}
        @AuraEnabled public Date receivedDate {get;set;}
        @AuraEnabled public Decimal amount {get;set;}
        @AuraEnabled public String isTrustDeposit {get;set;}
    }
}