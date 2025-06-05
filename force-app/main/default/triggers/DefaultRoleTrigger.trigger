/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 11-23-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-23-2020   Revolution Group (Brian Ezell)   Initial Version
**/
trigger DefaultRoleTrigger on Default_Role__c (after insert, after update) {
    if(!System.isFuture()) {
        DefaultRoleTriggerHandler.updateRolesOnTasks();
    }
}