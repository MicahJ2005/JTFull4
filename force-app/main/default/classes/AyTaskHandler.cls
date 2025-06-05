/***
 * @description : Class to handle Task functions
 * @author      : prateek@ayodia 
 * @contents    : 
 ***/
public class AyTaskHandler{

    // @description - Method to prepopulate data 
    // @param       - set<Id> matterIds
    // @return      - void
    public static void prepopulateDataOnTask(list<Task> taskList){

        //System.debug('***Starting prepopulateDataOnTask***');
        //System.debug('  SOQL Queries = ' + Limits.getQueries());
        
        set<Id> caseIds = new set<Id>();
        set<Id> matterIds = new set<Id>();
        for(Task tsk : taskList){
            if(tsk.WhatId != null){
                if(tsk.Matter__c == null){
                    if(tsk.WhatId.getSObjectType().getDescribe().getName() == 'Case'){
                        caseIds.add(tsk.Top_Level_Case_Id__c);
                    }
                }else{
                    matterIds.add(tsk.Matter__c);   
                }
            }
        }
        
        if(caseIds.size() > 0){
            
            map<Id,Case> caseMap = new Map<Id,Case>([Select Id, Project__c From Case Where Id IN : caseIds]);
            //System.debug('****AyTaskTrigger***prepopulateDataOnTask***caseMap'+caseMap);
            for(Task tsk : taskList){    
                if(caseMap.containsKey(tsk.Top_Level_Case_Id__c)){
                    tsk.Matter__c = caseMap.get(tsk.Top_Level_Case_Id__c).Project__c;
                }
                matterIds.add(tsk.Matter__c);
            }
        }
        if(matterIds.size() > 0) {  
            // get hourly rates from Project Rate
            map<String,Decimal> projectRoleRateMap = new map<String,Decimal>();
            for(Project_Rate__c prr : [Select Id, Hourly_Rate__c, Role__c From Project_Rate__c Where Project__c IN : matterIds]){
                projectRoleRateMap.put(prr.Role__c,prr.Hourly_Rate__c);    
            }
            
            // populate Billing Rate
            for(Task tsk : taskList){
                if(projectRoleRateMap.containsKey(tsk.Default_Queue_Name__c)){
                    tsk.Billing_Rate__c = projectRoleRateMap.get(tsk.Default_Queue_Name__c);
                }
            }
        }
    }
    
