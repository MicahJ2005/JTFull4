public without sharing class AyManageAutoPayCtrl {
    
    @AuraEnabled
    public static AyAutoPayWrapper handleInit(){
    
        AyAutoPayWrapper w = new AyAutoPayWrapper();
        boolean isPersonAcc = false;
        Id accountId, contactId;
        for(User usr : [Select Id, Contact_Id__c From User Where Id =: UserInfo.getUserId()]){
            contactId = usr.Contact_Id__c;
            if(usr.Contact_Id__c.startsWith('001')){
                isPersonAcc = true;
                accountId = usr.Contact_Id__c;    
            }
        }
        
        if(!isPersonAcc){
            for(Contact con : [Select Id, AccountId From Contact Where Id =: contactId]){
                accountId = con.AccountId;
            }
        }

        // get saved payment methods
        map<String,Object> contactLinkMap = new map<String,Object>();
        /*
        if(!Test.isRunningTest()){
            contactLinkMap = affinipay.AffiniPayService.checkContactLink('Account',accountId);
        	w.savedPaymentMethods = JSON.serialize(contactLinkMap);
        }
        System.debug('***contactLinkMap='+contactLinkMap);
        */
        
        if(Test.isRunningTest()){
            //contactLinkMap = '{contact_code=0030, created={caller_country_code=US, caller_inet_address=13.110.6.8, caller_location=37.751,-97.822, client_country_code=US, client_id=e0abf65ec55c56d4ddf5ad440e9e6a6998a6e0ff9da1ff2b7b0329d17fd53276, client_inet_address=13.110.6.8, client_location=37.751,-97.822, timestamp=2022-04-12T10:26:35.945Z, user=carrie@johnsonturner.com}, display_name=Carrie Test 3-14, id=org_5CZC1hH3BAdvekjHAvGJy, members={page=1, page_size=20, results=(), total_entries=0}, modified={caller_country_code=US, caller_inet_address=13.110.14.8, caller_location=37.751,-97.822, client_country_code=US, client_id=e0abf65ec55c56d4ddf5ad440e9e6a6998a6e0ff9da1ff2b7b0329d17fd53276, client_inet_address=13.110.14.8, client_location=37.751,-97.822, timestamp=2022-04-21T13:24:36.149Z, user=carrie@johnsonturner.com}, name=Carrie Test 3-14, owner={display_name=Johnson/Turner Legal, id=org_bdgrF1mgxI5Si4BdjMHtr, name=Johnson/Turner Legal, owner_id=org_a9p7cYn9MzBIL6egPb51O, preferred_email=chris@johnsonturner.com, sort_name=Johnson/Turner Legal, test_mode=false, type=organization}, owner_id=org_bdgrF1mgxI5Si4BdjMHtr, payment_methods=({account_number=************4242, address={postal_code=134107, preferred=false, type=address}, allow_future_payments=false, card_type=VISA, created={caller_country_code=US, caller_inet_address=13.110.14.8, caller_location=37.751,-97.822, client_country_code=US, client_id=e0abf65ec55c56d4ddf5ad440e9e6a6998a6e0ff9da1ff2b7b0329d17fd53276, client_inet_address=13.110.14.8, client_location=37.751,-97.822, timestamp=2022-04-21T13:24:36.148Z, user=carrie@johnsonturner.com}, expiration_month=1, expiration_year=2025, id=pmtd_VYczpEn1T2MqoYjx7QsLC, modified={caller_country_code=US, caller_inet_address=13.110.14.8, caller_location=37.751,-97.822, client_country_code=US, client_id=e0abf65ec55c56d4ddf5ad440e9e6a6998a6e0ff9da1ff2b7b0329d17fd53276, client_inet_address=13.110.14.8, client_location=37.751,-97.822, timestamp=2022-04-21T13:24:36.148Z, user=carrie@johnsonturner.com}, name=Prateek Maan, ...}), ...}';
            map<String,Object> tMap = new map<String,Object>();
            tMap.put('id',(Object)'pmtd_**********');
			list<Object> objList = new list<Object>();
            objList.add((Object)tMap);
            contactLinkMap.put('payment_methods', objList);
            
        }else{
            contactLinkMap = affinipay.AffiniPayService.checkContactLink('Account',accountId);
        	w.savedPaymentMethods = JSON.serialize(contactLinkMap);
        }

        // get existing payment methods
        w.mattersMap = new map<String,String>();
        w.existingSetupList = new list<AyAutoPayWrapper.MatterDetailsWrapper>();
        
        for(AcctSeed__Project__c proj : [Select Id, Name, Auto_Debit_Method_Token__c From AcctSeed__Project__c Where AcctSeed__Account__c = : accountId AND Is_Active__c = true]){
            w.mattersMap.put(proj.Id, proj.Name);

            if(proj.Auto_Debit_Method_Token__c != null && proj.Auto_Debit_Method_Token__c.trim() != ''){
                AyAutoPayWrapper.MatterDetailsWrapper mdw = new AyAutoPayWrapper.MatterDetailsWrapper();
                mdw.matterName = proj.Name;

                map<String,Object> tokenMap = (map<String,Object>) JSON.deserializeUntyped(proj.Auto_Debit_Method_Token__c);

                if(tokenMap.containsKey('id')){
                    String token = (String)tokenMap.get('id');
                    if(contactLinkMap.containsKey('payment_methods')){
                        list<Object> payment_methods = (list<Object>)contactLinkMap.get('payment_methods');
                        for(Object obj : payment_methods){
                            map<String,Object> paymentMethodsMap = (map<String,Object>)obj;
                            if(paymentMethodsMap != null && paymentMethodsMap.containsKey('id')){
                                if(paymentMethodsMap.get('id') == token){
                                    if(paymentMethodsMap.get('payment_type') == 'credit_card'){  
                                        mdw.paymentMethod = paymentMethodsMap.get('card_type') + ' ' + paymentMethodsMap.get('account_number');
                                    }else{
                                        mdw.paymentMethod = 'BANK - ' + paymentMethodsMap.get('account_number');
                                    }  
                                    w.existingSetupList.add(mdw);
                                }
                            }   
                        }
                    }
                }
            }
        }
        //System.debug('****w.existingSetupList='+w.existingSetupList);
		//System.debug('****w.mattersMap='+w.mattersMap);
       
        return w;
    }

    @AuraEnabled
    public static String setupAutoPay(Id matterId, string tokenStr){
        try{
            if(tokenStr != null && tokenStr.trim() != ''){
                AcctSeed__Project__c proj = new AcctSeed__Project__c(Id= matterId, Auto_Debit_Method_Token__c = tokenStr, Auto_Pay__c = true);
                update proj;    
                return null;
            }else{return 'Please select a payment method first.';}
        }catch(Exception e){return e.getMessage();}
    }
}