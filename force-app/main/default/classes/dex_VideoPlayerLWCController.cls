/**
 * @description       : Controller for dex_VideoPlayerLWC
 * @author            : Dextara (Albert Liu)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   07/24/2024   Dextara (Albert Liu)			   Initial Version
**/
public without sharing class dex_VideoPlayerLWCController {
    
    @AuraEnabled(cacheable=true)
    public static String getTaskList(String recordId) {
        List<outputs> taskList = new List<outputs>();
        
        // Get list of Task records associated with Matter.
        // Contains link to Video.
        List<Task> tasks = [SELECT Id, Video_URL__c, Subject, Matter__c, Status, ActivityDate
                            FROM Task WHERE Matter__c != null AND Matter__c = :recordId AND 
                            (Status = 'Completed' OR (Subject = 'Attend ICMC' AND ActivityDate != null))
                            AND Video_URL__c != null AND Video_URL__c != ''];
        
        for(Task t : tasks) {
            if(t.Subject == 'Attend ICMC' && t.ActivityDate == null) {
                continue;
            }
            outputs ot = new outputs();
            ot.Id = t.Id;
            ot.Url = t.Video_URL__c;
            ot.Subject = t.Subject;
            taskList.add(ot);
        }
        
        // Get list of Case Strategy records associated with Matter
        List<Case_Strategy__c> cs = [SELECT Id, Matter__c, Status_Spousal_Maintenance__c, Status_Child_Support__c, Child_Support_Video__c, Spousal_Maintenance_Video__c 
                                     FROM Case_Strategy__c WHERE Matter__c = :recordId AND ((Status_Spousal_Maintenance__c != '' AND Status_Spousal_Maintenance__c != 'NA')
                                                                                            OR (Status_Child_Support__c != '' AND Status_Child_Support__c != 'NA'))];
        Boolean hasCS = false;
        Boolean hasSM = false;
        
        // Determine if criteria is met to display videos for Child Support and Spousal Maintenance.
        for(Case_Strategy__c c : cs) {
            if(!hasCS && c.Status_Child_Support__c != '' && c.Status_Child_Support__c != 'NA') {
                outputs ot = new outputs();
                ot.Id = c.Id;
                ot.Url = c.Child_Support_Video__c;
                ot.Subject = 'Status- Child Support/Case Strategy';
                taskList.add(ot);
                hasCS = true;
            }
            if(!hasSM && c.Status_Spousal_Maintenance__c != '' && c.Status_Spousal_Maintenance__c != 'NA') {
                outputs ot = new outputs();
                ot.Id = c.Id;
                ot.Url = c.Spousal_Maintenance_Video__c;
                ot.Subject = 'Status- Spousal Maintenance/Case Strategy';
                taskList.add(ot);
                hasSM = true;
            }
        }
        
        String JSONString = JSON.serialize(taskList);
        return JSONString;
    }
    
    public class outputs {
        public String Id;
        public String Url;
        public String Subject;
    }
}