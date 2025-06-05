public class AyGenerateBatchInvoicesCon {
    public Opportunity opp {get;set;}
    public accorto__Project__c forResourceLookup {get;set;}
    public boolean displayMessage {get;private set;}
    
    public AyGenerateBatchInvoicesCon(){
        opp = new Opportunity();
        forResourceLookup = new accorto__Project__c();
        displayMessage = false;
        if(ApexPages.currentPage().getParameters().get('s') == '1'){
            displayMessage = true;
        }
    }

    public PageReference executeBatch(){
        AyBatchCreateInvoicesForTime b;
        if(forResourceLookup.accorto__Manager__c != null){
            b = new AyBatchCreateInvoicesForTime(opp.CloseDate, forResourceLookup.accorto__Manager__c);
        }else{
            b = new AyBatchCreateInvoicesForTime(opp.CloseDate);   
        }
        Database.executeBatch(b);
        Pagereference pg = Page.AyGenerateBatchInvoices;
        pg.getParameters().put('s','1');
        pg.setRedirect(true);
        return pg;
    }
}