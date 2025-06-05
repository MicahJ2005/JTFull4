/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 12-24-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-04-2020   Revolution Group (Brian Ezell)   Initial Version
**/
public with sharing class ScheduleAppointmentController {

    private Schema.SObjectType objectType;
    private String objectId;

    public ScheduleAppointmentController(ApexPages.StandardController std) {
        objectId = std.getId();
        objectType = std.getRecord().getSObjectType();
    }

    public PageReference redirectToSchedule() {

        String url = 'https://go.oncehub.com/';

        try {
            //https://go.oncehub.com/LBradP?sosfLeadId={!Lead.Id}&sosfContactId={!Contact.Id}&sosfCaseId={!Case.Id}
            if(objectType == Schema.Lead.getSObjectType()) {

                Lead l =
                    [
                        SELECT Id, Book_Consult_With__c
                        FROM Lead
                        WHERE Id = :objectId
                    ];
                if(l.Book_Consult_With__c == null) {
                    throw new ScheduleAppointmentException('This lead has no selected "Book Consult With" value.');
                }
                url += getUrlFromPicklist(l.Book_Consult_With__c) + '?sosfLeadId=' + l.Id;
            } else if(objectType == Schema.Opportunity.getSObjectType()) {
                Opportunity opp =
                    [
                        SELECT Id, AccountId, Book_Consult_With__c, Contact_ID__c
                        FROM Opportunity
                        WHERE Id = :objectId
                    ];
                    if(opp.Book_Consult_With__c == null) {
                        throw new ScheduleAppointmentException('This opportunity has no selected "Book Consult With" value.');
                    }
                    if(opp.Contact_ID__c == null) {
                        throw new ScheduleAppointmentException('This opportunity does not have a ScheduleOnce contact value.');
                    }

                url += String.format('{0}?sosfContactId={1}',
                    new List<String> {
                        getUrlFromPicklist(opp.Book_Consult_With__c),
                        opp.Contact_ID__c
                    });

            } else if(objectType == Schema.AcctSeed__Project__c.getSObjectType()) {

               List<AcctSeed__Project__c> projects =
                    [
                        SELECT Id, AcctSeed__Opportunity__c,
                            (
                                SELECT Id
                                FROM Cases__r
                            )
                        FROM AcctSeed__Project__c
                        WHERE Id = :objectId
                    ];

                if(projects.isEmpty()) {
                    throw new ScheduleAppointmentException('No projects were found on this opportunity.');
                }

                Opportunity opp =
                [
                    SELECT Id, AccountId, Account.PersonContactId,
                        (
                            SELECT Id
                            FROM AcctSeed__Projects__r
                        ),
                        (
                            SELECT Id, Name, Assigned_User__r.FirstName, Assigned_User__r.LastName
                            FROM Default_Roles__r
                            WHERE Name = 'Attorney'
                        )
                    FROM Opportunity
                    WHERE Id = :projects[0].AcctSeed__Opportunity__c
                ];

                url += String.format('{0}_{1}-C?sosfContactId={2}', new List<String> {
                    opp.Default_Roles__r[0].Assigned_User__r.FirstName,
                    opp.Default_Roles__r[0].Assigned_User__r.LastName,
                    opp.Account.PersonContactId //, AccountId
                    // projects[0].Cases__r[0].Id
                });
            }
            
            System.debug('Url = ' + url);
            PageReference pageRef = new PageReference(url);
            pageRef.setRedirect(true);
            return pageRef;
        } catch (Exception e) {
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, e.getMessage());
            ApexPages.addMessage(msg);
            return null;
        }
    }

    private static String getUrlFromPicklist(String picklistValue) {
        String urlPiece = picklistValue.replace(' ', '_');
        if(!urlPiece.startsWith('Any')) {
            urlPiece += '-L';
        } else {
            urlPiece = urlPiece.replace('Any', 'All');
            if(urlpiece.right(1) != 's') {
                urlPiece += 's';
            }
        }
        return urlPiece;
    }

    public class ScheduleAppointmentException extends Exception {}
}