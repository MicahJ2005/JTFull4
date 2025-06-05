//scheduler class for Batch to manage auto charge
global class AyScheduleBatchHandleMatterAutoPay implements Schedulable{
    global void execute(SchedulableContext SC) {
            
        AyBatchHandleMatterAutoPay b = new AyBatchHandleMatterAutoPay();   
        If(!Test.isRunningTest()){ Database.executeBatch(b,1); }
   }
}