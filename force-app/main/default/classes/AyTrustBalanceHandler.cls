public class AyTrustBalanceHandler{

    /***
     * @desc   : Method to create trust activity statement
     * @params : set<Id> trustBalanceIds
     * @return : void
     ***/
    public static void createTrustActivityStatement(set<Id> trustBalanceIds){
        
        map<String,Id> keyBalanceMap = new map<String,Id>();
        set<Id> accountingPeriodIds = new set<Id>();
        set<Id> matterIds = new set<Id>();
        
        // fetch data
        set<Id> crIds = new set<Id>();
        set<Id> bcrIds = new set<Id>();
        set<Id> cdIds = new set<Id>();
        set<Id> billingIds = new set<Id>();
        set<Id> bLineIds = new set<Id>();
        set<Id> payableIds = new set<Id>();
        set<Id> payableLineIds = new set<Id>();
        set<Id> jeLineIds = new set<Id>();

        for(Trust_Balance__c tb : [Select Id, Accounting_Period__c, Matter__c, 
                                          (Select Id, Cash_Receipt__c, Cash_Disbursement__c, Billing_Cash_Receipt__c, Billing__c, Billing_Line__c, Payable__c, Payable_Line__c, Journal_Entry_Line__c From Trust_Account_Activities__r) 
                                     From Trust_Balance__c 
                                    Where Id IN : trustBalanceIds]){
            if(tb.Matter__c != null && tb.Accounting_Period__c != null){
                accountingPeriodIds.add(tb.Accounting_Period__c);
                matterIds.add(tb.Matter__c);
                String key = tb.Accounting_Period__c + ':' + tb.Matter__c;
                keyBalanceMap.put(key, tb.Id);
                
                for(Trust_Account_Activity__c accActivity : tb.Trust_Account_Activities__r){
                    if(accActivity.Cash_Receipt__c != null){
                        crIds.add(accActivity.Cash_Receipt__c);
                    }
                    if(accActivity.Billing_Cash_Receipt__c != null){
                        bcrIds.add(accActivity.Billing_Cash_Receipt__c);
                    }
                    if(accActivity.Cash_Disbursement__c != null){
                        cdIds.add(accActivity.Cash_Disbursement__c);
                    }
                    if(accActivity.Billing__c != null){
                        billingIds.add(accActivity.Billing__c);
                    }
                    if(accActivity.Billing_Line__c != null){
                        bLineIds.add(accActivity.Billing_Line__c);
                    }
                    if(accActivity.Payable__c != null){
                        payableIds.add(accActivity.Payable__c);
                    }
                    if(accActivity.Payable_Line__c != null){
                        payableLineIds.add(accActivity.Payable_Line__c);
                    }
                    if(accActivity.Journal_Entry_Line__c != null){
                        jeLineIds.add(accActivity.Journal_Entry_Line__c);
                    }
                }

            }
        }

        list<Trust_Account_Activity__c> trustAccountActivityList = new list<Trust_Account_Activity__c>();
        System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***matterIds=='+matterIds);
        System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***accountingPeriodIds=='+accountingPeriodIds);
        System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***crIds=='+crIds);
        //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***cdIds=='+cdIds);
        //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***bcrIds=='+bcrIds);
        //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***billingIds=='+billingIds);
        //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***bLineIds=='+bLineIds);
        //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***payableIds=='+payableIds);

        // process all cash receipts
        for(AcctSeed__Cash_Receipt__c cr : [Select Id, AcctSeed__Accounting_Period__c, AcctSeed__Project__c, AcctSeed__Amount__c, AcctSeed__Bank_Account__c 
                                              From AcctSeed__Cash_Receipt__c
                                             Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                               AND AcctSeed__Project__c IN : matterIds
                                               AND Id NOT IN : crIds
                                               AND AcctSeed__Bank_Account__r.Is_Trust_Account__c = true
                                               AND AcctSeed__Status__c = 'Posted']){
            if(cr.AcctSeed__Accounting_Period__c != null && cr.AcctSeed__Project__c != null){       
                String key = cr.AcctSeed__Accounting_Period__c + ':' +cr.AcctSeed__Project__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Cash_Receipt__c = cr.Id;
                    //taa.Trust_Account_GL_Code__c = cr.AcctSeed__Bank_Account__c;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all billing cash receipts
        for(AcctSeed__Billing_Cash_Receipt__c bcr : [Select Id, AcctSeed__Accounting_Period__c, Matter_ID__c, AcctSeed__Applied_Amount__c 
                                                       From AcctSeed__Billing_Cash_Receipt__c
                                                      Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds
                                                        AND Id NOT IN : bcrIds
                                                        AND Is_SYS_Trust_Account_Activity__c = true
                                                        AND Matter_ID__c IN : matterIds]){
            if(bcr.AcctSeed__Accounting_Period__c != null && bcr.Matter_ID__c != null){       
                String key = bcr.AcctSeed__Accounting_Period__c + ':' + bcr.Matter_ID__c;
                //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***Matter_ID__c=='+bcr.Matter_ID__c);
                //System.debug('****AyTrustBalanceHandler***createTrustActivityStatement***key=='+key);
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Billing_Cash_Receipt__c = bcr.Id;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all cash disbursements
        for(AcctSeed__Cash_Disbursement__c cd : [Select Id, AcctSeed__Accounting_Period__c, AcctSeed__Project__c, AcctSeed__Amount__c, AcctSeed__Bank_Account__c 
                                                   From AcctSeed__Cash_Disbursement__c
                                                  Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                                    AND AcctSeed__Project__c IN : matterIds
                                                    AND Id NOT IN : cdIds
                                                    AND Is_SYS_Trust_Account_Activity__c = true
                                                    AND AcctSeed__Bank_Account__r.Is_Trust_Account__c = true
                                                    AND AcctSeed__Status__c = 'Posted']){
            if(cd.AcctSeed__Accounting_Period__c != null && cd.AcctSeed__Project__c != null){       
                String key = cd.AcctSeed__Accounting_Period__c + ':' +cd.AcctSeed__Project__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Cash_Disbursement__c = cd.Id;
                    //taa.Trust_Account_GL_Code__c = cd.AcctSeed__Bank_Account__c;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all bills
        for(AcctSeed__Billing__c bill : [Select Id, Matter__c, AcctSeed__Accounting_Period__c, 
                                                (Select Id, AcctSeed__Total__c From AcctSeed__Project_Billing_Lines__r) 
                                           From AcctSeed__Billing__c 
                                          Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                            AND Matter__c IN : matterIds
                                            AND Id NOT IN : billingIds
                                            AND AcctSeed__Status__c = 'Posted']){
            if(bill.AcctSeed__Accounting_Period__c != null && bill.Matter__c != null){       
                String key = bill.AcctSeed__Accounting_Period__c + ':' +bill.Matter__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Billing__c = bill.Id;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all billing lines
        for(AcctSeed__Billing_Line__c bl : [Select Id, AcctSeed__Billing__r.AcctSeed__Accounting_Period__c, AcctSeed__Project__c 
                                              From AcctSeed__Billing_Line__c 
                                             Where AcctSeed__Billing__r.AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                               AND AcctSeed__Project__c IN : matterIds 
                                               AND Id NOT IN : bLineIds
                                               AND AcctSeed__Billing__r.AcctSeed__Status__c = 'Posted']){
            String key = bl.AcctSeed__Billing__r.AcctSeed__Accounting_Period__c + ':' +bl.AcctSeed__Project__c;
            if(keyBalanceMap.containsKey(key)){    
                Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                taa.Trust_Balance__c = keyBalanceMap.get(key);
                taa.Billing_Line__c = bl.Id;
                trustAccountActivityList.add(taa);
            }
        }

        // process all payables
        for(AcctSeed__Account_Payable__c ap : [Select Id, Matter__c, AcctSeed__Accounting_Period__c,
                                                      (Select Id, AcctSeed__Amount__c From AcctSeed__Project_Account_Payable_Lines__r)    
                                                 From AcctSeed__Account_Payable__c
                                                Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                                  AND Matter__c IN : matterIds
                                                  AND Id NOT IN : payableIds
                                                  AND AcctSeed__Status__c = 'Posted']){
            if(ap.AcctSeed__Accounting_Period__c != null && ap.Matter__c != null){       
                String key = ap.AcctSeed__Accounting_Period__c + ':' +ap.Matter__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Payable__c = ap.Id;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all payable lines
        for(AcctSeed__Account_Payable_Line__c apl : [Select Id, AcctSeed__Account_Payable__r.AcctSeed__Accounting_Period__c, AcctSeed__Project__c 
                                                       From AcctSeed__Account_Payable_Line__c 
                                                      Where AcctSeed__Account_Payable__r.AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                                        AND AcctSeed__Project__c IN : matterIds 
                                                        AND Id NOT IN : payableLineIds
                                                        AND AcctSeed__Account_Payable__r.AcctSeed__Status__c = 'Posted']){
            String key = apl.AcctSeed__Account_Payable__r.AcctSeed__Accounting_Period__c + ':' +apl.AcctSeed__Project__c;
            if(keyBalanceMap.containsKey(key)){
                Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                taa.Trust_Balance__c = keyBalanceMap.get(key);
                taa.Payable_Line__c = apl.Id;
                trustAccountActivityList.add(taa);
            }
        }

        // process all je lines
        for(AcctSeed__Journal_Entry_Line__c jel : [Select Id, AcctSeed__Debit__c, AcctSeed__Credit__c, AcctSeed__Journal_Entry__c, AcctSeed__Journal_Entry__r.AcctSeed__Accounting_Period__c, AcctSeed__Project__c 
                                                     From AcctSeed__Journal_Entry_Line__c
                                                    Where AcctSeed__Journal_Entry__r.AcctSeed__Accounting_Period__c IN : accountingPeriodIds
                                                      AND AcctSeed__Project__c IN : matterIds
                                                      AND AcctSeed__GL_Account__r.Is_Trust_Account__c = true
                                                      AND Id NOT IN : jeLineIds
                                                      AND AcctSeed__Journal_Entry__r.AcctSeed__Status__c = 'Posted']){
            if(jel.AcctSeed__Journal_Entry__r.AcctSeed__Accounting_Period__c != null && jel.AcctSeed__Project__c != null){       
                String key = jel.AcctSeed__Journal_Entry__r.AcctSeed__Accounting_Period__c + ':' +jel.AcctSeed__Project__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Journal_Entry_Line__c = jel.Id;
                    taa.Journal_Entry__c = jel.AcctSeed__Journal_Entry__c;
                    //taa.Withdrawal__c = jel.AcctSeed__Credit__c;
                    trustAccountActivityList.add(taa);
                }
            }    
        }

        // insert trust activity statements
        if(trustAccountActivityList.size() > 0){
            insert trustAccountActivityList;
        }
    }
    
    /***
     * @desc   : Method to create trust activity statement FOR FLAT FEE
     * @params : set<Id> trustBalanceIds
     * @return : void
     ***
    public static void createTrustActivityStatementFlatFee(set<Id> trustBalanceIds){
        
        map<String,Id> keyBalanceMap = new map<String,Id>();
        set<Id> accountingPeriodIds = new set<Id>();
        set<Id> matterIds = new set<Id>();
        
        // fetch data
        set<Id> crIds = new set<Id>();
        set<Id> bcrIds = new set<Id>();
        set<Id> cdIds = new set<Id>();
        

        for(Trust_Balance__c tb : [Select Id, Accounting_Period__c, Matter__c, 
                                          (Select Id, Cash_Receipt__c, Cash_Disbursement__c, Billing_Cash_Receipt__c, Billing__c, Billing_Line__c, Payable__c, Payable_Line__c, Journal_Entry_Line__c From Trust_Account_Activities__r) 
                                     From Trust_Balance__c 
                                    Where Id IN : trustBalanceIds]){
            if(tb.Matter__c != null && tb.Accounting_Period__c != null){
                accountingPeriodIds.add(tb.Accounting_Period__c);
                matterIds.add(tb.Matter__c);
                String key = tb.Accounting_Period__c + ':' + tb.Matter__c;
                keyBalanceMap.put(key, tb.Id);
                
                for(Trust_Account_Activity__c accActivity : tb.Trust_Account_Activities__r){
                    if(accActivity.Cash_Receipt__c != null){
                        crIds.add(accActivity.Cash_Receipt__c);
                    }
                    if(accActivity.Billing_Cash_Receipt__c != null){
                        bcrIds.add(accActivity.Billing_Cash_Receipt__c);
                    }
                    if(accActivity.Cash_Disbursement__c != null){
                        cdIds.add(accActivity.Cash_Disbursement__c);
                    }
                }
            }
        }

        list<Trust_Account_Activity__c> trustAccountActivityList = new list<Trust_Account_Activity__c>();
        

        // process all cash receipts
        for(AcctSeed__Cash_Receipt__c cr : [Select Id, AcctSeed__Accounting_Period__c, AcctSeed__Project__c, AcctSeed__Amount__c, AcctSeed__Bank_Account__c 
                                              From AcctSeed__Cash_Receipt__c
                                             Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                               AND AcctSeed__Project__c IN : matterIds
                                               AND Id NOT IN : crIds
                                               //AND Include_in_Trust_Balance__c = true
                                               AND AcctSeed__Status__c = 'Posted']){
            if(cr.AcctSeed__Accounting_Period__c != null && cr.AcctSeed__Project__c != null){       
                String key = cr.AcctSeed__Accounting_Period__c + ':' +cr.AcctSeed__Project__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Cash_Receipt__c = cr.Id;
                    //taa.Trust_Account_GL_Code__c = cr.AcctSeed__Bank_Account__c;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all billing cash receipts
        for(AcctSeed__Billing_Cash_Receipt__c bcr : [Select Id, AcctSeed__Accounting_Period__c, Matter_ID__c, AcctSeed__Applied_Amount__c 
                                                       From AcctSeed__Billing_Cash_Receipt__c
                                                      Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds
                                                        AND Id NOT IN : bcrIds
                                                        AND Is_SYS_Trust_Account_Activity__c = true
                                                        AND Matter_ID__c IN : matterIds]){
            if(bcr.AcctSeed__Accounting_Period__c != null && bcr.Matter_ID__c != null){       
                String key = bcr.AcctSeed__Accounting_Period__c + ':' + bcr.Matter_ID__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Billing_Cash_Receipt__c = bcr.Id;
                    trustAccountActivityList.add(taa);
                }
            }
        }

        // process all cash disbursements
        for(AcctSeed__Cash_Disbursement__c cd : [Select Id, AcctSeed__Accounting_Period__c, AcctSeed__Project__c, AcctSeed__Amount__c, AcctSeed__Bank_Account__c 
                                                   From AcctSeed__Cash_Disbursement__c
                                                  Where AcctSeed__Accounting_Period__c IN : accountingPeriodIds 
                                                    AND AcctSeed__Project__c IN : matterIds
                                                    AND Id NOT IN : cdIds
                                                    AND Is_SYS_Trust_Account_Activity__c = true
                                                    //AND Include_in_Trust_Balance__c = true
                                                    AND AcctSeed__Status__c = 'Posted']){
            if(cd.AcctSeed__Accounting_Period__c != null && cd.AcctSeed__Project__c != null){       
                String key = cd.AcctSeed__Accounting_Period__c + ':' +cd.AcctSeed__Project__c;
                if(keyBalanceMap.containsKey(key)){
                    Trust_Account_Activity__c taa = new Trust_Account_Activity__c();
                    taa.Trust_Balance__c = keyBalanceMap.get(key);
                    taa.Cash_Disbursement__c = cd.Id;
                    //taa.Trust_Account_GL_Code__c = cd.AcctSeed__Bank_Account__c;
                    trustAccountActivityList.add(taa);
                }
            }
        }
        
        // insert trust activity statements
        if(trustAccountActivityList.size() > 0){
            insert trustAccountActivityList;
        }

    }*/

    /***
     * @desc   : Method to delete trust activity statement
     * @params : set<Id> billingIds
     * @return : void
     ***/
    public static void handleBillingUnpost(set<Id> billingIds){

        set<Id> billingLineIds = new set<Id>();
        for(AcctSeed__Billing_Line__c bl : [Select Id, AcctSeed__Project__c From AcctSeed__Billing_Line__c Where AcctSeed__Billing__c In : billingIds]){
            billingLineIds.add(bl.Id);   
        }

        List<Trust_Account_Activity__c> activityList_toDelete = [Select Id From Trust_Account_Activity__c Where (Billing__c IN : billingIds OR Billing_Line__c IN : billingLineIds)];
        if(activityList_toDelete.size() > 0){
            delete activityList_toDelete;
        }
    }
	
    /***
     * @desc   : Method to delete trust activity statement
     * @params : set<Id> payableIds
     * @return : void
     ***/
    public static void handlePayableUnpost(set<Id> payableIds){

        
        // delete trust activity statement
        set<Id> payableLineIds = new set<Id>();
        for(AcctSeed__Account_Payable_Line__c pl : [Select Id, AcctSeed__Project__c From AcctSeed__Account_Payable_Line__c Where AcctSeed__Account_Payable__c In : payableIds]){
            payableLineIds.add(pl.Id);   
        }

        List<Trust_Account_Activity__c> activityList_toDelete = [Select Id From Trust_Account_Activity__c Where (Payable__c IN : payableIds OR Payable_Line__c IN : payableLineIds)];
        if(activityList_toDelete.size() > 0){
            delete activityList_toDelete;
        }
    }

    /***
     * @desc   : Method to delete trust activity statement
     * @params : set<Id> jeIds
     * @return : void
     ***/
    public static void handleJEUnpost(set<Id> jeLineIds){

        set<Id> jeIds = new set<Id>();
        for(AcctSeed__Journal_Entry_Line__c jel : [Select Id, AcctSeed__Journal_Entry__c From AcctSeed__Journal_Entry_Line__c Where Id In : jeLineIds]){
            jeIds.add(jel.AcctSeed__Journal_Entry__c);   
        }

        List<Trust_Account_Activity__c> activityList_toDelete = [Select Id From Trust_Account_Activity__c Where (Journal_Entry__c IN : jeIds OR Journal_Entry_Line__c IN : jeLineIds)];
        if(activityList_toDelete.size() > 0){
            delete activityList_toDelete;
        }
    }

    /***
     * @desc   : Method to delete trust activity statement
     * @params : set<Id> crIds
     * @return : void
     ***/
    public static void handleCRUnpost(set<Id> crIds){

        List<Trust_Account_Activity__c> activityList_toDelete = [Select Id From Trust_Account_Activity__c Where Cash_Receipt__c IN : crIds];
        if(activityList_toDelete.size() > 0){
            delete activityList_toDelete;
        }
    }

    /***
     * @desc   : Method to delete trust activity statement
     * @params : set<Id> cdIds
     * @return : void
     ***/
    public static void handleCDUnpost(set<Id> cdIds){

        List<Trust_Account_Activity__c> activityList_toDelete = [Select Id From Trust_Account_Activity__c Where Cash_Disbursement__c IN : cdIds];
        if(activityList_toDelete.size() > 0){
            delete activityList_toDelete;
        }
    }

    /***
     * @desc   : Method to delete trust activity statement
     * @params : set<Id> bcrIds
     * @return : void
     ***/
    public static void handleBCRDelete(set<Id> bcrIds){

        list<AcctSeed__Journal_Entry__c> jeList_toDelete = new list<AcctSeed__Journal_Entry__c>();
        list<AcctSeed__Journal_Entry__c> jeList_toUnpost = new list<AcctSeed__Journal_Entry__c>();
        for(AcctSeed__Journal_Entry__c je : [Select Id, AcctSeed__Status__c from AcctSeed__Journal_Entry__c Where Billing_Cash_Receipt__c IN : bcrIds AND AcctSeed__Accounting_Period__r.AcctSeed__Status__c = 'Open']){
            if(je.AcctSeed__Status__c == 'Posted'){
                jeList_toUnpost.add(je);
            }
            jeList_toDelete.add(je);
        }


        if(jeList_toUnpost.size() > 0){
            AcctSeed.PostResult[] unpostResults = AcctSeed.JournalEntryPostService.unpostJournalEntries(jeList_toUnpost);
        }

        if(jeList_toDelete.size() > 0){
            delete jeList_toDelete;
        }

        List<Trust_Account_Activity__c> activityList_toDelete = [Select Id From Trust_Account_Activity__c Where Billing_Cash_Receipt__c IN : bcrIds];
        if(activityList_toDelete.size() > 0){
            delete activityList_toDelete;
        }
    }

    /***
     * @desc   : Method to handle trust balance and account activity creation, called when transaction is inserted
     * @params : set<Id> matterIds
     * @return : void
     ***/
    public static void handleTrustBalanceCreation(map<Id,Id> matterIdAccountingPeriodIdMap){
        System.debug('****handleTrustBalanceCreation***matterIdAccountingPeriodIdMap='+matterIdAccountingPeriodIdMap);
        set<Id> tbalSet = new set<Id>();
        //set<Id> tbalSet_FF = new set<Id>();
        Date dt = Date.newInstance(2022,04,30);
        //Id accountingPeriodId = [Select Id From AcctSeed__Accounting_Period__c Where AcctSeed__Start_Date__c <=: dt AND AcctSeed__End_Date__c >=: dt AND AcctSeed__Status__c = 'Open'].Id;

        /*map<Id,String> matterIdOppTypeMap = new map<Id,String>();
        for(AcctSeed__Project__c proj : [Select Id, AcctSeed__Opportunity__r.Rate_Type__c From AcctSeed__Project__c Where Id IN : matterIdAccountingPeriodIdMap.keySet()]){
            matterIdOppTypeMap.put(proj.Id, proj.AcctSeed__Opportunity__r.Rate_Type__c);
        }*/

        set<Id> accountingPeriodIds = new set<Id>();
        for(AcctSeed__Accounting_Period__c ap : [Select Id From AcctSeed__Accounting_Period__c Where AcctSeed__End_Date__c <=: dt Order By AcctSeed__End_Date__c DESC LIMIT 50]){
            accountingPeriodIds.add(ap.Id);
        }

        map<Id,Trust_Balance__c> matterIdTrustBalanceMap = new map<Id,Trust_Balance__c>();
        for(Trust_Balance__c tb : [Select Id, Matter__c From Trust_Balance__c Where Matter__c IN : matterIdAccountingPeriodIdMap.keySet() AND Accounting_Period__c IN : matterIdAccountingPeriodIdMap.values()]){
            tbalSet.add(tb.Id);
            matterIdTrustBalanceMap.put(tb.Matter__c, tb);
            /*if(matterIdOppTypeMap.containsKey(tb.Matter__c)){
                matterIdTrustBalanceMap.put(tb.Matter__c, tb);
                if(matterIdOppTypeMap.get(tb.Matter__c) == 'Flat Fee'){
                    tbalSet_FF.add(tb.Id);
                }else{
                    tbalSet.add(tb.Id);  
                }
            }*/
        }

        map<Id, AcctSeed__Project__c> matterMap = new map<Id,AcctSeed__Project__c>([Select Id, AcctSeed__Account__c, AcctSeed__Account__r.AcctSeed__Billing_Contact__c From AcctSeed__Project__c Where Id IN : matterIdAccountingPeriodIdMap.keySet()]);
        list<Trust_Balance__c> tbalList = new list<Trust_Balance__c>();
        for(Id mid : matterIdAccountingPeriodIdMap.keySet()){
            if(!matterIdTrustBalanceMap.containsKey(mid) && !accountingPeriodIds.contains(matterIdAccountingPeriodIdMap.get(mid))){
                Trust_Balance__c tbal = new Trust_Balance__c();
                tbal.Matter__c = mid;
                if(matterMap.containsKey(mid) && matterMap.get(mid).AcctSeed__Account__c != null){
                    tbal.Account__c = matterMap.get(mid).AcctSeed__Account__c;
                    tbal.Billing_Contact__c = matterMap.get(mid).AcctSeed__Account__r.AcctSeed__Billing_Contact__c;
                }
                tbal.Accounting_Period__c = matterIdAccountingPeriodIdMap.get(mid);
                tbal.Date_of_Trust_Account_Creation__c = Date.today();
                tbalList.add(tbal);
            }
        }

        if(tbalList.size() > 0){
            insert tbalList;
            for(Trust_Balance__c tb : tbalList){
                tbalSet.add(tb.Id);
                /*if(matterIdOppTypeMap.containsKey(tb.Matter__c)){
                    if(matterIdOppTypeMap.get(tb.Matter__c) == 'Flat Fee'){
                        tbalSet_FF.add(tb.Id);
                    }else{
                        tbalSet.add(tb.Id);  
                    }
                }*/
            }
        }
        
        if(tbalSet.size() > 0){
            AyTrustBalanceHandler.createTrustActivityStatement(tbalSet);
        }

        // for flat fee
        //if(tbalSet_FF.size() > 0){
            //AyTrustBalanceHandler.createTrustActivityStatementFlatFee(tbalSet_FF);
        //}
    }

    /***
     * @desc   : Method to handle settlement of Hardcost Bill
     * @params : set<Id> billIds
     * @return : void
     ***/
    public static void handleHardcostBillSettlement(set<Id> billIds){

        /********************************************************************************/
            // code flow : 
            // 1. first check for open credit memo
            // 2. apply if any open credit memo found
            // 3. get all cash receipts from trust account activity and auto apply them
        /********************************************************************************/

        list<AcctSeed__Billing__c> billingList = [Select Id, AcctSeed__Opportunity__c, Next_Step_Opportunity__c, Name, AcctSeed__Ledger__c, AcctSeed__Customer__c, Matter__c, Matter__r.Trust_Balance__c, Matter__r.Trust_Balance__r.Closing_Balance__c, AcctSeed__Balance__c From AcctSeed__Billing__c Where Id IN : billIds Order By AcctSeed__Due_Date2__c DESC];
        
        // 1. first check for open credit memo
        set<Id> oppIds = new set<Id>();
        set<Id> nextStepOppIds = new set<Id>();
        set<Id> trustBalanceIds = new set<Id>();
        map<Id,Decimal> billingBalMap = new map<Id,Decimal>();

        for(AcctSeed__Billing__c bill : billingList){
            oppIds.add(bill.AcctSeed__Opportunity__c);
            nextStepOppIds.add(bill.Next_Step_Opportunity__c);
            billingBalMap.put(bill.Id, bill.AcctSeed__Balance__c);
            trustBalanceIds.add(bill.Matter__r.Trust_Balance__c);
        }
        
        // 2. apply if any open credit memo found
        System.debug('****handleHardcostBillSettlement***oppIds='+oppIds);
        System.debug('****handleHardcostBillSettlement***nextStepOppIds='+nextStepOppIds);
        System.debug('****handleHardcostBillSettlement***billingBalMap='+billingBalMap);
        System.debug('****handleHardcostBillSettlement***trustBalanceIds='+trustBalanceIds);

        list<AcctSeed__Billing_Credit_Memo__c> bcmList = new list<AcctSeed__Billing_Credit_Memo__c>();
        for(AcctSeed__Billing__c memo : [Select Id, AcctSeed__Balance__c, AcctSeed__Accounting_Period__c, AcctSeed__Opportunity__c, Next_Step_Opportunity__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__c IN : oppIds AND ( (Next_Step_Opportunity__c IN : nextStepOppIds AND Next_Step_Opportunity__c != null) OR (Next_Step_Opportunity__c = null) ) AND AcctSeed__Type__c = 'Credit Memo' AND AcctSeed__Balance__c < 0 AND AcctSeed__Status__c = 'Posted']){
            Decimal memoBalance = memo.AcctSeed__Balance__c;
            for(AcctSeed__Billing__c bill : billingList){
                Decimal billingBal = billingBalMap.get(bill.Id);
                if(memo.AcctSeed__Opportunity__c == bill.AcctSeed__Opportunity__c && memo.Next_Step_Opportunity__c == bill.Next_Step_Opportunity__c && ( (memo.Next_Step_Opportunity__c != null && bill.Next_Step_Opportunity__c != null) || (memo.Next_Step_Opportunity__c == null && bill.Next_Step_Opportunity__c == null)) ){
                    
                    if(memoBalance == 0 || billingBal == 0){
                        break;
                    }

                    Decimal amtToApply = 0;
                    if(billingBal > memoBalance){
                        amtToApply = memoBalance; 
                        memoBalance = 0;
                    }else{
                        amtToApply = billingBal; 
                        billingBalMap.put(bill.Id,0);   
                    }

                    AcctSeed__Billing_Credit_Memo__c bcm = new AcctSeed__Billing_Credit_Memo__c();
                    bcm.AcctSeed__Billing_Credit_Memo__c = memo.Id;
                    bcm.AcctSeed__Billing_Invoice__c = bill.Id;
                    bcm.AcctSeed__Accounting_Period__c = memo.AcctSeed__Accounting_Period__c;                        
                    bcm.AcctSeed__Amount__c = amtToApply;
                    bcm.AcctSeed__Applied_Date__c = Date.today();
                    bcmList.add(bcm); 
                }
            }
        }

        if(bcmList.size() > 0){
            insert bcmList;
        }

        // 3. get all cash receipts from trust account activity and auto apply them
        list<AcctSeed__Cash_Receipt__c> crList = new list<AcctSeed__Cash_Receipt__c>();
        for(Trust_Account_Activity__c taa : [Select Id, Trust_Balance__c, Trust_Balance__r.Closing_Balance__c, Cash_Receipt__c, Cash_Receipt__r.AcctSeed__Balance__c, Cash_Receipt__r.AcctSeed__Account__c  
                                               From Trust_Account_Activity__c 
                                              Where Trust_Balance__c IN : trustBalanceIds
                                                AND Cash_Receipt__c != null
                                                AND Cash_Receipt__r.AcctSeed__Balance__c > 0
                                              Order By Trust_Balance__c]){
            crList.add(new AcctSeed__Cash_Receipt__c(Id = taa.Cash_Receipt__c, Auto_Apply__c = true));
        
        }

        System.debug('****AyTrustBalanceHandler***handleHardcostBillSettlement***crList=='+crList);
        if(crList.size() > 0){
            update crList;
        }
    }

    // to populate latest trust balance on Matter
    public static void populateLatestTrustBalanceOnMatter(list<Trust_Balance__c> tBalList){

        map<Id,Trust_Balance__c> matterIdTrustBalanceMap = new map<Id,Trust_Balance__c>();
        for(Trust_Balance__c tbal : tBalList){
            if(!matterIdTrustBalanceMap.containsKey(tbal.Matter__c)){
                matterIdTrustBalanceMap.put(tbal.Matter__c, tbal);
            }else if(tbal.Accounting_Period_Start_Date__c > matterIdTrustBalanceMap.get(tbal.Matter__c).Accounting_Period_Start_Date__c){
                matterIdTrustBalanceMap.put(tbal.Matter__c, tbal);    
            }
        }
        
        list<AcctSeed__Project__c> matterList_toUpdate = new list<AcctSeed__Project__c>();
        for(AcctSeed__Project__c matter : [Select Id, Trust_Balance__c, Trust_Balance__r.Accounting_Period_Start_Date__c 
                                             From AcctSeed__Project__c
                                            Where Id IN : matterIdTrustBalanceMap.keySet()]){
            if(matterIdTrustBalanceMap.containsKey(matter.Id)){
                if(matter.Trust_Balance__c == null){
                    matter.Trust_Balance__c = matterIdTrustBalanceMap.get(matter.Id).Id;
                    matterList_toUpdate.add(matter);
                }else if(matter.Trust_Balance__r.Accounting_Period_Start_Date__c < matterIdTrustBalanceMap.get(matter.Id).Accounting_Period_Start_Date__c){
                    matter.Trust_Balance__c = matterIdTrustBalanceMap.get(matter.Id).Id;    
                    matterList_toUpdate.add(matter);
                }
            }    
        }
        if(matterList_toUpdate.size() > 0){
            update matterList_toUpdate;
        }
    }

    // to create JE for movement of money when trust balance is closed
    // to delete JE for movement of money when trust balance is opened 
    public static void handleTrustBalanceOpenClose(list<Trust_Balance__c> tBalList, map<Id,Trust_Balance__c> oldMap){
        set<Id> tbIds_toProcessJe = new set<Id>();
        set<Id> tbIds_toDelJe = new set<Id>();
        for(Trust_Balance__c tb : tBalList){
            if(tb.Status__c == 'Closed' && oldMap.get(tb.Id).Status__c != 'Closed'){
                tbIds_toProcessJe.add(tb.Id);
            }else if(tb.Status__c != 'Closed' && oldMap.get(tb.Id).Status__c == 'Closed'){
                tbIds_toDelJe.add(tb.Id);
            }
        }

        if(tbIds_toProcessJe.size() > 0){
            AyAccountingFunctions.createJEonTrustBalanceClose(tbIds_toProcessJe);
        }

        // delete JE on status open
        if(tbIds_toDelJe.size() > 0){
            list<AcctSeed__Journal_Entry__c> jeList_toDel = new list<AcctSeed__Journal_Entry__c>();
            map<Id,Boolean> tbIdPostedJeMap = new map<Id,Boolean>();
            for(AcctSeed__Journal_Entry__c je : [Select Id, Trust_Balance__c, AcctSeed__Status__c From AcctSeed__Journal_Entry__c Where Trust_Balance__c In : tbIds_toDelJe]){
                if(je.AcctSeed__Status__c == 'Posted'){
                    if(!tbIdPostedJeMap.containsKey(je.Trust_Balance__c)){
                        tbIdPostedJeMap.put(je.Trust_Balance__c, true);
                    }
                }else{
                    jeList_toDel.add(je);   
                }
            }

            // delete JE if not posted
            if(jeList_toDel.size() > 0){
                delete jeList_toDel;
            }

            // throw error if JE is posted
            for(Trust_Balance__c tb : tBalList){
                if(tbIdPostedJeMap.containsKey(tb.Id)){
                    tb.addError('Please unpost JE created for this trust balance first.');   
                }
            }
        }
    }

    public static void handlePreviousMonthTrustBalance(list<Trust_Balance__c> tBalList){
        /*map<String,Id> keyIdMap = new map<String,Id>();
        set<Id> matterIds = new set<Id>();
        set<String> apNames = new set<String>();

        for(Trust_Balance__c tb : tBalList){
            //System.debug('**tb.AP_Name__c='+tb.AP_Name__c);
            if(tb.AP_Name__c != null && tb.AP_Name__c != ''){
                Integer apMonth = Integer.valueOf(tb.AP_Name__c.split('-')[1]);
                //System.debug('**apMonth='+apMonth);
                if(apMonth < Date.today().month()){
                    String nextAPName = tb.AP_Name__c.split('-')[0] + '-';
                    //System.debug('**nextAPName='+nextAPName);
                    if(apMonth < 10){
                        nextAPName += '0'+ (apMonth + 1);
                    }else{
                        nextAPName += (apMonth + 1);
                    }
                    //System.debug('**nextAPNameFinal='+nextAPName);
                    matterIds.add(tb.Matter__c);
                    apNames.add(nextAPName);

                    String key = nextAPName + ' | ' + tb.Matter__c;
                    keyIdMap.put(key,tb.Id);
                }
            }
        }
        
        list<Trust_Balance__c> tbList = new list<Trust_Balance__c>();
        for(Trust_Balance__c tb : [Select Id, Matter__c, Prior_Month_Trust_Balance__c, Accounting_Period__r.Name From Trust_Balance__c Where Accounting_Period__r.Name IN : apNames AND Matter__c IN : matterIds]){
            String key = tb.Accounting_Period__r.Name + ' | ' + tb.Matter__c;
            if(keyIdMap.containsKey(key) && tb.Prior_Month_Trust_Balance__c == null){
                tb.Prior_Month_Trust_Balance__c = keyIdMap.get(key);
                tbList.add(tb);
            }   
        }

        if(!tbList.isEmpty()){
            update tbList;
        }  */
    }
}