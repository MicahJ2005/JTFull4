({
    doInit : function(component, event, helper) {
        helper.onLoad(component);
    },

    closeTask: function(component, event, helper) {
 		helper.markTaskComplete(component);
    }
})