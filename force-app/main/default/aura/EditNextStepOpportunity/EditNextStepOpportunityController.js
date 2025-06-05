({
    onInit : function(component, event, helper) {
        let rowActions = helper.getRowActions.bind(this, component);

        var columns = [
            {
                type: 'text',
                fieldName: 'Name',
                label: 'Name',
                initialWidth: 500
            },
            {
                type: 'text',
                fieldName: 'Type',
                label: 'Type'
            },
            {
                type: "numeric",
                fieldName: "Hours",
                label: "Hours"
            },
            {
                type: "action",
                typeAttributes: { rowActions: rowActions }
            }
        ];

        component.set('v.caseColumns', columns);
        helper.onInit(component);
    },

    handleRowAction: function (component, event, helper) {
        let action = event.getParam('action');
        let row = event.getParam('row');

        switch (action.name) {
            case "edit":
                component.set("v.showEditHourDialog", true);
                component.set("v.editHoursNewHours", row.Hours);
                component.set("v.editHoursRowId", row.Id);
                component.set("v.editHoursType", row.Type);
            break;
        }
    },

    onSaveHours: function(component, event, helper) {
        component.set("v.showSpinner", true);

        helper.saveActivityHours(component);

        return;


        let mapTaskToHours = component.get("v.mapTaskToHours");
        let rowId = component.get("v.editHoursRowId");
        let rowHours = component.get("v.editHoursNewHours");
        mapTaskToHours[rowId] = rowHours;
        component.set("v.mapTaskToHours", mapTaskToHours);
        component.set("v.showEditHourDialog", false);

        helper.updateTreeGridHours(component);

    },

    onCancelHours: function(component, event, helper) {
        component.set("v.showEditHourDialog", false);
    },

    //By default, when a tree grid is collapsed,
    //it delelects all children.  This will persist the
    //changes.
    onToggleGrid: function(component, event, helper) {
        helper.refreshTreeGrid(component);
        if(!event.getParam("isExpanded")) {
            component.set("v.treeGridEvent", "Collapsed");
        }
    }

})