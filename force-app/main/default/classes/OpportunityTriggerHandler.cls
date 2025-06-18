/**
 * @File Name          : OpportunityTriggerHandler.cls
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-26-2022
 * @Modification Log   :
 * Ver       Date            Author              Modification
 * 1.0    5/14/2020   Revolution Group (Brian Ezell)     Initial Version
**/
public class OpportunityTriggerHandler {

    private static Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();
    private static Id hourlyMatterRecordTypeId = Schema.SObjectType.AcctSeed__Project__c.getRecordTypeInfosByName().get('Hourly').getRecordTypeId();
    private static final String PROPOSALMADESTAGE = 'Proposal Made';
    private static final String WAITINGONCUSTOMERSTAGE = 'Waiting on Customer';

    public static void createDefaultRoles(List<Opportunity> newOpps) {

        List<String> availableDefaultRoles = Util.getDefaultRolesPicklistOptions();

        List<Group> roles =
            [
                SELECT Id, Name
                FROM Group
                WHERE Type = 'Queue'
                    AND Name = :availableDefaultRoles
            ];

        //First create a map of name => id for easy lookup
        Map<String, Id> mapRoleNameToId = new Map<String, Id>();
        for(Group q : roles) {
            mapRoleNameToId.put(q.Name, q.Id);
        }

        List<Default_Role__c> newDefaultRoles = new List<Default_Role__c>();

        for(Opportunity o : newOpps) {
            for(String role : availableDefaultRoles) {
                newDefaultRoles.add(new Default_Role__c(
                    Opportunity__c = o.Id,
                    Name = role,
                    Assigned_Queue__c = role == 'CES' ? null : role,
                    Assigned_User__c = role == 'CES' ? o.OwnerId : role != null ? null : UserInfo.getUserId()
                ));
            }
        }

        System.debug('Default Roles = ' + newDefaultRoles);
        insert newDefaultRoles;
    }

    public static void createProjectOnClosedWonOpportunity(List<Opportunity> newOpps, Map<Id, Opportunity> oldOPpsMap) {

        List<Opportunity> closedWonOps = new List<Opportunity>();
        List<Id> nextStepIdsToActivate = new List<Id>();
        for(Opportunity o : newOpps) {
            Opportunity oldOpp = oldOppsMap.get(o.Id);

            if(o.RecordTypeId != nextStepRecordTypeId ) {
                if(o.StageName != oldOpp.stageName && o.StageName == 'Closed Won') {
                    if(o.Rate_Type__c == 'Hourly') {
                        AcctSeed__Project__c hourlyProject = new AcctSeed__Project__c (
                            Name = o.Name,
                            RecordTypeId = hourlyMatterRecordTypeId,
                            AcctSeed__Status__c = 'Active',
                            AcctSeed__Account__c = o.AccountId,
                            AcctSeed__Opportunity__c = o.Id,
                            Spouse__c = o.Spouse__c
                        );
                        insert hourlyProject;
                    } else {
                        List<CreateProcessFlowController.ProcessInput> inputs = new List<CreateProcessFlowController.ProcessInput>();
                        CreateProcessFlowController.ProcessInput oneInput = new CreateProcessFlowController.ProcessInput();

                        oneInput.ObjectId = o.Id;
                        oneInput.ObjectName = 'Opportunity';
                        oneInput.TemplateId = null;

                        inputs.add(oneInput);

                        CreateProcessFlowController processor = new CreateProcessFlowController(oneInput);
                        System.enqueueJob(processor);

                    }
                }
            } else {

                //If this was closd won and a next step project, then
                //mark the cases as active
                if(o.StageName != oldOpp.StageName && o.StageName == 'Closed Won') {
                    nextStepIdsToActivate.add(o.Id);
                }
            }
        }

        if(!nextStepIdsToActivate.isEmpty()) {
            markNextStepCasesAsActive(nextStepIdsToActivate);
        }
    }

    @Future
    private static void markNextStepCasesAsActive(List<Id> oppIds) {
        List<Case> cases =
            [
                SELECT Id, Status
                FROM Case
                WHERE Opportunity__c = :oppIds
            ];

        List<Case> updateCases = new List<Case>();
        for(Case c : cases) {
            updateCases.add(new Case (
                Id = c.Id,
                Status = 'Active'
            ));
        }
        if(!updateCases.isEmpty()) {
            update updateCases;
        }
    }

