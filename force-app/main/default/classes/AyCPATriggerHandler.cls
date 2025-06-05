public with sharing class AyCPATriggerHandler {
    
    @future(callout=true)
    public static void chargeDownpayment(Id cpaId){
        Customer_Products_Approval__c cpa  = [Select Id, Down_Payment__c, Next_Step_Matter__c, Payment_Method_Token__c, Next_Step_Matter__r.AcctSeed__Account__c, Opportunity__c From Customer_Products_Approval__c Where Id =: cpaId];
        String amount_str = String.valueOf(cpa.Down_Payment__c);
        map<String,Object> paymentResponseMap = new map<String,Object>();
        //if(!Test.isRunningTest()){paymentResponseMap = affinipay.AffiniPayService.createPayment('Account', ''+cpa.Next_Step_Matter__r.AcctSeed__Account__c, 'bank_ElDxADRiKRgDAE41r7uc9', '', amount_str, cpa.Payment_Method_Token__c, '', '', '', 'Downpayment : '+ Date.today());}

        if(paymentResponseMap.containsKey('id') || test.isRunningTest()){
            String affinipayId = (String) paymentResponseMap.get('id');
            for(affinipay__Transaction__c tra : [Select Id, affinipay__Link_Object_ID__c From affinipay__Transaction__c Where affinipay__AffiniPay_ID__c =: affinipayId]){
                tra.Matter__c = cpa.Next_Step_Matter__c;
                tra.Opportunity__c = cpa.Opportunity__c;
                update tra;
            }
        }
    }

    public static void handleFinance(Id cpaId){
        for(Customer_Products_Approval__c cpa : [Select Id, Date_of_First_Payment__c, Term_in_Months__c, Payment_Frequency__c, Opportunity__c, Down_Payment__c, Next_Step_Matter__c, Financed_Package__c From Customer_Products_Approval__c Where Id =: cpaId]){
            Opportunity opp = new Opportunity(Id=cpa.Opportunity__c);
            ApexPages.StandardController sc = new ApexPages.StandardController(opp);
            AyCreateFinanceFromOppExt ext = new AyCreateFinanceFromOppExt(sc);
            ext.fin.Downpayment__c = cpa.Down_Payment__c;
            ext.fin.No_of_Instalments__c = Integer.valueOf(cpa.Term_in_Months__c);
            ext.fin.Payment_Frequency__c = cpa.Payment_Frequency__c;
            ext.fin.First_Instalment_Payment_Date__c = cpa.Date_of_First_Payment__c;
            ext.fin.Customer_Products_Approval__c = cpa.Id;
            System.debug('****cpa.Financed_Package__c=='+cpa.Financed_Package__c);
            System.debug('****ext.wrapperList=='+ext.wrapperList);
            if(cpa.Financed_Package__c == 'This Next Step Only'){
                for(AyCreateFinanceFromOppExt.OppWrapper opw : ext.wrapperList){
                    if(cpa.Opportunity__c == opw.opp.Id){
                        opw.selected = true;
                    }
                }
            }else if( cpa.Financed_Package__c == 'All Open Packages'){
                for(AyCreateFinanceFromOppExt.OppWrapper opw : ext.wrapperList){
                    opw.selected = true;    
                }
            }
            ext.createFinance();

            ext.fin.Create_Accounting__c = true;
            update ext.fin;
        }
    }
}