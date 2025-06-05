({
    loadAndShowTemplateNodes : function(component, helper) {
        component.set("v.isLoading", true);
        var templateId = component.get("v.recordId");
		var action = component.get("c.getTemplateNodes");
        action.setParams({
            templateId : templateId
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                var templates = JSON.parse(response.getReturnValue());
                var tree = helper.setupGrid(component, helper, templates);
            } else {
                helper.showErrorMessageAry(helper, rObj.Messages);
            }
            component.set("v.isLoading", false);
        });
        $A.enqueueAction(action);
    },

    setupGrid: function(component, helper, templates) {
        var data = [];
        for(var i = 0; i < templates.length; i++) {
            data.push(
                helper.getTemplateRows(component, helper, templates[i])
            );
        }
        component.set("v.gridData", data);
    },

    getTemplateRows: function(component, helper, template) {
        var templateData = {
            Name: template.Name,
            Tasks: template.NumberOfChildSteps,
            ChildTasks: template.NumberOfChildTemplateSteps,
            Id: template.Id,
            ParentId: template.ParentId,
            Type: "Template",
            Link: "/" + template.Id,
            _children: [],
        };

        for(var i = 0; i < template.ChildTemplateList.length; i++) {
            var t = template.ChildTemplateList[i];
            templateData._children.push(
                helper.getTemplateRows(component, helper, t))
        }

        for(var i = 0; i < template.ChildStepList.length; i++) {
            var task = template.ChildStepList[i];
            templateData._children.push({
                Name: task.Name,
                Tasks: null,
                ChildTasks: null,
                Hours: task.Hours,
                Id: task.Id,
                Type: "Task",
                Link: "/" + task.Id,
                ParentId: template.Id,
                Order: task.Order,
                AnticipatedCompletitionDays: task.AnticipatedCompletitionDays,
                UseQueue: task.UseQueue,
            });
        }
        return templateData;
    },

    getRowActions: function (component, row, doneCallback) {
        var actions = [];

        if(row.Type == "Template") {
            actions.push({
                "label": "Add Task",
                "iconName": "utility:task",
                "name": "add_task",
            });
            actions.push({
                "label": "Add Event",
                "iconName": "utility:event",
                "name": "add_event",
            });
            actions.push({
                "label": "Add Template",
                "iconName": "utility:text_template",
                "name": "add_template",
            });
            actions.push({
                "label": "Edit Template",
                "iconName": "utility:text_template",
                "name": "edit_template",
            });
            actions.push({
                "label": "Delete Template",
                "iconName": "utility:delete",
                "name": "delete_template",
            });
        } else {
            actions.push({
                "label": "Add Dependency",
                "iconName": "utility:zoom",
                "name": "add_dependency",
            });
            actions.push({
                "label": "Edit Task",
                "iconName": "utility:delete",
                "name": "edit_task",
            });
            actions.push({
                "label": "Delete Task",
                "iconName": "utility:delete",
                "name": "delete_task",
            });
        }

        doneCallback(actions);
    },

    deleteRecord: function(component, helper) {
        var deleteRecordType = component.get("v.deleteRecordConfirmationRecordType");
        var deleteRecordId = component.get("v.deleteRecordConfirmationRecordId");

        var action;

        if(deleteRecordType == "template") {
            action = component.get("c.deleteTemplateRecord");
        } else {
            action = component.get("c.deleteTaskRecord");
        }

        action.setParams({
            recordId : deleteRecordId
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                helper.showSuccessMessage(helper, "Deleted");
                helper.loadAndShowTemplateNodes(component, helper);
            } else {
                showErrorMessage(helper, "An error occurred");
            }
        });
        $A.enqueueAction(action);

    },

    //Toast message functions
    showSuccessMessage : function(helper, msg) {
        helper.showToast(helper, msg, "success");
    },

    showErrorArray : function(helper, msgAry) {
    	var msg = msgAry.join("\n");
        helper.showErrorMessage(helper, msg);
    },

    showErrorMessage : function(helper, msg) {
        helper.showToast(helper, msg, "error");
    },

    showToast : function(msg) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Success!",
            "message": msg,
            "type": "success"
        });
        toastEvent.fire();
    },

    showDeleteConfirmationDialog: function(component, helper) {
        util.showModalDialog(component, "backdrop", "slds-backdrop--");
        util.showModalDialog(component, "deleteRecordConfirmationDialog", "slds-fade-in-");
    },

    hideDeleteConfirmationDialog: function(component, helper) {
        util.hideModalDialog(component, "backdrop", "slds-backdrop--");
        util.hideModalDialog(component, "deleteRecordConfirmationDialog", "slds-fade-in-");
    },

})