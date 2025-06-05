public class AyTrustBalanceMassCloseController{

    public list<Trust_Balance__c> selectedTrustBalanceList {get;set;}
    public set<Id> tbIds_toProcess = new set<Id>();
    public boolean displayConfirmationMsg {get;set;}

    public AyTrustBalanceMassCloseController(ApexPages.StandardSetController con){
        selectedTrustBalanceList = con.getSelected();
        set<Id> tbIds = new set<Id>();
        for(Trust_Balance__c tb : selectedTrustBalanceList){
            tbIds.add(tb.Id);
        }
        selectedTrustBalanceList = [Select Id, Name, Matter__r.Name, Accounting_Period__r.Name From Trust_Balance__c where Id IN : tbIds AND Status__c != 'Closed'];

        for(Trust_Balance__c tb : selectedTrustBalanceList){
            tbIds_toProcess.add(tb.Id);
        }

        displayConfirmationMsg = false;
        
        if(ApexPages.currentPage().getParameters().get('s') == '1'){
           displayConfirmationMsg = true;
        }
    }

    public Pagereference massCloseTrustBalance(){
        AyBatchCloseTrustBalance b = new AyBatchCloseTrustBalance(tbIds_toProcess);
        Database.executeBatch(b,1);
        PageReference pg = Page.AyTrustBalanceMassClose;
        pg.getParameters().put('s','1');
        pg.setRedirect(true);
        return pg;
    }
}