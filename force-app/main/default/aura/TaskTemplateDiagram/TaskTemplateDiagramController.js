({
    doInit : function(component, event, helper) {

        var rowActions = helper.getRowActions.bind(this, component);

        var columns = [
            {
                type: "url",
                fieldName: "Link",
                label: "Name",
                typeAttributes: {
                    label: { fieldName: "Name" }
                },
            },
            {
                type: "number",
                fieldName: "Order",
                label: "Order"
            },
            {
                type: "boolean",
                fieldName: "UseQueue",
                label: "Queue",
            },
            {
                type: "number",
                fieldName: "Tasks",
                label: "Tasks"
            },
            {
                type: "number",
                fieldName: "ChildTasks",
                label: "Child Template Tasks"
            },
            {
                type: "number",
                fieldName: "Hours",
                label: "Hours"
            },
            {
                type: "number",
                fieldName: "AnticipatedCompletitionDays",
                label: "Anticipated Days"
            },
            {
                type: "action",
                typeAttributes: { rowActions: rowActions }
            }
        ];
        component.set("v.columns", columns);
        helper.loadAndShowTemplateNodes(component, helper);
    },


    refreshTree: function(component, event, helper) {
        var eventMsg = event.getParam("message").toUpperCase();
        if(eventMsg && eventMsg.includes("WAS SAVED")){
            helper.loadAndShowTemplateNodes(component, helper);
        }
    },

    handleRowAction: function (component, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');

        switch (action.name) {
            case 'add_event':

                var createRecordEvent = $A.get("e.force:createRecord");
                createRecordEvent.setParams({
                    "entityApiName": "Task_Tracker_Template_Step__c",
                    "defaultFieldValues": {
                        "Task_Tracker_Template__c": row.Id,
                        "Activity_Type__c": "Event",
                    },
                    "panelOnDestroyCallback": function(event) {
                        $A.get('e.force:refreshView').fire();
                        helper.loadAndShowTemplateNodes(component, helper);
                    },
                    "navigationLocation": "LOOKUP",
                });
                createRecordEvent.fire();

            break;

            case 'add_task':

                var createRecordEvent = $A.get("e.force:createRecord");
                createRecordEvent.setParams({
                    "entityApiName": "Task_Tracker_Template_Step__c",
                    "defaultFieldValues": {
                        "Task_Tracker_Template__c": row.Id,
                        "Activity_Type__c": "Task",
                    },
                    "panelOnDestroyCallback": function(event) {
                        $A.get('e.force:refreshView').fire();
                        helper.loadAndShowTemplateNodes(component, helper);
                    },
                    "navigationLocation": "LOOKUP",
                });
                createRecordEvent.fire();

            break;

            case 'add_template':

                var createRecordEvent = $A.get("e.force:createRecord");
                createRecordEvent.setParams({
                    "entityApiName": "Task_Tracker_Template__c",
                    "defaultFieldValues": {
                        "Parent_Template__c": row.Id,
                    },
                    "panelOnDestroyCallback": function(event) {
                        $A.get('e.force:refreshView').fire();
                        helper.loadAndShowTemplateNodes(component, helper);
                    },
                    "navigationLocation": "LOOKUP",
                });
                createRecordEvent.fire();

            break;

            case "add_dependency":
                var createRecordEvent = $A.get("e.force:createRecord");
                createRecordEvent.setParams({
                    "entityApiName": "Task_Tracker_Step_Dependency__c",
                    "defaultFieldValues": {
                        "Task_Tracker_Template__c": row.ParentId,
                        "Step__c": row.Id,
                    },
                    "panelOnDestroyCallback": function(event) {
                        $A.get('e.force:refreshView').fire();
                        helper.loadAndShowTemplateNodes(component, helper);
                    },
                    "navigationLocation": "LOOKUP",
                });
                createRecordEvent.fire();
            break;

            case "edit_task":
            case "edit_template":
                var editRecordEvent = $A.get("e.force:editRecord");
                editRecordEvent.setParams({
                     "recordId": row.Id,
               });
                editRecordEvent.fire();
            break;

            case "delete_template":
                component.set("v.deleteRecordConfirmationRecordType", "template");
                component.set("v.deleteRecordConfirmationRecordId", row.Id);
                helper.showDeleteConfirmationDialog(component, helper);
            break;

            case "delete_task":
                component.set("v.deleteRecordConfirmationRecordType", "task");
                component.set("v.deleteRecordConfirmationRecordId", row.Id);
                helper.showDeleteConfirmationDialog(component, helper);
            break;
        }
    },

    onCancelDeleteRecord: function(component, event, helper) {
        component.set("v.deleteRecordConfirmationRecordType", "");
        component.set("v.deleteRecordConfirmationRecordId", "");
        helper.hideDeleteConfirmationDialog(component, helper);
    },

    onConfirmDeleteRecord: function(component, event, helper) {
        helper.deleteRecord(component, helper);
        helper.hideDeleteConfirmationDialog(component, helper);

        component.set("v.deleteRecordConfirmationRecordType", "");
        component.set("v.deleteRecordConfirmationRecordId", "");
    },
})