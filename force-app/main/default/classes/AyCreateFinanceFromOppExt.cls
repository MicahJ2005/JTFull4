public class AyCreateFinanceFromOppExt{

    public Id oppId {get;set;}
    public list<OppWrapper> wrapperList {get;set;}
    public Finance__c fin {get;set;}

    public AyCreateFinanceFromOppExt(ApexPages.StandardController con){
        
        wrapperList = new list<OppWrapper>();
        oppId = con.getRecord().Id;
        fin = new Finance__c();
        fin.Parent_Opportunity__c = oppId;

        set<Id> oppIdsSet = new set<Id>();
        list<Opportunity> oppList = [Select Id, Name, Next_Step_Matter__c, Billing_Attorney_lk__r.Name, StageName, Billing_Attorney__c, Next_Step_Matter__r.AcctSeed__Opportunity__c, (Select Id, AcctSeed__Opportunity__c From AcctSeed__Projects__r) From Opportunity Where Id =: oppId];
        set<Id> matterIds = new set<Id>();
        for(Opportunity oppo : oppList){
            
            oppIdsSet.add(oppo.Id);

            if(oppo.Next_Step_Matter__c != null){
                fin.Matter__c = oppo.Next_Step_Matter__c;
                oppIdsSet.add(oppo.Next_Step_Matter__r.AcctSeed__Opportunity__c);
                matterIds.add(oppo.Next_Step_Matter__c);
            }

            for(AcctSeed__Project__c proj : oppo.AcctSeed__Projects__r){
                fin.Matter__c = proj.Id;   
                matterIds.add(proj.Id);
            }

            for(Opportunity op : [Select Id From Opportunity where Next_Step_Matter__c IN : matterIds AND Next_Step_Matter__c != null]){
                oppIdsSet.add(op.Id);   
            }
            
        }
        
        // to show only those opportunities which have open bills
            set<Id> oppIdsFinal = new set<Id>();
            
            // standard billings
            for(AcctSeed__Billing__c sb : [Select Id, AcctSeed__Opportunity__c From AcctSeed__Billing__c Where AcctSeed__Opportunity__c IN : oppIdsSet AND AcctSeed__Balance__c > 0 AND Next_Step_Opportunity__c = null]){
                oppIdsFinal.add(sb.AcctSeed__Opportunity__c);
            }

            // next step
            for(AcctSeed__Billing__c nxt : [Select Id, Next_Step_Opportunity__c From AcctSeed__Billing__c Where Next_Step_Opportunity__c IN : oppIdsSet AND AcctSeed__Balance__c > 0]){
                oppIdsFinal.add(nxt.Next_Step_Opportunity__c);
            }
        // ends here


        for(Opportunity oppo : [Select Id, Name, StageName, Billing_Attorney__c, Billing_Attorney_lk__r.Name From Opportunity Where Id IN : oppIdsFinal]){
            OppWrapper orr = new OppWrapper(oppo);
            wrapperList.add(orr);
        }

        // for unbilled
        for(Opportunity oppo : oppList){
            if(wrapperList.size() == 0 && oppIdsFinal.size() == 0){
                wrapperList.add(new OppWrapper(oppo));
            }
        } 
    }

    public PageReference createFinance(){
        System.Savepoint sp = Database.setSavePoint();
        Boolean isValid = false;
        for(AyCreateFinanceFromOppExt.OppWrapper w : wrapperList){
            if(w.selected){
                isValid = true;
            }
        }

        try{
            if(isValid){
                insert fin;
                
                list<Finance_Opportunity__c> financeOppList = new list<Finance_Opportunity__c>();
                for(AyCreateFinanceFromOppExt.OppWrapper w : wrapperList){
                    if(w.selected){
                        Finance_Opportunity__c fOpp = new Finance_Opportunity__c();
                        fOpp.Opportunity__c = w.opp.Id;
                        fOpp.Finance__c = fin.Id;
                        fOpp.Matter__c = fin.Matter__c;
                        financeOppList.add(fOpp);
                    }
                }
                
                if(financeOppList.size() > 0){
                    insert financeOppList;
                }

                PageReference pg = new PageReference('/'+fin.Id);
                pg.setRedirect(true);
                return pg;
                
            }else{
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'Please select atleast one opportunity to continue.'));
            }
        }catch(Exception e){
            Database.rollback(sp);
            ApexPages.addMessages(e);
        }
        return null;
        
    }



    public class OppWrapper{
        public Boolean selected {get;set;}
        public Opportunity opp {get;set;}
        public OppWrapper(Opportunity op){
            opp = op;
            selected = false;
        }
    }

}