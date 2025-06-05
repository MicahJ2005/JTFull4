({
    onInit : function(component, event, helper) {
        let rowActions = helper.getRowActions.bind(this, component);

        var columns = [
            {
                type: 'text',
                fieldName: 'Name',
                label: 'Name'
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

        component.set('v.templateColumns', columns);

        let flow = component.find("templateFlow");
        let flowParams = [
            { name: 'MatterId', type: 'String', value: component.get('v.recordId') }
        ]
        flow.startFlow("Next_Step", flowParams);

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
            break;
        }
    },

    onSaveHours: function(component, event, helper) {
        let mapTaskToHours = component.get("v.mapTaskToHours");
        let rowId = component.get("v.editHoursRowId");
        let rowHours = component.get("v.editHoursNewHours");
        mapTaskToHours[rowId] = rowHours;
        component.set("v.mapTaskToHours", mapTaskToHours);
        component.set("v.showEditHourDialog", false);

        helper.saveActivityHours(component);
        helper.updateTreeGridHours(component);

    },

    onCancelHours: function(component, event, helper) {
        component.set("v.showEditHourDialog", false);
    },

    flowStatusChanged: function(component, event, helper) {
        //If the flow is done, assign the template id to the lightning attribute
        if (event.getParam('status') == "FINISHED") {

            //Christan Gordon (Revolution Group) on 12/29/2021: Output all flow output variables within console for reference
            let flowOutputVariables = event.getParam("outputVariables");

            console.log('Flow Output Variables: '+JSON.stringify(flowOutputVariables, null,'\t'));

            //CGRevGroup (12/29/2021): Store the next step opportunity record instance received
            let nextStepOppObj = flowOutputVariables[0].value;

            component.set("v.nextStepOpp",nextStepOppObj);
            
            //Added by CGRevGroup (12/29/2021): Showcase Next Step Opportunity record in console for reference
            console.log('Next Step Opp: '+JSON.stringify(nextStepOppObj));

            //Modified by CGRevGroup (12/29/2021): Commented out code line below since the opportunity record is no longer created in the screen flow.
            //let oppId = event.getParam("outputVariables")[1].value;
            let tempId = event.getParam("outputVariables")[2].value;

            //Showcase template ID in console
            console.log('Template Id Received: '+tempId);

            let allSelectedIds = tempId.split(";");
            component.set("v.productSelectedIds", allSelectedIds);

            //Modified by CGRevGroup (12/29/2021): Commented out code line below since the opportunity record is no longer created in the screen flow.
            //component.set("v.opportunityId", oppId);

            if(tempId) {
                
                console.log('Evaluating Template Ids....');
                component.set("v.templatesToFinalize", tempId.split(";"));
                helper.loadNextTemplate(component);
                component.set("v.showFlow", false);
                component.set("v.showTemplateSelector", true);
            }
        }
    },

    //Modified by CGREvGroup (Revolution Group) on 12/29/2021: Changed function name from clickCreateTemplate to clickCreateOppAndTemplate
    clickCreateOppAndTemplate: function(component, event, helper) {
        //Avoids clicking the button multiple times.
        component.find("btnFinalize").set('v.disabled',true);

         //Modified by CGREvGroup (Revolution Group) on 12/29/2021: Changed function name from makeTemplate to makeOppAndTemplate
        helper.makeOppAndTemplate(component);
    },

    onRowSelected: function(component, event, helper) {
        //Have to use the last event since collapsing the grid
        //calls both functions since collapsed, selected items
        //get unselected
        let lastEvent = component.get("v.treeGridEvent");
        if(lastEvent != "Collapsed") {
            helper.updateTreeGrid(component);
        }
        helper.refreshTreeGrid(component);
        component.set("v.treeGridEvent", "Select");
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