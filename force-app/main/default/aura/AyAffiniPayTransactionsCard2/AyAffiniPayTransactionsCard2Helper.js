({
    initCreditCardFields : function(component, helper){
		var settings = component.get('v.settings');
        
        const creditCardField = {
            selector: '#ap_credit_card_field_id',
            input : {
                type: 'credit_card_number',
                css: {
                    'font-size': '15px',
                    'padding-left': '6px',
                    'border-radius': '4px',
                    'border': '1px solid rgb(217, 219, 221)',
                    ':focus' : {
                        'border-color': 'rgb(21, 137, 238)',
                        'box-shadow': '0 0 3px #0070d2',
                        'outline': '0',
                    }
                }
            }
        }
        const cvv_hosted_field = {
            selector: '#ap_cvv_field_id',
            input : {
                type: 'cvv',
                css: {
                    'font-size': '15px',
                    'padding-left': '6px',
                    'border-radius': '4px',
                    'border': '1px solid rgb(217, 219, 221)',
                    ':focus' : {
                        'border-color': 'rgb(21, 137, 238)',
                        'box-shadow': '0 0 3px #0070d2',
                        'outline': '0',
                    }
                }
            }
        }
        var pKey = $A.get("{!$Label.c.Affinipay_Public_Key}");
        console.log('public key=='+ pKey);
        const hostedFieldsConfiguration = {
            //publicKey: 'm_DYJd_9keRPS2VUQftr4aEg',
            publicKey: pKey,
            input: {
                css: {
                    'font-family': 'Salesforce Sans", Arial, sans-serif',
                    'font-size': '25px',
                    'color': '#444444',
                }
            },
            fields: [
                creditCardField
                ,cvv_hosted_field
            ]
        }
		const hostedFieldsCallBack = function (state) {
			console.log(JSON.stringify(state, null, 2));
		}
    
		const hostedFields = window.AffiniPay.HostedFields.initializeFields(hostedFieldsConfiguration, hostedFieldsCallBack);
        helper.getCcPaymentToken =  hostedFields.getPaymentToken;
		console.log('End after scripts handler');
    },

	initAchFields : function(component, helper){
		var settings = component.get('v.settings');
        
        const achAcctNumField = {
            selector: '#ap_acct_number_field_id',
            input : {
                type: 'bank_account_number',
                css: {
                    'font-size': '15px',
                    'padding-left': '6px',
                    'border-radius': '4px',
                    'border': '1px solid rgb(217, 219, 221)',
                    ':focus' : {
                        'border-color': 'rgb(21, 137, 238)',
                        'box-shadow': '0 0 3px #0070d2',
                        'outline': '0',
                    }
                }
            }
        }
        
        const achRoutingNumField = {
            selector: '#ap_acct_routing_field_id',
            input : {
                type: 'routing_number',
                css: {
                    'font-size': '15px',
                    'padding-left': '6px',
                    'border-radius': '4px',
                    'border': '1px solid rgb(217, 219, 221)',
                    ':focus' : {
                        'border-color': 'rgb(21, 137, 238)',
                        'box-shadow': '0 0 3px #0070d2',
                        'outline': '0',
                    }
                }
            }
        }
        var pKey = $A.get("{!$Label.c.Affinipay_Public_Key}");
        console.log('public key=='+ pKey);
        const hostedFieldsConfiguration = {
            //publicKey: 'm_DYJd_9keRPS2VUQftr4aEg',
            publicKey: pKey,
            input: {
                css: {
                    'font-family': 'Salesforce Sans", Arial, sans-serif',
                    'font-size': '25px',
                    'color': '#444444',
                }
            },
            fields: [
                achAcctNumField, achRoutingNumField
            ]
        }
        
		const hostedFieldsCallBack = function (state) {
			console.log(JSON.stringify(state, null, 2));
		}
        
		const hostedFields = helper.HostedFields.initializeFields(hostedFieldsConfiguration, hostedFieldsCallBack);
        helper.getAchPaymentToken =  hostedFields.getPaymentToken;
		console.log('End after scripts handler');
    },
      
    clearErrors : function(component){
        component.set("v.hasChargeErrors", false);
        component.set("v.chargeErrors", []);
    },    
    
    showErrors : function(component, messages){
        component.set("v.hasChargeErrors", true);
        component.set("v.chargeErrors", messages);
		component.set("v.actionsDisabled", false);
    },

    doMethodCharge : function(component, helper){
        helper.clearErrors(component);
		component.set("v.actionsDisabled", true);
        
		if(component.find("email").get("v.value") === '' || component.find("email").get("v.value") === undefined) {
            helper.showErrors(component, ['Please provide email and try again.']);
            return;
        }
        
		if(component.get("v.depositAccountId") === '' || component.get("v.depositAccountId") === undefined){
            helper.showErrors(component, ['Deposit account is required. Please contact your system administrator.']);
            return;
        }
        
        if(component.find("amount").get("v.value") === '' || component.find("amount").get("v.value") === '0.00') {
            helper.showErrors(component, ['Amount is required']);
            return;
        }
        
        var reference = component.find("reference").get("v.value");
        var methodId = component.find("paymentMethod").get("v.value");
        var contact = component.get("v.contact");
        var methods = contact.payment_methods.filter(m => m.id === methodId);
        if (methods.length > 0) {
            var tokenObj = {
                id: methodId,
                type: methods[0].payment_type === 'bank_account' ? 'bank' : 'card'
            };
            
            var objectType = 'Account';
            var objectId = component.get("v.recordId");

            var relatedType = component.get("v.selectedRelatedType");
            var relatedObject = component.get("v.selectedRelatedObject");
            var mtrId = component.get("v.selectedMatter");

            var action = component.get("c.makePayment");
            action.setParams({'objectType':objectType, 
                              'objectId':objectId,
                              'depositAccountId': component.get("v.depositAccountId"),
                              'emailAddress': component.find("email").get("v.value"),
                              'amount' : component.find("amount").get("v.value"),
                              'tokenJsonStr': JSON.stringify(tokenObj),
							  'relatedType': 'relatedType',
                              'relatedId': relatedObject === null ? null : relatedObject.Id,
                              'relatedName': relatedObject === null ? null : relatedObject.Name,
                              'reference': reference,
                              'selectedMatterId' : mtrId
                             });
            action.setCallback(this, function(response) {
                component.set("v.actionsDisabled", false);
                var state = response.getState();
                if (state === "SUCCESS"){
                    var json = JSON.parse(response.getReturnValue());
                    if (json['status'] == 'AUTHORIZED'){
                        component.set("v.isChargeModal", false);
                        component.set("v.isRequestModal", false);
                        component.set("v.isModalOpen", false);
                        helper.navigateToPaymentStatus(component, helper);
                    }else{
                        var json = JSON.parse(response.getReturnValue());
                        helper.showErrors(component, json.response.messages.map(function(a) {return a.message;}));
                    }                        
                }
            });
            $A.enqueueAction(action);             
        }else{
            component.set("v.actionsDisabled", false);
            console.log("No method found.");
        }
    },
    
    doCreditCardCharge : function(component, helper){
        console.log("doCreditCardCharge")
        component.set("v.actionsDisabled", true);
        helper.clearErrors(component);
        var email_str = component.find("email").get("v.value");
        if(email_str === '' || email_str === undefined) {
            helper.showErrors(component, ['Please provide email and try again.']);
            return;
        }

        if(component.find("cardHolder").get("v.value") === '') {
            helper.showErrors(component, ['Card Holder name is required']);
            return;
        }
        
		if(component.get("v.depositAccountId") === '' || component.get("v.depositAccountId") === undefined){
            helper.showErrors(component, ['Deposit account is required. Please contact your system administrator.']);
            return;
        }
        
        if(component.find("amount").get("v.value") === '' || component.find("amount").get("v.value") === '0.00') {
            helper.showErrors(component, ['Amount is required']);
            return;
        }
        
		if(component.find("postalCode").get("v.value") === '') {
            helper.showErrors(component, ['Postal code is required']);
            return;
        }
        
        /*console.log("All good till here, now validating 3rd party.");
        var thirdPartyPayment = component.find("cc-tpan-pm").get("v.checked");
        console.log("thirdPartyPayment="+thirdPartyPayment);
        if(thirdPartyPayment){

            console.log("1");
            if(component.find("cc-tpeml-pm").get("v.value") === ''){
                helper.showErrors(component, ['Third Party Email is required.']);
                return;
            }
            
            console.log("2");
            if(component.find("cc-tpmob-pm").get("v.value") === '') {
                helper.showErrors(component, ['Third Party Mobile number is required.']);
                return;
            }
        }*/

        console.log("All good till here, now generating token");
        var token = helper.getCcPaymentToken({"postal_code": component.find("postalCode").get("v.value"), 
                                              "name": component.find("cardHolder").get("v.value"),
                                              "exp_year": component.find("cc-year").get("v.value"), 
                                              "exp_month": component.find("cc-month").get("v.value"),
                                              "email": email_str})
			.then($A.getCallback(function (paymentResult) {                
            	var objectType = 'Account';
	            var objectId = component.get("v.recordId");
    	        
	            var relatedType = component.get("v.selectedRelatedType");
    	        var relatedObject = component.get("v.selectedRelatedObject");                
                var reference = component.find("reference").get("v.value");
                
                // new vals
                var selectedTransactionType = component.get("v.tType");
                var selectedMatterId = component.get("v.selectedMatter");
                var thirdPartyPayment = component.find("cc-tpan-pm").get("v.checked");
                
                var tpEmail_c = component.find("cc-tpeml-pm");
                var tpEmail = '';
                if(tpEmail_c != null && tpEmail_c != 'undefined'){
                    tpEmail = tpEmail_c.get("v.value");
                }

                var tpMobile_c = component.find("cc-tpmob-pm");
                var tpMobile = '';
                if(tpMobile_c != null && tpMobile_c != 'undefined'){
                    tpMobile = tpMobile_c.get("v.value")
                }
                
                console.log("selectedTransactionType="+selectedTransactionType);
                console.log("selectedMatterId="+selectedMatterId);
                console.log("thirdPartyPayment="+thirdPartyPayment);
                console.log("tpEmail="+tpEmail);
                console.log("tpMobile="+tpMobile);


                console.log("objectType="+objectType);
                console.log("objectId="+objectId);
                console.log("depositAccountId="+component.get("v.depositAccountId"));
                console.log("email_str="+email_str);
                console.log("amount="+component.find("amount").get("v.value"));
                console.log("tokenJsonStr="+JSON.stringify(paymentResult, null, 2));
                console.log("relatedType="+relatedType);
                
                var action = component.get("c.makePayment");
                action.setParams({'objectType': objectType, 
                                  'objectId': objectId,
                                  'depositAccountId': component.get("v.depositAccountId"),
                                  'emailAddress': email_str,
                                  'amount' : component.find("amount").get("v.value"),
                                  'tokenJsonStr': JSON.stringify(paymentResult, null, 2),
                                  'relatedType': relatedType,
                              	  'relatedId': relatedObject === null ? null : relatedObject.Id,
                              	  'relatedName': relatedObject === null ? null : relatedObject.Name,
                                  'reference': reference,
                                  'tType' : selectedTransactionType,
                                  'selectedMatterId' : selectedMatterId,
                                  'thirdPartyPayment' : thirdPartyPayment,
                                  'tpEmail' : tpEmail,
                                  'tpMobile' : tpMobile
                                 });
                action.setCallback(this, function(response){
                    component.set("v.actionsDisabled", false);
                    var state = response.getState();
                    console.log("state="+state)
                    if(state === "SUCCESS"){
						var json = JSON.parse(response.getReturnValue());
                        console.log('***doCreditCardCharge***'+json['status']);
                        if(json['status'] == 'AUTHORIZED'){
                            component.set("v.isChargeModal", false);
                            component.set("v.isRequestModal", false);
                            component.set("v.isModalOpen", false);
                            var savePM = component.find("cc-save-pm").get("v.checked");
                            if(savePM){
                                helper.addPaymentMethod(component, helper, JSON.stringify(paymentResult, null, 2));
                            }else{
                                helper.showToast('Payment Success!','The credit card payment completed successfully.','success');
                                $A.get('e.force:refreshView').fire();     
                            }
                        }else{
                            var json = JSON.parse(response.getReturnValue());
                            helper.showErrors(component, json.response.messages.map(function(a) {return a.message;}));
                        }                        
                    }
                });
                $A.enqueueAction(action);
            }))
			.catch($A.getCallback(function (err) {
				console.log('***doCreditCardCharge***'+err);
                component.set("v.actionsDisabled", false);
				helper.showErrors(component, ['Card number and CVV are required']);
			}));
    },

    doAchCharge : function(component, helper){
        component.set("v.actionsDisabled", true);
		helper.clearErrors(component);
        
		var email_str = component.find("email").get("v.value");
        if(email_str === '' || email_str === undefined) {
            helper.showErrors(component, ['Please provide email and try again.']);
            return;
        }
        
		if(component.get("v.depositAccountId") === '' || component.get("v.depositAccountId") === undefined){
            helper.showErrors(component, ['Deposit account is required. Please contact your system administrator.']);
            return;
        }
        
        if(component.find("amount").get("v.value") === '' || component.find("amount").get("v.value") === '0.00') {
            helper.showErrors(component, ['Amount is required']);
            return;
        }
        
        var acctHolderType = component.find("ach-acct-holder-type").get("v.value");
        var formFields = {
            email: email_str,
            account_holder_type: acctHolderType,
            account_type: component.find("ach-bank-acct-type").get("v.value"),
            postal_code: component.find("ach-postal-code").get("v.value")
        };
        
        if(acctHolderType === 'business'){
            formFields.name = component.find("ach-acct-name").get("v.value");
            
			if(formFields.name === ''){
            	helper.showErrors(component, ['Account name is required']);
	            return;
    	    }
        }else{
            formFields.given_name = component.find("ach-acct-first_name").get("v.value");
            formFields.surname = component.find("ach-acct-last_name").get("v.value");
            
            if(formFields.given_name === ''){
            	helper.showErrors(component, ['First name is required']);
	            return;
    	    }
            
            if(formFields.surname === ''){
                helper.showErrors(component, ['Last name is required']);
	            return;
    	    }
        }

		if(component.find("ach-postal-code").get("v.value") === ''){
            helper.showErrors(component, ['Postal code is required']);
            return;
        }        
        
        var token = helper.getAchPaymentToken(formFields)
			.then($A.getCallback(function (paymentResult) {
                console.log('recordId:'+component.get("v.recordId"));
				console.log(JSON.stringify(paymentResult, null, 2));

	            var objectType = 'Account';
    	        var objectId = component.get("v.recordId");
        	    
                var reference = component.find("reference").get("v.value");
	            var relatedType = component.get("v.selectedRelatedType");
    	        var relatedObject = component.get("v.selectedRelatedObject");                

                var action = component.get("c.makePayment");
                action.setParams({'objectType': objectType, 
                                  'objectId': objectId,
                                  'depositAccountId':component.get("v.depositAccountId"),
                                  'emailAddress':email_str,
                                  'amount' : component.find("amount").get("v.value"),
                                  'tokenJsonStr': JSON.stringify(paymentResult, null, 2),
								  'relatedType': relatedType,
                              	  'relatedId': relatedObject === null ? null : relatedObject.Id,
                              	  'relatedName': relatedObject === null ? null : relatedObject.Name,
                                  'reference': reference
                                 });
                action.setCallback(this, function(response) {
                    component.set("v.actionsDisabled", false);
                    var state = response.getState();
                    
                    if(state === "SUCCESS"){
						var json = JSON.parse(response.getReturnValue());
                        if (json['status'] == 'AUTHORIZED'){
                            component.set("v.isChargeModal", false);
                            component.set("v.isRequestModal", false);
                            component.set("v.isModalOpen", false);
                            //helper.reloadTransactions(component, helper);
                            var savePM = component.find("ach-save-pm").get("v.checked");
                            if(savePM){
                                helper.addPaymentMethod(component, helper, JSON.stringify(paymentResult, null, 2));
                            }else{
                                helper.showToast('Payment Success!','The credit card payment completed successfully.','success');
                                $A.get('e.force:refreshView').fire();     
                            }
                        }else{
                            var json = JSON.parse(response.getReturnValue());
                            helper.showErrors(component, json.response.messages.map(function(a) {return a.message;}));
                        }                        
                    }
                });
                $A.enqueueAction(action);
            }))
			.catch($A.getCallback(function (err) {
				console.log(err);
                helper.showErrors(component, ['Account and routing number are required']);
			}));
    },

    addPaymentMethod : function(component, helper, jsonStr){
        console.log('***addPaymentMethod***');
        //console.log('***addPaymentMethod***jsonStr='+jsonStr);
        var action = component.get("c.addMethodToObject");
        component.set("v.actionsDisabled", true); 
        //console.log('***addPaymentMethod***action created');
          action.setParams({
            objectType: 'Account',
            objectId: component.get("v.recordId"),
            tokenJsonStr: jsonStr
          });
          //console.log('***addPaymentMethod***params set');  
          action.setCallback(this, function (response) {
            var state = response.getState();
            console.log('***addPaymentMethod***state='+state);
            component.set("v.actionsDisabled", false); 
            if(state === "SUCCESS"){
                helper.navigateToPaymentStatus(component, helper);
            }else{
                var json = JSON.parse(response.getReturnValue());
                helper.showErrors(component,[
                  "The payment information provided appears invalid. Please double check the numbers and retry."
                ]);
              }
          });
          $A.enqueueAction(action);
    },

    navigateToPaymentStatus : function(component, helper) {  
          
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
        "url": "/payment-status"
        });
        urlEvent.fire();  
          
    },
    
    refreshContact: function(component, event, helper, callback){
		var action = component.get("c.initAction");
        action.setParams({
            accountId: component.get("v.recordId")
        });
        action.setCallback(this, function(response) {
			var state = response.getState();
			if (state === "SUCCESS") {
                var retObj = response.getReturnValue();
                var json = JSON.parse(retObj.jsonStr);
				if (json.email_addresses && json.email_addresses.length > 0) {
					component.set('v.contactEmail', json.email_addresses[0].address);
				}
				if (json.payment_methods === undefined || json.payment_methods.length === 0) {
                     component.set('v.activeAccordianSection', 'newPaymentMethod');
                     component.set('v.showPaymentMethods', 'false');
                }
                else {
					component.set('v.activeAccordianSection', 'existingPaymentMethod');
                    component.set('v.showPaymentMethods', 'true');
                }
                if (json.payment_methods) {
                    json.payment_methods.forEach(function (item,index) {
                        if (item.payment_type === 'credit_card') {
                            item.method_description = item.card_type + ' ' + item.account_number;
                        }
                        else {
                            item.method_description = 'BANK ' + item.account_number;
                        }
                    });
                }
                component.set('v.contact', json);
                if (callback) {
                    callback();
                }
			}
		});
        $A.enqueueAction(action);
    },
    
    showToast : function(title, message, type){
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "type": type
        });
        toastEvent.fire();
    }
})