/**
 * @description       :
 * @author            : Revolution Group (Bart Young)
 * @group             :
 * @last modified on  : 03/22/2021
 * @last modified by  : Revolution Group (Bart Young)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   03-22-2021   Revolution Group (Bart Young)   Initial Version
**/
public with sharing class ScheduleParalegalController {

    private Schema.SObjectType objectType;
    private String objectId;

    public ScheduleParalegalController(ApexPages.StandardController std) {
        objectId = std.getId();
        objectType = std.getRecord().getSObjectType();
    }

    public PageReference redirectToSchedule() {

        String url = 'https://go.oncehub.com/';

        try {
            System.debug('Object Type = ' + objectType);
            //https://go.oncehub.com/LBradP?sosfLeadId={!Lead.Id}&sosfContactId={!Contact.Id}&sosfCaseId={!Case.Id}
            if(objectType == Schema.Lead.getSObjectType()) {
                    Lead l =
                    [
                        SELECT Id, Book_Consult_With__c
                        FROM Lead
                        WHERE Id = :objectId
                    ];

                url += String.format('{0}?sosfLeadId={1}',
                    new List<String> {
                        getUrlFromPicklist(l.Book_Consult_With__c),
                        objectId
                    });
            } else if(objectType == Schema.Opportunity.getSObjectType()) {
                Opportunity opp =
                    [
                        SELECT Id, AccountId,
                            (
                                SELECT Id
                                FROM AcctSeed__Projects__r
                            ),
                            (
                                SELECT Id, Name, Assigned_User__r.FirstName, Assigned_User__r.LastName, Assigned_User__r.ScheduleOnce_Booking_Name__c
                                FROM Default_Roles__r
                                WHERE Name = 'Paralegal'
                            )
                        FROM Opportunity
                        WHERE Id = :objectId
                    ];

                if(opp.Default_Roles__r.isEmpty() || opp.Default_Roles__r[0].Assigned_User__r.FirstName == null || opp.Default_Roles__r[0].Assigned_User__r.LastName == null) {
                    throw new ScheduleParalegalException('No paralegal was found for this opportunity.');
                }

                Set<Id> projectIds = new Set<Id>();
                for(AcctSeed__Project__c p : opp.AcctSeed__Projects__r) {
                    projectIds.add(p.Id);
                }

                List<AcctSeed__Project__c> projects =
                    [
                        SELECT Id,
                            (
                                SELECT Id
                                FROM Cases__r
                            )
                        FROM AcctSeed__Project__c
                        WHERE Id = :projectIds
                    ];
                if(projects.isEmpty() || projects[0].Cases__r.isEmpty()) {
                    throw new ScheduleParalegalException('No cases found on this matter.');
                }

                url += String.format('{0}?sosfContactId={1}&sosfCaseId={2}', new List<String> {
                    opp.Default_Roles__r[0].Assigned_User__r.ScheduleOnce_Booking_Name__c,
                    opp.AccountId,
                    projects[0].Cases__r[0].Id
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
                    throw new ScheduleParalegalException('No projects were found on this opportunity.');
                }

                Opportunity opp =
                [
                    SELECT Id, AccountId, Account.PersonContactId,
                        (
                            SELECT Id
                            FROM AcctSeed__Projects__r
                        ),
                        (
                            SELECT Id, Name, Assigned_User__r.FirstName, Assigned_User__r.LastName, Assigned_User__r.ScheduleOnce_Booking_Name__c
                            FROM Default_Roles__r
                            WHERE Name = 'Paralegal'
                        )
                    FROM Opportunity
                    WHERE Id = :projects[0].AcctSeed__Opportunity__c
                ];

                url += String.format('{0}?sosfContactId={1}', new List<String> {
                    opp.Default_Roles__r[0].Assigned_User__r.ScheduleOnce_Booking_Name__c,
                    opp.Account.PersonContactId
                });
            }
            
            System.debug('Url = ' + url);
            PageReference pageRef = new PageReference(url);
            pageRef.setRedirect(true);
            return pageRef;
        } catch (Exception e) {
            System.debug(e.getMessage());
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

    public class ScheduleParalegalException extends Exception {}
}