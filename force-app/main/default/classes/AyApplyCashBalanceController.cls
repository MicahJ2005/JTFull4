public class AyApplyCashBalanceController{

    @AuraEnabled
    public static string applyCashBalance(string trustBalanceId){
        try{
            list<AcctSeed__Cash_Receipt__c> crList = new list<AcctSeed__Cash_Receipt__c>();
            for(Trust_Account_Activity__c taa : [Select Id, Cash_Receipt__c, Billing__c From Trust_Account_Activity__c Where Trust_Balance__c = : trustBalanceId]){
                if(taa.Cash_Receipt__c != null){
                    crList.add(new AcctSeed__Cash_Receipt__c(Id = taa.Cash_Receipt__c, Auto_Apply__c = true));
                }
            }

            if(crList.size() > 0){
                update crList;
            }

        }catch(Exception e){return e.getMessage() + ' on line : ' + e.getLineNumber();}

        return null;
    }

}