/*** 
    @DESC        : controller class to fetch flat fee billings to display on Portal
    @AUTHOR      : Bhupesh Jindal (bhupesh@ayodia.com)
    @AUDITED BY  :
    @REVISION(S) :
***/
public without sharing class AyPortalBillingController {
    //method to fetch billing and populate wrapper
    @AuraEnabled
    public static AyPortalBillingDetailWrapper fetchBills(){
        //variable declaration
        string contactId;
        string accountId;
        

        //initialize wrapper
        AyPortalBillingDetailWrapper dataWrapper = new AyPortalBillingDetailWrapper();
        dataWrapper.pastBillings = new list<AyPortalBillingDetailWrapper.BillingDetail>();
        dataWrapper.futureBillings = new list<AyPortalBillingDetailWrapper.BillingDetail>();
        dataWrapper.pastTotalBalance = 0;
        dataWrapper.upcomingTotalBalance = 0;
        dataWrapper.totalPastDue = 0;
        dataWrapper.dueWithin15Days = 0;
            
        try{
            //get logged in user's contactId
            contactId = [Select Id, ContactId from User where Id =: userinfo.getuserId() Limit 1].ContactId;
            
            //get account id
            if(contactId != null){
                accountId = [Select Id, AccountId From Contact Where Id =: contactId].AccountId;
            }

            //fetch past flat fee billings related to the logged in user
            for(AcctSeed__Billing__c bill : [Select Id, Name, Matter__r.Name, AcctSeed__Due_Date2__c, AcctSeed__Total__c, AcctSeed__Balance__c, Billing_Status__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__r.Rate_Type__c = 'Flat Fee' AND AcctSeed__Customer__c =: accountId Order By AcctSeed__Due_Date2__c DESC]){
                //populate wrapper for all billings
                AyPortalBillingDetailWrapper.BillingDetail billWrap = new AyPortalBillingDetailWrapper.BillingDetail();
                billWrap.billingNumber = bill.Name;
                billWrap.billingId = bill.Id;
                billWrap.matterName = bill.Matter__r.Name;
                billWrap.dueDate = bill.AcctSeed__Due_Date2__c;
                billWrap.amount = bill.AcctSeed__Total__c;
                billWrap.balance = bill.AcctSeed__Balance__c;
                billWrap.status = bill.Billing_Status__c;
                
                /*if(bill.AcctSeed__Due_Date2__c <= Date.today()){
                    dataWrapper.pastBillings.add(billWrap);
                    dataWrapper.pastTotalBalance = dataWrapper.pastTotalBalance + bill.AcctSeed__Balance__c;
                }else{
                    dataWrapper.futureBillings.add(billWrap);
                    dataWrapper.upcomingTotalBalance = dataWrapper.upcomingTotalBalance + bill.AcctSeed__Balance__c;
                }*/
                if(bill.Billing_Status__c == 'Paid'){
                    dataWrapper.pastBillings.add(billWrap);
                    dataWrapper.pastTotalBalance = dataWrapper.pastTotalBalance + bill.AcctSeed__Balance__c;
                }else{
                    dataWrapper.futureBillings.add(billWrap);
                    dataWrapper.upcomingTotalBalance = dataWrapper.upcomingTotalBalance + bill.AcctSeed__Balance__c;
                    if(bill.AcctSeed__Due_Date2__c <= Date.today()){
                        dataWrapper.totalPastDue = dataWrapper.totalPastDue + bill.AcctSeed__Balance__c;
                    }else if(bill.AcctSeed__Due_Date2__c >= Date.today() && bill.AcctSeed__Due_Date2__c <= Date.today().addDays(15) ){
                        dataWrapper.dueWithin15Days = dataWrapper.dueWithin15Days + bill.AcctSeed__Balance__c;
                    }
                }
            }            
        }catch(Exception e){
            dataWrapper.errorMessage = e.getMessage();
        }
        return dataWrapper;
    }
}