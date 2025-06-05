({
	loadSummary: function (component, helper)
	{
        var caseId = component.get("v.recordId");
		var action = component.get("c.getChildTasksSummary");
        action.setParams({
            caseId : caseId
        });

        action.setCallback(this, function (response)
		{
            if(response.getState() == "SUCCESS")
			{
                var caseSummaries = JSON.parse(response.getReturnValue());
				var totalTasks = 0;
				var completeTasks = 0;
				for(var i = 0; i < caseSummaries.length; i++) {
					totalTasks += caseSummaries[i].TotalTasks;
					completeTasks += caseSummaries[i].CompleteTasks;
                    var pct = (100 * (caseSummaries[i].CompleteTasks / caseSummaries[i].TotalTasks)).toFixed(2);
                    if(isNaN(pct)) {
                        pct = 100;
                    }
                    var childPct = (100 * (caseSummaries[i].ChildTasksCompleted / caseSummaries[i].ChildTasks)).toFixed(2);
                    if(isNaN(childPct)) {
                        childPct = 100;
                    }
                    var compositeTotalTasks = caseSummaries[i].TotalTasks + caseSummaries[i].ChildTasks;
                    var compositeCompletedTasks = caseSummaries[i].CompleteTasks + caseSummaries[i].ChildTasksCompleted;
                    var compositePct = (100 * (compositeCompletedTasks / compositeTotalTasks)).toFixed(2);
					caseSummaries[i].Label = caseSummaries[i].CaseName + ' (' + pct  + '%)';
                    caseSummaries[i].Value = pct;
                    caseSummaries[i].Display = "(" + caseSummaries[i].CompleteTasks + " / " + caseSummaries[i].TotalTasks + ")";
                    caseSummaries[i].IsCurrentCase = caseId == caseSummaries[i].CaseId;
                    caseSummaries[i].Indent = 11 - (11 - caseSummaries[i].Level);
                    caseSummaries[i].ChildLabel = "(" + caseSummaries[i].ChildTasksCompleted + " / " + caseSummaries[i].ChildTasks + ")";
                    caseSummaries[i].ChildValue = childPct;
                    caseSummaries[i].CompositePct = compositePct;
                    caseSummaries[i].CompositeLabel = caseSummaries[i].CaseName + ' (' + compositeCompletedTasks + " / " + compositeTotalTasks  + ')';
				}
				component.set("v.CaseSummaryList", caseSummaries);
				component.set("v.OverallPercentComplete", 100 * (completeTasks / totalTasks));
				component.set("v.OverallTitle", (100 * (completeTasks / totalTasks)).toFixed(2) + "%");
            }
            else
			{
                helper.showErrorMessageAry(helper, response.getError());
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
})