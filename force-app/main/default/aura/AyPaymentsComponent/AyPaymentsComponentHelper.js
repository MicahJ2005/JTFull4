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
        //console.log('public key=='+ pKey);
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
        //console.log('public key=='+ pKey);
        const hostedFieldsConfiguration = {
            publicKey: pKey,
            //publicKey : 'm_DYJd_9keRPS2VUQftr4aEg',
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

    doStoreCreditCard: function (component, helper) {
        component.set("v.actionsDisabled", true);
        helper.clearErrors(component);
    
        var token = helper
          .getCcPaymentToken({
            postal_code: component.find("postalCode").get("v.value"),
            exp_year: component.find("cc-year").get("v.value"),
            exp_month: component.find("cc-month").get("v.value"),
            email: component.find("cardHolderEmail").get("v.value")
          })
          .then(
            $A.getCallback(function (paymentResult) {
              console.log("recordId:" + component.get("v.cpaId"));
              console.log(JSON.stringify(paymentResult, null, 2));
              var action = component.get("c.addMethodToObject");
              var isCreditCardCharge = component.get("v.isCreditCardVisible");
              var payType = 'card';
              if(isCreditCardCharge){
                payType = 'card';
              }else{
                payType = 'bank';
              }
              console.log('***doStoreCreditCard***payType='+payType);
              action.setParams({
                objectId: component.get("v.cpaId"),
                tokenJsonStr: JSON.stringify(paymentResult, null, 2),
                pmType : payType
              });
              action.setCallback(this, function (response) {
                component.set("v.actionsDisabled", false);
                var state = response.getState();
                console.log('***doStoreCreditCard***state='+state);
                if(state === "SUCCESS"){
                    component.set("v.isEditable", false);
                    helper.showToast(
                      "Method Stored",
                      "The credit card was stored successfully.",
                      "success"
                    ); 
                }else{
                  helper.showErrors(component, [
                    "The payment information provided appears invalid. Please double check the number and expiration date and retry."
                  ]);
                }
              });
              $A.enqueueAction(action);
            })
          )
          .catch(
            $A.getCallback(function (err) {
              console.log(err);
              helper.showErrors(component, [
                "Card number and CVV are missing or invalid"
              ]);
            })
          );
    },
    
    doStoreAch: function (component, helper) {
        console.log("***doStoreAch***");
        component.set("v.actionsDisabled", true);
        helper.clearErrors(component);
        console.log("***errors cleared***");

        var acctHolderType = component.find("ach-acct-holder-type").get("v.value");
        var formFields = {
          account_holder_type: acctHolderType,
          account_type: component.find("ach-bank-acct-type").get("v.value"),
          postal_code: component.find("ach-postal-code").get("v.value"),
          email: component.find("ach-cardHolderEmail").get("v.value")
        };

        var token = helper
          .getAchPaymentToken(formFields)
          .then(
            $A.getCallback(function (paymentResult) {
              paymentResult.type = "bank";
              console.log("***doStoreAch***recordId:" + component.get("v.cpaId"));
              console.log(JSON.stringify(paymentResult, null, 2));
              var action = component.get("c.addMethodToObject");
              var payType = 'card';
              var isCreditCardCharge = component.get("v.isCreditCardVisible");
              if(isCreditCardCharge){
                payType = 'card';
              }else{
                payType = 'bank';
              }
              action.setParams({
                objectId: component.get("v.cpaId"),
                tokenJsonStr: JSON.stringify(paymentResult, null, 2),
                pmType : payType
              });
              console.log("***doStoreAch***payType=" + payType);
              action.setCallback(this, function (response) {
                var state = response.getState();
                component.set("v.actionsDisabled", false);
                console.log("***doStoreAch***state=" + state);
                if(state === "SUCCESS"){
                  var json = JSON.parse(response.getReturnValue());
                    component.set("v.obj", {
                      results: json.response.payment_methods
                    });
                    helper.showToast(
                      "Method Stored",
                      "The credit card was stored successfully.",
                      "success"
                    );
                  
                }else{
                    var json = JSON.parse(response.getReturnValue());
                    helper.showErrors(component, [
                      "The payment information provided appears invalid. Please double check the account numbers and retry."
                    ]);
                }
              });
              $A.enqueueAction(action);
            })
          )
          .catch(
            $A.getCallback(function (err) {
              console.log(err);
              helper.showErrors(component, [
                "Account and routing number are missing or invalid"
              ]);
            })
          );
    },
    
    refreshContact: function(component, event, helper, callback){
		    var action = component.get("c.initAction");
        action.setParams({
            cpaId: component.get("v.cpaId")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if(state === "SUCCESS"){
                var retObj = response.getReturnValue();
                var json = JSON.parse(retObj.jsonStr);
                if(json.email_addresses && json.email_addresses.length > 0) {
                    component.set('v.contactEmail', json.email_addresses[0].address);
                }
                if(json.payment_methods === undefined || json.payment_methods.length === 0){
                    component.set('v.activeAccordianSection', 'newPaymentMethod');
                    component.set('v.showPaymentMethods', 'false');
                }else{
                    component.set('v.activeAccordianSection', 'existingPaymentMethod');
                    component.set('v.showPaymentMethods', 'true');
                }
                if(json.payment_methods){
                    json.payment_methods.forEach(function (item,index) {
                        if(item.payment_type === 'credit_card') {
                            item.method_description = item.card_type + ' ' + item.account_number;
                        }else{
                            item.method_description = 'BANK ' + item.account_number;
                        }
                    });
                }
                component.set('v.contact', json);
                if(callback){
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