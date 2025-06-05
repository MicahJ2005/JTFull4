/*** 
    @DESC        : controller class to fetch non trust payments to display on Portal
    @AUTHOR      : Bhupesh Jindal (bhupesh@ayodia.com)
    @AUDITED BY  :
    @REVISION(S) :
***/
public without sharing class AyPortalNonTrustPaymentsController {
    //method to fetch billing and populate wrapper
    @AuraEnabled
    public static AyPortalNonTrustPaymentsWrapper fetchPayments(){
        //variable declaration
        string contactId;
        string accountId;
        //initialize wrapper
        AyPortalNonTrustPaymentsWrapper dataWrapper = new AyPortalNonTrustPaymentsWrapper();
        dataWrapper.paymentsList = new List<AyPortalNonTrustPaymentsWrapper.PaymentDetail>();
        dataWrapper.totalAmount = 0;

        try{
            //get logged in user's contactId
            contactId = [Select Id, ContactId from User where Id =: userinfo.getuserId() Limit 1].ContactId;
            
            //get account id
            if(contactId != null){
                accountId = [Select Id, AccountId From Contact Where Id =: contactId].AccountId;
            }

            //fetch non trust payments related to the logged in user
            for(AcctSeed__Cash_Receipt__c cr : [Select Id, AcctSeed__Project__r.Name, AcctSeed__Receipt_Date__c, AcctSeed__Amount__c, Include_in_Trust_Balance__c From AcctSeed__Cash_Receipt__c Where  AcctSeed__Account__c =: accountId AND AcctSeed__Bank_Account__c !=: Label.AyPortal_Trust_Bank_Account  Order By  AcctSeed__Receipt_Date__c DESC]){
                //populate wrapper for all billings
                AyPortalNonTrustPaymentsWrapper.PaymentDetail paymentWrap = new AyPortalNonTrustPaymentsWrapper.PaymentDetail();
                paymentWrap.amount = cr.AcctSeed__Amount__c;
                paymentWrap.matterName = cr.AcctSeed__Project__r.Name;
                paymentWrap.receivedDate = cr.AcctSeed__Receipt_Date__c;
				if(cr.Include_in_Trust_Balance__c){
                    paymentWrap.isTrustDeposit = 'Yes';
                }else{
                    paymentWrap.isTrustDeposit = 'No';
                }
                dataWrapper.paymentsList.add(paymentWrap);
                dataWrapper.totalAmount = dataWrapper.totalAmount + cr.AcctSeed__Amount__c;
            }
        }catch(Exception e){
            dataWrapper.errorMessage = e.getMessage();
        }
        return dataWrapper;
    }
}