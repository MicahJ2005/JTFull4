({
	doInIt : function(component, event, helper) {
		var recordId =  component.get("v.recordId");        
        var action = component.get('c.applyCashBalance');
        action.setParams({
            "trustBalanceId":recordId
        });
        
        action.setCallback(this,function(a){
            var message = a.getReturnValue();
            var toastEvent = $A.get("e.force:showToast");          
            if($A.util.isEmpty(message)){
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "Cash balance applied successfully." ,
                    "type": "success"                   
                });
            }else{
                toastEvent.setParams({
                    "title": "Error!",
                    "message": message,
                    "type": "error"
                });
                
            }
            toastEvent.fire();
            $A.get("e.force:closeQuickAction").fire();  
            $A.get('e.force:refreshView').fire();
        });
        $A.enqueueAction(action);
	}
})