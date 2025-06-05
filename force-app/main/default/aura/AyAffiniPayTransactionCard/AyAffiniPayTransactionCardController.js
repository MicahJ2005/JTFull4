({
	doInIt : function(component, event, helper) {
		var accId = component.get("v.recordId");
		var action = component.get('c.initAction');
        action.setParams({
            "accountId":accId
        });
        action.setCallback(this,function(a){
            var responseData = a.getReturnValue();
            component.set("v.dataWrapper",responseData);
			//alert('public key= '+responseData.publicKey);
        });
        $A.enqueueAction(action);
		
	},
	closeComp : function(component, event, helper) {
        var recordId = component.get("v.recordId"); 
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": recordId
        });
        navEvt.fire();
	},
	submitAction : function(component, event, helper) {
		var valid = true;
		var dataWrapper = component.get("v.dataWrapper");
		//validate amount
		if(dataWrapper.amount == null){
			valid = false;
		}
		//check selected method
		if(dataWrapper.selectedMethodId == null){
			//fetch selected tab for new method
			dataWrapper.newMethod.methodType = component.get("v.newPaymentMethodType");
			if(dataWrapper.newMethod.methodType == 'cc'){
				//validate credit card details
				var validCC = component.find('inputCC').reduce(function (validSoFar, inputCmp) {
					inputCmp.reportValidity();
					return validSoFar && inputCmp.checkValidity();
				}, true);
				if (!validCC) {
					valid = false;
				}
				if(dataWrapper.newMethod.month == null || dataWrapper.newMethod.year == null){
					valid = false;
				}
			}else if(dataWrapper.newMethod.methodType == 'ach'){
				//validate check details
				var validACH = component.find('inputACH').reduce(function (validSoFar, inputCmp) {
					inputCmp.reportValidity();
					return validSoFar && inputCmp.checkValidity();
				}, true);
				if (!validACH) {
					valid = false;
				}
				//validate bank holder type and bank account type
				if(dataWrapper.newMethod.accountHolderType == null || dataWrapper.newMethod.bankAccountType == null){
					valid = false;
				}
			}
		}
		if(valid){
			//process payment
			//alert('valid');
			var creditCardFieldConfig = {
				selector: dataWrapper.newMethod.ccNumber,
				input: {
				  type: "credit_card_number"
				}
			}
			
			var cvvFieldConfig = {
				selector:dataWrapper.newMethod.cvv,
				input: {
				  type: "cvv"
				}
			}
			var hostedFieldsConfiguration = {
				publicKey: dataWrapper.publicKey,
				fields: [
				  creditCardFieldConfig,
				  cvvFieldConfig,
				]
			}
			
			var hostedFieldsCallback = function (state) {
				console.log(JSON.stringify(state, null, 2))
			}
			
			
			var hostedFields = window.AffiniPay.HostedFields.initializeFields(hostedFieldsConfiguration, hostedFieldsCallback);
			
			//var state = hostedFields.getState();
			
		}
	},
	onloadScript : function(component, event, helper) {
		
		
	}
})