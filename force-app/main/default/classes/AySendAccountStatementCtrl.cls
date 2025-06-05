public class AySendAccountStatementCtrl{

    public Boolean displaySuccessMsg {get;set;}
    public set<Id> selectedRecordIds {get;set;}    
    public Integer selectedRecordsCount {get{
        if(selectedRecordIds != null){
            return selectedRecordIds.size();
        }else{return 0;}
    }private set;}
    
    public AySendAccountStatementCtrl(ApexPages.StandardSetController con) {
        selectedRecordIds = new set<Id>();
        displaySuccessMsg = false;
        if(ApexPages.currentPage().getParameters().get('s') == '1'){
            displaySuccessMsg = true;    
        }

        for(Trust_Balance__c tb : (list<Trust_Balance__c>) con.getSelected()){
            selectedRecordIds.add(tb.Id);
        }
    }    
    
    public PageReference proceedToSend(){
        
        List<Trust_Balance__c> tbList = new List<Trust_Balance__c>();
        
        for(Trust_Balance__c tb : [Select Id From Trust_Balance__c Where Id IN : selectedRecordIds]){
            tb.Send_Email__c = true;
            tbList.add(tb);
        }
        
        if(tbList.size() > 0){
            update tbList;
        }
        
        PageReference pg = Page.AySendAccountStatement;
        pg.getParameters().put('s','1');
        pg.setRedirect(true);
        return pg;        
        
    }
    
    public PageReference back(){ 
        return new ApexPages.Action('{!List}').invoke();
    }
    
}