    // @description - Method to Populate Task hours and amount on Matter
    // @param       - set<Id> matterIds
    // @return      - void
    public static map<Id,AcctSeed__Project__c> handleTaskHourCalculationsOld(set<Id> matterIds){
        
        //System.debug('***Starting handleTaskHourCalculations***');
        //System.debug('  SOQL Queries = ' + Limits.getQueries());

        set<Id> qualifiedCaseIds = new set<Id>();
        for(Case cs : [Select Id From Case Where Opportunity_Product__r.Opportunity.StageName = 'Closed Won' AND Project__c IN : matterIds]){
            qualifiedCaseIds.add(cs.Id);
        }
        System.debug('****AyTaskHandler***handleTaskHourCalculations***qualifiedCaseIds=='+qualifiedCaseIds);
        map<Id,AcctSeed__Project__c> projectMap = new map<Id,AcctSeed__Project__c>();
        
        for(AcctSeed__Project__c proj : [Select Id, Total_Task_Hours__c, Total_Task__c, Completed_Hours__c, Completed_Task__c, Open_Hours__c, Open_Task__c From AcctSeed__Project__c Where Id IN : matterIds]){
            proj.Total_Task_Hours__c = 0;
            proj.Total_Task__c = 0;
            proj.Completed_Hours__c = 0;
            proj.Completed_Task__c = 0;
            proj.Open_Hours__c = 0;
            proj.Open_Task__c = 0;
            projectMap.put(proj.Id, proj);
        }
        
        // to filter out tasks
        // i.e. task should not be not applicable
        set<Id> unQualifiedTaskIds = new set<Id>();
        for(Task tsk : [Select Id, Not_Applicable__c, Status From Task Where Matter__c IN : matterIds]){
           
            if(tsk.Status == 'Not Applicable' || tsk.Status == 'Terminated' ||tsk.Not_Applicable__c ){
                unQualifiedTaskIds.add(tsk.Id);    
            }
        }
        System.debug('****AyTaskHandler***handleTaskHourCalculations***unQualifiedTaskIds=='+unQualifiedTaskIds);

        // All tasks
        for(AggregateResult ar : [Select Matter__c, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where Matter__c IN : matterIds AND Id NOT IN : unQualifiedTaskIds AND WhatId IN : qualifiedCaseIds Group By Matter__c]){
            Id projectId = (Id) ar.get('Matter__c');
            if(projectMap.containsKey(projectId)){
                projectMap.get(projectId).Total_Task_Hours__c = (Decimal) ar.get('hours');
                projectMap.get(projectId).Total_Task__c = (Decimal) ar.get('total');
            }
        }
        
        // Completed tasks
        for(AggregateResult ar : [Select Matter__c, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where Matter__c IN : matterIds AND Status = 'Completed' AND Id NOT IN : unQualifiedTaskIds AND WhatId IN : qualifiedCaseIds Group By Matter__c]){
            Id projectId = (Id) ar.get('Matter__c');
            if(projectMap.containsKey(projectId)){
                projectMap.get(projectId).Completed_Hours__c = (Decimal) ar.get('hours');
                projectMap.get(projectId).Completed_Task__c = (Decimal) ar.get('total');
            }
        }

        // Open task
        for(AggregateResult ar : [Select Matter__c, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where Matter__c IN : matterIds AND Status != 'Completed' AND Id NOT IN : unQualifiedTaskIds AND WhatId IN : qualifiedCaseIds Group By Matter__c]){
            Id projectId = (Id) ar.get('Matter__c');
            if(projectMap.containsKey(projectId)){
                projectMap.get(projectId).Open_Hours__c = (Decimal) ar.get('hours');
                projectMap.get(projectId).Open_Task__c = (Decimal) ar.get('total');
            }
        }

        System.debug('****AyTaskHandler***handleTaskHourCalculations***projectMap=='+projectMap);
        return projectMap;
        //if(projectMap.values().size() > 0){
            //update projectMap.values();
        //}

    }
    
