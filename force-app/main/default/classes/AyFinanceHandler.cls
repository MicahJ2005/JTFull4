public class AyFinanceHandler{

    // @desc   : method to settle previous bills and create new bills
    // @param  : set<Id> financeIds
    // @return : void
    public static void createFinanceAccounting(set<Id> financeIds){
        

        map<String,String> configMap = new map<String,String>();
        for(Accounting_Config__c ac : [Select Key__c, Value__c From Accounting_Config__c]){
            configMap.put(ac.Key__c, ac.Value__c);
        }

        map<String,String> glConfigMap = new map<String,String>();
        for(Ay_GL_Config__mdt glc : [Select Id, Key__c, Value__c From Ay_GL_Config__mdt]){
            glConfigMap.put(glc.Key__c, glc.Value__c);
        }
        AcctSeed__GL_Account__c glAccount = [Select Id from AcctSeed__GL_Account__c Where AcctSeed__Type__c = 'Revenue' Limit 1];
        
        // 1. Settle previous Bills
        set<Id> oppIds = new set<Id>();
        Id accountingPeriodId = AyAccountingFunctions.getAccountingPeriod(Date.today());
        list<AcctSeed__Billing__c> memoList = new list<AcctSeed__Billing__c>();
        map<Id,Finance__c> financeBillingMap = new map<Id,Finance__c>();

        map<String,Id> officeMap = new map<String,Id>();
        map<String,Id> areaOfLawMap = new map<String,Id>();
        for(AcctSeed__Accounting_Variable__c av : [Select Id, Name, AcctSeed__Type__c From AcctSeed__Accounting_Variable__c]){
            if(av.AcctSeed__Type__c == 'GL Account Variable 1'){
                officeMap.put(av.Name, av.Id);    
            }else if(av.AcctSeed__Type__c == 'GL Account Variable 4'){
                areaOfLawMap.put(av.Name, av.Id);
            }
        }

        for(Finance__c fin : [Select Id, Matter__c, Payment_Frequency__c, Parent_Opportunity__r.Kapsten_Matter__c, Total_Adjusted_Amount__c, Parent_Opportunity__r.Area_of_Law__c, Parent_Opportunity__r.Originator_LU__c, Parent_Opportunity__r.Billing_Attorney_lk__c, Parent_Opportunity__r.Office_that_consult_occurred_in__c, First_Instalment_Payment_Date__c, No_of_Instalments__c, Total_Consolidated_Amount__c, Total_Instalment_Amount__c, Parent_Opportunity__r.AccountId, Parent_Opportunity__c, Downpayment__c From Finance__c Where Id IN : financeIds]){
            
            
            String ledgerKey = 'JTL_Ledger_Id';
            if(fin.Parent_Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }
            
            AcctSeed__Billing__c memo = new AcctSeed__Billing__c();
            memo.Finance__c = fin.Id;
            memo.AcctSeed__Opportunity__c = fin.Parent_Opportunity__c;
            memo.AcctSeed__Customer__c = fin.Parent_Opportunity__r.AccountId;
            memo.AcctSeed__Status__c = 'Approved';
            memo.Matter__c = fin.Matter__c;
            memo.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            memo.Originator__c = fin.Parent_Opportunity__r.Originator_LU__c;
            memo.Billing_Attorney__c = fin.Parent_Opportunity__r.Billing_Attorney_lk__c;
            memo.AcctSeed__Date__c = Date.today();
            memoList.add(memo);
            financeBillingMap.put(fin.Id, fin);
        }

        if(memoList.size() > 0){
            insert memoList;
            
            list<AcctSeed__Billing_Line__c> bLineList = new list<AcctSeed__Billing_Line__c>();

            map<Id,Id> matterIdMemoIdMap = new map<Id,Id>();
            map<Id,Decimal> matterIdAmountMap = new map<Id,Decimal>();
            for(AcctSeed__Billing__c memo : memoList){
                if(financeBillingMap.containsKey(memo.Finance__c)){
                    Finance__c fin = financeBillingMap.get(memo.Finance__c);
                    AcctSeed__Billing_Line__c bLine = new AcctSeed__Billing_Line__c();
                    bLine.AcctSeed__Billing__c = memo.Id;
                    bLine.AcctSeed__Rate__c = (fin.Total_Consolidated_Amount__c - fin.Total_Adjusted_Amount__c) * (-1);
                    bLine.AcctSeed__Hours_Units__c = 1;
                    bLine.Originator_LU__c = fin.Parent_Opportunity__r.Originator_LU__c;
                    bLine.Billing_Attorney_lk__c = fin.Parent_Opportunity__r.Billing_Attorney_lk__c;
                    matterIdAmountMap.put(memo.Matter__c, bLine.AcctSeed__Rate__c * (-1));
                    String key = '';
                    if(fin.Parent_Opportunity__r.Kapsten_Matter__c == 'Yes'){key = 'Instalment_GL_Account_Kapsten';}else{key = 'Instalment_GL_Account_JTL';}
                    //bline.AcctSeed__Revenue_GL_Account__c = glConfigMap.get(key);
                    if(!Test.isRunningTest()){
                        bline.AcctSeed__Revenue_GL_Account__c = glConfigMap.get(key);
                    }else{
                        bline.AcctSeed__Revenue_GL_Account__c = glAccount.Id;
                    }
                    if(officeMap.containsKey(fin.Parent_Opportunity__r.Office_that_consult_occurred_in__c)){
                        bLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(fin.Parent_Opportunity__r.Office_that_consult_occurred_in__c);
                    }
                    if(areaOfLawMap.containsKey(fin.Parent_Opportunity__r.Area_of_Law__c)){
                        bLine.AcctSeed__GL_Account_Variable_4__c = areaOfLawMap.get(fin.Parent_Opportunity__r.Area_of_Law__c);
                    }
                    bLineList.add(bLine);
                    matterIdMemoIdMap.put(fin.Matter__c, memo.Id);
                }
            }
            insert bLineList;
            

            // post bill
            AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(memoList);
            list<AcctSeed__Billing_Credit_Memo__c> bcmList = new list<AcctSeed__Billing_Credit_Memo__c>();
            
            
            for(AcctSeed__Billing__c bill : [Select Id, Name, AcctSeed__Opportunity__c, AcctSeed__Balance__c, Matter__c From AcctSeed__Billing__c Where Matter__c In : matterIdMemoIdMap.keySet() And AcctSeed__Balance__c > 0 AND AcctSeed__Opportunity__c != null AND AcctSeed__Type__c = 'Invoice' Order by Matter__c]){
                System.debug('****AyFinanceHandler***createFinanceAccounting***bill==='+bill.name + ' | ' + bill.Id + ' | ' + bill.AcctSeed__Balance__c);
                if(matterIdMemoIdMap.containsKey(bill.Matter__c) && matterIdAmountMap.containsKey(bill.Matter__c)){
                    Decimal amount = matterIdAmountMap.get(bill.Matter__c);
                    if(amount > 0){
                        Decimal amountToApply;
                        if(amount >= bill.AcctSeed__Balance__c){
                            amountToApply = bill.AcctSeed__Balance__c;
                        }else{
                            amountToApply = amount;
                        }
                        AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                        bcm.AcctSeed__Billing_Credit_Memo__c = matterIdMemoIdMap.get(bill.Matter__c);
                        bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                        bcm.AcctSeed__Accounting_Period__c = accountingPeriodId;
                        bcm.AcctSeed__Amount__c = amountToApply * (-1);
                        bcm.AcctSeed__Applied_Date__c = Date.today();
                        bcmList.add(bcm);
                        
                        matterIdAmountMap.put(bill.Matter__c, amount - amountToApply);
                        
                    }
                }
            }
            if(bcmList.size() > 0){
                insert bcmList;
            }
        }

        //2. Create New Bills for installments
        list<AcctSeed__Billing__c> billingList = new list<AcctSeed__Billing__c>();

        // 2.1. downpayment bill
        for(Finance__c fin : financeBillingMap.values()){

            String ledgerKey = 'JTL_Ledger_Id';
            if(fin.Parent_Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }

            AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
            bill.AcctSeed__Status__c = 'Approved';
            bill.AcctSeed__Customer__c = fin.Parent_Opportunity__r.AccountId;
            bill.Finance__c = fin.Id;
            bill.Matter__c = fin.Matter__c;
            bill.Finance_Type__c = 'Downpayment';
            bill.AcctSeed__Billing_Comment__c = 'Downpayment';
            bill.AcctSeed__Opportunity__c = fin.Parent_Opportunity__c;
            bill.AcctSeed__Customer__c = fin.Parent_Opportunity__r.AccountId;
            bill.AcctSeed__Date__c = Date.today();
            bill.AcctSeed__Ledger__c = configMap.get(ledgerKey);
            bill.AcctSeed__Due_Date2__c = Date.today();
            bill.AcctSeed__Accounting_Period__c = accountingPeriodId;
            bill.Originator__c = fin.Parent_Opportunity__r.Originator_LU__c;
            bill.Billing_Attorney__c = fin.Parent_Opportunity__r.Billing_Attorney_lk__c;
            billingList.add(bill);
        }

        // 2.2 Installmemt bills
        for(Finance__c fin : financeBillingMap.values()){
            
            Integer freqDays = 0;
            if(fin.Payment_Frequency__c == 'Weekly'){
                freqDays = 7;
            }else if(fin.Payment_Frequency__c == 'Bi-weekly'){
                freqDays = 14;
            }else if(fin.Payment_Frequency__c == 'Monthly'){
                freqDays = 30;   
            }

            String ledgerKey = 'JTL_Ledger_Id';
            if(fin.Parent_Opportunity__r.Kapsten_Matter__c == 'Yes'){
                ledgerKey = 'Kapsten_Ledger_Id';
            }

            Integer noOfInstallments = 0;
            if(fin.No_of_Instalments__c != null){
                noOfInstallments = Integer.valueOf(fin.No_of_Instalments__c);    
            }

            if(noOfInstallments > 0 && freqDays > 0){
                Integer monthsCount = 1;
                Integer freqDaysTemp = freqDays;
                for(Integer i = 0; i < noOfInstallments; i++){
                    AcctSeed__Billing__c bill = new AcctSeed__Billing__c();
                    bill.AcctSeed__Status__c = 'Approved';
                    bill.AcctSeed__Customer__c = fin.Parent_Opportunity__r.AccountId;
                    bill.Finance__c = fin.Id;
                    bill.Matter__c = fin.Matter__c;
                    bill.Finance_Type__c = 'Instalment';
                    bill.AcctSeed__Ledger__c = configMap.get(ledgerKey);
                    bill.AcctSeed__Opportunity__c = fin.Parent_Opportunity__c;
                    bill.AcctSeed__Date__c = Date.today();
                    bill.AcctSeed__Customer__c = fin.Parent_Opportunity__r.AccountId;
                    bill.Originator__c = fin.Parent_Opportunity__r.Originator_LU__c;
                    bill.Billing_Attorney__c = fin.Parent_Opportunity__r.Billing_Attorney_lk__c;
                    if(i == 0){
                        bill.AcctSeed__Due_Date2__c = fin.First_Instalment_Payment_Date__c; 
                    }else{
                        if(freqDays != 30){
                            bill.AcctSeed__Due_Date2__c = fin.First_Instalment_Payment_Date__c.addDays(freqDaysTemp);
                            freqDaysTemp += freqDays;
                        }else{
                            bill.AcctSeed__Due_Date2__c = fin.First_Instalment_Payment_Date__c.addMonths(monthsCount);  
                            monthsCount++;  
                        } 
                    }
                    
                    bill.AcctSeed__Accounting_Period__c = accountingPeriodId;
                    billingList.add(bill);
                }
            }
        }

        if(billingList.size() > 0){
            insert billingList;

            // to populate office on billing line
            //map<String,Id> officeMap = new map<String,Id>();
            //for(AcctSeed__Accounting_Variable__c av : [Select Id, Name From AcctSeed__Accounting_Variable__c Where AcctSeed__Type__c = 'GL Account Variable 1' AND AcctSeed__Active__c = true]){
                //officeMap.put(av.Name, av.Id);
            //}

            // Create billing lines
            list<AcctSeed__Billing_Line__c> billingLinesList = new list<AcctSeed__Billing_Line__c>();
            map<Id,Decimal> financeInstallmentTotalMap = new map<Id,Decimal>();
            for(AcctSeed__Billing__c bill : billingList){
                if(financeBillingMap.containsKey(bill.Finance__c)){
                    Finance__c fin = financeBillingMap.get(bill.Finance__c);
                    if(!financeInstallmentTotalMap.containsKey(fin.Id)){
                        financeInstallmentTotalMap.put(fin.Id, (fin.Total_Consolidated_Amount__c - fin.Downpayment__c));
                    }
                    AcctSeed__Billing_Line__c bline = new AcctSeed__Billing_Line__c();
                    bLine.AcctSeed__Billing__c = bill.Id;
                    if(bill.AcctSeed__Billing_Comment__c == 'Downpayment'){
                        bLine.AcctSeed__Rate__c = fin.Downpayment__c;
                    }else{

                        Decimal amountToSettle = financeInstallmentTotalMap.get(fin.Id);
                        Decimal installmentAmount = ( (fin.Total_Consolidated_Amount__c - fin.Downpayment__c) / fin.No_of_Instalments__c).setScale(2);
                        //System.debug('****amountToSettle=='+amountToSettle);
                        //System.debug('****installmentAmount=='+installmentAmount);
                        Decimal diff = amountToSettle - installmentAmount;
                        //System.debug('****diff=='+diff);
                        if(diff >= 0){
                            bLine.AcctSeed__Rate__c = installmentAmount;
                            //System.debug('**settled via installment amount**');
                            financeInstallmentTotalMap.put(fin.Id, diff);
                        }else{  // in case of overpaid
                            bLine.AcctSeed__Rate__c = amountToSettle;
                            //System.debug('**settled via diff**');
                        }
                        
                        // in case underpaid
                        if(diff > 0 && diff < 1){
                            System.debug('**HERE**'+diff);
                            bLine.AcctSeed__Rate__c = bLine.AcctSeed__Rate__c + diff;  
                        }
                    }
                    String key = '';
                    if(fin.Parent_Opportunity__r.Kapsten_Matter__c == 'Yes'){key = 'Instalment_GL_Account_Kapsten';}else{key = 'Instalment_GL_Account_JTL';}
                    //bline.AcctSeed__Revenue_GL_Account__c = glConfigMap.get(key);
                    if(!Test.isRunningTest()){
                        bline.AcctSeed__Revenue_GL_Account__c = glConfigMap.get(key);
                    }else{
                        bline.AcctSeed__Revenue_GL_Account__c = glAccount.Id;
                    }
                    if(officeMap.containsKey(fin.Parent_Opportunity__r.Office_that_consult_occurred_in__c)){
                        bLine.AcctSeed__GL_Account_Variable_1__c = officeMap.get(fin.Parent_Opportunity__r.Office_that_consult_occurred_in__c);
                    }
                    if(areaOfLawMap.containsKey(fin.Parent_Opportunity__r.Area_of_Law__c)){
                        bLine.AcctSeed__GL_Account_Variable_4__c = areaOfLawMap.get(fin.Parent_Opportunity__r.Area_of_Law__c);
                    }
                    bLine.AcctSeed__Hours_Units__c = 1;
                    bLine.Originator_LU__c = fin.Parent_Opportunity__r.Originator_LU__c;
                    bLine.Billing_Attorney_lk__c = fin.Parent_Opportunity__r.Billing_Attorney_lk__c;
                    billingLinesList.add(bLine);
                }
            }

            if(billingLinesList.size() > 0){
                insert billingLinesList;
            }

            // post new bills
            AcctSeed.PostResult[] postResults = AcctSeed.BillingPostService.postBillings(billingList);
        }
    }

    // to get accounting period of a date
    public static Id getAccountingPeriod(Date d){
        Id periodId  ;
        for(AcctSeed__Accounting_Period__c period : [Select Id from AcctSeed__Accounting_Period__c where AcctSeed__Start_Date__c <=:d AND AcctSeed__End_Date__c >=:d AND AcctSeed__Status__c='Open' order by AcctSeed__Start_Date__c limit 1]){
            periodId = period.Id;
        }
        return periodId;
    }
    
    // @desc   : method to populate rollup values on finance opportunity
    // @param  : set<Id> financeOpportunity Ids
    // @return : void
    public static void populateRollupValues(set<Id> financeOppIds){

        //System.debug('****AyFinanceHandler***populateRollupValues***');
        
        set<Id> oppIds = new set<Id>();
        set<Id> matterIds = new set<Id>();
        set<Id> oppIds_ForUnbilled = new set<Id>();
        list<Finance_Opportunity__c> fopList = [Select Id, Matter__c, Opportunity__c, Opportunity__r.StageName From Finance_Opportunity__c Where Id IN : financeOppIds];
        for(Finance_Opportunity__c fop : fopList){
            oppIds.add(fop.Opportunity__c);
            matterIds.add(fop.Matter__c);
            if(fop.Opportunity__r.StageName != 'Closed Won'){
                oppIds_ForUnbilled.add(fop.Opportunity__c);
            }
        }
        //System.debug('****AyFinanceHandler***populateRollupValues***oppIds='+oppIds);
        //System.debug('****AyFinanceHandler***populateRollupValues***matterIds='+matterIds);

        // fetch total, received and waved off amount
        // for standard
        map<Id,AyFinanceHandler.RollUpDataWrapper> oppIdRollupDataMap = new map<Id,AyFinanceHandler.RollUpDataWrapper>();
        for(AggregateResult ag : [Select AcctSeed__Opportunity__c, SUM(AcctSeed__Total__c) total, SUM(AcctSeed__Received_Amount__c) rec, SUM(AcctSeed__Credit_Memo_Applied_Amount__c) wavedOff 
                                    From AcctSeed__Billing__c
                                   Where AcctSeed__Opportunity__c IN : oppIds AND Next_Step_Opportunity__c = null AND AcctSeed__Balance__c != 0
                                   Group By AcctSeed__Opportunity__c]){
            Id oppId = (Id) ag.get('AcctSeed__Opportunity__c');
            
            AyFinanceHandler.RollUpDataWrapper wrap  = new AyFinanceHandler.RollUpDataWrapper();
            wrap.oppId = oppId;
            wrap.total = (Decimal) ag.get('total');
            wrap.received = (Decimal) ag.get('rec');
            wrap.wavedOff = (Decimal) ag.get('wavedOff');
            oppIdRollupDataMap.put(oppId, wrap);
        }
        //System.debug('****AyFinanceHandler***populateRollupValues***oppIdRollupDataMap='+oppIdRollupDataMap);
        
        // fetch total, received and waved off amount
        // for next step    
        for(AggregateResult ag : [Select Next_Step_Opportunity__c, SUM(AcctSeed__Total__c) total, SUM(AcctSeed__Received_Amount__c) rec, SUM(AcctSeed__Credit_Memo_Applied_Amount__c) wavedOff 
                                    From AcctSeed__Billing__c
                                   Where Next_Step_Opportunity__c IN : oppIds AND AcctSeed__Balance__c != 0
                                   Group By Next_Step_Opportunity__c]){
            Id oppId = (Id) ag.get('Next_Step_Opportunity__c');
            
            AyFinanceHandler.RollUpDataWrapper wrap  = new AyFinanceHandler.RollUpDataWrapper();
            wrap.oppId = oppId;
            wrap.total = (Decimal) ag.get('total');
            wrap.received = (Decimal) ag.get('rec');
            wrap.wavedOff = (Decimal) ag.get('wavedOff');
            oppIdRollupDataMap.put(oppId, wrap);
        }
        //System.debug('****AyFinanceHandler***populateRollupValues***oppIdRollupDataMap 2=='+oppIdRollupDataMap);

        // fetch adjusted balance from matter
        for(AcctSeed__Project__c matter : [Select Id, AcctSeed__Opportunity__c, Adjusted_Balance__c From AcctSeed__Project__c Where Id IN : matterIds]){
            
            if(oppIdRollupDataMap.containsKey(matter.AcctSeed__Opportunity__c)){
                AyFinanceHandler.RollUpDataWrapper wrap  = oppIdRollupDataMap.get(matter.AcctSeed__Opportunity__c);
                
                if(matter.Adjusted_Balance__c < 0){
                    wrap.adjustedAmount = matter.Adjusted_Balance__c * (-1);
                }else{
                    wrap.adjustedAmount = matter.Adjusted_Balance__c;
                }
                
                oppIdRollupDataMap.put(matter.AcctSeed__Opportunity__c, wrap);
            }
        }
        //System.debug('****AyFinanceHandler***populateRollupValues***oppIdRollupDataMap 3=='+oppIdRollupDataMap);

        // check if next step matter exists
        for(Opportunity opp : [Select Id, Next_Step_Matter__r.Adjusted_Balance__c From Opportunity Where Next_Step_Matter__c != null AND Next_Step_Matter__c IN : matterIds]){
            
            if(oppIdRollupDataMap.containsKey(opp.Id)){
                AyFinanceHandler.RollUpDataWrapper wrap  = oppIdRollupDataMap.get(opp.Id);
                
                if(opp.Next_Step_Matter__r.Adjusted_Balance__c < 0){
                    wrap.adjustedAmount = opp.Next_Step_Matter__r.Adjusted_Balance__c * (-1);
                }else{
                    wrap.adjustedAmount = opp.Next_Step_Matter__r.Adjusted_Balance__c;
                }
                
                //wrap.adjustedAmount = opp.Next_Step_Matter__r.Adjusted_Balance__c;
                oppIdRollupDataMap.put(opp.Id, wrap);
            }
        }
        //System.debug('****AyFinanceHandler***populateRollupValues***oppIdRollupDataMap final=='+oppIdRollupDataMap);

        if(oppIds_ForUnbilled.size() > 0){
            for(AggregateResult ag : [Select Id, SUM(Amount)totalUnbilled From Opportunity Where Id In : oppIds_ForUnbilled Group By Id]){
                Id oppId = (Id) ag.get('Id');
                AyFinanceHandler.RollUpDataWrapper wrap;
                if(oppIdRollupDataMap.containsKey(oppId)){
                    wrap = oppIdRollupDataMap.get(oppId);
                }else{
                    wrap = new AyFinanceHandler.RollUpDataWrapper();
                    wrap.oppId = oppId;
                }
                wrap.unbilledAmount = (Decimal) ag.get('totalUnbilled');
                oppIdRollupDataMap.put(oppId, wrap);
            }
        }


        // popualte back in finance opportunity
        for(Finance_Opportunity__c fop : fopList){
            if(oppIdRollupDataMap.containsKey(fop.Opportunity__c)){
                AyFinanceHandler.RollUpDataWrapper wrap  = oppIdRollupDataMap.get(fop.Opportunity__c);
                fop.Billed_Amount__c = wrap.total;
                fop.Received_Amount__c = wrap.received;
                fop.Waved_Off_Amount__c = wrap.wavedOff;
                fop.Adjusted_Balance__c = wrap.adjustedAmount;
                fop.Unbilled_Amount__c = wrap.unbilledAmount;
            }
        }

        if(fopList.size() > 0){
            update fopList;
        }
    }

    public class RollUpDataWrapper{
        public Id oppId {get;set;}
        public Decimal total{get;set;}
        public Decimal received{get;set;}
        public Decimal wavedOff {get;set;}
        public Decimal adjustedAmount {get;set;}
        public Decimal unbilledAmount {get;set;}
    }

}