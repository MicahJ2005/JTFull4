({
    doInit : function(component, event, helper) {
        helper.loadTemplateList(component, helper);
    },

    handleTemplateSelectionChange: function(component, event, helper) {
        helper.loadTemplateSteps(component, helper);
    },

    handleDependencyChange: function(component, event, helper) {
        var selectedValues = event.getParam("value").toString();
        helper.handleDependencySelectionChanges(component, event, selectedValues);
        helper.saveChanges(component, helper);
    },

    saveDependencies: function(component, event, helper) {
        helper.saveChanges(component, helper);
    },
})