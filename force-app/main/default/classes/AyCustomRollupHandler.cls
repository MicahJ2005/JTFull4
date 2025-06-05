/***********************************************
@author       :  Shubham@Ayodia
@date         :  13May,2021
@description  :  Class to handle custom rollup
************************************************/
public class AyCustomRollupHandler {
    
    // @desc       : method to handle rollup BillingBalance on Matter.
    // @param      : set of Matter records to process
    // @return     : void
    /*public static void balanceRollupOnMatter(set<Id> matterIds) {
        
        // map of Matter id & Matter
        map<Id, AcctSeed__Project__c> matterMap = new map<Id, AcctSeed__Project__c>();

        for(Id mId : matterIds){
            AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = mId, Total_Due_Balance__c = 0);
            matterMap.put(mId, matter);
        }

        // Aggregate query
        for(AggregateResult res : [Select Matter__c, SUM(AcctSeed__Balance__c) balance From AcctSeed__Billing__c 
                                   Where Matter__c IN: matterIds 
                                   AND AcctSeed__Status__c = 'Posted'
                                   AND AcctSeed__Balance__c > 0
                                   AND Past_Due_Days__c > 10
                                   Group By Matter__c] ){
            String matterId = (Id)res.get('Matter__c');
            if(matterMap.containsKey(matterId)){
                AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = matterId, Total_Due_Balance__c = (Decimal)res.get('balance'));
                matterMap.put(matterId, matter);
            }
        }
        
        if(matterMap.values().size() > 0){
            update matterMap.values();
        }  
    }
    
    // @desc       : method to handle rollup Current Billing Balance on Matter.
    // @param      : set of Matter records to process
    // @return     : void
    public static void currentBalanceRollupOnMatter(set<Id> matterIds) {
        
        // map of Matter id & Matter
        map<Id, AcctSeed__Project__c> matterMap = new map<Id, AcctSeed__Project__c>();

        for(Id mId : matterIds){
            AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = mId, Current_Billing_Balance__c = 0);
            matterMap.put(mId, matter);
        }

        // Aggregate query
        for(AggregateResult res : [Select Matter__c, SUM(AcctSeed__Balance__c) balance From AcctSeed__Billing__c 
                                   Where Matter__c IN: matterIds 
                                   AND AcctSeed__Status__c = 'Posted'
                                   Group By Matter__c] ){
            String matterId = (Id)res.get('Matter__c');
            if(matterMap.containsKey(matterId)){
                AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = matterId, Current_Billing_Balance__c = (Decimal)res.get('balance'));
                matterMap.put(matterId, matter);
            }
        }
        
        if(matterMap.values().size() > 0){
            update matterMap.values();
        }  
    }*/
    
    // @desc       : method to handle rollup Billing CreditMemo Total on Matter.
    // @param      : set of Matter records to process
    // @return     : void
    public static void creditMemoBalRollupOnMatter(set<Id> matterIds) {
        
        // map of Matter id & Matter
        map<Id, Id> billIdWithMatterIdMap = new map<Id, Id>();
        map<Id, Decimal> matterIdWithTotalMap = new map<Id, Decimal>();
        Set<String> glStringSet = new Set<String>();
        if(Label.Revenue_GL_Codes.contains(',')){
            String[] temp = Label.Revenue_GL_Codes.split(',');
            for(String gl : temp){
                glStringSet.add(gl.trim());
            }                
        }else{
            glStringSet.add(Label.Revenue_GL_Codes.trim());    
        }
        
        // for setting null values as zero
        for(Id mId : matterIds){
            matterIdWithTotalMap.put(mId, 0);
        }
        
        for(AcctSeed__Billing__c bill : [Select Id, Matter__c, AcctSeed__Status__c From AcctSeed__Billing__c 
                                    Where Matter__c IN : matterIds 
                                      AND AcctSeed__Status__c = 'Posted'
                                      AND AcctSeed__Type__c = 'Credit Memo']){

            billIdWithMatterIdMap.put(bill.Id, bill.Matter__c);          
        }
        
        for(AcctSeed__Billing_Line__c bLine : [Select Id, AcctSeed__Billing__c, AcctSeed__Total__c, AcctSeed__Revenue_GL_Account__c FROM AcctSeed__Billing_Line__c WHERE AcctSeed__Billing__c IN : billIdWithMatterIdMap.keySet()]){
            // only process specific gl
            if(glStringSet.contains(bLine.AcctSeed__Revenue_GL_Account__c)){                    
                Id matterId = billIdWithMatterIdMap.get(bLine.AcctSeed__Billing__c);
                
                if(matterIdWithTotalMap.containsKey(matterId)){
                    Decimal newTotal = matterIdWithTotalMap.get(matterId) + bLine.AcctSeed__Total__c;
                    matterIdWithTotalMap.put(matterId, newTotal);
                }else{
                    matterIdWithTotalMap.put(matterId, bLine.AcctSeed__Total__c);
                }                                   
            }
        }

        // update matter
        if(matterIdWithTotalMap.keySet().size() > 0){
            List<AcctSeed__Project__c> matterIdListToUpdate = new List<AcctSeed__Project__c>();
            
            //for(AcctSeed__Project__c mtr : [Select Id FROM AcctSeed__Project__c WHERE ID IN : matterIdWithTotalMap.keySet()]){
            for(Id mtrId : matterIdWithTotalMap.keySet()){
                if(matterIdWithTotalMap.containsKey(mtrId)){
                    matterIdListToUpdate.add(new AcctSeed__Project__c(Id = mtrId, Total_Matter_Credit__c = matterIdWithTotalMap.get(mtrId)));
                }
            }
            
            if(matterIdListToUpdate.size() > 0){
                update matterIdListToUpdate;
            }
        }
    }
    
