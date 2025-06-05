/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-21-2021
 * @last modified by  : Revolution Group (Brian Ezell)
**/
trigger OpportunityLineItemTrigger on OpportunityLineItem (before insert, before update) {
    if(!System.isFuture()) {
            if(Trigger.isBefore) {
                OpportunityLineItemTriggerHandler.productProcessFlowConverted();
            }
    }
}