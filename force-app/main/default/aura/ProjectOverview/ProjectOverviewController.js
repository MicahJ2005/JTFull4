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
                type: "string",
                fieldName: "Type",
                label: "Type"
            },
            {
                type: "number",
                fieldName: "Hours",
                label: "Hours"
            },
            {
                type: "string",
                fieldName: "OwnerName",
                label: "Owner"
            },
            {
                type: "action",
                typeAttributes: { rowActions: rowActions }
            }
        ];
        component.set("v.columns", columns);

        helper.populateGrid(component);
    },

    refreshTree: function(component, event, helper) {
        var eventMsg = event.getParam("message").toUpperCase();
        if(eventMsg && eventMsg.includes("WAS SAVED")){
            helper.populateGrid(component);
        }
    },

    handleRowAction: function (component, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');

        switch (action.name) {
            case "edit":
                var editRecordEvent = $A.get("e.force:editRecord");
                editRecordEvent.setParams({
                     "recordId": row.Id,
               });
                editRecordEvent.fire();
            break;
        }
    },

})