public without sharing class AyPaymentsComponentController{
    
    @AuraEnabled
    public static AyAffiniPayTransactionCardWrapper initAction(Id cpaId){
        AyAffiniPayTransactionCardWrapper dataWrapper = new AyAffiniPayTransactionCardWrapper();
        
        Customer_Products_Approval__c cpa = [Select Id, Opportunity__r.AccountId from Customer_Products_Approval__c where id=:cpaId];
        //fetch affinipay public key
        for(affinipay__AffiniPay_Settings__c afSet: [Select Id, affinipay__Public_Key__c From affinipay__AffiniPay_Settings__c LIMIT 1]){
            dataWrapper.publicKey = afSet.affinipay__Public_Key__c; //m_DYJd_9keRPS2VUQftr4aEg
        }
        
        dataWrapper.depositAccountId = 'a3N63000000bg2PEAQ';
        dataWrapper.accountId = cpa.Opportunity__r.AccountId;
        if(!Test.isRunningTest()){map<String,Object> contactLinkMap = affinipay.AffiniPayService.checkContactLink('account',dataWrapper.accountId);dataWrapper.jsonStr = JSON.serialize(contactLinkMap);}
        return dataWrapper;
        
    }

    @AuraEnabled 
    public static map<String,Object> addMethodToObject(String objectId, String tokenJsonStr, String pmType){
        map<String,Object> addResponseMap = new map<String,Object>();
        //if(!Test.isRunningTest()){

            Customer_Products_Approval__c cpa_fetch = [Select Id, Opportunity__r.AccountId from Customer_Products_Approval__c where id=:objectId];
            if(Test.isRunningTest()){
				addResponseMap.put('payment_methods', 'test id=yvguhiuo234,');                
            }else{
                addResponseMap = affinipay.AffiniPayService.addMethodToObject('Account', cpa_fetch.Opportunity__r.AccountId, tokenJsonStr);
            }
            //addResponseMap = affinipay.AffiniPayService.addMethodToObject('Account', cpa_fetch.Opportunity__r.AccountId, tokenJsonStr);
            
            System.debug('*****cpa_fetch.Opportunity__r.AccountId==='+cpa_fetch.Opportunity__r.AccountId);
            System.debug('*****tokenJsonStr==='+tokenJsonStr);
            System.debug('*****addResponseMap==='+addResponseMap);

            Object tempList = addResponseMap.get('payment_methods');
            String paymentMethods = tempList.toString();

            String methodTokenRAW = paymentMethods.substringAfter(' id=');
            
            String methodToken = methodTokenRAW.substringBefore(',');

            PaymentMethodWrapper pmw = new PaymentMethodWrapper();
            pmw.id = methodToken;
            pmw.type = pmType;
            
            // convert to json
            String paymentMethodTokenFinal = JSON.serialize(pmw);

            // update payment method json token in cpa record
            Customer_Products_Approval__c cpa = new Customer_Products_Approval__c(Id = objectId, Payment_Method_Token__c = paymentMethodTokenFinal);
            update cpa;
            
        //}
        return addResponseMap;
    }

    public class PaymentMethodWrapper{
        public string id {get;set;}
        public string type {get;set;}
    }

}