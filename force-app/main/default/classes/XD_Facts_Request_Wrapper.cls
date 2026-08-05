public class XD_Facts_Request_Wrapper {
    
    @AuraEnabled @InvocableVariable(label='XD Facts Record' required=true)
    public XD_Facts__c xdFactsRecord;

    @AuraEnabled @InvocableVariable(label='Business Contact' required=true)
    public Contact businessContact;
    
}