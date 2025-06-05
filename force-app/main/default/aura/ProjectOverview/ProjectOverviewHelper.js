({
    populateGrid : function(component) {
        component.set("v.isLoading", true);
        var projectId = component.get("v.recordId");
		var action = component.get("c.getProjectCasesAndTasks");
        action.setParams({
            projectId : projectId
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS") {
                var masterCases = JSON.parse(response.getReturnValue());
                this.setupGrid(component, masterCases);
            } else {
                this.showErrorMessageAry(helper, rObj.Messages);
            }
            component.set("v.isLoading", false);
        });
        $A.enqueueAction(action);
    },

    setupGrid: function(component, masterCases) {
        var data = [];
        for(let i = 0; i < masterCases.length; i++) {
            data.push(
                this.getGridRows(component, masterCases[i])
            );
        }

        component.set("v.gridData", data);
    },

    getGridRows: function(component, cse) {
        var rowData = {
            Name: cse.Name,
            Tasks: cse.NumberOfChildSteps,
            Id: cse.Id,
            ParentId: cse.ParentId,
            Type: cse.Type,
            Link: "/" + cse.Id,
            OwnerName: cse.OwnerName,
            Hours: cse.Hours,
            _children: [],
        };

        for(var i = 0; i < cse.Children.length; i++) {
            var t = cse.Children[i];
            rowData._children.push(
                this.getGridRows(component, t))
        }

        return rowData;
    },

    getRowActions: function (component, row, doneCallback) {
        var actions = [];
        actions.push({
            "label": "Edit",
            "iconName": "utility:edit",
            "name": "edit",
        });
        doneCallback(actions);
    },

})