({
    loadCases: function(component, helper) {
        var recordId = component.get("v.recordId");
        var recordLinkedField = component.get("v.CaseLinkedField");
        console.log('recordLinkedField: ' + recordLinkedField);
		var action = component.get("c.getCaseSummaries");
        action.setParams({
            objectId : recordId,
            caseLinkedField: recordLinkedField
        });

        action.setCallback(this, function (response)
		{
            console.log('response.getState(): ' + response.getState());
            if(response.getState() == "SUCCESS")
			{
                console.log('response.getReturnValue(): ' + response.getReturnValue());
                var objectCaseSummaries = JSON.parse(response.getReturnValue());
                console.log('objectCaseSummaries: ' + objectCaseSummaries);
                
                for(var x = 0; x < objectCaseSummaries.length; x++) {

                    var totalTasks = 0;
                    var completeTasks = 0;
                    var caseSummaries = objectCaseSummaries[x].Summaries;

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
                        var compositePct = compositeTotalTasks > 0 ? (100 * (compositeCompletedTasks / compositeTotalTasks)).toFixed(2) : 100;

                        caseSummaries[i].Label = caseSummaries[i].CaseName + ' (' + pct  + '%)';
                        caseSummaries[i].Value = pct;
                        caseSummaries[i].Display = "(" + caseSummaries[i].CompleteTasks + " / " + caseSummaries[i].TotalTasks + ")";
                        caseSummaries[i].IsCurrentCase = false;
                        caseSummaries[i].Indent = 11 - (11 - caseSummaries[i].Level);
                        caseSummaries[i].ChildLabel = "(" + caseSummaries[i].ChildTasksCompleted + " / " + caseSummaries[i].ChildTasks + ")";
                        caseSummaries[i].ChildValue = childPct;
                        caseSummaries[i].CompositePct = compositePct;
                        caseSummaries[i].CompositeLabel = caseSummaries[i].CaseName + ' (' + compositeCompletedTasks + " / " + compositeTotalTasks  + ')';
                    }
                    objectCaseSummaries[x].OverallPercentComplete = (100 * (completeTasks / totalTasks)).toFixed(2);
                    objectCaseSummaries[x].Label = objectCaseSummaries[x].ParentCaseName + ' (' + objectCaseSummaries[x].OverallPercentComplete  + '%)';
                }
                component.set("v.CaseListOfSummaries", objectCaseSummaries);
            }
            else
			{
                helper.showErrorMessage(helper, response.getError()[0].message);
            }
        });
        $A.enqueueAction(action);
    }

})