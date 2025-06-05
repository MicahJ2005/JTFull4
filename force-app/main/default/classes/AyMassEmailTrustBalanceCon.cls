public class AyMassEmailTrustBalanceCon {

    public Boolean displaySuccessMsg {get;set;}
    public set<Id> selectedRecordIds {get;set;}
    public Integer selectedRecordsCount {get{
        if(selectedRecordIds != null){
            return selectedRecordIds.size();
        }else{return 0;}
    }private set;}
    public AyMassEmailTrustBalanceCon(ApexPages.StandardSetController con) {
        selectedRecordIds = new set<Id>();
        displaySuccessMsg = false;
        if(ApexPages.currentPage().getParameters().get('s') == '1'){
            displaySuccessMsg = true;    
        }

        for(Trust_Balance__c tb : (list<Trust_Balance__c>) con.getSelected()){
            selectedRecordIds.add(tb.Id);
        }
    }

    public PageReference processSelectedRecords(){
        
        AyBatchEmailTrustBalance b = new AyBatchEmailTrustBalance(selectedRecordIds);
        Database.executeBatch(b,1);

        PageReference pg = Page.AyMassEmailTrustBalance;
        pg.getParameters().put('s','1');
        pg.setRedirect(true);
        return pg;
    }

}