({
   onInit : function(component) {

        let opportunityId = component.get("v.recordId");

        //Get the Opportunity - need to make sure Has_Next_Step_Template_Created__c = true
        let getOpportunityAction = component.get("c.getOpportunityCases");
        getOpportunityAction.setParams({
            oppId : opportunityId
        });

        getOpportunityAction.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                let cases = JSON.parse(response.getReturnValue());
                component.set("v.caseData", cases);
            } else {
                this.showErrorMessage(response.getError()[0].message);
            }
        });
        $A.enqueueAction(getOpportunityAction);
    },

    updateTreeGridHours: function(component) {
        let gridData = component.get("v.caseData");
        let mapTasksToHours = component.get("v.mapTaskToHours");
        for(let i = 0; i < gridData.length; i++) {
            this.updateChildren(component, mapTasksToHours, gridData[i]);
        }
    },

    updateChildren: function(component, mapTasksToHours, template) {
        if(mapTasksToHours[template.Id]) {
            template.Hours = mapTasksToHours[template.Id];
        }
        for(let i = 0; i < template._children.length; i++) {
            this.updateChildren(component, mapTasksToHours, template._children[i]);
        }
    },

    //String activityId, String type, Decimal hours
    saveActivityHours: function(component) {
        let activityId = component.get("v.editHoursRowId");
        let newHours = component.get("v.editHoursNewHours");
        let activityType = component.get("v.editHoursType");

        let action = component.get("c.saveActivityHours");

        action.setParams({
            activityId : activityId,
            type : activityType,
            hours : newHours
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                this.showSuccessMessage("Task hours updated.");
                this.onInit(component);
            } else {
                this.showErrorMessage(response.getError()[0].message);
            }
            component.set("v.showEditHourDialog", false);
            component.set("v.showSpinner", false);

        });
        $A.enqueueAction(action);
    },

    getRowActions: function (component, row, doneCallback) {
        var actions = [];

        if(row.Type != "Case") {
            actions.push({
                "label": "Modify Hours",
                "iconName": "utility:edit",
                "name": "edit",
            });
        }

        doneCallback(actions);
    },

    getMapOfHours: function(template, mapToHours) {
        if(template.Type != "Case") {
            mapToHours[template.Id] = template.Hours;
        }

        for(let i = 0; i < template._children.length; i++) {
            this.getMapOfHours(template._children[i], mapToHours);
        }
    },

        //Creates a map to list of children for
    //the tree grid to know if a parent checkbox
    //is clicked.
    getMapOfChildren: function(template, templateIds, mapToChildren) {
        templateIds.push(template.Id);
        mapToChildren[template.Id] = [];

        for(let i = 0; i < template._children.length; i++) {
            for(let j = 0; j < templateIds.length; j++) {
                mapToChildren[templateIds[j]].push(template._children[i].Id);
            }

            //Get all of the children templates
            this.getMapOfChildren(template._children[i], templateIds, mapToChildren);
        }
        templateIds.pop();
    },

    updateTreeGrid: function(component) {
        this.getAllSelectedItems(component);
    },

    refreshTreeGrid: function(component) {
        component.set("v.templateSelectedItems", component.get("v.currentTemplateSelectedItems"));
    },

    //Message Helpers

    showSuccessMessage: function(msg) {
        this.showToast(msg, "success");
    },

    showErrorMessage : function(msg) {
        this.showToast(msg, "error");
    },

    showToast : function(msg, msgType) {
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": msgType == 'error' ? 'Error!' : "Success!",
            "message": msg,
            "type": msgType
        });
        toastEvent.fire();
    },

})