/**
 * @File Name          : OpportunityTrigger.trigger
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-26-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    5/14/2020   Revolution Group (Brian Ezell)     Initial Version
**/
trigger OpportunityTrigger on Opportunity (after insert, after update) {

    List<Opportunity> newOpps = Trigger.new;
    Map<Id, Opportunity> oldOppsMap = (Map<Id, Opportunity>)Trigger.oldMap;
    Map<Id, Opportunity> newOppsMap = (Map<Id, Opportunity>)Trigger.newMap;

    if(Trigger.isInsert) {
        OpportunityTriggerHandler.createDefaultRoles(newOpps);
        if(Trigger.isAfter){
            System.debug('InafterINsert Trigger');
            OpportunityTriggerHandler.RelateCommunicationsForOpportunities(newOppsMap);
        }
    } else {
        OpportunityTriggerHandler.createProjectOnClosedWonOpportunity(newOpps, oldOppsMap);
        OpportunityTriggerHandler.updateCESRoleIfOwnerChanges(newOpps, oldOppsMap);
        OpportunityTriggerHandler.createCommunityUser(newOpps, oldOppsMap);
    }
}