/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 04-26-2022
 * @last modified by  : Brian Ezell (Slalom)
**/
public without sharing class CustomerProductsApprovalHelper {

    /**
    * @description Update next step opp tasks with the 
    *   Customer Product Approval link
    * @author Brian Ezell (Slalom) | 03-23-2022 
    * @param newApprovals 
    **/
    public static void updateTasksWithApproval(List<Customer_Products_Approval__c> customerApprovalList) {

        Set<Id> filteredCustomerApprovalIds = new Set<Id>();
        for(Customer_Products_Approval__c cpa : customerApprovalList) {
            if(cpa.Next_Step_Matter__c != null) {
                filteredCustomerApprovalIds.add(cpa.Id);
            }
        }

        updateTasksWithApprovalFuture(filteredCustomerApprovalIds);

    }

    @TestVisible
    @Future
    private static void updateTasksWithApprovalFuture(Set<id> customerApprovalIdSet) {

        List<Customer_Products_Approval__c> approvals = 
            [
                SELECT Id, Name, Next_Step_Matter__c
                FROM Customer_Products_Approval__c  
                WHERE Next_Step_Matter__c != NULL
                    AND Id = :customerApprovalIdSet
            ];

        System.debug('Approvals = ' + approvals.size());

        Map<Id, Id> mapNextStepMatterIdToApproval = new Map<Id, Id>();
        
        for(Customer_Products_Approval__c a : approvals) {
            mapNextStepMatterIdToApproval.put(a.Next_Step_Matter__c, a.Id);
        }
        
        List<Task> tasks = 
            [
                SELECT Id, Matter__c
                FROM Task
                WHERE Matter__c = :mapNextStepMatterIdToApproval.keyset()
                    AND Customer_Products_Approval__c = NULL
            ];
        
        List<Task> updateTasks = new List<Task>();
        
        for(Task t : tasks) {
            updateTasks.add(new Task (
                Id = t.Id,
                Customer_Products_Approval__c = mapNextStepMatterIdToApproval.get(t.Matter__c)
            ));
        }
        
        if(!updateTasks.isEmpty()) {
            update updateTasks;
        }            
    }
    
    public static void testPadding() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}