/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-21-2021
 * @last modified by  : Revolution Group (Brian Ezell)
**/
public with sharing class OpportunityLineItemTriggerHandler {

    public static void productProcessFlowConverted() {
        List<OpportunityLineItem> newLines = Trigger.new;
        Map<Id, OpportunityLineItem> mapOldLines = Trigger.isInsert ? null : (Map<Id, OpportunityLineItem>) Trigger.oldMap;
        Map<Id, Opportunity> mapUpdateOpps = new Map<Id, Opportunity>();

        Set<Id> product2Ids = new Set<Id>();
        for(OpportunityLineItem li : newLines) {
            product2Ids.add(li.Product2Id);
        }

        Map<Id, Product2> mapProducts = new Map<Id, Product2> (
            [
                SELECT Id, Cost__c, Description, Business_Entity__c
                FROM Product2
                WHERE Id = :product2Ids
            ]
        );

        for(OpportunityLineItem li : newLines) {
            Product2 prod = mapProducts.get(li.Product2Id);
            if(String.isBlank(li.List_of_Services_and_Documents__c)) {
                li.List_of_Services_and_Documents__c = prod.Description;
                li.Cost__c = prod.Cost__c;
            }

            if(prod.Business_Entity__c == 'Kapsten') {
                if(!mapUpdateOpps.containsKey(li.OpportunityId)) {
                    mapUpdateOpps.put(li.OpportunityId,
                        new Opportunity(
                            Id = li.OpportunityId,
                            Kapsten_Matter__c = 'Yes'
                        )
                    );
                } else {
                    mapUpdateOpps.get(li.OpportunityId).Kapsten_Matter__c = 'Yes';
                }
            }

            if(String.isNotBlank(li.Product_Name__c)) {
                if(!mapUpdateOpps.containsKey(li.OpportunityId)) {
                    mapUpdateOpps.put(li.OpportunityId,
                        new Opportunity(
                            Id = li.OpportunityId,
                            Package__c = li.Product_Name__c
                        )
                    );
                } else {
                    mapUpdateOpps.get(li.OpportunityId).Package__c = li.Product_Name__c;
                }
            }
        }

        if(!mapUpdateOpps.isEmpty()) {
            update mapUpdateOpps.values();
        }
    }
}