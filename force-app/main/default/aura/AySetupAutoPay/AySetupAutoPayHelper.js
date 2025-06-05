({
	refreshContact: function(component, event, helper, callback){
		var action = component.get("c.getExistingPaymentMethods");
        action.setParams({
            matterId: component.get("v.recordId")
        });
        action.setCallback(this, function(response){
			var state = response.getState();
			if(state === "SUCCESS"){
                var json = JSON.parse(response.getReturnValue());
                if(json.payment_methods){
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