public class AyCreateBillFromInvoiceController {
    
    public list<accorto__Invoice__c> selectedInvoiceList {get;set;}
    private set<Id> invIds_toProcess = new set<Id>();
    public boolean displayConfirmationMsg {get;set;}
    public integer totalRecords {get;set;}
    public integer totalQualifiedRecords {get;set;}
    
    public AyCreateBillFromInvoiceController(ApexPages.StandardSetController con){
        selectedInvoiceList = con.getSelected();
        set<Id> invIds = new set<Id>();
        for(accorto__Invoice__c inv : selectedInvoiceList){
            invIds.add(inv.Id);
        }
        selectedInvoiceList = [Select Id, Name, Create_Billing__c, Billing__c, accorto__Status__c, accorto__Project__c, accorto__Invoice_Date__c, accorto__Total_Amount__c From accorto__Invoice__c where Id IN : invIds];
        totalRecords = selectedInvoiceList.size();
        totalQualifiedRecords = 0;
        for(accorto__Invoice__c i : selectedInvoiceList){
            if(!i.Create_Billing__c && i.Billing__c == null){
                totalQualifiedRecords += 1;
            }
        }
        for(accorto__Invoice__c inv : selectedInvoiceList){
            invIds_toProcess.add(inv.Id);
        }
        
        displayConfirmationMsg = false;
        
        if(ApexPages.currentPage().getParameters().get('s') == '1'){
            displayConfirmationMsg = true;
        }
    }
    
    public Pagereference createBillFromInvoice(){
        AyBatchCreateBillFromInvoice b = new AyBatchCreateBillFromInvoice(invIds_toProcess);
        Database.executeBatch(b,1);
        PageReference pg = Page.AYCreateBillFromInvoice;
        pg.getParameters().put('s','1');
        pg.setRedirect(true);
        return pg;
    }
}