/**
 * @File Name          : MasterTaskSummaryController.cls
 * @Description        : Shows the master case progress and
 *                          child cases under it
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 07-21-2021
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/28/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public class MasterTaskSummaryController {

	@AuraEnabled
	public static String getChildTasksSummary(String caseId)
	{

		List<Case> currentCase =
			[
				SELECT Top_Level_Task_Tracker_Case__c
				FROM Case
				WHERE Id = :caseId
			];

		List<Case> cases = new List<Case>();
		if(!currentCase.isEmpty()) {
			cases =
			[
				SELECT Id, Subject, Tasks_Completed__c, Tasks_To_Complete__c, ParentId,
					(
						SELECT Id, Subject, Tasks_Completed__c, Tasks_To_Complete__c, ParentId
						FROM Cases
						ORDER BY Order__c, Subject
					),
					(
						SELECT Id, Status
						FROM Tasks
						ORDER BY Order__c, Subject
					),
					(
						SELECT Id, Is_Completed__c
						FROM Events
						ORDER BY Order__c, Subject
					)
				FROM Case
				WHERE Top_Level_Task_Tracker_Case__c = :currentCase[0].Top_Level_Task_Tracker_Case__c
				ORDER BY Order__c, Subject
			];
		}

		Case topLevelCase = null;
		for(Case c : cases) {
			if(c.ParentId == null) {
				topLevelCase = c;
				break;
			}
		}

		Map<Id, Summary> caseSummaries = getParentAndChildSummaries(cases, topLevelCase, 0);

		return JSON.serialize(caseSummaries.values());
	}

	private static Map<Id, Summary> getParentAndChildSummaries(List<Case> allCases, Case parentCase, Integer level) {

		Map<Id, Summary> summaries = new Map<Id, Summary>();

		//We only want to get information on child cases,
		//but we'll need to iterate over all cases to ensure
		for(Case c : allCases) {
			if(c.Id == parentCase.Id) {
				Summary s = getSummaryFromCase(c, level);
				summaries.put(c.Id, s);

				for(Case childCase : c.Cases) {
					Map<Id, Summary> childSummaries = getParentAndChildSummaries(allCases, childCase, level+1);
					for(Summary childSummary : childSummaries.values()) {
						s.ChildTasks += childSummary.TotalTasks;
						s.ChildTasksCompleted += childSummary.CompleteTasks;
					}

					summaries.putAll(childSummaries);
				}
			}
		}
		return summaries;
	}

	private static Summary getSummaryFromCase(Case c, Integer level) {
    	List<TaskStatus> closedStatus = [SELECT MasterLabel, IsClosed FROM TaskStatus WHERE IsClosed = true];
                
        Map<String, TaskStatus> mapStatus = new Map<String, TaskStatus>();
        for(TaskStatus ts : closedStatus) {
            mapStatus.put(ts.MasterLabel, ts);
        }
        
		Summary s = new Summary();
		s.CaseId = c.Id;
		s.CaseName = c.Subject;

		Integer tasksToComplete = 0;
		Integer tasksCompleted = 0;

		for(Task t : c.Tasks) {
			tasksToComplete++;
			tasksCompleted += mapStatus.containsKey(t.Status) ? 1 : 0;
		}

		for(Event e : c.Events) {
			tasksToComplete++;
			tasksCompleted += e.Is_Completed__c ? 1 : 0;
		}

		s.TotalTasks = tasksToComplete;
		s.CompleteTasks = tasksCompleted;
		s.IsCompleted = tasksToComplete == tasksCompleted;
		s.IsParent = c.ParentId == null;
		s.Level = level;

		return s;
	}

	public class Summary
	{
		public Summary() {
			TotalTasks = 0;
			CompleteTasks = 0;
			Level = 0;
			ChildTasks = 0;
			ChildTasksCompleted = 0;
		}

		public String CaseName;
		public String CaseId;
		public Integer TotalTasks;
		public Integer CompleteTasks;
		public Boolean IsParent;
		public Integer Level;
		public Boolean IsCompleted;
		public Integer ChildTasks;
		public Integer ChildTasksCompleted;
	}
}