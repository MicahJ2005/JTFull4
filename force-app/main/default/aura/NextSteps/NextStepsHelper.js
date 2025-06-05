({
    onInit : function(component) {
        let opportunityId = component.get("v.recordId");

        if(!component.get("v.selectedTemplateIds")) {
            return;
        }

        component.set("v.showTemplateSelector", false);

        //Get the Opportunity - need to make sure Has_Next_Step_Template_Created__c = true
        let getOpportunityAction = component.get("c.getOpportunity");
        getOpportunityAction.setParams({
            oppId : opportunityId
        });
        getOpportunityAction.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                let template = JSON.parse(response.getReturnValue());
                if(template || template.length == 0 || template.Has_Next_Step_Template_Created__c) {
                    //Do nothing for now...
                } else {
                    component.set("v.showFlow", false);
                    component.set("v.showTemplateSelector", false);
                }
            } else {
                this.showErrorMessage(response.getError()[0].message);
            }
        });
        $A.enqueueAction(getOpportunityAction);
    },

    loadNextTemplate: function(component) {

        let allSelectedIds = component.get("v.productSelectedIds");
        let tempIds = component.get("v.templatesToFinalize");
        let progress = ((allSelectedIds.length - tempIds.length) / allSelectedIds.length) * 100;

        component.set("v.progress", progress);

        //Get the next template to look at
        if(tempIds && tempIds.length > 0) {

            let getTemplatesAction = component.get("c.getTaskTrackerTemplates");
            getTemplatesAction.setParams({
                templateId : tempIds[0].trim()
            });
            getTemplatesAction.setCallback(this, function (response)
            {
                if(response.getState() == "SUCCESS") {

                    let finalizedTemplates = component.get("v.templatesToFinalize");

                    //First create a map of Id => List of subcomponents so we know what to check
                    let templates = JSON.parse(response.getReturnValue());
                    let mapToChildren = new Object();
                    let templateIds = [];
                    component.set("v.templateName", templates[0].Name);
                    for(let i = 0; i < templates.length; i++) {
                        this.getMapOfChildren(templates[i], templateIds, mapToChildren)
                    }

                    let mapToHours = new Object();
                    //Map each task to the number of hours so we know what to save
                    //for each task as the end.
                    for(let i = 0; i < templates.length; i++) {
                        this.getMapOfHours(templates[i], mapToHours);
                    }

                    component.set("v.mapTaskToHours", mapToHours);
                    component.set("v.mapSubcomponents", mapToChildren);
                    component.set("v.templateItems", templates);
                    component.set("v.showTemplateSelector", true);
                } else {
                    this.showErrorMessage(response.getError()[0].message);
                }
            });
            $A.enqueueAction(getTemplatesAction);
        }
    },

    updateTreeGridHours: function(component) {
        let gridData = component.get("v.templateItems");
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

    //Combines selected items stored in the variable against
    //items selected in the grid
    getAllSelectedItems: function(component) {
        let gridSelectedNodes = component.find("nextStepGrid").getSelectedRows();
        let nodeSubcomponents = component.get("v.mapSubcomponents");

        let currentSelectedNodes = [];

        for(let i = 0; i < gridSelectedNodes.length; i++) {
            currentSelectedNodes.push(gridSelectedNodes[i].Id);
            for(let j = 0; j < nodeSubcomponents[gridSelectedNodes[i].Id].length; j++) {
                currentSelectedNodes.push(nodeSubcomponents[gridSelectedNodes[i].Id][j]);
            }
        }
        component.set("v.currentTemplateSelectedItems", currentSelectedNodes);
    },

    getSelectedChildren: function(node, component) {
        let currentStoredSelectedRowIds = component.get("v.currentTemplateSelectedItems");
        let gridExpandedRowIds = component.find("nextStepGrid").getCurrentExpandedRows();
        let gridSelectedNodes = component.find("nextStepGrid").getSelectedRows();

        let gridSelectedRowIds = [];
        for(let i = 0; i < gridSelectedNodes.length; i++) {
            gridSelectedRowIds.push(gridSelectedNodes[i].Id);
        }

        let isSelectedNode = gridSelectedRowIds.includes(node.Id);
        let isExpandedNode = gridExpandedRowIds.includes(node.Id);
        let isCurrentSelectedNode = currentStoredSelectedRowIds.includes(node.Id);
        let isCaseNode = node.hasOwnProperty('_children') && node._children.length > 0;

        if(isSelectedNode) {
            if(!isCurrentSelectedNode) {
                currentStoredSelectedRowIds.push(node.Id);
            }
        } else {
            if(isCurrentSelectedNode) {
                currentStoredSelectedRowIds = this.removeElementFromArray(currentStoredSelectedRowIds, node.Id);
            }
        }
        component.set("v.currentTemplateSelectedItems", currentStoredSelectedRowIds);

        if(isCaseNode) {
            for(let i = 0; i < node._children.length; i++) {
                if(!currentStoredSelectedRowIds.includes(node._children[i].Id)) {
                    currentStoredSelectedRowIds.push(node._children[i].Id);
                }
            }
            for(let i = 0; i < node._children.length; i++) {
                this.getSelectedChildren(node._children[i], component);
            }
        }
    },

    //Modified by CGREvGroup (Revolution Group) on 12/29/2021: Changed function name from makeTemplate to makeOppAndTemplate
    makeOppAndTemplate: function(component) {
        if(!component.get("v.templatesToFinalize")) {
            return;
        }

        //Output current Opportunity Id
        let opportunityId = component.get("v.opportunityId");

        if(opportunityId === ''){

        console.log('Creating Next Step Opportunity with the following values...');
        //Added by CGREvGroup (Revolution Group) on 12/29/2021: Create Next Step Opportunity Opportunity to Retrieve its record Id
        //Store apex action
        let createNextStepOppAction =  component.get("c.createNextStepOpportunity");

        //Retrieve stored Next Stop Object
        let newNextStepOpp = component.get("v.nextStepOpp");

        newNextStepOpp = JSON.stringify(newNextStepOpp, null, '\t');

        //Output newNextStep Record
        console.log(newNextStepOpp);

        //Set its parameters
        createNextStepOppAction.setParams({

            //Set oppObj apex method parameter to the stringified version of the stored nextStepOpp obj
            oppObj: newNextStepOpp

        });

        //Set Callback function for what to do when a response is received
        createNextStepOppAction.setCallback(this,function(response){

            //Evaluate the state of the response
            //If a SUCCESS state was received,
            if(response.getState() === 'SUCCESS'){

                //Output response received for reference
                console.log('Next Step Opp Id Received: '+response.getReturnValue());

                //Store Opp Id received
                component.set("v.opportunityId", response.getReturnValue());

                //Make templates
                this.makeTemplate(component);

            }

            else {

                console.log('The following errors occurred: '+JSON.stringify(response.getError(), null, '\t'));
                console.log('The following response state was received: '+response.getState());

            }

        });

        //Queue Action for Execution
        $A.enqueueAction(createNextStepOppAction);

        }

        //If oppId exists, just make the templates
        else{

            this.makeTemplate(component);

        }

    },

    //Added By Christan Gordon (Revolution Group) on 12/30/2021: Used to create task tracker itemss
    makeTemplate : function(component){

        let finalizedTemplates = component.get("v.templatesToFinalize");
        let templateId = finalizedTemplates[0].trim();

            component.set("v.templatesToFinalize", finalizedTemplates.slice(1));
            component.set("v.isLoading", true);

            //Retrieve new Opp Id value
            let oppId = component.get("v.opportunityId");

            //Get the Opportunity - need to make sure Has_Next_Step_Template_Created__c = true
            let createTemplateAction = component.get("c.createTaskTrackerForNextSteps");
            createTemplateAction.setParams({
                matterId: component.get("v.recordId"),
                oppId : oppId,
                templateId: templateId,
                strMap: JSON.stringify(component.get('v.mapTaskToHours')),
                selectedTaskIds: component.get("v.templateSelectedItems")
            });

            createTemplateAction.setCallback(this, function (response)
		    {
                if(response.getState() == "SUCCESS") {
                    //pop off the template that was just created.
                    let finalTemplates = component.get("v.templatesToFinalize");
                    if(finalTemplates.length > 0) {
                        this.loadNextTemplate(component);
                        component.find("btnFinalize").set('v.disabled', false);
                    } else {
                        this.showToast('Next Step Cases Created.', 'success');
                        $A.get("e.force:closeQuickAction").fire();
                }

                } else {
                    this.showErrorMessage(response.getError()[0].message);
                }
            component.set("v.isLoading", false);
            });
        
        $A.enqueueAction(createTemplateAction);

    },

    getArrayDifference: function(ary1, ary2) {
        for(let i = 0; i < ary1.length; i++) {
            if(!ary2.includes(ary1[i])) {
                return ary1[i];
            }
        }
        return null;
    },

    removeElementFromArray: function(arr, ele) {
        let filteredAry = arr.filter(function(e) {
            return e != ele
        });
        return filteredAry;
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