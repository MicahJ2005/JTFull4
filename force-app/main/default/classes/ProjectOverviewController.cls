/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 10-14-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   10-09-2020   Revolution Group (Brian Ezell)   Initial Version
**/

public class ProjectOverviewController {

    @AuraEnabled
    public static string getProjectCasesAndTasks(String projectId) {
        //Get the ID on the top level case
        List<Case> masterCases =
            [
                SELECT Id
                FROM Case
                WHERE Project__c = :projectId
            ];

        Set<String> masterCaseIds = new Set<String>();
        for(Case c : masterCases) {
            masterCaseIds.add(c.Id);
        }

        List<Case> cases =
            [
                SELECT Id, Subject, Tasks_Completed__c, Status, Tasks_To_Complete__c, ParentId, Top_Level_Task_Tracker_Case__c, Order__c,
                    Owner.Name,
                    (
                        SELECT Id, Status, Subject, Task_Tracker_Template_Step__c, Is_Completed__c, Order__c, Hours__c,
                            Owner.Name
                        FROM Tasks
                        ORDER BY Order__c, Subject
                    ),
                    (
                        SELECT Id, Subject, ActivityDate, Task_Tracker_Template_Step__c, Is_Completed__c, Order__c, Hours__c,
                            Owner.Name
                        FROM Events
                        ORDER BY Order__c, Subject
                    ),
                    (
                        SELECT Id, Name, Task_Depends_On_Id__c, Task_Id__c
                        FROM Case_Dependencies__r
                    )
                FROM Case
                WHERE Top_Level_Task_Tracker_Case__c = :masterCaseIds
                ORDER BY Order__c, Subject
            ];

        Map<String, CaseObject> mapCaseIdToObjects = new Map<String, CaseObject>();

        //First map out the cases
        for(Case c : cases) {
            CaseObject cObj = new CaseObject();

            cObj.ParentId = c.ParentId;
            cObj.Id = c.Id;
            cObj.Name = c.Subject;
            cObj.OwnerName = c.Owner.Name;
            cObj.Type = 'Case';

            for(Task t : c.Tasks) {
                CaseObject taskObj = new CaseObject();
                taskObj.ParentId = c.Id;
                taskObj.Id = t.Id;
                taskObj.Name = t.Subject;
                taskObj.OwnerName = t.Owner.Name;
                taskObj.Hours = t.Hours__c != null ? t.Hours__c : 0;
                taskObj.Type = 'Task';
                cObj.Children.add(taskObj);
                cObj.Hours += taskObj.Hours;
            }

            for(Event e : c.Events) {
                CaseObject eventObj = new CaseObject();
                eventObj.ParentId = c.Id;
                eventObj.Id = e.Id;
                eventObj.Name = e.Subject;
                eventObj.OwnerName = e.Owner.Name;
                eventObj.Hours = e.Hours__c != null ? e.Hours__c : 0;
                eventObj.Type = 'Event';
                cObj.Children.add(eventObj);
                cObj.Hours += eventObj.Hours;
            }

            mapCaseIdToObjects.put(cObj.Id, cObj);
        }

        Map<String, Decimal> mapCaseIdToHoursTotal = new Map<String, Decimal>();
        //Gather up the summed up hours
        for(CaseObject c : mapCaseIdToObjects.values()) {
            Decimal currentHours = mapCaseIdToHoursTotal.containsKey(c.ParentId) ? mapCaseIdToHoursTotal.get(c.ParentId) : 0;
            mapCaseIdToHoursTotal.put(c.ParentId, currentHours + c.Hours);
        }

        for(String parentCaseId : mapCaseIdToHoursTotal.keySet()) {
            if(mapCaseIdToObjects.containsKey(parentCaseId)) {
                mapCaseIdToObjects.get(parentCaseId).Hours += mapCaseIdToHoursTotal.get(parentCaseId);
            }
        }

        //Converts the mapping to a single master case with the child cases/tasks/events under it.
        List<CaseObject> masterCaseObjectList = new List<CaseObject>();
        for(Case c : masterCases) {
            masterCaseObjectList.add(unflattenCaseObject(mapCaseIdToObjects.get(c.Id), mapCaseIdToObjects));
        }

        return JSON.serialize(masterCaseObjectList);
    }

    private static CaseObject unflattenCaseObject(CaseObject cObject, Map<String, CaseObject> mapCaseObjects) {
        CaseObject newCaseObject = cloneCaseObject(cObject);
        for(CaseObject c : mapCaseObjects.values()) {
            if(cObject.Id == c.ParentId) {
                newCaseObject.Children.add(unflattenCaseObject(c, mapCaseObjects));
            }
        }
        return newCaseObject;
    }

    /**
    * @description Creates a clone of the CaseObject
    *   used to avoid pointers getting deleted when
    *   updating removing objects from the map
    * @author Revolution Group (Brian Ezell) | 10-09-2020
    * @param co
    * @return CaseObject
    **/
    private static CaseObject cloneCaseObject(CaseObject co) {
        CaseObject newObject = new CaseObject();
        newObject.Id = co.Id;
        newObject.Name = co.Name;
        newObject.OwnerName = co.OwnerName;
        newObject.ParentId = co.ParentId;
        newObject.Type = co.Type;
        newObject.Hours = co.Hours;
        for(CaseObject childCo : co.Children) {
            newObject.Children.add(cloneCaseObject(childCo));
        }
        return newObject;
    }

    public class CaseObject {

        public CaseObject() {
            Children = new List<CaseObject>();
            Hours = 0;
        }
        public String ParentId;
        public String Id;
        public String Name;
        public String OwnerName;
        public Decimal Hours;
        public String Type;
        public List<CaseObject> Children;
    }
}