    public static void updateCESRoleIfOwnerChanges(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppsMap) {
        Map<Id, Id> mapOpportunityToNewOwner = new Map<Id, Id>();
        for(Opportunity o : newOpps) {
            Opportunity oldOpp = oldOppsMap.get(o.Id);
            if(o.OwnerID != oldOpp.OwnerId) {
                mapOpportunityToNewOwner.put(o.Id, o.OwnerId);
            }
        }

        if(!mapOpportunityToNewOwner.isEmpty()) {
            List<Default_Role__c> cesRoles =
                [
                    SELECT Id, Opportunity__c
                    FROM Default_Role__c
                    WHERE Opportunity__c = :mapOpportunityToNewOwner.keySet()
                        AND Name = 'CES'
                ];
            List<Default_Role__c> updateRoles = new List<Default_Role__c>();
            for(Default_Role__c r : cesRoles) {
                updateRoles.add(new Default_Role__c(
                    Id = r.Id,
                    Assigned_User__c = mapOpportunityToNewOwner.get(r.Opportunity__c)
                ));
            }
            update updateRoles;
        }
    }

    public static void createCommunityUser(List<Opportunity> newOppsList, Map<Id, Opportunity> oldOppMap){
        Id nextStepRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Next_Step').getRecordTypeId();
        Set<Id>accoutIds = new Set<Id>();
        for (Opportunity opp : newOppsList){
            if(opp.StageName != oldOppMap.get(opp.Id).StageName && opp.StageName == PROPOSALMADESTAGE && opp.RecordTypeId == nextStepRecordTypeId){
               accoutIds.add(opp.AccountId);
            }
        }
        if(accoutIds.size() > 0 ){
            String orgId = UserInfo.getOrganizationId();
            String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
            Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
            String uniqueName = orgId + dateString + randomInt;
            Account currentAccount = [Select Id, PersonContactId, PersonEmail, LastName, FirstName, IsPersonAccount, IsCustomerPortal From Account Where Id IN: accoutIds];
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name='Kapsten Customer Community Login User' Limit 1];


            if(currentAccount.isPersonAccount == true && currentAccount.IsCustomerPortal == false){
                User newUser = new User(
                    UserName = currentAccount.PersonEmail,
                    FirstName = currentAccount.FirstName,
                    LastName = currentAccount.LastName,
                    Alias =  currentAccount.FirstName.substring(0,1) + currentAccount.LastName.substring(0,4),
                    CommunityNickname = currentAccount.FirstName + '.' + currentAccount.LastName + '.' + uniqueName.substring(18,23),
                    email = currentAccount.PersonEmail,
                    ContactId = currentAccount.PersonContactId,
                    ProfileId = portalProfile.Id,
                    EmailEncodingKey = 'UTF-8',
                    TimeZoneSidKey = 'America/Los_Angeles',
                    LocaleSidKey = 'en_US',
                    LanguageLocaleKey = 'en_US'
                    );

                    try {
                        Database.insert(newUser);

                        assignPermissionSet(new Set<Id>{newUser.Id});

                        createProductsToApprove(newOppsList[0].Id, newUser.Id);
                    } catch (Exception ex) {
                        System.Debug('Unable to create new user:' + ex.getMessage());
                        newOppsList[0].addError(ex.getMessage());
                    }

            }else if(currentAccount.isPersonAccount == true && currentAccount.IsCustomerPortal == true){
                try {
                    User currentUser = [Select Id From User Where ContactId =: currentAccount.PersonContactId Limit 1];
                    system.debug('Current User' +  currentUser);
                    createProductsToApprove(newOppsList[0].Id, currentUser.Id);
                } catch (Exception ex) {
                    System.Debug('Unable to create new user:' + ex.getMessage());
                    newOppsList[0].addError(ex.getMessage());
                }

            }
        }

    }

    public static void createProductsToApprove(Id oppId, Id userId){
        List<Customer_Products_Approval__c> custProdToInsert = new List<Customer_Products_Approval__c>();
        List<Opportunity> opps =
            [
                SELECT Id, Next_Step_Matter__c, Related_Matter_Termination__c, Total_w_New_Opportunity__c
                FROM Opportunity
                WHERE Next_Step_Matter__c != null
                    AND Id =: oppId
            ];

        System.Debug('Opps: ' + opps);
        if(opps.size() > 0){
            for(Opportunity opp: opps){

                    Customer_Products_Approval__c cpa = new Customer_Products_Approval__c();
                    //cpa.OwnerId = userId;
                    cpa.Opportunity__c = opp.Id;
                	cpa.Opportunity_MD__c = opp.Id;
                    cpa.Status__c = WAITINGONCUSTOMERSTAGE;
                    cpa.Next_Step_Matter__c = opp.Next_Step_Matter__c;
                    cpa.Related_Matter_Termination__c = opp.Related_Matter_Termination__c;
                    custProdToInsert.add(cpa);
            }
        }

        System.Debug('This Many Product To Approve: ' + custProdToInsert);

        if(custProdToInsert.size() > 0) {
            insert custProdToInsert;
        }
    }

    @future
    public static void assignPermissionSet(set<Id> userIds){
        User u = [Select id from User where Id IN: userIds];
        PermissionSet pSet = [SELECT Id FROM PermissionSet WHERE Name = 'Community_Permission_Set' Limit 1];
        PermissionSetAssignment  pr = new PermissionSetAssignment (AssigneeId=u.Id,PermissionSetId=pSet.Id);
        insert pr;
    }

    public static void RelateCommunicationsForOpportunities(Map<Id, Opportunity> newMap) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : newMap.values()) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }

        // Get all prior Opportunities for the same accounts, excluding the newly inserted ones
        List<Opportunity> priorOpps = [
            SELECT Id, AccountId, CreatedDate
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND Id NOT IN :newMap.keySet()
            ORDER BY CreatedDate DESC
        ];

        // Map of AccountId -> most recent previous Opportunity
        Map<Id, Opportunity> mostRecentPriorOppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : priorOpps) {
            if (!mostRecentPriorOppMap.containsKey(opp.AccountId)) {
                mostRecentPriorOppMap.put(opp.AccountId, opp);
            }
        }

        List<SObject> newLinks = new List<SObject>();

        for (Opportunity newOpp : newMap.values()) {
            Id acctId = newOpp.AccountId;
            if (acctId == null || !mostRecentPriorOppMap.containsKey(acctId)) continue;

            Opportunity prevOpp = mostRecentPriorOppMap.get(acctId);

            // Call Transcripts
            List<Related_Call_Transcript__c> prevCalls = [
                SELECT Id, Call_Transcript__c
                FROM Related_Call_Transcript__c
                WHERE Opportunity__c = :prevOpp.Id
            ];
            for (Related_Call_Transcript__c call : prevCalls) {
                newLinks.add(new Related_Call_Transcript__c(
                    Opportunity__c = newOpp.Id,
                    Call_Transcript__c = call.Call_Transcript__c
                ));
            }

            // Meeting Transcripts
            List<Related_Meeting_Transcript__c> prevMeetings = [
                SELECT Id, Meeting_Transcript__c
                FROM Related_Meeting_Transcript__c
                WHERE Opportunity__c = :prevOpp.Id
            ];
            for (Related_Meeting_Transcript__c meeting : prevMeetings) {
                newLinks.add(new Related_Meeting_Transcript__c(
                    Opportunity__c = newOpp.Id,
                    Meeting_Transcript__c = meeting.Meeting_Transcript__c
                ));
            }

            // Text Messages
            List<Related_Text_Message__c> prevTexts = [
                SELECT Id, Text_Message_Session__c
                FROM Related_Text_Message__c
                WHERE Opportunity__c = :prevOpp.Id
            ];
            for (Related_Text_Message__c text : prevTexts) {
                newLinks.add(new Related_Text_Message__c(
                    Opportunity__c = newOpp.Id,
                    Text_Message_Session__c = text.Text_Message_Session__c
                ));
            }
        }

        if (!newLinks.isEmpty()) {
            // insert newLinks;
        }
    }
}