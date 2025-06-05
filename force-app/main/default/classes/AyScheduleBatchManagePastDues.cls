//scheduler class for Batch to manage past dues
global class AyScheduleBatchManagePastDues implements Schedulable{
    global void execute(SchedulableContext SC) {
            
        AyBatchManagePastDues b = new AyBatchManagePastDues();   
        If(!Test.isRunningTest()){ Database.executeBatch(b,200); }
   }
}