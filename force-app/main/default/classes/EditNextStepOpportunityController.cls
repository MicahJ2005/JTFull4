/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 06-05-2022
 * @last modified by  : Brian Ezell (Slalom)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   07-06-2021   Revolution Group (Brian Ezell)   Initial Version
**/
public with sharing class EditNextStepOpportunityController {

    @AuraEnabled
    public static string getOpportunityCases(String oppId) {
        try {

            Opportunity opp =
                [
                    SELECT Id, RecordType.Name, StageName
                    FROM Opportunity
                    WHERE Id = :oppId
                ];

            if(!opp.RecordType.Name.equalsIgnoreCase('Next Step')) {
                throw new EditNextStepOpportunityException('The oppportunity can only be of type Next Step.');
            }

            if(opp.StageName.containsIgnoreCase('Close')) {
                throw new EditNextStepOpportunityException('The oppportunity must be open to modify hours.');
            }

            Map<Id, Case> cases = new Map<Id, Case> (
                [
                    SELECT Id, Subject, Opportunity__c, ParentId,
                        (
                            SELECT Id, Subject, Hours__c
                            FROM Tasks
                            ORDER BY Order__c
                        ),
                        (
                            SELECT Id, Subject, Hours__c
                            FROM Events
                            ORDER BY Order__c
                        ),
                        (
                            SELECT Id, Subject, Opportunity__c, ParentId
                            FROM Cases
                            ORDER BY Order__c
                        )
                    FROM Case
                    WHERE Opportunity__c = :oppId
                    ORDER BY Order__c
                ]);

            if(cases.isEmpty()) {
                throw new EditNextStepOpportunityException('No cases were found to edit hours.');
            }
            
            List<CaseCls> topLevelCasesCls = new List<CaseCls>();

            //Allow for multiple top level cases for next steps with
            //multiple products
            List<Case> masterCases = new List<Case>();

            //First, get the master case
            for(Case c : cases.values()) {
                if(c.ParentId == null) {
                    masterCases.add(c);

                    CaseCls newCls = new CaseCls();
                    newCls.Name = c.Subject;
                    newCls.Id = c.Id;
                    newCls.Type = 'Case';
                    newCls.Children = getChildCases(c, cases);

                    //For top level cases make sure to add tasks
                    //and events on these as well.

                    for(Task t : c.Tasks) {
                        CaseCls act = new CaseCls();
                        act.Id = t.Id;
                        act.Type = 'Task';
                        act.Hours = t.Hours__c;
                        act.Name = t.Subject;
                        newCls.Children.add(act);
                    }

                    for(Event e : c.Events) {
                        CaseCls act = new CaseCls();
                        act.Id = e.Id;
                        act.Type = 'Event';
                        act.Hours = e.Hours__c;
                        act.Name = e.Subject;
                        newCls.Children.add(act);
                    }

                    topLevelCasesCls.add(newCls);
                }
            }

            //Must set lists to "__children" for lightning treegrids to
            //pick up hierarchies
            String caseJson = JSON.serialize(topLevelCasesCls);

            return caseJson.replace('Children', '_children');
        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string saveActivityHours(String activityId, String type, Decimal hours) {
        try {
			
            if(type.equalsIgnoreCase('task')) {
                Task taskId = [SELECT Id, WhatId FROM Task WHERE Id =: activityId LIMIT 1];
                Case relatedCase = [SELECT Id, Opportunity_Product__c, Opportunity__c, Project__c, OppProd_TemplateId__c FROM Case WHERE Id = :taskId.WhatId LIMIT 1];
                
                update new Task(
                    Id = activityId,
                    Hours__c = hours
                );
                
                if(relatedCase != null && relatedCase.Opportunity__c != null && relatedCase.OppProd_TemplateId__c != null && relatedCase.Project__c != null) {
                    NextStepController.calculateOpportunityProRata(relatedCase.Opportunity__c, relatedCase.OppProd_TemplateId__c, relatedCase.Project__c);
                }

            } else {
                update new Event(
                    Id = activityId,
                    Hours__c = hours
                );
            }
            return JSON.serialize(activityId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Get a list of all child cases
    * @author Revolution Group (Brian Ezell) | 07-06-2021
    * @param parentCase
    * @param allCases
    * @return List<CaseCls>
    **/
    private static List<CaseCls> getChildCases(Case parentCase, Map<Id, Case> mapAllCases) {

        List<CaseCls> lstCases = new List<CaseCls>();

        for(Case c : mapAllCases.values()) {
            if(parentCase.Id == c.ParentId) {
                Case caseData = mapAllCases.get(c.Id);
                CaseCls childCase = new CaseCls();

                childCase.Id = caseData.Id;
                childCase.Type = 'Case';
                childCase.Name = caseData.Subject;

                childCase.Children = getChildCases(c, mapAllCases);

                for(Task t : caseData.Tasks) {
                    CaseCls act = new CaseCls();
                    act.Id = t.Id;
                    act.Type = 'Task';
                    act.Hours = t.Hours__c;
                    act.Name = t.Subject;
                    childCase.Children.add(act);
                }

                for(Event e : caseData.Events) {
                    CaseCls act = new CaseCls();
                    act.Id = e.Id;
                    act.Type = 'Event';
                    act.Hours = e.Hours__c;
                    act.Name = e.Subject;
                    childCase.Children.add(act);
                }

                lstCases.add(childCase);
            }
        }
        return lstCases;
    }

    public class CaseCls {
        public CaseCls() {
            Children = new List<CaseCls>();
        }

        public String Id;
        public String Name;
        public String Type;
        public Decimal Hours;
        public List<CaseCls> Children;
    }

    public class EditNextStepOpportunityException extends Exception {}
}