//Scheduler class for Batch Create Trust Balance
// this batch will run on 1st of every month
global class AyScheduleBatchCreateTrustBalance implements Schedulable{
    
    global void execute(SchedulableContext SC) {
        
        set<Id> matterIds = new set<Id>();
        for(AcctSeed__Project__c matter : [Select Id from AcctSeed__Project__c where Is_Active__c = true]){
            matterIds.add(matter.Id);
        }
        
        if(matterIds.size() > 0){
            AyBatchCreateTrustBalance b = new AyBatchCreateTrustBalance(matterIds);
            Database.executeBatch(b,1);     
        }       
   }
   
}