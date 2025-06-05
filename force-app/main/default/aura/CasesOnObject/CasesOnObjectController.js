({
	doInit: function(component, event, helper) {
		helper.loadCases(component, helper);
	},

	redirectToRecord: function(component, event, helper) {
		var recordId = event.getSource().get("v.name");
		var navEvt = $A.get("e.force:navigateToSObject");
		navEvt.setParams({
		  "recordId": recordId,
		  "slideDevName": "Detail"
		});
		navEvt.fire();
	},

})