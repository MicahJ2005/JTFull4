/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 11-24-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-23-2020   Revolution Group (Brian Ezell)   Initial Version
**/
trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {
    if(Content_DL_Trigger__c.getOrgDefaults().Is_Enabled__c) {
        ContentDocumentLinkTriggerHandler.ChangeDocumentVisbility();
    }
}