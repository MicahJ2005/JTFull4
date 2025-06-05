({
	onloadScript: function(component, event, helper){
		helper.HostedFields = window.AffiniPay.HostedFields;
  	},
	 
    doInIt: function(component, event, helper){
        component.set("v.changePaymentMethod", false);

        var action = component.get("c.handleInit");
        action.setCallback(this, function(response){
			var state = response.getState();
			if(state === "SUCCESS"){
                var res = response.getReturnValue();
                component.set("v.wrap", res);
                
                // matters
                var mattersMap = [];
                var result = res.mattersMap;
                for(var key in result){
					mattersMap.push({key: key, value: result[key]});
                }
              	component.set("v.mattersMap", mattersMap);
               	
                // payment methods
				var responseJSON = res.savedPaymentMethods;
                helper.refreshContact(component, event, helper, responseJSON);
			}
        });
        $A.enqueueAction(action);
    },
    
    changePaymentMethod : function(component, event, helper){
    	component.set("v.changePaymentMethod", true);    
    },
    
    cancelChangePaymentMethod : function(component, event, helper){
    	component.set("v.changePaymentMethod", false);    
    },
    
    setupAutoPay_js: function(component, event, helper){
        var methodId = component.find("paymentMethod").get("v.value");
        
        var contact = component.get("v.contact");
        var methods = contact.payment_methods.filter(m => m.id === methodId);
        if(methods.length > 0){
			var tokenObj = {
                id: methodId,
                type: methods[0].payment_type === 'bank_account' ? 'bank' : 'card'
            };
            
			var action = component.get("c.setupAutoPay");
            action.setParams({
                'matterId':component.get("v.selectedMatter"),
                'tokenStr':JSON.stringify(tokenObj)
            }); 
            action.setCallback(this, function(response) {
                var state = response.getState();
                if(state === "SUCCESS"){
                    var msg = response.getReturnValue();
                    if(msg == undefined || msg == '' || msg == null){
                        helper.showToast('Success!','Auto Debit scheduled successfully.','success');
                    }else{
                        helper.showToast('Error',msg,'error');
                    }  
			        $A.enqueueAction(component.get('c.doInIt'));
                }
            });
            $A.enqueueAction(action);                         
        }
    }
})