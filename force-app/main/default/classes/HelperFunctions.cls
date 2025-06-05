/**
 * @File Name          : HelperFunctions.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 10-15-2020
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    6/10/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public with sharing class HelperFunctions {

    public static List<Case> getAssociatedCases(String caseId) {
        List<Case> startCase =
        [
            SELECT Id, Top_Level_Task_Tracker_Case__c
            FROM Case
            WHERE Id = :caseId
        ];

        if(startCase.isEmpty()) {
            return null;
        }

        List<Case> allCases =
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
            WHERE Top_Level_Task_Tracker_Case__c = :startCase[0].Top_Level_Task_Tracker_Case__c
            ORDER BY Order__c, Subject
        ];
        return allCases;
    }

    /**
    * @description Updates the counts on the cases for
    *   task/events and completitions
    * @author Revolution Group (Brian Ezell) | 6/10/2020
    * @param caseIds
    * @return void
    **/
    public static void updateCaseCounts(Set<Id> caseIds) {
        //Run through each parent case.
        for(Id cId : caseIds) {
            updateAssociatedCases(cId);
        }
    }

     /**
    * @description Calculates the due date of an activity from a task date
    *   using either calendar or business days
    * @author Revolution Group (Brian Ezell) | 09-21-2020
    * @param taskDate
    * @return Date
    **/
    public static Date calculateDateFromActivityDate(String dateType, Integer daysOut) {

        //Arbitrary saturday and sunday for testing weekends
        Date saturday = Date.newInstance(2020, 9, 19);
        Date sunday = Date.newInstance(2020, 9, 20);

        if(dateType == 'Business') {

            Integer offsetIndex = daysOut;
            Integer daysAdded = 0;
            Integer addValue = offsetIndex < 0 ? -1 : 1;
            Date indexDate = Date.today();

            while(true) {
                //Weekday if both are false
                if(Math.mod(sunday.daysBetween(indexDate), 7) != 0 && Math.mod(saturday.daysBetween(indexDate), 7) != 0) {
                    daysAdded++;
                }
                if(daysAdded > Math.abs(daysOut)) {
                    break;
                }
                indexDate += addValue;
            }
            return indexDate;
        }
        
        return Date.today() + daysOut;
    }

    public static Date calculateDateFromActivityDateAdjusted(String dateType, Integer daysOut, Date startDate) {

        //Arbitrary saturday and sunday for testing weekends
        Date saturday = Date.newInstance(2020, 9, 19);
        Date sunday = Date.newInstance(2020, 9, 20);

        if(dateType == 'Business') {

            Integer offsetIndex = daysOut;
            Integer daysAdded = 0;
            Integer addValue = offsetIndex < 0 ? -1 : 1;
            Date indexDate = startDate;

            while(true) {
                //Weekday if both are false
                if(Math.mod(sunday.daysBetween(indexDate), 7) != 0 && Math.mod(saturday.daysBetween(indexDate), 7) != 0) {
                    daysAdded++;
                }
                if(daysAdded > Math.abs(daysOut)) {
                    break;
                }
                indexDate += addValue;
            }
            return indexDate;
        }
        if(startDate != null) {
            return startDate + daysOut;
        } else {
            return null;
        }
        
    }
    
    /**
    * @description Updates the cases from the sample
    *   templates as the case id passed in.
    * @author Revolution Group (Brian Ezell) | 6/10/2020
    * @param caseId
    * @return void
    **/
    private static void updateAssociatedCases(Id caseId) {
        List<Case> allCases = getAssociatedCases(caseId);
        List<Case> updateCases = new List<Case>();
        for(Case c : allCases) {
            CaseTally tally = getRollupCaseCounts(c, allCases);
            updateCases.add(new Case (
                Id = c.Id,
                Tasks_To_Complete__c = tally.TasksToComplete,
                Tasks_Completed__c = tally.TasksCompleted,
                Status = tally.TasksCompleted == 0 ? 'New' :
                    tally.TasksToComplete > tally.TasksCompleted ? 'In Progress' :
                    'Completed'
            ));
        }
        update updateCases;
    }

    /**
    * @description Gets the CaseTally counts for a
    *   specific case passed in.
    * @author Revolution Group (Brian Ezell) | 6/10/2020
    * @param parentCase
    * @param allCases
    * @return CaseTally
    **/
    private static CaseTally getRollupCaseCounts(Case parentCase, List<Case> allCases) {
        CaseTally tally = new CaseTally();
        Set<Id> childIds = new Set<Id>{parentCase.Id};
        Integer childCount = childIds.size();
        do {
            childCount = childIds.size();
            for(Case c : allCases) {
                if(childIds.contains(c.ParentId)) {
                    childIds.add(c.Id);
                }
            }
        } while(childCount != childIds.size());
        //Keep going until no more cases are added -
        //we must be done then.

        for(Case c : allCases) {
            if(childIds.contains(c.Id)) {
                tally.TasksToComplete += c.Tasks.size() + c.Events.size();
                for(Task t : c.Tasks) {
                    tally.TasksCompleted += t.Is_Completed__c ? 1 : 0;
                }
                for(Event e : c.Events) {
                    tally.TasksCompleted += e.Is_Completed__c ? 1 : 0;
                }
            }
        }
        return tally;
    }

    public class CaseTally {
        public CaseTally() {
            TasksCompleted = 0;
            TasksToComplete = 0;
        }
        public Decimal TasksCompleted;
        public Decimal TasksToComplete;
    }
}