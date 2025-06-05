/*** 
    @DESC        : controller class to fetch trust account statement and trust statement activities to display on Portal
    @AUTHOR      : Bhupesh Jindal (bhupesh@ayodia.com)
    @AUDITED BY  :
    @REVISION(S) :
***/
public without sharing class AyPortalTrustAccountStatementController {
    //method to fetch billing and populate wrapper
    @AuraEnabled
    public static AyPortalTrustAccountStatementWrapper fetchTrustBalance(){
        //variable declaration
        string contactId;
        string accountId;
        //initialize wrapper
        AyPortalTrustAccountStatementWrapper dataWrapper = new AyPortalTrustAccountStatementWrapper();
        dataWrapper.trustBalance = new list<AyPortalTrustAccountStatementWrapper.TrustBalanceDetail>();
        dataWrapper.trustActivities = new list<AyPortalTrustAccountStatementWrapper.TrustStatememtActivities>();
        dataWrapper.matterList = new list<AyPortalTrustAccountStatementWrapper.Matter>();
        try{

            //get logged in user's contactId
            contactId = [Select Id, ContactId from User where Id =: userinfo.getuserId() Limit 1].ContactId;
            
            //get account id
            if(contactId != null){
                accountId = [Select Id, AccountId From Contact Where Id =: contactId].AccountId;
            }
            //prior month statement ids
            set<Id> priorMonthStatementIds = new set<Id>();

            //fetch matter details
            for(AcctSeed__Project__c matter: [Select Id, Name, Closing_Balance__c From AcctSeed__Project__c Where AcctSeed__Account__c =: accountId ORDER BY CreatedDate DESC]){
                AyPortalTrustAccountStatementWrapper.Matter matterWrap = new AyPortalTrustAccountStatementWrapper.Matter();
                matterWrap.matterName = matter.Name;
                matterWrap.amount = matter.Closing_Balance__c;
                dataWrapper.matterList.add(matterWrap);
            }

            //fetch current month trust account statemnt & activities related to the logged in user
            for(Trust_Balance__c monthlyStatement : [Select Id, Name, Prior_Month_Trust_Balance__c, Matter__r.Name, Total_Billed__c, Closing_Balance__c, Account_Total_Past_Due_Amount__c, Accounting_Period__r.Name,  (Select Id, Name, Activity_Date__c, Activity_Amount__c, Activity_Description__c, Cash_Receipt__c, Cash_Receipt__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c, Cash_Disbursement__c, Cash_Disbursement__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c, Billing_Cash_Receipt__c, Billing_Cash_Receipt__r.AcctSeed__Cash_Receipt__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c From Trust_Account_Activities__r Where (Activity_Description__c =: 'Withdrawal' OR Activity_Description__c =: 'Deposit') ORDER BY Activity_Date__c DESC) From Trust_Balance__c Where Account__c =: accountId AND Accounting_Period__r.AcctSeed__Start_Date__c <= TODAY AND Accounting_Period__r.AcctSeed__End_Date__c >= TODAY Order By Matter__r.Name]){
                priorMonthStatementIds.add(monthlyStatement.Prior_Month_Trust_Balance__c);
                //populate wrapper 
                AyPortalTrustAccountStatementWrapper.TrustBalanceDetail statementWrap = new AyPortalTrustAccountStatementWrapper.TrustBalanceDetail();
                statementWrap.matterName = monthlyStatement.Matter__r.Name;
                statementWrap.statementNum = monthlyStatement.Name;
                statementWrap.statementId = monthlyStatement.Id;
                statementWrap.month = monthlyStatement.Accounting_Period__r.Name;
                statementWrap.total = monthlyStatement.Total_Billed__c;
                statementWrap.dueAmount = monthlyStatement.Account_Total_Past_Due_Amount__c;
                statementWrap.balance = monthlyStatement.Closing_Balance__c;
                dataWrapper.trustBalance.add(statementWrap);
                for(Trust_Account_Activity__c activity: monthlyStatement.Trust_Account_Activities__r){
                    //check activity validity
                    if(validateActivity(activity)){
                        AyPortalTrustAccountStatementWrapper.TrustStatememtActivities activityWrap = new AyPortalTrustAccountStatementWrapper.TrustStatememtActivities();
                        activityWrap.activityNum = activity.Name;
                        activityWrap.transactionDate = activity.Activity_Date__c;
                        activityWrap.amount = activity.Activity_Amount__c;
                        activityWrap.description = activity.Activity_Description__c;
                        activityWrap.matterName = monthlyStatement.Matter__r.Name;
                        dataWrapper.trustActivities.add(activityWrap);
                    }
                }
            }

            //fetch prior month trust account statemnt & activities related to the logged in user
            for(Trust_Balance__c monthlyStatement : [Select Id, Name, Matter__r.Name, Total_Billed__c, Closing_Balance__c, Account_Total_Past_Due_Amount__c, Accounting_Period__r.Name,  (Select Id, Name, Activity_Date__c, Activity_Amount__c, Activity_Description__c, Cash_Receipt__c, Cash_Receipt__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c, Cash_Disbursement__c, Cash_Disbursement__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c, Billing_Cash_Receipt__c, Billing_Cash_Receipt__r.AcctSeed__Cash_Receipt__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c From Trust_Account_Activities__r Where (Activity_Description__c =: 'Withdrawal' OR Activity_Description__c =: 'Deposit') ORDER BY Activity_Date__c DESC) From Trust_Balance__c Where Id IN: priorMonthStatementIds Order By Matter__r.Name]){
                //populate wrapper 
                AyPortalTrustAccountStatementWrapper.TrustBalanceDetail statementWrap = new AyPortalTrustAccountStatementWrapper.TrustBalanceDetail();
                statementWrap.matterName = monthlyStatement.Matter__r.Name;
                statementWrap.statementNum = monthlyStatement.Name;
                statementWrap.statementId = monthlyStatement.Id;
                statementWrap.month = monthlyStatement.Accounting_Period__r.Name;
                statementWrap.total = monthlyStatement.Total_Billed__c;
                statementWrap.dueAmount = monthlyStatement.Account_Total_Past_Due_Amount__c;
                statementWrap.balance = monthlyStatement.Closing_Balance__c;
                dataWrapper.trustBalance.add(statementWrap);
                for(Trust_Account_Activity__c activity: monthlyStatement.Trust_Account_Activities__r){
                    //check activity validity
                    if(validateActivity(activity)){
                        AyPortalTrustAccountStatementWrapper.TrustStatememtActivities activityWrap = new AyPortalTrustAccountStatementWrapper.TrustStatememtActivities();
                        activityWrap.activityNum = activity.Name;
                        activityWrap.transactionDate = activity.Activity_Date__c;
                        activityWrap.amount = activity.Activity_Amount__c;
                        activityWrap.description = activity.Activity_Description__c;
                        activityWrap.matterName = monthlyStatement.Matter__r.Name;
                        dataWrapper.trustActivities.add(activityWrap);
                    }
                }
            }
        }catch(Exception e){
            dataWrapper.errorMessage = e.getMessage();
        }
        return dataWrapper;
    }
    
    private static boolean validateActivity(Trust_Account_Activity__c activity){
        boolean valid = false;
        //check if activity belongs to a trust account
        if(activity.Cash_Receipt__c != null && activity.Cash_Receipt__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c){
            valid = true;
        }else if(activity.Cash_Disbursement__c != null && activity.Cash_Disbursement__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c){
            valid = true;
        }else if(activity.Billing_Cash_Receipt__c != null && activity.Billing_Cash_Receipt__r.AcctSeed__Cash_Receipt__r.AcctSeed__Bank_Account__r.Is_Trust_Account__c){
            valid = true;
        }
        return valid;
    }
}