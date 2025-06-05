({

    onLoad: function(component) {
        let recordId = component.get("v.recordId");
		let action = component.get("c.getTaskStatus");
        action.setParams({
            taskId: recordId
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                let objectInfo = JSON.parse(response.getReturnValue());
                component.set("v.objectTypeName", objectInfo.ObjectTypeName);
                if(objectInfo.ObjectTypeName == 'Task') {
                    component.set("v.taskStatus", objectInfo.Status);
                    component.set("v.showButton", objectInfo.Status != 'Completed');
                } else {
                    component.set("v.showButton", false);
                }

            } else {
                this.showToast('Error Marking Task Complete: ' + response.getError(), 'error');
            }
        });
        $A.enqueueAction(action);
    },

    markTaskComplete : function(component) {
        let recordId = component.get("v.recordId");
		let action = component.get("c.markTaskComplete");
        action.setParams({
            taskId: recordId
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                this.showToast('Task Marked Complete!', 'success');
                $A.get("e.force:refreshView").fire();
            } else {
                this.showToast('Error Marking Task Complete!', 'error');
            }
        });
        $A.enqueueAction(action);
    },

    showToast : function(msg, msgType) {
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Success!",
            "message": msg,
            "type": msgType
        });
        toastEvent.fire();
    },
})