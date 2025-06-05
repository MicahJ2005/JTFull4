/****************************************************
@author       :  Shubham@Ayodia
@date         :  20May,2021
@description  :  To show Monthly Account Statement PDF
*****************************************************/
public class AyMonthlyStatementPDFController {
    
    // variable declaration
    public list<BillingLineWrapper> bLineWrapperList{get;private set;}
    public list<ResourceWrapper> resourceWrapperList{get;private set;}
    public list<ExpenseBillingLineWrapper> expenseWrapperList{get;private set;}
    public list<CashReceiptWrapper> crWrapperList{get;private set;}
    public list<CRWrapper> crWrapList{get;private set;}
    public list<BillingCashReceiptWrapper> bcrWrapperList{get;private set;}
    public list<CashDisbursementWrapper> cdWrapperList{get;private set;}
    public AdditionalInfo info{get; private set;}
    public decimal totalBcrAmount {get; private set;}
      
    //constructor
    public AyMonthlyStatementPDFController() {
        bLineWrapperList = new list<BillingLineWrapper>();
        resourceWrapperList = new list<ResourceWrapper>();
        expenseWrapperList = new list<ExpenseBillingLineWrapper>();
        crWrapperList = new list<CashReceiptWrapper>();
        crWrapList = new list<CRWrapper>();
        bcrWrapperList = new list<BillingCashReceiptWrapper>();
        totalBcrAmount = 0;
        cdWrapperList = new list<CashDisbursementWrapper>();
        info = new AdditionalInfo();
        info.totalBillAmount = 0;
        info.totalBillHours = 0;
        info.totalExpenseAmount = 0;
        info.totalPaymentAmount = 0;

        // Set of ids
        set<Id> trustActivityIds = new set<Id>();
        set<Id> billingIds = new set<Id>();
        set<Id> cashReceiptIds = new set<Id>();
        set<Id> cdIds = new set<Id>();
        set<Id> bcrIds = new set<Id>();
        
        map<Id, string> resIdNameMap = new map<Id, string>();
        
        Id trustBalanceId = ApexPages.currentPage().getParameters().get('id');
        
        if(trustBalanceId != null){
            Trust_Balance__c trustBalance = [Select Id, Name, Matter__c, Matter__r.Name, Matter__r.Total_Due_Balance__c, Matter__r.AcctSeed__Account__r.Name, Matter__r.AcctSeed__Account__r.BillingStreet, Matter__r.AcctSeed__Account__r.BillingCity, Matter__r.AcctSeed__Account__r.BillingState, Matter__r.AcctSeed__Account__r.BillingPostalCode, Opening_Balance__c, Ending_Balance__c, Prior_Month_Trust_Balance__r.Closing_Balance__c, Accounting_Period__c, Accounting_Period__r.AcctSeed__Start_Date__c, Accounting_Period__r.AcctSeed__End_Date__c From Trust_Balance__c Where Id =: trustBalanceId];
            info.statementNumber = trustBalance.Name;
            info.accountName = trustBalance.Matter__r.AcctSeed__Account__r.Name;
            info.billingStreet = trustBalance.Matter__r.AcctSeed__Account__r.BillingStreet;
            info.billingCity = trustBalance.Matter__r.AcctSeed__Account__r.BillingCity;
            info.billingState = trustBalance.Matter__r.AcctSeed__Account__r.BillingState;
            info.billingPostalCode = trustBalance.Matter__r.AcctSeed__Account__r.BillingPostalCode;
            info.statementDate = trustBalance.Accounting_Period__r.AcctSeed__End_Date__c;
            info.matterName = trustBalance.Matter__r.Name;
            info.matterId = trustBalance.Matter__c;
            info.beginningBalance = trustBalance.Opening_Balance__c;
            info.endingBalance = trustBalance.Ending_Balance__c;
            if(trustBalance.Accounting_Period__r.AcctSeed__Start_Date__c != null){
                info.accPeriodStartDate = trustBalance.Accounting_Period__r.AcctSeed__Start_Date__c;
            }
            if(trustBalance.Accounting_Period__c != null){
                info.accPeriod = trustBalance.Accounting_Period__c;
            }
            
            //fetch Trust Account Activity related to trust Balance
            for(Trust_Account_Activity__c activity : [Select Id, Name, Billing__c, Cash_Receipt__c, Cash_Disbursement__c, Billing_Cash_Receipt__c From Trust_Account_Activity__c Where Trust_Balance__c =: trustBalanceId]){
                trustActivityIds.add(activity.Id);
                if(activity.Billing__c != null){
                    billingIds.add(activity.Billing__c);
                }
                if(activity.Cash_Receipt__c != null){
                    cashReceiptIds.add(activity.Cash_Receipt__c);
                }
                if(activity.Cash_Disbursement__c != null){
                    cdIds.add(activity.Cash_Disbursement__c);
                }
                if(activity.Billing_Cash_Receipt__c != null){
                    bcrIds.add(activity.Billing_Cash_Receipt__c);
                }
            }
        }
        
        // populate billing line wrapper & resource id-name map
        for(AcctSeed__Billing_Line__c billLine: [Select Id, Accorto_Invoice_Line__r.accorto__Description__c, Accorto_Invoice_Line__r.accorto__TE_Item__r.accorto__TE_Date_First__c, AcctSeed__Hours_Units__c, AcctSeed__Rate__c, AcctSeed__Total__c, Accorto_Invoice_Line__c, Resource__c, Resource__r.Name From AcctSeed__Billing_Line__c where AcctSeed__Billing__c IN: billingIds AND AcctSeed__Billing__r.AcctSeed__Status__c = 'Posted' AND AcctSeed__Billing__r.Payable__c = null Order By AcctSeed__Date__c]){
            bLineWrapperList.add(new BillingLineWrapper(billLine));
            if(billLine.Resource__r.Name != null){
                resIdNameMap.put(billLine.Resource__c, billLine.Resource__r.Name); 
            }
        }

        AggregateResult[] groupedResults = [SELECT Resource__c, SUM(AcctSeed__Hours_Units__c)totalHours, SUM(AcctSeed__Total__c)totalAamount  FROM AcctSeed__Billing_Line__c Where AcctSeed__Billing__c IN: billingIds AND AcctSeed__Billing__r.Payable__c = null GROUP BY Resource__c ];
        system.debug('groupedResults'+ groupedResults);
        for (AggregateResult ar : groupedResults)  {
            decimal totalhours = (decimal)ar.get('totalhours');
            decimal totalAmount = (decimal)ar.get('totalAamount');
            decimal averageRate = (totalAmount/totalhours).setScale(2);
            resourceWrapperList.add(new ResourceWrapper(averageRate, totalhours, (string)ar.get('Resource__c')));
        }

        //populate resource name in wrapper
        for(ResourceWrapper wrap: resourceWrapperList){
            if(resIdNameMap.containsKey(wrap.resId)){
                wrap.resName = resIdNameMap.get(wrap.resId);
            }
            //calculate total billed hours
            if(wrap.totalHours != null){
                info.totalBillHours+= wrap.totalHours;
            }
        }

        //calclate total billing amount
        for(BillingLineWrapper wrap: bLineWrapperList){
            if(wrap.totalAmount != null && wrap.totalAmount > 0){
                info.totalBillAmount+=  wrap.totalAmount;
            }
        }

        //fetch Expense BillingLine related to trust activities
        for(AcctSeed__Billing_Line__c billLine : [Select Id, Payable_Line__r.AcctSeed__Account_Payable__r.AcctSeed__Payee__c, Payable_Line__r.AcctSeed__Invoice_Comment__c, AcctSeed__Total__c, AcctSeed__Billing__r.AcctSeed__Date__c From AcctSeed__Billing_Line__c Where AcctSeed__Billing__c IN: billingIds AND AcctSeed__Billing__r.AcctSeed__Status__c = 'Posted' AND AcctSeed__Billing__r.Payable__c != null Order By AcctSeed__Date__c]){
            expenseWrapperList.add(new ExpenseBillingLineWrapper(billLine));
            if(billLine.AcctSeed__Total__c != null && billLine.AcctSeed__Total__c > 0){
                info.totalExpenseAmount+= billLine.AcctSeed__Total__c;
            }
        }
        
        //fetch Past Due Billings
        info.priorMonthTotal = 0;
        for(AcctSeed__Billing__c bill : [Select Id, AcctSeed__Accounting_Period__c, AcctSeed__Balance__c From AcctSeed__Billing__c Where Matter__c =: info.matterId AND AcctSeed__Balance__c > 0 AND AcctSeed__Accounting_Period__r.AcctSeed__Start_Date__c <: info.accPeriodStartDate AND AcctSeed__Status__c = 'Posted']){
            info.priorMonthTotal+= bill.AcctSeed__Balance__c;
        }
        
        //fetch CashReceipt related to trust activities
        for(AcctSeed__Cash_Receipt__c cr : [Select Id, AcctSeed__Receipt_Date__c, AcctSeed__Description__c, AcctSeed__Payment_Reference__c, AcctSeed__Amount__c From AcctSeed__Cash_Receipt__c Where Id IN: cashReceiptIds AND AcctSeed__Accounting_Period__c =: info.accPeriod]){
            if(cr.AcctSeed__Amount__c != null && cr.AcctSeed__Amount__c >= 0){
                crWrapperList.add(new CashReceiptWrapper(cr));  
            }
        }
        
        //fetch CashReceipt related to trust activities
        for(AcctSeed__Cash_Receipt__c cr : [Select Id, AcctSeed__Receipt_Date__c, AcctSeed__Payment_Reference__c, AcctSeed__Amount__c From AcctSeed__Cash_Receipt__c Where Id IN: cashReceiptIds AND AcctSeed__Accounting_Period__c =: info.accPeriod AND (AcctSeed__Bank_Account__r.Name = 'J-10702 - Bell Bank INCOME Checking' OR AcctSeed__Bank_Account__r.Name = 'J-10003 - TCF Bank Operating Account')]){
            crWrapList.add(new CRWrapper(cr));
            if(cr.AcctSeed__Amount__c != null && cr.AcctSeed__Amount__c >= 0){
                info.totalPaymentAmount+= cr.AcctSeed__Amount__c * (-1);
            }
        }
        
        
        //fetch Billing Cash Receipt related to trust activities
        for(AcctSeed__Billing_Cash_Receipt__c bcr : [Select Id, AcctSeed__Applied_Date__c, AcctSeed__Applied_Amount__c, CreatedDate From AcctSeed__Billing_Cash_Receipt__c Where Id IN: bcrIds AND AcctSeed__Cash_Receipt__r.AcctSeed__Accounting_Period__c = :info.accPeriod]){
            If(bcr.AcctSeed__Applied_Amount__c != null){
                bcrWrapperList.add(new BillingCashReceiptWrapper(bcr));
                totalBcrAmount = totalBcrAmount + (bcr.AcctSeed__Applied_Amount__c * -1);
            }
        }
        
        //fetch Cash Disbursement related to trust activities
        for(AcctSeed__Cash_Disbursement__c cd : [Select Id, AcctSeed__Disbursement_Date__c, AcctSeed__Description__c, AcctSeed__Amount__c From AcctSeed__Cash_Disbursement__c Where Id IN: cdIds AND AcctSeed__Accounting_Period__c =: info.accPeriod]){
            if(cd.AcctSeed__Amount__c != null && cd.AcctSeed__Amount__c <= 0){
                cdWrapperList.add(new CashDisbursementWrapper(cd));    
            }
        }
        
    }
    
