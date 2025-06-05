/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 10-15-2021
 * @last modified by  : Revolution Group (Brian Ezell)
**/
public with sharing class ProcessPriceOverride {

    @InvocableMethod(label='Process Opportunity Price Override' category='Opportunity')
    public static List<PriceOverrideResultCls> processPriceOverride(List<OpportunityPriceOverrideCls> priceOverrides) {

        PriceOverrideResultCls results = new PriceOverrideResultCls();
        results.IsSuccessful = true;

        try {

            Id oppId = priceOverrides[0].OpportunityId;
            Decimal newPrice = priceOverrides[0].OverridePrice;
            Opportunity currentOpportunity =
                [
                    SELECT Id, Name, Amount
                    FROM Opportunity
                    WHERE Id = :oppId
                ];

            //This method will take in the price and round it to the desired value.
            //Then it will return the new price.
            List<Decimal> newOpportunityRoundedPrice = OpportunityLineItemHelper.getUpdatedPricing(new List<Decimal> { priceOverrides[0].OverridePrice });

            Decimal newPriceRatio = newOpportunityRoundedPrice[0] / currentOpportunity.Amount;

            System.debug('newOpportunityRoundedPrice = ' + newOpportunityRoundedPrice);
            System.debug('newPriceRatio = ' + newPriceRatio);

            List<Case> cases =
                [
                    SELECT Id, Subject,
                        (
                            SELECT Id, Subject, Hours__c
                            FROM Tasks
                            WHERE Hours__c > 0
                        )
                    FROM Case
                    WHERE Opportunity__c = :oppId
                ];

            List<Task> updateTasks = new List<Task>();
            for(Case c : cases) {
                for(Task t : c.Tasks) {
                    Task updateTask = new Task (
                        Id = t.Id,
                        Hours__c = newPriceRatio * t.Hours__c
                    );
                    updateTasks.add(updateTask);
                }
            }

            update updateTasks;

            List<OpportunityLineItem> opportunityProducts =
                [
                    SELECT Id, UnitPrice
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :oppId
                ];

            List<OpportunityLineItem> updateOppLines = new List<OpportunityLineItem>();

            for(OpportunityLineItem ol : opportunityProducts) {
                updateOppLines.add(new OpportunityLineItem(
                    Id = ol.Id,
                    UnitPrice = ol.UnitPrice * newPriceRatio
                ));
            }

            update updateOppLines;

        } catch (Exception e) {
            results.IsSuccessful = false;
            results.Message = e.getMessage() + '\n' + e.getStackTraceString();
        }

        return new List<PriceOverrideResultCls> {
            results
        };
    }

    public class OpportunityPriceOverrideCls {

        @InvocableVariable(label='Opportunity Id' required=true)
        public String OpportunityId;

        @InvocableVariable(label='New Opportunity Price' required=true)
        public Decimal OverridePrice;
    }

    public class PriceOverrideResultCls {

        @InvocableVariable(label='Successful')
        public Boolean IsSuccessful;

        @InvocableVariable(label='Return Message')
        public String Message;
    }

}