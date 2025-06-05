({
	refreshContact: function(component, event, helper, responseJSON){
        console.log('**refreshContact**');
        var json = JSON.parse(responseJSON);
        if(json.payment_methods){
            json.payment_methods.forEach(function (item,index) {
                if(item.payment_type === 'credit_card'){
                    item.method_description = item.card_type + ' ' + item.account_number;
                }
                else{
                    item.method_description = 'BANK ' + item.account_number;
                }
            });
        }
        component.set('v.contact', json);
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