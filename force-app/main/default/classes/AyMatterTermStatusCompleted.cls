/*** 
    @DESC        : to populate CT reference on case
    @AUTHOR      : ashutosh@ayodia.com
    @AUDITED BY  :
    @REVISION(S) :
***/
public without sharing class AyMatterTermStatusCompleted{
    
    @InvocableMethod
    public static void populateCaseTerminationOnCase(List<Id> mtIdList){
        
        Map<Id, Case_Termination__c> csIdWithCTMap = new map<Id, Case_Termination__c>();
        List<Case> caseList = new List<Case>();
        
        //fetch all CT
        for(Case_Termination__c ct : [Select Id, Case__c From Case_Termination__c Where Matter_Termination__c IN : mtIdList]){
            csIdWithCTMap.put(ct.Case__c, ct);
        }
        
        for(Id csId :  csIdWithCTMap.keySet()){
            caseList.add(new Case(Id = csId, Status = 'Terminated', Case_Termination__c = csIdWithCTMap.get(csId).Id)); 
        }
        
        if(caseList.size() > 0 ){
            update caseList;
        }
        
    }
    
    // @desc       : method to handle Update Case Status (Terminated)
    // @param      : set of Matter Termination records to process
    // @return     : void
    
    /*public static void updateCaseStatusToTerminated(Set<Id> mtIds){
       
        // Variable declaration 
        Set<Id> ctIds = new Set<Id>();
        List<Case> cList = new List<Case>();
        
        // Query on case termination to fetch related data
        for(Case_Termination__c ct : [Select Id, Case__c From Case_Termination__c Where Matter_Termination__c IN : mtIds]){
            ctIds.add(ct.Case__c);
        }
        
        // Query on case to fetch related data and update case status to terminated
        for(Case c : [Select Id, Status from Case Where ID IN : ctIds]){
            c.Status = 'Terminated';
            cList.add(c);
        }
        
        if(cList.size() > 0){
            update cList;
        }
    }*/
    
}