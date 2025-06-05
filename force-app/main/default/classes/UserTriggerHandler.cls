/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 11-30-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   11-21-2020   Revolution Group (Brian Ezell)   Initial Version
**/
public with sharing class UserTriggerHandler {

    public static void onUserChanges() {

        List<Id> usersToShare = new List<Id>();

        Map<Id, User> newUsersMap = new Map<Id, User>(
            [
                SELECT Id, Profile.Name, IsActive
                FROM User
                WHERE Id = :Trigger.new
                    AND IsActive = true
                    AND Profile.Name LIKE '%Community%'
            ]);
        shareMattersWithUsers(newUsersMap.keySet());
    }

    /**
    * @description Takes a list of created users and
    *   shares matters/cases with them based on
    *   the spouse lookup on the opportunity.
    * @author Revolution Group (Brian Ezell) | 11-21-2020
    * @param userIds
    **/
    @TestVisible
    @Future
    private static void shareMattersWithUsers(Set<Id> userIds) {

        List<User> users =
            [
                SELECT Id, Name, Email, IsActive, Profile.Name
                FROM User
                WHERE Id = :userIds
                    AND IsActive = true
            ];

        //We have to match based on email AND name so do both
        List<String> emailsForLookup = new List<String>();
        List<String> namesForLookup = new List<String>();

        for(User u : users) {
            emailsForLookup.add(u.Email);
            namesForLookup.add(u.Name);
        }

        //Get the matters and the cases that point to them
        List<AcctSeed__Project__c> matters =
            [
                SELECT Id, Name, AcctSeed__Opportunity__r.Spouse__r.PersonEmail,
                    AcctSeed__Opportunity__r.Spouse__r.Name, AcctSeed__Opportunity__r.Account.Name, AcctSeed__Opportunity__r.Account.PersonEmail,
                    (
                        SELECT Id, Subject
                        FROM Cases__r
                    )
                FROM AcctSeed__Project__c
                WHERE (
                        AcctSeed__Opportunity__r.Spouse__r.PersonEmail = :emailsForLookup
                        AND AcctSeed__Opportunity__r.Spouse__r.Name = :namesForLookup
                ) OR (
                    AcctSeed__Opportunity__r.Account.PersonEmail = :emailsForLookup
                    AND AcctSeed__Opportunity__r.Account.Name = :namesForLookup
                )
            ];

        //Match the matter up to the person accout (email and name)
        for(AcctSeed__Project__c m : matters) {
            for(User u : users) {
                if(u.Email != null && u.Name != null) {
                    if(
                        (u.Email.equalsIgnoreCase(m.AcctSeed__Opportunity__r.Spouse__r.PersonEmail) && u.Name.equalsIgnoreCase(m.AcctSeed__Opportunity__r.Spouse__r.Name)) ||
                        (u.Email.equalsIgnoreCase(m.AcctSeed__Opportunity__r.Account.PersonEmail) && u.Name.equalsIgnoreCase(m.AcctSeed__Opportunity__r.Account.Name))
                    ) {
                            shareMatterAndCases(u.Id, m);
                    }
                }
            }
        }
    }

    /**
    * @description Creates the shares for the project (matter) and
    *   child cases under it.  This allows the spouse to see
    *   them.
    * @author Revolution Group (Brian Ezell) | 11-21-2020
    * @param userId
    * @param matter
    **/
    private static void shareMatterAndCases(Id userId, AcctSeed__Project__c matter) {

        //Community plus licensing not in sandbox so don't save
        if(!IsSandbox() && !Test.isRunningTest()) {
            //Grant sharing to the matter
            insert new AcctSeed__Project__Share (
                UserOrGroupId = userId,
                AccessLevel = 'Edit',
                ParentId = matter.Id
            );
        }

        Set<Id> caseIds = new Set<Id>();
        for(Case c : matter.Cases__r) {
            caseIds.add(c.Id);
        }

        List<Case> matterCases =
            [
                SELECT Id, Subject
                FROM Case
                WHERE Top_Level_Task_Tracker_Case__c = :caseIds
            ];

        List<CaseShare> caseShares = new List<CaseShare>();
        for(Case c : matterCases) {
            caseShares.add(new CaseShare(
                CaseId = c.Id,
                UserOrGroupId = userId,
                CaseAccessLevel = 'Edit'
            ));
        }

        if(!caseShares.isEmpty() && !IsSandbox() && !Test.isRunningTest()) {
            insert caseShares;
        }
    }

    private static Boolean IsSandbox() {
        return
            [
                SELECT IsSandbox
                FROM Organization
                LIMIT 1
            ].IsSandbox;
    }

}