/*** 
    @DESC        : controller class to handle payment from portal
    @AUTHOR      : prateek@ayodia
    @AUDITED BY  :
    @REVISION(S) :
***/
public without sharing class AyAffiniPayTransactionCardCont {
    //method to handle onload functions
    @AuraEnabled
    public static AyAffiniPayTransactionCardWrapper initAction(Id accountId){
        AyAffiniPayTransactionCardWrapper dataWrapper = new AyAffiniPayTransactionCardWrapper();

        //fetch affinipay public key
        for(affinipay__AffiniPay_Settings__c afSet: [Select Id, affinipay__Public_Key__c From affinipay__AffiniPay_Settings__c LIMIT 1]){
            dataWrapper.publicKey = afSet.affinipay__Public_Key__c; //m_DYJd_9keRPS2VUQftr4aEg
        }

        boolean isPersonAcc = false;
        for(User usr : [Select Id, Contact_Id__c From User Where Id =: UserInfo.getUserId()]){
            dataWrapper.contactId = usr.Contact_Id__c;
            if(usr.Contact_Id__c.startsWith('001')){
                isPersonAcc = true;
                dataWrapper.accountId = usr.Contact_Id__c;    
            }
        }
        System.debug('****dataWrapper.contactId='+dataWrapper.contactId);
        System.debug('****isPersonAcc='+isPersonAcc);
        if(!isPersonAcc){
            for(Contact con : [Select Id, AccountId From Contact Where Id =: dataWrapper.contactId]){
                dataWrapper.accountId = con.AccountId;
            }
        }
        
        dataWrapper.matters = new map<String,String>();
        for(AcctSeed__Project__c proj : [Select Id, Name From AcctSeed__Project__c Where AcctSeed__Account__c = : dataWrapper.accountId AND Is_Active__c = true]){
            dataWrapper.matters.put(proj.Id, proj.Name);
        }

        dataWrapper.transactionType = new map<String,String>();
		for(Schema.PicklistEntry pickListVal : affinipay__Transaction__c.Transaction_Type__c.getDescribe().getPicklistValues()){
			dataWrapper.transactionType.put(pickListVal.getValue(), pickListVal.getLabel());
		}     
        
        //dataWrapper.depositAccountId = 'a3N63000000bg4oEAA';
        if(!Test.isRunningTest()){map<String,Object> contactLinkMap = affinipay.AffiniPayService.checkContactLink('account',accountId);dataWrapper.jsonStr = JSON.serialize(contactLinkMap);}
            return dataWrapper;
        
    }

    
    @AuraEnabled
    public static string makePayment(String objectType, String objectId, String depositAccountId, String emailAddress, String amount, String tokenJsonStr, String relatedType, String relatedId, String relatedName, String reference, String tType, String selectedMatterId, Boolean thirdPartyPayment, String tpEmail, String tpMobile){
        map<String,Object> paymentResponseMap = new map<String,Object>();
        if(!Test.isRunningTest()){paymentResponseMap = affinipay.AffiniPayService.createPayment(objectType, objectId, depositAccountId, emailAddress, amount, tokenJsonStr, relatedType, relatedId, relatedName, reference);}
        if(paymentResponseMap.containsKey('id') || test.isRunningTest()){
            String affinipayId = (String) paymentResponseMap.get('id');
            for(affinipay__Transaction__c tra : [Select Id, affinipay__Link_Object_ID__c From affinipay__Transaction__c Where affinipay__AffiniPay_ID__c =: affinipayId]){
                tra.Matter__c = selectedMatterId;
                tra.Transaction_Type__c = tType;
                update tra;
                
                Account act = new Account(Id = tra.affinipay__Link_Object_ID__c);
                act.X3rd_Party_Authorization_Needed__c = thirdPartyPayment;
                act.X3rd_Party_Payer_Email__c = tpEmail;
                act.X3rd_Party_Payer_Mobile__c = tpMobile;
                update act;
            }

        }

        return JSON.serialize(paymentResponseMap);
    }

     // method to add payment method to object
    @AuraEnabled 
    public static map<String,Object> addMethodToObject(String objectType, String objectId, String tokenJsonStr){
        map<String,Object> addResponseMap = new map<String,Object>();
        if(!Test.isRunningTest()){addResponseMap = affinipay.AffiniPayService.addMethodToObject(objectType, objectId, tokenJsonStr);}
        return addResponseMap;
    }
}