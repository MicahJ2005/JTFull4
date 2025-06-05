({
	doInIt : function(component, event, helper) {
        var today = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD");
        component.set('v.todaysDate', today);
		var action = component.get('c.fetchBills');
        action.setParams({
        });
        action.setCallback(this,function(a){
            var responseData = a.getReturnValue();
            component.set("v.dataWrapper",responseData);
        });
        $A.enqueueAction(action);

	},
    billPDF : function(component, event, helper) {
        var selectedItem = event.currentTarget;
        var id = selectedItem.dataset.id;
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
          "url": ""+id
        });
        urlEvent.fire();
		
	}
})