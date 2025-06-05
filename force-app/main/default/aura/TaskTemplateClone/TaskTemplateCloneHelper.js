({
    cloneTemplate : function(component) {

        component.set("v.buttonDisabled", true);
        var templateId = component.get("v.recordId");
        var templateName = component.get("v.masterTemplateName");

		var action = component.get("c.cloneTemplate");
        action.setParams({
            templateId : templateId,
            templateName: templateName
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS")
			{
                var urlEvent = $A.get("e.force:navigateToSObject");
                urlEvent.setParams({
                    "recordId": response.getReturnValue()
                });
                urlEvent.fire();
            } else
			{
                component.set("v.errorMessage", response.getError());
                component.set("v.buttonDisabled", false);
            }
        });
        $A.enqueueAction(action);
    }
})