    // @desc       : method to handle rollup Billing Total on Matter.
    // @param      : set of Matter records to process
    // @return     : void
    public static void billingTotalRollupOnMatter(set<Id> matterIds) {
        
        // map of Matter id & Matter
        map<Id, Id> billIdWithMatterIdMap = new map<Id, Id>();
        map<Id, Decimal> matterIdWithTotalMap = new map<Id, Decimal>();
        Set<String> glStringSet = new Set<String>();
        if(Label.Revenue_GL_Codes.contains(',')){
            String[] temp = Label.Revenue_GL_Codes.split(',');
            for(String gl : temp){
                glStringSet.add(gl.trim());
            }                
        }else{
            glStringSet.add(Label.Revenue_GL_Codes.trim());    
        }
        
        // for setting null values as zero
        for(Id mId : matterIds){
            matterIdWithTotalMap.put(mId, 0);
        }
        
        for(AcctSeed__Billing__c bill : [Select Id, Matter__c, AcctSeed__Status__c From AcctSeed__Billing__c 
                                    Where Matter__c IN : matterIds 
                                      AND AcctSeed__Status__c = 'Posted'
                                      AND AcctSeed__Total__c > 0]){

            billIdWithMatterIdMap.put(bill.Id, bill.Matter__c);          
        }
        
        for(AcctSeed__Billing_Line__c bLine : [Select Id, AcctSeed__Billing__c, AcctSeed__Total__c, AcctSeed__Revenue_GL_Account__c FROM AcctSeed__Billing_Line__c WHERE AcctSeed__Billing__c IN : billIdWithMatterIdMap.keySet()]){
            // only process specific gl
            if(glStringSet.contains(bLine.AcctSeed__Revenue_GL_Account__c)){                    
                Id matterId = billIdWithMatterIdMap.get(bLine.AcctSeed__Billing__c);
                
                if(matterIdWithTotalMap.containsKey(matterId)){
                    Decimal newTotal = matterIdWithTotalMap.get(matterId) + bLine.AcctSeed__Total__c;
                    matterIdWithTotalMap.put(matterId, newTotal);
                }else{
                    matterIdWithTotalMap.put(matterId, bLine.AcctSeed__Total__c);
                }                                   
            }
        }

        // update matter
        if(matterIdWithTotalMap.keySet().size() > 0){
            List<AcctSeed__Project__c> matterIdListToUpdate = new List<AcctSeed__Project__c>();
            
            /*for(AcctSeed__Project__c mtr : [Select Id FROM AcctSeed__Project__c WHERE ID IN : matterIdWithTotalMap.keySet()]){
                mtr.Total_Matter_Price__c = matterIdWithTotalMap.get(mtr.Id);
                matterIdListToUpdate.add(mtr);
            }*/
            for(Id mtrId : matterIdWithTotalMap.keySet()){
                if(matterIdWithTotalMap.containsKey(mtrId)){
                    matterIdListToUpdate.add(new AcctSeed__Project__c(Id = mtrId, Total_Matter_Price__c = matterIdWithTotalMap.get(mtrId)));    
                }
            }
            
            if(matterIdListToUpdate.size() > 0){
                update matterIdListToUpdate;
            }
        }
    }
    
    /*
    // @desc       : method to handle rollup Opportunity Price on Matter.
    // @param      : set of Matter records to process
    // @return     : void
    public static void oppPriceRollupOnMatter(set<Id> oppIds) {
        
        // Aggregate query
        map<Id,Decimal> oppAmountMap = new map<Id,Decimal>();
        for(AggregateResult ag : [Select Id, SUM(Amount) amt From Opportunity Where Id IN: oppIds Group By Id]){
      oppAmountMap.put((ID) ag.get('Id'), (Decimal) ag.get('amt'));  
        }
        
        // process all opportunities
        map<Id,AcctSeed__Project__c> matterMap = new map<Id,AcctSeed__Project__c>(); 
        
        // 1. process all next step opportunities
        for(Opportunity opp : [Select Id, Next_Step_Matter__c From Opportunity Where Next_Step_Matter__c != null AND Id IN : oppIds]){
            if(oppAmountMap.containsKey(opp.Id)){
            matterMap.put(opp.Next_Step_Matter__c, new AcctSeed__Project__c(Id = opp.Next_Step_Matter__c, Total_Matter_Price__c = oppAmountMap.get(opp.Id)));
      }
        }
        
        // 2. process all first step opps
        for(AcctSeed__Project__c proj : [Select Id, AcctSeed__Opportunity__c From AcctSeed__Project__c Where AcctSeed__Opportunity__c IN : oppIds]){
            if(oppAmountMap.containsKey(proj.AcctSeed__Opportunity__c)){
                if(matterMap.containsKey(proj.Id)){
                  AcctSeed__Project__c existing = matterMap.get(proj.Id);
                    existing.Total_Matter_Price__c += oppAmountMap.get(proj.AcctSeed__Opportunity__c);
                    matterMap.put(proj.Id, existing);    
                }else{
                    proj.Total_Matter_Price__c = oppAmountMap.get(proj.AcctSeed__Opportunity__c);
                    matterMap.put(proj.Id, proj);    
                }
          }
        }
            
        if(matterMap.values().size() > 0){
            update matterMap.values();
        }   
    } */
    