    // @description - Method to calculate Earned Fee and Un-Earned Fee
    // @param       - set<Id> matterIds
    // @return      - void
    public static void handleTaskHourCalculations(set<Id> matterIds){
        
        try{
            // this method needs to be called to calculate task hour details
            map<Id,AcctSeed__Project__c> projMap = AyTaskHandler.handleTaskHourCalculationsOld(matterIds);
    
    
            set<Id> qualifiedCaseIds = new set<Id>();
            map<Id,Case> caseMap = new map<Id,Case>();
            for(Case cs : [Select Id, Completed_Task__c, Total_Task__c From Case Where Opportunity_Product__r.Opportunity.StageName = 'Closed Won' AND Project__c IN : matterIds]){
                qualifiedCaseIds.add(cs.Id);
                if(cs.Total_Task__c == null){cs.Total_Task__c = 0;}
                if(cs.Completed_Task__c == null){cs.Completed_Task__c = 0;}  
                caseMap.put(cs.Id, cs); 
            }
            //System.debug('****AyTaskHandler***handleTaskHourCalculations***qualifiedCaseIds=='+qualifiedCaseIds);
            
            // to filter out tasks
            // i.e. task should not be not applicable
            set<Id> unQualifiedTaskIds = new set<Id>();
            /*for(Task tsk : [Select Id, Not_Applicable__c, Status From Task Where Matter__c IN : matterIds]){   
                if(tsk.Status == 'Not Applicable' || tsk.Status == 'Terminated' ||tsk.Not_Applicable__c ){
                    unQualifiedTaskIds.add(tsk.Id);    
                }
            }*/
            //System.debug('****AyTaskHandler***handleTaskHourCalculations***unQualifiedTaskIds=='+unQualifiedTaskIds);
    
            // All tasks
            for(AggregateResult ar : [Select WhatId, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where WhatId IN : qualifiedCaseIds AND Id NOT IN : unQualifiedTaskIds Group By WhatId]){
                Id caseId = (Id) ar.get('WhatId');
                if(caseMap.containsKey(caseId)){
                    caseMap.get(caseId).Total_Task__c = (Decimal) ar.get('total');
                }
            }
            
            // Completed tasks
            for(AggregateResult ar : [Select WhatId, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where Status = 'Completed' AND Id NOT IN : unQualifiedTaskIds AND WhatId IN : qualifiedCaseIds Group By WhatId]){
                Id caseId = (Id) ar.get('WhatId');
                if(caseMap.containsKey(caseId)){
                    caseMap.get(caseId).Completed_Task__c = (Decimal) ar.get('total');
                }
            }
    
            //System.debug('****AyTaskHandler***handleTaskHourCalculations***caseMap=='+caseMap);
            
            if(caseMap.values().size() > 0){
                update caseMap.values();
            }
    
            list<AcctSeed__Project__c>projectListToUpdate = new list<AcctSeed__Project__c>();
            for(AcctSeed__Project__c prok : [Select Id, (Select Id, Opportunity_Product__c, Earned_Fee__c, Un_Earned_Fee__c, Project__c, Status, Product_Price__c From Cases__r Order By Project__r.Name ASC) From AcctSeed__Project__c Where Id IN : matterIds]){
                
                // calculate total task value for each product
                map<Id,Decimal> productIdTotalTaskValue = new map<Id,Decimal>();
                for(Case cs : prok.Cases__r){
                    if(caseMap.containsKey(cs.Id)){
                        Decimal totalTask;
                        if(caseMap.get(cs.Id).Total_Task__c == null){
                            totalTask = 0;
                        }else{
                            totalTask = caseMap.get(cs.Id).Total_Task__c;
                        }
    
                        if(!productIdTotalTaskValue.containsKey(cs.Opportunity_Product__c)){
                            productIdTotalTaskValue.put(cs.Opportunity_Product__c, 0);     
                        }
    
                        Decimal totalTaskFinal = productIdTotalTaskValue.get(cs.Opportunity_Product__c) + totalTask;
                        productIdTotalTaskValue.put(cs.Opportunity_Product__c,totalTaskFinal);
                        
                    }
                }
                //System.debug('****AyTaskHandler***handleTaskHourCalculations***productIdTotalTaskValue=='+productIdTotalTaskValue);
    
                Decimal earnedTotal = 0;
                Decimal unearnedTotal = 0;
    
                // calculate earned and un-earned 
                for(Case cs : prok.Cases__r){
                    if(productIdTotalTaskValue.containsKey(cs.Opportunity_Product__c)){
                        Decimal totalTaskValue = productIdTotalTaskValue.get(cs.Opportunity_Product__c);            // product task value
    
                        
                        if(cs.Product_Price__c != null && cs.Product_Price__c > 0 && totalTaskValue != null && totalTaskValue > 0){
                            
                            Decimal ratio = cs.Product_Price__c / totalTaskValue ;
                            
                            Decimal totalTask = caseMap.get(cs.Id).Total_Task__c.setScale(2);
                            Decimal completedTask = caseMap.get(cs.Id).Completed_Task__c.setScale(2);
        
                            if(totalTask == null){totalTask = 0.00;}
                            if(completedTask == null){completedTask = 0.00;}
        
                            //System.debug('****AyTaskHandler***handleTaskHourCalculations***totalTask=='+totalTask);
                            //System.debug('****AyTaskHandler***handleTaskHourCalculations***completedTask=='+completedTask);
        
                            Decimal earned;
                            if(completedTask == totalTask && completedTask > 0){                                   // if task is completed
                                earned = completedTask * ratio;
                                //System.debug('****TASK IS COMPLETED****');
                            }else if(completedTask == 0 && totalTask != 0){                                        // if task is not completed
                                earned = 0;
                                //System.debug('****TASK IS NOT COMPLETED****');
                            }else if(completedTask != totalTask && completedTask != 0 && totalTask != 0){          // if task is partially completed
                                //earned = (completedTask / totalTask) * ratio;
                                earned = completedTask * ratio;
                                //System.debug('****TASK IS PARTIALLY COMPLETED****');
                            }else{
                                earned = 0;
                            }
                            earned = earned.setScale(2);
                            earnedTotal += earned.setScale(2);
                            
                            // if status is not terminated
                            //System.debug('****AyTaskHandler***handleTaskHourCalculations***cs.status=='+cs.status);
                            if(cs.status != 'Terminated'){// && cs.Status != 'On Hold')
                                Decimal unearnedTemp = 0;
        
                                if(completedTask == totalTask && completedTask > 0){                           // if task is completed
                                    unearnedTemp = 0;
                                }else if(completedTask == 0 && totalTask != 0){                                 // if task is not completed
                                    unearnedTemp = totalTask * ratio;
                                }else if(completedTask != totalTask && completedTask != 0 && totalTask != 0){   // if task is partially completed
                                    //unearnedTemp = (totalTask - earned) * ratio;
                                    unearnedTemp = (totalTask - completedTask) * ratio;
                                }else{
                                    unearnedTemp = 0;
                                }
        
                                unearnedTemp = unearnedTemp.setScale(2);
                                unearnedTotal += unearnedTemp.setScale(2);                                      // set scale for round off
                                
                            }
                        }
                    }
                    //System.debug('------------------------------------------------------------------------------------------------------------');
                    //System.debug('------------------------------------------------------------------------------------------------------------');
    
                }
                
                //System.debug('****AyTaskHandler***handleTaskHourCalculations***earnedTotal=='+earnedTotal);
                //System.debug('****AyTaskHandler***handleTaskHourCalculations***unearnedTotal=='+unearnedTotal);
                if(projMap.containsKey(prok.Id)){
                    AcctSeed__Project__c p = projMap.get(prok.Id);
                    p.Earned_Fee_Value__c = earnedTotal;
                    p.Un_Earned_Fee_Value__c = unearnedTotal;
                    projectListToUpdate.add(p);
                }
                //prok.Earned_Fee_Value__c = earnedTotal;
                //prok.Un_Earned_Fee_Value__c = unearnedTotal;
                //projectListToUpdate.add(prok);
            } 
    
            if(projectListToUpdate.size() > 0){
                update projectListToUpdate;
            }
        }catch(Exception e){
            System.debug(e.getMessage() + ' | Line : ' + e.getLineNumber());
        }    

    }
   
    public static void handleTerminatedTasks(list<Task> taskList){
        set<Id> matterIds = new set<Id>();
        for(Task ts : taskList){
            if(ts.Matter__c != null){
                matterIds.add(ts.Matter__c);
            }
        }
        map<Id, AcctSeed__Project__c> matterMap = new map<Id, AcctSeed__Project__c>();
        for(Id mattrId : matterIds){
            matterMap.put(mattrId, new AcctSeed__Project__c(Id = mattrId, Value_of_Terminated_Tasks__c  = 0));
        }
        
        // Terminated Task
        for(AggregateResult ag : [Select Matter__c, SUM(Total_Task_Amount__c ) totl From Task Where Matter__c IN : matterIds AND Matter__c != null AND Status = 'Terminated' Group By Matter__c]){
            Id matterId = (Id) ag.get('Matter__c');
            if(matterId != null && matterMap.containsKey(matterId)){
                matterMap.get(matterId).Value_of_Terminated_Tasks__c = (Decimal) ag.get('totl');   
            } 
        }
        if(matterMap.size() > 0){
            update matterMap.values();
        }
    }
  
}