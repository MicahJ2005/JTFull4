/**
 * @File Name          : DEX_CasesOnObjectController.cls
 * @Description        : Handles lists of tracker cases on any object
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 02-12-2021
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    3/20/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public without sharing class DEX_CasesOnObjectController {

	@AuraEnabled
	public static String getCaseSummaries(String objectId, String caseLinkedField) {
        String sql = 'SELECT Id FROM Case WHERE ' + caseLinkedField + ' = :objectId AND Is_Task_Tracker_Case__c = true AND Is_Parent_Process__c = true AND Status != \'Template Pending\' ORDER BY Order__c, Subject';
        System.debug(sql);
        List<Case> cases = Database.query(sql);
        
        List<ObjectSummaryByCases> listOfMapSummaries = new List<ObjectSummaryByCases>();

        for(Case c : cases) {
            String jsonResult = MasterTaskSummaryController.getChildTasksSummary(c.Id);
            System.debug(jsonResult);
            if(jsonResult != null) {
                List<MasterTaskSummaryController.Summary> caseSummaries = (List<MasterTaskSummaryController.Summary>)JSON.deserialize(jsonResult, List<MasterTaskSummaryController.Summary>.class);

                ObjectSummaryByCases objSummary = new ObjectSummaryByCases();
                objSummary.ParentCaseName = caseSummaries[0].CaseName;
                objSummary.Summaries = caseSummaries;
                listOfMapSummaries.add(objSummary);
            }
        }
        return JSON.serialize(listOfMapSummaries);
    }

    public class ObjectSummaryByCases {
        public String ParentCaseName;
        public List<MasterTaskSummaryController.Summary> Summaries;
    }

}