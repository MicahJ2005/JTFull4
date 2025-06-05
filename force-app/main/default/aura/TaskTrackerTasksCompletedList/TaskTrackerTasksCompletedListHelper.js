({
	loadTaskList : function(component) {
        var caseId = component.get("v.recordId");
		var action = component.get("c.getTaskList");
        action.setParams({
            caseId : caseId
        });

        action.setCallback(this, function (response) {
            if(response.getState() == "SUCCESS") {
                var rObj = JSON.parse(response.getReturnValue());
                if(rObj.IsSuccessful) {
                    var taskItems = rObj.TaskItems;
                    var selectItems = this.getSelectedItemsFromTaskList(component, taskItems);
                    var optionItems = this.getOptionItemsFromTaskList(component, taskItems);

                    component.set("v.TaskList", optionItems);
                    component.set("v.CompletedTasks", selectItems);

                    this.showEventList(component);
                }
                else {
                    this.showErrorMessageAry(rObj.Messages);
                }
            }
            component.set("v.IsLoading", false);
        });
        $A.enqueueAction(action);
    },

    showEventList: function(component) {

        var caseId = component.get("v.recordId");
        var eventAction = component.get("c.getEventList");
        eventAction.setParams({
            caseId: caseId
        });

        eventAction.setCallback(this, function(response){
            component.set("v.IsLoading", false);
            if(response.getState() == "SUCCESS") {
                var eventList = JSON.parse(response.getReturnValue());
                component.set("v.EventList", eventList);
            }
            else {
                this.showErrorMessageAry(rObj.Messages);
            }
        });
        $A.enqueueAction(eventAction);

    },

    showScreenPop: function(component) {

        $A.util.removeClass(component.find("eventScreenPop"), "slds-hide");

        var caseId = component.get("v.recordId");
        var taskName = component.get("v.SelectedTaskName");

        var taskAction = component.get("c.getTaskInformation");
        taskAction.setParams({
            caseId: caseId,
            taskName: taskName
        });

        taskAction.setCallback(this, function (response) {
            if(response.getState() == "SUCCESS") {
                var task = JSON.parse(response.getReturnValue());
                var inputVariables = [
                    {
                        name : 'inputCaseId',
                        type : 'String',
                        value : caseId
                    },
                    {
                        name : 'inputTemplateStepId',
                        type : 'String',
                        value : task.Task_Tracker_Template_Step__c
                    }
                    ];
                var flow = component.find("eventScreenPop");
                flow.startFlow("Screen_Pop_Task_Compete_Schedule_Events", inputVariables);

            }
            else {
                this.showErrorMessageAry(rObj.Messages);
            }

        });
        $A.enqueueAction(taskAction);
    },

    saveTaskList : function(component) {

        try {
            var action = component.get("c.updateTaskList");
            var caseId = component.get("v.recordId");
            var optionList = component.get("v.TaskList");
            var selectedList = component.get("v.CompletedTasks");
            var taskList = this.getTaskListFromOptionItems(component, selectedList, optionList);
            var jsonTaskList = JSON.stringify(taskList);
            action.setParams({
                'caseId' : caseId,
                'jsonTaskList' : jsonTaskList
            });

            action.setCallback(this, function (response) {
                if(response.getState() == "SUCCESS") {
                    var responseStr = response.getReturnValue();
                    if(typeof(responseStr) == 'undefined') {
                        this.showErrorMessage("Response was undefined - error occurred.");
                    }
                    else {
                        var rObj = JSON.parse(responseStr);
                        if(rObj.IsSuccessful) {
                            var taskItems = rObj.TaskItems;
                            var selectItems = this.getSelectedItemsFromTaskList(component, taskItems);
                            var optionItems = this.getOptionItemsFromTaskList(component, taskItems);

                            component.set("v.TaskList", optionItems);
                            component.set("v.CompletedTasks", selectItems);
                            this.showSuccessMessage('Case tasks updated.');

                            $A.get('e.force:refreshView').fire();
                        } else {
                            this.showErrorArray(rObj.Messages);
                        }
                    }
                    $A.get("e.force:refreshView").fire();
                } else {
                    this.showErrorArrayFromResponse(response);
                    this.loadTaskList(component);
                }
                component.set("v.IsLoading", false);
            });
            $A.enqueueAction(action);
        } catch (e) {
            this.showErrorMessage('Error occurred.');
        }
    },

    getSelectedItemsFromTaskList : function(component, taskItems) {
        var selectedItems = [];
        for(var i in taskItems) {
            var item = taskItems[i];
            if(item.IsComplete == true) {
            	selectedItems.push(item.Name);
            }
        }
        return selectedItems;
	},

    getOptionItemsFromTaskList : function(component, taskItems) {
        var optionItems = [];
        for(var i in taskItems) {
            var item = taskItems[i];
            optionItems.push({
                "label" : item.Name + ' (' + item.OwnerName + ')',
                "value" : item.Name
            });
        }
        return optionItems;
	},

    getTaskListFromOptionItems : function(component, selectedItems, optionItems) {
        var taskList = [];
        for(var i in optionItems) {
            var item = optionItems[i];
            taskList.push({
                "Name" : item.value,
                "IsComplete" : this.isItemInSelectedList(item, selectedItems)
            });
        }
        return taskList;
    },

    isItemInSelectedList : function(item, selectedItems) {
        for(var i in selectedItems) {
            var currentSelected = selectedItems[i];
            if(item.value == currentSelected) {
                return true;
            }
        }
        return false;
    },

    toggleLoading : function(component, isLoading) {
    	component.set("v.IsLoading", isLoading);
    },

    //Toast message functions
    showSuccessMessage : function(msg) {
        this.showToast(msg, "success");
    },

    showErrorArray : function(msgAry) {
    	var msg = msgAry.join("\n");
        this.showErrorMessage(msgAry);
    },

    showErrorArrayFromResponse: function(response) {
        var errors = response.getError();
        var msgs = [];
        for(var x = 0; x < errors.length; x++) {
            if(errors[x].fieldErrors.length > 0) {
                msgs.push(errors[x].field[0].message);
            }
            if(errors[x].pageErrors.length > 0) {
                msgs.push(errors[x].pageErrors[0].message);
            }
        }
        this.showErrorMessage(msgs.join());
    },

    showErrorMessage : function(msg) {
        this.showToast(msg, "error");
    },

    showToast: function(msg, msgType) {
        var toastEvent	= $A.get("e.force:showToast");
        var toastMode	= (msgType == "success" ? "dismissible" : "sticky");
        var toastTitle	= (msgType == "success" ? "Success" : "Error");
        var toastIcon	= (msgType == "success" ? "check" : "error");
        toastEvent.setParams({
            "title"		:toastTitle,
            "message"	: msg,
            "mode"		: toastMode,
            "type"      : msgType,
            "key"		: toastIcon
        });
        toastEvent.fire();
    }
})