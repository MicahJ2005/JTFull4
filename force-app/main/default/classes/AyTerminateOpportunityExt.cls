public class AyTerminateOpportunityExt{
    public Id matterId {get;set;}
    public list<CasesListWrapper> closedCasesList {get;set;}
    public list<CasesListWrapper> openCasesList {get;set;}
    public list<TemplateHeaderWrapper> mainList{get;set;}
    map<String, TemplateHeaderWrapper> templateNameWithWrapperMap = new map<String, TemplateHeaderWrapper>();
    //public String selectedValue{get;set;}

    public AyTerminateOpportunityExt(ApexPages.StandardController con){
        matterId = con.getRecord().Id;
        closedCasesList = new list<CasesListWrapper>();
        openCasesList = new list<CasesListWrapper>();
        mainList = new list<TemplateHeaderWrapper>();
        if(matterId != null){
            init();
        }
    }

    private void init(){
        set<Id> caseIds = new set<Id>();
        set<Id> cIdSet = new set<Id>();
        set<Id> openCasesIdSet = new set<Id>();
        map<Id,CasesListWrapper> caseWrapperMap = new map<Id,CasesListWrapper>();
        Integer i = 0;
        
        // get all case ids which are related to this matter
        for(Case c : [Select Id, Status From Case Where Project__c =: matterId]){
            if(c.Status == 'Active' || c.Status == 'On Hold'){
                cIdSet.add(c.Id);
            }
        }
        
        // get all open cases IDs
        // cases which have open tasks 
        // i.e. task with status != 'terminated' or status != 'Not Applicable' or Status != 'Completed'
        for(Task tsk : [Select WhatId, Status From Task Where WhatId IN : cIdSet]){
            if(tsk.Status != 'Terminated' && tsk.Status != 'Not Applicable' && tsk.Status != 'Completed'){
                openCasesIdSet.add(tsk.WhatId);
            } 
        }
        
        // fetch cases details
        set<Id> productIds = new set<Id>();
        //for(Case cs : [Select Id, ClosedDate, Project__c, Opportunity_Product__c, Task_Tracker_Template__r.Parent_Template__c, Opportunity_Product__r.TotalPrice, CaseNumber, Subject, Status, Task_Tracker_Template__r.Is_Master_Template__c, Task_Tracker_Template__r.Parent_Template__r.Name, Task_Tracker_Template__r.Name From Case Where Project__c =: matterId AND Id IN : openCasesIdSet AND (ParentId = null OR Parent.ParentId = null) ORDER BY CaseNumber, Task_Tracker_Template__r.Parent_Template__r.Name ]){
        for(Case cs : [Select Id, ClosedDate, Project__c, Opportunity_Product__c, Task_Tracker_Template__r.Parent_Template__c, Opportunity_Product__r.TotalPrice, CaseNumber, Subject, Status, Task_Tracker_Template__r.Is_Master_Template__c, Task_Tracker_Template__r.Parent_Template__r.Name, Task_Tracker_Template__r.Name, ParentId, Parent.ParentId From Case Where Project__c =: matterId AND Id IN : openCasesIdSet ORDER BY CaseNumber, Task_Tracker_Template__r.Parent_Template__r.Name ]){            
            String templateName;
            if(cs.Task_Tracker_Template__r.Is_Master_Template__c){
                templateName = cs.Task_Tracker_Template__r.Name;
            }else{
                templateName = cs.Task_Tracker_Template__r.Parent_Template__r.Name;
            }
            if(templateName != null){
                if(!templateNameWithWrapperMap.containsKey(templateName) ){
                    templateNameWithWrapperMap.put(templateName, new TemplateHeaderWrapper(templateName, i));
                    i++;
                }
                templateNameWithWrapperMap.get(templateName).wrapperList.add(new CasesListWrapper(cs));
            }
            caseIds.add(cs.Id);
            caseWrapperMap.put(cs.Id, new CasesListWrapper(cs)); 
            if(cs.Opportunity_Product__c != null){
                productIds.add(cs.Opportunity_Product__c);
            }
        }

        // to filter out tasks
        // i.e. task should not be not applicable
        set<Id> unQualifiedTaskIds = new set<Id>();
        for(Task tsk : [Select Id, Not_Applicable__c, Status From Task Where Matter__c =: matterId]){
            if(tsk.Status == 'Not Applicable' || tsk.Not_Applicable__c){
                unQualifiedTaskIds.add(tsk.Id);    
            }
        }

        // to calculate task value of product
        // populate productIdCaseList map
        // this map contains all the cases w.r.t the product
        map<Id,list<Case>> productIdCaseList = new map<Id,list<Case>>();
        set<Id>productCaseIds = new set<Id>();
        for(Case cs : [Select Id, Opportunity_Product__c From Case Where Project__c =: matterId AND Opportunity_Product__c IN : productIds AND Opportunity_Product__c != null]){
            if(!productIdCaseList.containsKey(cs.Opportunity_Product__c)){
                productIdCaseList.put(cs.Opportunity_Product__c, new list<Case>());    
            }
            productIdCaseList.get(cs.Opportunity_Product__c).add(cs);
            productCaseIds.add(cs.Id);
        }
        
        // populate caseTaskValueMap
        // this map contains total task value w.r.t. case
        map<Id, Decimal> caseTaskValueMap = new map<Id,Decimal>();
        for(AggregateResult ts : [Select WhatId, SUM(Net_Amount__c) total From Task Where WhatId IN : productCaseIds AND Id NOT IN : unQualifiedTaskIds Group By WhatId]){
            Id caseId = (ID) ts.get('WhatId');
            Decimal totl = (Decimal) ts.get('total');
            caseTaskValueMap.put(caseId, totl);
        }

        // populate productTaskValueMap
        // this map contains total task value w.r.t. product
        map<Id,Decimal> productTaskValueMap = new map<Id,Decimal>();
        for(Id prodId : productIdCaseList.keySet()){
            Decimal finalTemp = 0;
            for(Case cs : productIdCaseList.get(prodId)){
                if(caseTaskValueMap.containsKey(cs.Id)){
                    finalTemp += caseTaskValueMap.get(cs.Id);
                }
            }
            productTaskValueMap.put(prodId, finalTemp);
        }

        // rollup of all Open tasks
        // these tasks should not be marked NA        
        for(AggregateResult ar : [Select WhatId, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where WhatId IN : caseIds AND Status != 'Completed' AND Id NOT IN : unQualifiedTaskIds Group By WhatId]){
            Id caseId = (Id) ar.get('WhatId');
            if(caseWrapperMap.containsKey(caseId)){
                caseWrapperMap.get(caseId).openTaskHours = (Decimal) ar.get('hours');
                caseWrapperMap.get(caseId).openTaskAmount = (Decimal) ar.get('total');
            }
        }
        
        // rollup of all Completed tasks
        // these tasks should not be marked NA
        for(AggregateResult ar : [Select WhatId, SUM(Hours__c) hours, SUM(Net_Amount__c) total From Task Where WhatId IN : caseIds AND Status = 'Completed' AND Status != 'Refund' AND Id NOT IN : unQualifiedTaskIds Group By WhatId]){
            Id caseId = (Id) ar.get('WhatId');
            if(caseWrapperMap.containsKey(caseId)){
                caseWrapperMap.get(caseId).completedTaskHours = (Decimal) ar.get('hours');
                caseWrapperMap.get(caseId).completedTaskAmount = (Decimal) ar.get('total');
            }
        }

        // rollup of all NA tasks
        // these tasks should be marked NA
        for(AggregateResult ar : [Select WhatId, SUM(Net_Amount__c) net From Task Where WhatId IN : caseIds AND Status != 'Refund' AND Id IN : unQualifiedTaskIds Group By WhatId]){
            Id caseId = (Id) ar.get('WhatId');
            if(caseWrapperMap.containsKey(caseId)){
                caseWrapperMap.get(caseId).totalNAValue = (Decimal) ar.get('net');
            }
        }

        // rollup of all refund tasks
        for(AggregateResult ar : [Select WhatId, SUM(Net_Amount__c) net From Task Where WhatId IN : caseIds AND Status = 'Refund' Group By WhatId]){
            Id caseId = (Id) ar.get('WhatId');
            if(caseWrapperMap.containsKey(caseId)){
                caseWrapperMap.get(caseId).totalRefundValue = (Decimal) ar.get('net');
            }
        }

        System.debug('****AyTerminateOpportunityExt***init***caseWrapperMap=='+caseWrapperMap);

        // for each template wrapper
        for(TemplateHeaderWrapper w : templateNameWithWrapperMap.values()){
            mainList.add(w);

            // for each case wrapper
            for(CasesListWrapper clw : w.wrapperList){
                // populate open and completed task hours
                if(caseWrapperMap.containsKey(clw.cs.Id)){
                    clw.openTaskHours = caseWrapperMap.get(clw.cs.Id).openTaskHours;
                    clw.openTaskAmount = caseWrapperMap.get(clw.cs.Id).openTaskAmount;

                    clw.completedTaskHours = caseWrapperMap.get(clw.cs.Id).completedTaskHours;
                    clw.completedTaskAmount = caseWrapperMap.get(clw.cs.Id).completedTaskAmount;
                }
                if(clw.isClosed){
                    w.closedCasesList.add(clw);    
                }else{
                    w.openCasesList.add(clw);
                }

                if(productTaskValueMap.containsKey(clw.cs.Opportunity_Product__c)){
                    clw.productTotalTasksValue = productTaskValueMap.get(clw.cs.Opportunity_Product__c);
                }
            }            
        }

    }

    public PageReference redirectToMatterTermination(){
        System.Savepoint sp = Database.setSavepoint();
        try{
            list<Case_Termination__c> ctList = new list<Case_Termination__c>();
            Decimal openTaskValue = 0;
            for(TemplateHeaderWrapper w : mainList){                
                for(CasesListWrapper clw : w.openCasesList){
                    if(clw.status != null && clw.status.trim() != ''){
                        openTaskValue += clw.openTaskAmount;                        
                    }
                }                
            }
                        

            Decimal totalTaskValue = 0;
            for(TemplateHeaderWrapper w : mainList){
                for(CasesListWrapper clw : w.openCasesList){
                    totalTaskValue += clw.totalTaskValue;    
                }
            }

            for(TemplateHeaderWrapper w : mainList){
                for(CasesListWrapper clw : w.closedCasesList){
                    totalTaskValue += clw.totalTaskValue;    
                }
            }
            

            AcctSeed__Project__c proj = [Select Id, AcctSeed__Opportunity__c From AcctSeed__Project__c Where Id =: matterId];
            Matter_Termination__c term = new Matter_Termination__c();
            term.Matter__c = matterId;
            term.Opportunity__c = proj.AcctSeed__Opportunity__c;
            term.Value_Of_Incomplete_Tasks__c = openTaskValue;
            term.Value_of_All_Tasks__c = totalTaskValue;
            term.Termination_Status__c = 'In Process';
            insert term; 


            // sort out case ids that needs to be processed
            // first get the selected case ids
            set<Id> selectedIds = new set<Id>();
            for(TemplateHeaderWrapper w : mainList){
                for(CasesListWrapper clw : w.openCasesList){
                    if(clw.status != null && clw.status.trim() != ''){
                        selectedIds.add(clw.cs.Id);
                    }     
                }
            }

            // query children records of selected case ids
            // we are only going down two levels to get the child records, to extend functionality add more filters 
            for(Case childs : [Select Id From Case Where ParentId IN : selectedIds OR Parent.ParentId IN : selectedIds]){
                selectedIds.add(childs.Id);
            }
            
            map<Id, String> csIdWithStatusMap = new map<Id, String>();
            for(TemplateHeaderWrapper w : mainList){
                for(CasesListWrapper clw : w.openCasesList){
                    // check if reocrd needs to be processed
                    if(selectedIds.contains(clw.cs.Id) ){
                        Case_Termination__c ct = new Case_Termination__c();
                        ct.Matter_Termination__c = term.Id;
                        ct.Case__c = clw.cs.Id;
                        ct.Total_Open_Task_Hours__c = clw.openTaskHours;
                        ct.Total_Open_Task_Value__c = clw.openTaskAmount;
                        ct.Case_Prior_Status__c = clw.cs.Status;
                        ct.Opportunity_Product__c = clw.cs.Opportunity_Product__c;
                        ct.Product_Price__c = clw.cs.Opportunity_Product__r.TotalPrice;
                        ct.Product_Total_Task_Value__c = clw.productTotalTasksValue;
                        ct.Total_Completed_Task_Hours__c = clw.completedTaskHours;
                        ct.Total_Completed_Task_Value__c = clw.completedTaskAmount;
                        ct.Total_Refund_Task_Value__c = clw.totalRefundValue;
                        ct.Total_Not_Applicable_Task_Value__c = clw.totalNAValue;
                        ctList.add(ct);
                        csIdWithStatusMap.put(clw.cs.Id, clw.status);
                    }
                }
            }

            if(ctList.size() > 0){
                insert ctList;  
                
                list<case> caseList = new list<case>();   
                
                for(Case_Termination__c ct : ctList){
                    if(csIdWithStatusMap.containsKey(ct.Case__c)){
                        caseList.add(new Case(Id = ct.Case__c, Status = csIdWithStatusMap.get(ct.Case__c)));
                    }                    
                }   
                
                if(caseList.size() > 0){
                    update caseList;
                }
                                
            }

            //PageReference pg = new PageReference('/lightning/r/Matter_Termination__c/'+term.Id+'/edit?navigationLocation=DETAIL&count=1');
            
            PageReference pg = new PageReference('/'+term.Id);
            return pg;
        }catch(Exception e){
            Database.rollback(sp);
            ApexPages.addMessages(e);
        }

        return null;
    }

    public void onChangeTemplateStatus(){
        String indx = System.CurrentPageReference().getParameters().get('i');
        String sts = System.CurrentPageReference().getParameters().get('sts');
        System.debug('****indx= '+indx);
        System.debug('****sts= '+sts);
        TemplateHeaderWrapper w = mainList[Integer.valueOf(indx)];
        System.debug('****w= '+w);
        for(CasesListWrapper clw : w.wrapperList){
            clw.status = sts;                                     
        }

        //System.debug('****w.showData= '+w.showData);
    }

    public class TemplateHeaderWrapper{
        public String templateName {get;set;}
        public list<CasesListWrapper> wrapperList {get;set;}
        
        // display header only if it contains any row
        public boolean showData {get{
            for(CasesListWrapper clw : wrapperList){
                if(clw.display){
                    return true;
                }
            }
            return false;
        }private set;}
        public list<CasesListWrapper> closedCasesList {get;set;}
        public list<CasesListWrapper> openCasesList {get;set;}
        public Integer index{get;set;}
        
        public templateHeaderWrapper(String s, Integer i){

            wrapperList = new list<CasesListWrapper>();
            this.templateName = s;
            this.index = i;
            closedCasesList = new list<CasesListWrapper>();
            openCasesList = new list<CasesListWrapper>();
        }
    }

    public class CasesListWrapper{
        public Boolean terminate {get;set;}
        public Boolean onHold {get;set;}
        public String status {get;set;}
        
        public Case cs {get;set;}
        
        // only display those cases where either parent is null or parent of parent is null
        public boolean display{get{
            return (cs.Parent == null || cs.Parent.ParentId == null);
        }private set;}

        public Decimal completedTaskHours {get;set;}
        public Decimal completedTaskAmount {get;set;}

        public Decimal openTaskHours {get;set;}
        public Decimal openTaskAmount {get;set;}

        public Decimal productTotalTasksValue{get;set;}

        public Decimal totalNAValue{get;set;}
        public Decimal totalRefundValue{get;set;}

        public Decimal totalTaskValue {get{
            Decimal finalVal = 0;
            if(completedTaskAmount != null){
                finalVal += completedTaskAmount;    
            }
            if(openTaskAmount != null){
                finalVal += openTaskAmount;
            }
            return finalVal;
        }private set;}

        public Decimal totalTaskHours {get{
            Decimal finalVal = 0;
            if(completedTaskHours != null){
                finalVal += completedTaskHours;    
            }
            if(openTaskHours != null){
                finalVal += openTaskHours;
            }
            return finalVal;
        }private set;}

        public Id caseId {get{
            if(cs != null){
                return cs.Id;
            }return null;
        }}

        public Boolean isClosed {get{
            if(cs != null){
                return cs.ClosedDate != null;
            } return false;   
        }}
        
        public CasesListWrapper(Case cas){
            this.cs = cas;
            completedTaskHours = 0;
            completedTaskAmount = 0;
            openTaskHours = 0;
            openTaskAmount = 0;
        }
    }
}