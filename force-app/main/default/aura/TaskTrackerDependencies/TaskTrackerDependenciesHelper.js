({
    loadTemplateList : function(component, helper) {

        var stepId = component.get("v.recordId");

        var templateStepAction = component.get("c.getTemplateStepInformation");
        templateStepAction.setParams({
            stepId: stepId
        });

        //First, get the template off the step so we know what the default
        //value should be for the template select control
        templateStepAction.setCallback(this, function (response) {
            if(response.getState() == "SUCCESS") {
                var stepInformation = JSON.parse(response.getReturnValue());
                component.set("v.SelectedTemplate", stepInformation.Task_Tracker_Template__c);

                //Now get the list of templates
                var templateListAction = component.get("c.getTemplateList");
                templateListAction.setParams({
                    templateStepId: stepId
                });

                templateListAction.setCallback(this, function (response) {
                    if(response.getState() == "SUCCESS") {
                        var templateList = JSON.parse(response.getReturnValue());
                        component.set("v.Templates", templateList);
                        helper.loadTemplateSteps(component, helper);
                    }
                });
                $A.enqueueAction(templateListAction);
            }
        });
        $A.enqueueAction(templateStepAction);

    },

    loadTemplateSteps: function(component, helper) {
        var stepId = component.get("v.recordId");
        var templateId = component.get("v.SelectedTemplate");
        var templateStepsAction = component.get("c.getTemplateSteps");

        templateStepsAction.setParams({
            templateId: templateId,
            stepId: stepId
        });
        templateStepsAction.setCallback(this, function (response) {
            if(response.getState() == "SUCCESS") {
                var templateSteps = JSON.parse(response.getReturnValue());

                var steps = [];
                var selectedSteps = [];

                for(var i = 0; i < templateSteps.length; i++) {

                    var allStep = {
                        label : templateSteps[i].Label,
                        value : templateSteps[i].Value
                    };

                    if(templateSteps[i].IsDependency) {
                        selectedSteps.push(templateSteps[i].Value);
                    }
                    steps.push(allStep);
                }
                component.set("v.OtherSteps", steps);
                component.set("v.CurrentlyDependsOnSteps", selectedSteps);
            }
        });
        $A.enqueueAction(templateStepsAction);
    },

    handleDependencySelectionChanges: function(component, helper, strValues) {
        var options = [];

        if(strValues != "") {
            var splitValues = strValues != null ? strValues.split(",") : "";

            for(var i = 0; i < splitValues.length; i++) {
                options.push(splitValues[i]);
            }
        }

        component.set("v.CurrentlyDependsOnSteps", options);
    },

    saveChanges: function(component, helper) {

        var stepId = component.get("v.recordId");
        var options = component.get("v.CurrentlyDependsOnSteps");
        var action = component.get("c.updateDependencies");

        action.setParams({
            stepId : stepId,
            options: options
        });

        action.setCallback(this, function (response) {
            if(response.getState() == "SUCCESS") {
                helper.showToast("Dependencies saved.");
                helper.loadDependencies(component, helper);
            }
        });
        $A.enqueueAction(action);
    },

    showToast : function(msg) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Success!",
            "message": msg,
            "type": "success"
        });
        toastEvent.fire();
    }
})