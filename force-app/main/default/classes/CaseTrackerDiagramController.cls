/**
 * @File Name          : CaseTrackerDiagramController.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 09-15-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    2/19/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public class CaseTrackerDiagramController {

	@AuraEnabled
	public static String getCaseSummary(String caseId)
	{
        try {
            List<CaseProgress> cases = new List<CaseProgress>();
            cases.addAll(getChildCases(caseId));

            return JSON.serialize(cases);
        } catch (Exception e) {
            throw new AuraHandledException(Util.getExceptionError(e));
        }
    }

    private static List<CaseProgress> getChildCases(Id caseId) {
        List<CaseProgress> caseProgress = new List<CaseProgress>();

        List<Case> cases =
            [
				SELECT Id, Subject, Tasks_Completed__c, Tasks_To_Complete__c, Progress__c,
					(
						SELECT Id, Subject, Tasks_Completed__c, Tasks_To_Complete__c, Progress__c
                        FROM Cases
                        ORDER By Order__c
					),
					(
						SELECT Id, Status, IsClosed, Subject
                        FROM Tasks
                        ORDER By Order__c
					)
                FROM Case
                WHERE Id = :caseId
                ORDER By Order__c
            ];

        for(Case c : cases) {
            CaseProgress cp = new CaseProgress();
            cp.Id = c.Id;
            cp.Name = c.Subject;
            cp.Progress = c.Progress__c;
            cp.TasksToComplete = c.Tasks_To_Complete__c;
            cp.TasksComplete = c.Tasks_Completed__c;

            for(Task t : c.Tasks) {
                CaseTaskProgress tp = new CaseTaskProgress();
                tp.Id = t.Id;
                tp.Name = t.Subject;
                tp.IsComplete = t.IsClosed;
                cp.ChildTasks.add(tp);
            }

            if(!c.Cases.isEmpty()) {
                for(Case childCase : c.Cases) {
                    cp.ChildCases.addAll(getChildCases(childCase.Id));
                }
            }

            caseProgress.add(cp);
        }
        return caseProgress;
    }

    public class CaseProgress {

        public CaseProgress() {
            ChildCases = new List<CaseProgress>();
            ChildTasks = new List<CaseTaskProgress>();
        }

        public String Id;
        public String Name;
        public String Progress;
        public Decimal TasksComplete;
        public Decimal TasksToComplete;
        public List<CaseProgress> ChildCases;
        public List<CaseTaskProgress> ChildTasks;
    }

    public class CaseTaskProgress {
        public String Id;
        public String Name;
        public Boolean IsComplete;
    }

}