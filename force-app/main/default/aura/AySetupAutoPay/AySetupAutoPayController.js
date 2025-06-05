({
	onloadScript: function(component, event, helper){
	    helper.HostedFields = window.AffiniPay.HostedFields;
  	},
	
    doInIt: function(component, event, helper){
        var action = component.get("c.getExistingPaymentMethods");
    
        action.setParams({
          matterId: component.get("v.recordId")
        });
    
        action.setCallback(this, function(response){
          var state = response.getState();
          if(state === "SUCCESS"){
            console.log("success getting settings");
            var json = JSON.parse(response.getReturnValue());
            component.set("v.settings", json);
            var visibleAccounts = json.deposit_accounts
              ? json.deposit_accounts.filter((m) => m.selectable === true)
              : [];
            component.set("v.apAccounts", { results: visibleAccounts });
            component.set("v.apAccounts2", { results: visibleAccounts });
              
            // ensure the contact is linked to an affinipay contact
            helper.refreshContact(component, event, helper, null);
          }
        });
        $A.enqueueAction(action);
      },
    
    setupAutoPay_js: function(component, event, helper){
        var methodId = component.find("paymentMethod").get("v.value");
        
        var contact = component.get("v.contact");
        var methods = contact.payment_methods.filter(m => m.id === methodId);
        if (methods.length > 0){
            var tokenObj = {
                id: methodId,
                type: methods[0].payment_type === 'bank_account' ? 'bank' : 'card'
            };
            
			var action = component.get("c.setupAutoPay");
            action.setParams({
                'matterId':component.get("v.recordId"),
                'tokenStr':JSON.stringify(tokenObj)
            }); 
            action.setCallback(this, function(response) {
                var state = response.getState();
                if(state === "SUCCESS"){
                    var msg = JSON.parse(response.getReturnValue());
                    if(msg == undefined || msg == '' || msg == null){
                        helper.showToast('Success!','Auto Debit scheduled successfully.','success');
                    }else{
                        helper.showToast('Error',msg,'error');
                    }  
                    $A.get('e.force:refreshView').fire(); 
                    $A.get("e.force:closeQuickAction").fire();
                }
            });
            $A.enqueueAction(action);                         
        }
    }

})