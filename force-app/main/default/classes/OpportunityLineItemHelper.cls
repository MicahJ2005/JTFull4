/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 06-18-2021
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   03-03-2021   Revolution Group (Brian Ezell)   Initial Version
**/
public class OpportunityLineItemHelper {

    private static Task_Tracker_Settings__c trackerSettings = Task_Tracker_Settings__c.getInstance();

    /**
    * @description Takes in the current price and rounds/subtracts
    *   based on custom settings (Task_Tracker_Settings__c)
    * @author Revolution Group (Brian Ezell) | 03-03-2021
    * @param currentPrice
    * @return Decimal
    **/
    @InvocableMethod(label='Get Rounded Pricing' description='Returns the rounded pricing based on the custom settings for task tracker.')
    public static List<Decimal> getUpdatedPricing(List<Decimal> currentPricingList) {

        List<Decimal> finalPricingList = new List<Decimal>();
        if(currentPricingList != null) {
            for(Decimal d : currentPricingList) {
                Decimal rounded = (d / trackerSettings.Round_To_Nearest__c).round(System.RoundingMode.HALF_UP);
                Decimal finalPrice = (rounded * trackerSettings.Round_To_Nearest__c) - trackerSettings.Then_Subtract__c;
                finalPricingList.add(finalPrice);
            }
        }

        return finalPricingList;
    }

}