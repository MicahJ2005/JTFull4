/**********************************************
@author       :  Shubham@Ayodia
@date         :  22Apr,2022
@description  :  To show Billing Statement PDF
***********************************************/
public class AyBillingPDFController {
    
    // variable declaration
    public list<BillingLineWrapper> bLineWrapperList {get;private set;}
    public AdditionalInfo info {get; private set;}
    
    //constructor
    public AyBillingPDFController(){
        bLineWrapperList = new list<BillingLineWrapper>();
        info = new AdditionalInfo();
        info.totalBillAmount = 0;
        info.totalbalanceDue = 0;
        
        // get billing id
        Id billingId = ApexPages.currentPage().getParameters().get('id');
        
        if(billingId != null){
            
            AcctSeed__Billing__c bill = [Select Id, Name, AcctSeed__Customer__r.Name, AcctSeed__Customer__r.BillingStreet,
                                         AcctSeed__Customer__r.BillingCity, AcctSeed__Customer__r.BillingState, AcctSeed__Date__c,
                                         AcctSeed__Customer__r.BillingPostalCode, Matter__r.Name, AcctSeed__Due_Date2__c
                                         From AcctSeed__Billing__c Where Id =: billingId];
            
            info.customerName = bill.AcctSeed__Customer__r.Name;
            info.billingStreet = bill.AcctSeed__Customer__r.BillingStreet;
            info.billingCity = bill.AcctSeed__Customer__r.BillingCity;
            info.billingState = bill.AcctSeed__Customer__r.BillingState;
            info.billingPostalCode = bill.AcctSeed__Customer__r.BillingPostalCode;
            info.matterName = bill.Matter__r.Name;
            info.billingNumber = bill.Name;
            info.billingDate = bill.AcctSeed__Date__c;
            info.billingDueDate = bill.AcctSeed__Due_Date2__c;
            
            // populate billing line wrapper
            for(AcctSeed__Billing_Line__c billLine: [Select Id, AcctSeed__Date__c, AcctSeed__Billing__r.AcctSeed__Billing_Comment__c, 
                                                     AcctSeed__Billing__r.Payable__r.AcctSeed__Vendor__r.name, AcctSeed__Total__c, AcctSeed__Billing__r.AcctSeed__Balance__c,
                                                     AcctSeed__Billing__r.Payable__r.AcctSeed__Paid_Amount__c, SYS_Balance__c, SYS_Received__c 
                                                     From AcctSeed__Billing_Line__c where AcctSeed__Billing__c =: billingId Order By AcctSeed__Date__c]){
                                                         
                bLineWrapperList.add(new BillingLineWrapper(billLine));
                if(billLine.AcctSeed__Total__c >= 0){
                    Decimal payPaidAmnt = billLine.AcctSeed__Billing__r.Payable__r.AcctSeed__Paid_Amount__c != null ? billLine.AcctSeed__Billing__r.Payable__r.AcctSeed__Paid_Amount__c : 0;
                    info.totalbalanceDue+= (billLine.AcctSeed__Billing__r.AcctSeed__Balance__c);
                }
            }
        }
    }
    
    
    //Wrapper class for Billing Line
    public class BillingLineWrapper {
        public date billdate {get; private set;}
        public string description {get; private set;}
        public string payee {get; private set;}
        public decimal totalAmount {get; private set;}
        public decimal paidAmount {get; private set;}
        public decimal balanceDue {get; private set;}
        
        //Billing Line Wrapper Constructor
        public BillingLineWrapper (AcctSeed__Billing_Line__c billLine){
            this.billdate = billLine.AcctSeed__Date__c;
            this.description = billLine.AcctSeed__Billing__r.AcctSeed__Billing_Comment__c;
            this.payee = billLine.AcctSeed__Billing__r.Payable__r.AcctSeed__Vendor__r.name;
            this.totalAmount = billLine.AcctSeed__Total__c != null ? billLine.AcctSeed__Total__c.setScale(2) : 0;
            if(billLine.AcctSeed__Billing__r.Payable__r.AcctSeed__Paid_Amount__c != null){
                this.paidAmount = billLine.AcctSeed__Billing__r.Payable__r.AcctSeed__Paid_Amount__c.setScale(2);    
            }
            this.balanceDue = billLine.SYS_Balance__c.setScale(2);
            
            
        }
    }
    
    //Wrapper class for additional info
    public class AdditionalInfo{
        public string customerName {get; private set;}
        public string billingStreet {get; private set;}
        public string billingCity {get; private set;}
        public string billingState {get; private set;}
        public string billingPostalCode {get; private set;}
        public string matterName {get; private set;}
        public string billingNumber {get; private set;}
        public date billingDate {get; private set;}
        public date billingDueDate {get; private set;}
        public decimal totalbalanceDue {get; private set;}
        public decimal totalBillAmount {get; private set;}
    }
    
}