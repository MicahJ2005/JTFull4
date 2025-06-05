public class AyRefreshTrustBalanceExt{
    public string urlId {get;set;}
    public boolean displayMsg {get;set;}
    public string matterId;
    public date dt;

    public AyRefreshTrustBalanceExt(ApexPages.StandardController controller){
        urlId = controller.getRecord().Id;
        displayMsg = false;
        if(ApexPages.currentPage().getParameters().get('x') == '1'){
            displayMsg = true;
        }

        Trust_Balance__c tb = [Select Matter__c, Accounting_Period__c, Accounting_Period__r.AcctSeed__Start_Date__c From Trust_Balance__c Where Id =: urlId];
        matterId = tb.Matter__c;
        if(tb.Accounting_Period__c != null){dt = tb.Accounting_Period__r.AcctSeed__Start_Date__c.addDays(2);}
        else{dt = Date.today();}
    }
    
    public PageReference goBack(){
        if(urlId != null && urlId.trim() != ''){   
        }else{urlId = ApexPages.currentPage().getParameters().get('id');}
        PageReference pg = new PageReference('/'+urlId);
        return pg;
    }
    
    public PageReference refreshStatements(){
        set<Id> matterIdSet = new set<Id>();
        matterIdSet.add(matterId);
        AyBatchCreateTrustBalance b = new AyBatchCreateTrustBalance(matterIdSet, dt);
        Database.executeBatch(b,1);
        PageReference pg = Page.AyRefreshTrustBalance;
        pg.getParameters().put('id',urlId);
        pg.getParameters().put('x','1');
        pg.setRedirect(true);
        return pg;
    }

}