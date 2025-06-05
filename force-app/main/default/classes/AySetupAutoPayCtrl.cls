public class AySetupAutoPayCtrl{
    
    @AuraEnabled
    public static string getExistingPaymentMethods(Id matterId){
        for(AcctSeed__Project__c proj : [Select Id, AcctSeed__Account__c From AcctSeed__Project__c where Id =: matterId]){
            map<String,Object> contactLinkMap = new map<String,Object>();
            if(!Test.isRunningTest()){contactLinkMap = affinipay.AffiniPayService.checkContactLink('Account',proj.AcctSeed__Account__c);}
            return JSON.serialize(contactLinkMap);
        }
        return null;
    }

    @AuraEnabled
    public static string setupAutoPay(Id matterId, string tokenStr){
        try{
            AcctSeed__Project__c proj = new AcctSeed__Project__c(Id= matterId, Auto_Debit_Method_Token__c = tokenStr, Auto_Pay__c = true);
            update proj;    
            return null;
        }catch(Exception e){return e.getMessage();}
    }
}