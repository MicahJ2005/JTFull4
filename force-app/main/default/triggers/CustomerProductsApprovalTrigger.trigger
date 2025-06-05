/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 03-23-2022
 * @last modified by  : Brian Ezell (Slalom)
**/
trigger CustomerProductsApprovalTrigger on Customer_Products_Approval__c (after insert, after update) {

    if(!System.isFuture()) {
        CustomerProductsApprovalHelper.updateTasksWithApproval(Trigger.new);
    }
    
}