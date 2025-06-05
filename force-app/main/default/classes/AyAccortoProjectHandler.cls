public class AyAccortoProjectHandler {
    
    public static void createAccortoProjectLines(set<Id> accortoProjectIds){
        map<Id,accorto__Project__c> opportunityIdProjectMap = new map<Id,accorto__Project__c>();
        for(accorto__Project__c aproj : [Select Id, Matter__c, accorto__Opportunity__c 
                                           From accorto__Project__c
                                          Where Id IN : accortoProjectIds]){
            opportunityIdProjectMap.put(aproj.accorto__Opportunity__c, aproj);
        }

        list<accorto__Project_Line__c> projectLinesList = new list<accorto__Project_Line__c>();
        for(OpportunityLineItem oli : [Select Id, Product2Id, OpportunityId, Product2.Name
                                         From OpportunityLineItem 
                                        Where OpportunityId IN : opportunityIdProjectMap.keySet()]){
            if(opportunityIdProjectMap.containsKey(oli.OpportunityId)){
                accorto__Project__c aProj = opportunityIdProjectMap.get(oli.OpportunityId);
                accorto__Project_Line__c aProjLine = new accorto__Project_Line__c(
                    Name = oli.Product2.Name,
                    accorto__Project__c = aProj.Id,
                    accorto__Product__c = oli.Product2Id                    
                );       
                projectLinesList.add(aProjLine);
            }    
        }

        if(projectLinesList.size() > 0){
            insert projectLinesList;
        }
    }
    
}