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
public with sharing class ContentDocumentLinkTriggerHandler {

    public static void ChangeDocumentVisbility() {
        List<ContentDocumentLink> newLinks = Trigger.new;
        String orgId = UserInfo.getOrganizationId();

        for(ContentDocumentLink l : newLinks) {
            String byPassEmailToCase = '' + l.LinkedEntityId;
            System.debug('l.LinkedEntityId: ' + l.LinkedEntityId);
            if(l.LinkedEntityId == '0DB5w000000fzaEGAQ') {
                continue;
            }
            if(!byPassEmailToCase.startsWith('02s')) {
                l.Visibility = 'AllUsers';
                l.ShareType = 'I';
            }
        }
    }
}