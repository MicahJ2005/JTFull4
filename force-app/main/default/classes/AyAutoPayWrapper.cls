public class AyAutoPayWrapper{
    
    @AuraEnabled public map<String,String> mattersMap {get;set;}
    @AuraEnabled public map<String,String> existingSetupMap {get;set;}
    @AuraEnabled public string savedPaymentMethods {get;set;}
    @AuraEnabled public string existingPaymentMethod {get;set;}
    @AuraEnabled public list<MatterDetailsWrapper> existingSetupList {get;set;} 

    public class MatterDetailsWrapper{
        @AuraEnabled public String matterName {get;set;}
        @AuraEnabled public String paymentMethod {get;set;}
    }
    
}