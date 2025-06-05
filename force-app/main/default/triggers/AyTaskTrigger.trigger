/***
* @description : Trigger to handle DML functions on task
* @author      : prateek@ayodia 
* @contents    : 
1. populate Matter on Task (Before insert / update)
2. calculation of rollups on matter (After insert / update)
3. calculation of rollups on matter (After delete)
***/
trigger AyTaskTrigger on Task (before insert, before update, after insert, after update, after delete) {
    
    // 1. populate Matter on Task
    if(trigger.isBefore && (trigger.isInsert || trigger.isUpdate)){
        list<Task> taskList = new list<Task>();
        for(Task tsk : trigger.new){
            if(tsk.Top_Level_Case_Id__c != null){
                if(trigger.isInsert){
                    taskList.add(tsk);
                }
                if(trigger.isUpdate){
                    if(tsk.Top_Level_Case_Id__c != trigger.oldMap.get(tsk.Id).Top_Level_Case_Id__c){
                        taskList.add(tsk);
                    }
                }
                
            }
        }
        
        if(taskList.size() > 0){
            AyTaskHandler.prepopulateDataOnTask(taskList);
        }
        
    }
    
    // 2. for calculation of rollups on matter
    if(trigger.isAfter && (trigger.isInsert || trigger.isUpdate)){
        
        set<Id> matterIds = new set<Id>();
        for(Task tsk : trigger.new){
            if(tsk.Matter__c != null){
                if(trigger.isInsert){
                    matterIds.add(tsk.Matter__c);
                }
                
                if(trigger.isUpdate){
                    Task tskOld = trigger.oldMap.get(tsk.Id);
                    if( (tsk.Completed_Date__c != tskOld.Completed_Date__c) || (tsk.Status != tskOld.Status) || (tsk.Not_Applicable__c != tskOld.Not_Applicable__c) || (tsk.Hours__c != tskOld.Hours__c) || (tsk.Net_Amount__c != tskOld.Net_Amount__c)) {
                        matterIds.add(tsk.Matter__c);
                    }
                }
            }
        }
        
        if(matterIds.size() > 0){
            AyTaskHandler.handleTaskHourCalculations(matterIds);
        }   
    }
    
    // 3. for re-calculation of rollups on matter
    if(trigger.isAfter && trigger.isDelete){
        set<Id> matterIds = new set<Id>();
        for(Task tsk : trigger.old){
            if(tsk.Matter__c != null){
                matterIds.add(tsk.Matter__c);
            }
        }
        
        if(matterIds.size() > 0){
            AyTaskHandler.handleTaskHourCalculations(matterIds);
        }
    }
    
    // 3. for populate Value of Terminated Task on Matter
    if(trigger.isAfter && trigger.isUpdate){
        list<Task> taskList = new list<Task>();
        for(Task tsk : trigger.new){
            Task tskOld = trigger.oldMap.get(tsk.Id);
            if((tskOld.Status !='Terminated'&& tsk.Status =='Terminated') || (tskOld.Status =='Terminated'&& tsk.Status !='Terminated')){
                taskList.add(tsk);
            }
        }
        if(taskList.size() > 0){
            AyTaskHandler.handleTerminatedTasks(taskList);
        }
    }
    
}