    //Wrapper class for Billing Line
    public class BillingLineWrapper {
        public string description{get;set;}
        public decimal unitPrice{get;set;}
        public decimal quantity{get;set;}
        public decimal totalAmount{get;set;}
        public string initials{get;set;}
        public date billdate{get;set;}
        
        //Billing Line Wrapper Constructor
        public BillingLineWrapper (AcctSeed__Billing_Line__c billLine){
            this.description = billLine.Accorto_Invoice_Line__r.accorto__Description__c;
            this.unitPrice = billLine.AcctSeed__Rate__c.setScale(2);
            this.quantity = billLine.AcctSeed__Hours_Units__c.setScale(2);
            this.totalAmount = billLine.AcctSeed__Total__c.setScale(2);
            this.billdate = billLine.Accorto_Invoice_Line__r.accorto__TE_Item__r.accorto__TE_Date_First__c;            
            this.initials = getNameInitials(billLine.Resource__r.Name);
        }

        //method to split resource name and return initials
        private string getNameInitials(string name){
            list<string> splitName;
            string initials ='';
            if(name !=null && name.trim() != null){
                if(name.contains(' ')){
                    splitName = name.split(' ');
                }            
            
                for(string s: splitName){
                    initials += (s.left(1)).toUpperCase();
                }
            }
            return initials;
        }
    }

