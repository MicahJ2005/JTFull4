({
	doInIt : function(component, event, helper) {
		var action = component.get('c.fetchTrustBalance');
        action.setParams({
        });
        action.setCallback(this,function(a){
            var responseData = a.getReturnValue();
            component.set("v.dataWrapper",responseData);
        });
        $A.enqueueAction(action);

	}
})