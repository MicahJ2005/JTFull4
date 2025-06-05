/*** 
    @DESC        : to populate CT reference on case
    @AUTHOR      : ashutosh@ayodia.com
    @AUDITED BY  :
    @REVISION(S) :
***/
public without sharing class AyMatterTermStatusCancelled{
    
    @InvocableMethod
    public static void setPriorCaseStatus(List<Id> mtIdList){
        
        Map<Id, Case_Termination__c> csIdWithCTMap = new map<Id, Case_Termination__c>();
        List<Case> caseList = new List<Case>();
        
        //fetch all CT
        for(Case_Termination__c ct : [Select Id, Case__c, Case_Prior_Status__c From Case_Termination__c Where Matter_Termination__c IN : mtIdList]){
            System.debug('****case term***'+ct);
            csIdWithCTMap.put(ct.Case__c, ct);
        }
        
        for(Id csId :  csIdWithCTMap.keySet()){
            System.debug('****prior status*** '+csIdWithCTMap.get(csId).Case_Prior_Status__c);
            caseList.add(new Case(Id = csId, Status = csIdWithCTMap.get(csId).Case_Prior_Status__c)); 
        }
        
        if(caseList.size() > 0 ){
            update caseList;
            System.debug('***caseList= '+caseList);
        }
        
    }
    
}