    //Wrapper class for resource
    public class ResourceWrapper {
        public string resId{get;set;}
        public string resName{get;set;}
        public decimal avgRate{get;set;}
        public decimal totalHours{get;set;}

        //Resource Wrapper Constructor
        public ResourceWrapper (decimal rate, decimal hours, string resourceId){
            this.resId = resourceId;
            this.avgRate = rate;
            this.totalHours = hours;
        }
    }
    
    //Wrapper class for Expense BillingLine
    public class ExpenseBillingLineWrapper {
        public string payee{get;set;}
        public String comment{get;set;}
        public decimal totalAmount{get;set;}
        public date teDate{get;set;}
        
        //Expense BillingLine Wrapper Constructor
        public ExpenseBillingLineWrapper (AcctSeed__Billing_Line__c billLine){
            this.payee = billLine.Payable_Line__r.AcctSeed__Account_Payable__r.AcctSeed__Payee__c;
            this.comment = billLine.Payable_Line__r.AcctSeed__Invoice_Comment__c;
            this.totalAmount = billLine.AcctSeed__Total__c;
            this.teDate = billLine.AcctSeed__Billing__r.AcctSeed__Date__c;
        }
    }
    
    //Wrapper class for Cash Receipt
    public class CashReceiptWrapper {
        public date receiptDate{get;set;}
        public string description{get;set;}
        public string paymentReference{get;set;}
        public decimal amount{get;set;}