    // @desc       : method to handle rollup HardCost Billing Balance on Matter.
    // @param      : set of Matter records to process
    // @return     : void
    /*public static void hardCostBalanceRollupOnMatter(set<Id> matterIds) {
        
        // map of Matter id & Matter
        map<Id, AcctSeed__Project__c> matterMap = new map<Id, AcctSeed__Project__c>();

        for(Id mId : matterIds){
            AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = mId, Total_Hardcost_Billing_Balance__c = 0);
            matterMap.put(mId, matter);
        }

        // Aggregate query
        for(AggregateResult res : [Select Matter__c, SUM(AcctSeed__Balance__c) balance From AcctSeed__Billing__c 
                                   Where Matter__c IN: matterIds 
                                   AND AcctSeed__Status__c = 'Posted'
                                   AND Payable__c != null
                                   AND Payable__r.Hardcost__c = true
                                   Group By Matter__c] ){
            String matterId = (Id)res.get('Matter__c');
            if(matterMap.containsKey(matterId)){
                AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = matterId, Total_Hardcost_Billing_Balance__c = (Decimal)res.get('balance'));
                matterMap.put(matterId, matter);
            }
        }
        
        if(matterMap.values().size() > 0){
            update matterMap.values();
        }  
    }*/

    // @desc       : method to rollup Balance due, Current Balance and hardcost balance on matter
    // @param      : set of Matter records to process
    // @return     : void
    public static void populateDataOnMatter(set<Id> matterIds){
        // map of Matter id & Matter
        map<Id, AcctSeed__Project__c> matterMap = new map<Id, AcctSeed__Project__c>();
    
        if(matterIds != null && matterIds.size() > 0){
            for(Id mId : matterIds){
                if(mId != null){
                    AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = mId, Total_Due_Balance__c = 0, Current_Billing_Balance__c = 0, Total_Hardcost_Billing_Balance__c = 0);
                    matterMap.put(mId, matter);
                }
            }
            
            // Aggregate query - Total Due Balance 
            for(AggregateResult res : [Select Matter__c, SUM(AcctSeed__Balance__c) balance From AcctSeed__Billing__c 
                                       Where Matter__c IN: matterIds 
                                       AND AcctSeed__Status__c = 'Posted'
                                       AND AcctSeed__Balance__c > 0
                                       AND Past_Due_Days__c > 10
                                       Group By Matter__c] ){
                String matterId = (Id)res.get('Matter__c');
                if(matterMap.containsKey(matterId)){
                    //AcctSeed__Project__c matter = new AcctSeed__Project__c(Id = matterId, Total_Due_Balance__c = (Decimal)res.get('balance'));
                    AcctSeed__Project__c matter = matterMap.get(matterId);
                    matter.Total_Due_Balance__c = (Decimal)res.get('balance');
                    matterMap.put(matterId, matter);
                }
            }
            
            // Aggregate query - Current Billing Balance
            for(AggregateResult res : [Select Matter__c, SUM(AcctSeed__Balance__c) balance From AcctSeed__Billing__c 
                                       Where Matter__c IN: matterIds 
                                       AND AcctSeed__Status__c = 'Posted'
                                       AND Payable__c = null
                                       Group By Matter__c] ){
                String matterId = (Id)res.get('Matter__c');
                if(matterMap.containsKey(matterId)){
                    AcctSeed__Project__c matter = matterMap.get(matterId);
                    matter.Current_Billing_Balance__c = (Decimal)res.get('balance');
                    matterMap.put(matterId, matter);
                }
            }
            
            // Aggregate query - Hardcost Balance
            for(AggregateResult res : [Select Matter__c, SUM(AcctSeed__Balance__c) balance From AcctSeed__Billing__c 
                                       Where Matter__c IN: matterIds 
                                       AND AcctSeed__Status__c = 'Posted'
                                       AND Payable__c != null
                                       AND Payable__r.Hardcost__c = true
                                       Group By Matter__c] ){
                String matterId = (Id)res.get('Matter__c');
                
                if(matterMap.containsKey(matterId)){
                    AcctSeed__Project__c matter = matterMap.get(matterId);
                    matter.Total_Hardcost_Billing_Balance__c = (Decimal)res.get('balance');
                    matterMap.put(matterId, matter);
                }
            }
            
            if(matterMap.values().size() > 0){
                update matterMap.values();
            }
        }
    }
    
}