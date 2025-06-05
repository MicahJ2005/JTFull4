/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 11-21-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-21-2020   Revolution Group (Brian Ezell)   Initial Version
**/
trigger UserTrigger on User (after insert, after update) {

    UserTriggerHandler.onUserChanges();

}