        //Wrapper CashReceipt Constructor
        public CashReceiptWrapper (AcctSeed__Cash_Receipt__c cr){
            this.receiptDate = cr.AcctSeed__Receipt_Date__c;
            this.description = 'Deposit';
            this.paymentReference = cr.AcctSeed__Payment_Reference__c;
            this.amount = cr.AcctSeed__Amount__c;
        }
    }
    
    //Wrapper class for Cash Receipt
    public class CRWrapper {
        public date receiptDate{get;set;}
        public string paymentReference{get;set;}
        public decimal amount{get;set;}

        //Wrapper CashReceipt Constructor
        public CRWrapper (AcctSeed__Cash_Receipt__c cr){
            this.receiptDate = cr.AcctSeed__Receipt_Date__c;
            this.paymentReference = cr.AcctSeed__Payment_Reference__c;
            this.amount = cr.AcctSeed__Amount__c;
        }
    }
    
    //Wrapper class for Billing Cash Receipt
    public class BillingCashReceiptWrapper {
        public date appliedDate{get;set;}
        public decimal appliedAmount{get;set;}
        public string description{get;set;}

        //BillingCashReceipt Wrapper Constructor
        public BillingCashReceiptWrapper (AcctSeed__Billing_Cash_Receipt__c bcr){
            this.appliedDate = bcr.AcctSeed__Applied_Date__c;
            this.appliedAmount = bcr.AcctSeed__Applied_Amount__c * (-1); 
            this.description = 'Withdrawal';
        }
    }
    
    //Wrapper class for Cash Disbursement
    public class CashDisbursementWrapper {
        public date disbursementDate{get;set;}
        public string description{get;set;}
        public decimal amount{get;set;}

        //CashDisbursement Wrapper Constructor
        public CashDisbursementWrapper (AcctSeed__Cash_Disbursement__c cd){
            this.disbursementDate = cd.AcctSeed__Disbursement_Date__c;
            this.description = 'Withdrawal';
            this.amount = cd.AcctSeed__Amount__c * (-1);
        }
    }
    
    //wrapper class for additional info
    public class AdditionalInfo{
        public date statementDate{get;set;}
        public string statementNumber{get;set;}
        public string accountName{get;set;}
        public string billingStreet{get;set;}
        public string billingCity{get;set;}
        public string billingState{get;set;}
        public string billingPostalCode{get;set;}
        public string matterId{get;set;}
        public string matterName{get;set;}
        public decimal totalBillAmount{get;set;}
        public decimal totalExpenseAmount{get;set;}
        public decimal totalPaymentAmount{get;set;}
        public decimal totalBillHours{get;set;}
        public decimal beginningBalance{get;set;}
        public decimal endingBalance{get;set;}
        public decimal priorMonthTotal{get;set;}
        public Date accPeriodStartDate{get;set;}
        public String accPeriod{get;set;}

    }
}