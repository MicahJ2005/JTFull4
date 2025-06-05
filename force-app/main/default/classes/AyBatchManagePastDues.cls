public class AyBatchManagePastDues implements Database.Batchable<sObject>{


    // Start Method
    public Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'Select Id From Account';
        return Database.getQueryLocator(query);
    }
        
    // Execute Method
    public void execute(Database.BatchableContext BC, List<Account> scope){
        Set<Id> acIdSet = new Set<Id>();
        Integer remissionDays = Integer.valueOf(Label.Ay_Bill_Pay_Remission_Days);
        List<AcctSeed__Project__c> matterList = new List<AcctSeed__Project__c>();
        List<AcctSeed__Billing__c> bList = new List<AcctSeed__Billing__c>();
        List<Account> accList = new List<Account>();
        List<Account> acListToUpdate = new List<Account>();
        map<Id, Decimal> matterIdWithDueAmountMap = new map<Id, Decimal>();
        map<Id, Integer> accIdWithNumberOfDelayedPaymentsMap = new map<Id, Integer>();
        map<Id, Decimal> accIdWithDueAmountMap = new map<Id, Decimal>();

        System.Savepoint sp = Database.setSavePoint();
        try{

            for(Account acc : scope){
                acIdSet.add(acc.Id);
            }
            
            Integer i = 1;

            // get billing(s) that has late payments
            for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Customer__c, AcctSeed__Balance__c, Matter__c From AcctSeed__Billing__c Where AcctSeed__Customer__c IN : acIdSet 
                                                AND AcctSeed__Balance__c > 0 AND Past_Due_Days__c > 0 AND Past_Due_Days__c >: remissionDays AND AcctSeed__Date__c = LAST_N_Days:730 AND AcctSeed__Status__c = 'Posted']){ 
                
                bill.Is_Payment_Delayed__c = true;
                bList.add(bill);                                         
                if(matterIdWithDueAmountMap.containsKey(bill.Matter__c)){
                    Decimal temp = matterIdWithDueAmountMap.get(bill.Matter__c) + bill.AcctSeed__Balance__c;
                    matterIdWithDueAmountMap.put(bill.Matter__c, temp);
                }else{
                    matterIdWithDueAmountMap.put(bill.Matter__c, bill.AcctSeed__Balance__c);
                }

                if(accIdWithDueAmountMap.containsKey(bill.AcctSeed__Customer__c)){
                    Decimal temp = accIdWithDueAmountMap.get(bill.AcctSeed__Customer__c) + bill.AcctSeed__Balance__c;
                    accIdWithDueAmountMap.put(bill.AcctSeed__Customer__c, temp);
                }else{
                    accIdWithDueAmountMap.put(bill.AcctSeed__Customer__c, bill.AcctSeed__Balance__c);
                }
                
                if(accIdWithNumberOfDelayedPaymentsMap.containsKey(bill.AcctSeed__Customer__c)){
                    Integer j = accIdWithNumberOfDelayedPaymentsMap.get(bill.AcctSeed__Customer__c) + 1;
                    accIdWithNumberOfDelayedPaymentsMap.put(bill.AcctSeed__Customer__c, j);
                }else{
                    accIdWithNumberOfDelayedPaymentsMap.put(bill.AcctSeed__Customer__c, i);
                }
                
            }

            if(bList.size() > 0){
                update bList;
            }

            // get billing(s) that has late payments in past 3 days            
            List<AggregateResult> billAgg = [SELECT Count(Id) recCount, Matter__c FROM AcctSeed__Billing__c WHERE Is_Payment_Delayed__c = true AND AcctSeed__Due_Date2__c = LAST_N_Days:3 Group By Matter__c];
            List<AcctSeed__Project__c> mtrList = new List<AcctSeed__Project__c>();

            for(AggregateResult ar : billAgg){
                AcctSeed__Project__c mtr = new AcctSeed__Project__c(Id = (Id) ar.get('Matter__c'), No_of_Delayed_Payments_in_past_3_days__c = (Integer)ar.get('recCount'));
                mtrList.add(mtr);
            }

            if(mtrList.size() > 0){
                update mtrList;
            }


            
            // populate total past due amount on matter
            for(AcctSeed__Project__c m : [Select Id, Total_Past_Due_Amount__c From AcctSeed__Project__c Where AcctSeed__Account__c IN : acIdSet]){
                m.Total_Past_Due_Amount__c = 0;
                if(matterIdWithDueAmountMap.containsKey(m.Id)){
                    m.Total_Past_Due_Amount__c = matterIdWithDueAmountMap.get(m.Id);
                }
                matterList.add(m);
            }


            // update matter
            if(matterList.size() > 0){
                update matterList;
            }

            // populate number of late payments on account
            for (Account acc : scope) {
                if(accIdWithNumberOfDelayedPaymentsMap.containsKey(acc.Id)){
                    acc.Number_of_Delayed_Payments__c = accIdWithNumberOfDelayedPaymentsMap.get(acc.Id);
                    accList.add(acc);
                }
            }

            if(accList.size() > 0){
                update accList;
            }

            // populate total past due on account
            if(accIdWithDueAmountMap.size() > 0){
                for(Id acId : accIdWithDueAmountMap.keySet()){
                    Account ac = new Account(Id = acId, Total_Past_Due_Amount__c = accIdWithDueAmountMap.get(acId));
                    acListToUpdate.add(ac);
                }
            }

            if(acListToUpdate.size() > 0){
                update acListToUpdate;
            }
            

        }catch(Exception e){
            Database.rollback(sp);
        }
    }
    
    
    // Finish Method
    public void finish(Database.BatchableContext BC){
        
    }
    
}