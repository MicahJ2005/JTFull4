({
    doInit : function(component, event, helper) {
        component.set("v.IsLoading", true);
		helper.loadTaskList(component);
        component.set("v.IsLoading", false);
	},

    saveTaskList : function(component, event, helper) {
        component.set("v.IsLoading", true);
		helper.saveTaskList(component);
        component.set("v.IsLoading", false);
    },

    toggleTaskListItem : function(component, event, helper) {

        component.set("v.IsLoading", true);

        var selectedList = component.get("v.CompletedTasks");
        var changeValue = event.getParam("value");
        component.set("v.SelectedTaskName", changeValue[0]);

        //Make sure this item was checked (not unchecked)
        //before trying to run show the screen pop
        if(selectedList.includes(changeValue[0])) {
            helper.showScreenPop(component);
        }

        helper.saveTaskList(component);
        //component.set("v.IsLoading", false);
    },

    changeFlowStatus: function(component, event, helper) {
        if (event.getParam("status") == "FINISHED" || event.getParam("status") == "FINISHED_SCREEN") {
            $A.util.addClass(component.find("eventScreenPop"), "slds-hide");
        }
    }
})