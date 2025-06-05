/***
 * @description : Trigger to handle DML on Case
 * @author      : prateek@ayodia 
 * @contents    : 
 ***/
trigger AyCaseTrigger on Case (after update, after insert){
   
    //System.debug('***Starting AyCaseTrigger***');
    //System.debug('  SOQL Queries = ' + Limits.getQueries());
    
    if(trigger.isAfter && trigger.isUpdate){
        set<Id> caseIds = new set<Id>();
        for(Case cas : trigger.new){
            if(cas.Project__c != null){
                if(cas.Tasks_Completed__c != trigger.oldMap.get(cas.Id).Tasks_Completed__c){
                    caseIds.add(cas.Id);
                }
            }
        }
        // blank update all tasks to roll-up hours.
        if(caseIds.size() > 0){
            list<Task> tskList = [Select Id From Task Where Top_Level_Case_Id__c IN : caseIds];
            if(tskList.size() > 0){
                update tskList;
            }
        }
        
    }

    // to calculate termination liability.
    /*if(trigger.isAfter && (trigger.isInsert || trigger.isUpdate)){
        set<Id> projectIds = new set<Id>();
        for(Case cs : trigger.new){
            if(cs.Project__c != null){
                if(trigger.isInsert){
                    projectIds.add(cs.Project__c);
                }else if(trigger.isUpdate){
                    if( (cs.Termination_Liability__c != trigger.oldMap.get(cs.Id).Termination_Liability__c) || (cs.Project__c != trigger.oldMap.get(cs.Id).Project__c)){
                        projectIds.add(cs.Project__c);
                        projectIds.add(trigger.oldMap.get(cs.Id).Project__c);
                    }
                }
            }    
        }

        if(projectIds.size() > 0){
            map<Id,AcctSeed__Project__c> projMap = new map<Id,AcctSeed__Project__c>();
            for(Id projId : projectIds){
                projMap.put(projId, new AcctSeed__Project__c(Id = projId, Termination_Liability__c = 0));   
            } 

            for(AggregateResult ag : [Select Project__c, SUM(Termination_Liability__c) liab From Case Where Project__c In : projectIds Group by Project__c]){
                Id projectId = (Id) ag.get('Project__c');
                if(projMap.containsKey(projectId)){
                    projMap.get(projectId).Termination_Liability__c = (Decimal) ag.get('liab');
                }
            }

            if(projMap.size() > 0){
                update projMap.values();
            }
        }
    }*/
    
    
}