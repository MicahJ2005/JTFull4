/*********************************************************
@author       :  Shubham@Ayodia
@date         :  25Apr,2022
@description  :  To Display Total Unbilled Hours on Matter
**********************************************************/
public class AyDisplayUnbilledHoursOnMatterController {
    
    @AuraEnabled
    public static Decimal getUnbilledHours(String matterId){
        decimal totalUnbilledhours;
        if(matterId != null){
            for (AggregateResult ar : [SELECT accorto__Project__r.Matter__c, SUM(accorto__EstimatedCostAmt__c)totalHours FROM accorto__TE_Item__c Where accorto__Project__r.Matter__c =: matterId AND accorto__InvoiceLine__c = null GROUP BY accorto__Project__r.Matter__c ]){
                totalUnbilledhours = (decimal)ar.get('totalhours');
            }
        }
        return totalUnbilledhours;
    }
       
}