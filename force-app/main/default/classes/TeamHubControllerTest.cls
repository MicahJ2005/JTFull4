/**
 * Test class for TeamHubController
 * Covers all methods including team member retrieval, case creation, and member details
 * Updated Date: 15 May 2026
 */
@isTest
private class TeamHubControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users for different roles
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User billingAttorney = new User(
            FirstName = 'Billing',
            LastName = 'Attorney',
            Email = 'billing.attorney@test.com',
            Username = 'billing.attorney@test.com.testorg',
            Alias = 'battny',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Title = 'Senior Attorney',
            Phone = '555-0001',
            Hobbies__c = 'Reading',
            Hobbie2__c = 'Golf',
            FunFact__c = 'Loves coffee',
            Strengths__c = 'Litigation',
            AboutMe = 'Experienced attorney',
            UserBio__c = 'Bio here',
            UserApproach__c = 'Client-focused',
            ProfilePic__c = 'https://example.com/pic1.jpg',
            SO_Portal_Booking_Page__c = 'https://booking.com/attorney1'
        );
        insert billingAttorney;
        
        User attorneyTwo = new User(
            FirstName = 'Second',
            LastName = 'Attorney',
            Email = 'attorney.two@test.com',
            Username = 'attorney.two@test.com.testorg',
            Alias = 'attny2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Title = 'Associate Attorney'
        );
        insert attorneyTwo;
        
        User paralegal = new User(
            FirstName = 'Test',
            LastName = 'Paralegal',
            Email = 'paralegal@test.com',
            Username = 'paralegal@test.com.testorg',
            Alias = 'tparal',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Title = 'Paralegal'
        );
        insert paralegal;
        
        User css = new User(
            FirstName = 'Client',
            LastName = 'Support',
            Email = 'css@test.com',
            Username = 'css@test.com.testorg',
            Alias = 'tcss',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Title = 'CSS'
        );
        insert css;
        
        User coach = new User(
            FirstName = 'Test',
            LastName = 'Coach',
            Email = 'coach@test.com',
            Username = 'coach@test.com.testorg',
            Alias = 'tcoach',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Title = 'Coach'
        );
        insert coach;
        
        User ces = new User(
            FirstName = 'Test',
            LastName = 'CES',
            Email = 'ces@test.com',
            Username = 'ces@test.com.testorg',
            Alias = 'tces',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Title = 'CES'
        );
        insert ces;
        
        // Create Account
        Account testAccount = new Account(
            Name = 'Test Client Account'
        );
        insert testAccount;
        
        // Create Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Create Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Matter Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Area_of_Law__c = 'Family Law'
        );
        insert testOpp;
        
        // Create Matter (Project) with all team members
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name = 'Test Matter - Full Team',
            AcctSeed__Opportunity__c = testOpp.Id,
            Billing_Attorney_LU__c = billingAttorney.Id,
            Attorney_Two__c = attorneyTwo.Id,
            Paralegal_LU__c = paralegal.Id,
            CSS__c = css.Id,
            Coach_LU__c = coach.Id,
            CES__c = ces.Id,
            AcctSeed__Status__c = 'Active'
        );
        insert matter;
        
        // Create Matter with only Paralegal (no CSS)
        AcctSeed__Project__c matterParalegalOnly = new AcctSeed__Project__c(
            Name = 'Test Matter - Paralegal Only',
            AcctSeed__Opportunity__c = testOpp.Id,
            Paralegal_LU__c = paralegal.Id,
            AcctSeed__Status__c = 'Active'
        );
        insert matterParalegalOnly;
        
        // Create Matter with no team members
        AcctSeed__Project__c matterNoTeam = new AcctSeed__Project__c(
            Name = 'Test Matter - No Team',
            AcctSeed__Opportunity__c = testOpp.Id,
            AcctSeed__Status__c = 'Active'
        );
        insert matterNoTeam;
    }
    
    @isTest
    static void testGetAssigneesByRecordFullTeam() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - Full Team' 
            LIMIT 1
        ];
        
        Test.startTest();
        List<TeamHubController.TeamMemberDTO> teamMembers = 
            TeamHubController.getAssigneesByRecord(matter.Id);
        Test.stopTest();
        
        System.assertEquals(6, teamMembers.size(), 'Should return 6 team members');
        
        Set<String> roles = new Set<String>();
        for (TeamHubController.TeamMemberDTO member : teamMembers) {
            roles.add(member.Role);
            System.assertNotEquals(null, member.Name, 'Member should have a name');
            System.assertNotEquals(null, member.Email, 'Member should have an email');
            System.assertEquals(true, member.IsActive, 'Member should be active');
        }
        
        System.assert(roles.contains('Attorney One'), 'Should include Attorney One');
        System.assert(roles.contains('Attorney Two'), 'Should include Attorney Two');
        System.assert(roles.contains('Paralegal'), 'Should include Paralegal');
        System.assert(roles.contains('CSS'), 'Should include CSS');
        System.assert(roles.contains('Coach'), 'Should include Coach');
        System.assert(roles.contains('CES'), 'Should include CES');
        System.assert(!roles.contains('Originator'), 'Should NOT include Originator');
    }
    
    @isTest
    static void testGetAssigneesByRecordNoTeam() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - No Team' 
            LIMIT 1
        ];
        
        Test.startTest();
        List<TeamHubController.TeamMemberDTO> teamMembers = 
            TeamHubController.getAssigneesByRecord(matter.Id);
        Test.stopTest();
        
        System.assertEquals(0, teamMembers.size(), 'Should return empty list for matter with no team');
    }
    
    @isTest
    static void testGetAssigneesByRecordNullId() {
        Test.startTest();
        List<TeamHubController.TeamMemberDTO> teamMembers = 
            TeamHubController.getAssigneesByRecord(null);
        Test.stopTest();
        
        System.assertEquals(0, teamMembers.size(), 'Should return empty list for null ID');
    }

    @isTest
    static void testGetMemberDetails() {
        User u = [SELECT Id, UserBio__c, UserApproach__c FROM User WHERE Email = 'billing.attorney@test.com' LIMIT 1];
        
        Test.startTest();
        User resultUser = TeamHubController.getMemberDetails(u.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, resultUser, 'Should return a user object');
        System.assertEquals(u.Id, resultUser.Id, 'Should return the correct user ID');
        System.assertEquals('Bio here', resultUser.UserBio__c, 'Should return the correct Bio');
        System.assertEquals('Client-focused', resultUser.UserApproach__c, 'Should return the correct Approach');
        System.assertEquals('Reading', resultUser.Hobbies__c, 'Should return the correct Hobbies');
    }

    @isTest
    static void testGetBillingAttorneyId() {
        AcctSeed__Project__c matter = [
            SELECT Id, Billing_Attorney_LU__c 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - Full Team' 
            LIMIT 1
        ];
        
        Test.startTest();
        String resultId = TeamHubController.getBillingAttorneyId(matter.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, resultId, 'Billing Attorney ID should not be null');
        System.assertEquals(matter.Billing_Attorney_LU__c, resultId, 'Should return correct Billing Attorney ID');
    }
    
    @isTest
    static void testGetProjectName() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - Full Team' 
            LIMIT 1
        ];
        
        Test.startTest();
        String projectName = TeamHubController.getProjectName(matter.Id);
        Test.stopTest();
        
        System.assertEquals('Test Matter - Full Team', projectName, 'Should return correct project name');
    }
    
    @isTest
    static void testGetProjectNameNull() {
        Test.startTest();
        String projectName = TeamHubController.getProjectName(null);
        Test.stopTest();
        
        System.assertEquals('General', projectName, 'Should return General for null ID');
    }
    
    @isTest
    static void testGetContactIdFromProject() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - Full Team' 
            LIMIT 1
        ];
        
        Test.startTest();
        Id contactId = TeamHubController.getContactIdFromProject(matter.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, contactId, 'Should return a contact ID');
        
        Contact contact = [SELECT Id, LastName FROM Contact WHERE Id = :contactId];
        System.assertEquals('Doe', contact.LastName, 'Should return the correct contact');
    }
    
    @isTest
    static void testCreateCaseForTeamWithCSS() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - Full Team' 
            LIMIT 1
        ];
        
        User css = [SELECT Id FROM User WHERE Email = 'css@test.com' LIMIT 1];
        
        Test.startTest();
        String caseId = TeamHubController.createCaseForTeam(
            matter.Id,
            'Test Case Subject',
            'This is a test case description'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, caseId, 'Case ID should not be null');
        
        Case createdCase = [
            SELECT Id, Subject, Description, Status, Origin, Priority, OwnerId, ContactId, AccountId
            FROM Case 
            WHERE Id = :caseId
        ];
        
        System.assertEquals('Test Case Subject', createdCase.Subject, 'Subject should match');
        System.assert(createdCase.Description.contains('Test Matter - Full Team'), 'Description should contain matter name');
        System.assertEquals(css.Id, createdCase.OwnerId, 'Case should be assigned to CSS');
    }
    
    @isTest
    static void testCreateCaseForTeamFallbackToParalegal() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - Paralegal Only' 
            LIMIT 1
        ];
        
        User paralegal = [SELECT Id FROM User WHERE Email = 'paralegal@test.com' LIMIT 1];
        
        Test.startTest();
        String caseId = TeamHubController.createCaseForTeam(
            matter.Id,
            'Test Fallback Case',
            'Testing paralegal fallback'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, caseId, 'Case ID should not be null');
        
        Case createdCase = [SELECT Id, OwnerId FROM Case WHERE Id = :caseId];
        System.assertEquals(paralegal.Id, createdCase.OwnerId, 'Case should be assigned to Paralegal when CSS is not assigned');
    }
    
    @isTest
    static void testCreateCaseForTeamNoAssignee() {
        AcctSeed__Project__c matter = [
            SELECT Id 
            FROM AcctSeed__Project__c 
            WHERE Name = 'Test Matter - No Team' 
            LIMIT 1
        ];
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TeamHubController.createCaseForTeam(
                matter.Id,
                'Test No Assignee Case',
                'Testing no assignee scenario'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception when no CSS or Paralegal assigned');
    }
    
    @isTest
    static void testCreateCaseForTeamInvalidMatterId() {
        Id fakeId = Schema.SObjectType.AcctSeed__Project__c.getKeyPrefix() + '0'.repeat(15);
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TeamHubController.createCaseForTeam(
                fakeId,
                'Test Invalid Matter',
                'Testing invalid matter ID'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for invalid matter ID');
    }
    
    @isTest
    static void testTeamMemberDTOConstructor() {
        User testUser = [SELECT Id, Name, Email, Phone, IsActive, Title,
                        Hobbies__c, Hobbie2__c, Hobby3__c, Hobby4__c,
                        ClientStories__c, ClientStory2__c, Client_Name_1__c, Client_Name_2__c,
                        FunFact__c, Strengths__c, ProfilePic__c, AboutMe, UserBio__c,
                        UserApproach__c, SO_Portal_Booking_Page__c
                        FROM User 
                        WHERE Email = 'billing.attorney@test.com' 
                        LIMIT 1];
        
        Test.startTest();
        TeamHubController.TeamMemberDTO dto = new TeamHubController.TeamMemberDTO(testUser, 'Test Role');
        Test.stopTest();
        
        System.assertEquals(testUser.Id, dto.Id, 'ID should match');
        System.assertEquals('Test Role', dto.Role, 'Role should match');
        System.assertEquals(testUser.Hobbies__c, dto.Hobbies, 'Hobbies should match');
    }

    @isTest
    static void testUserDTOConstructor() {
        User testUser = [SELECT Id, Name, Email, Phone, IsActive, Title,
                        Hobbies__c, Hobbie2__c, Hobby3__c, Hobby4__c,
                        ClientStories__c, ClientStory2__c, Client_Name_1__c, Client_Name_2__c,
                        FunFact__c, Strengths__c, ProfilePic__c, AboutMe, UserBio__c,
                        UserApproach__c, SO_Portal_Booking_Page__c
                        FROM User 
                        WHERE Email = 'billing.attorney@test.com' 
                        LIMIT 1];
        
        Test.startTest();
        TeamHubController.UserDTO dto = new TeamHubController.UserDTO(testUser);
        Test.stopTest();
        
        System.assertEquals(testUser.Id, dto.Id, 'ID should match in legacy DTO');
        System.assertEquals(testUser.Name, dto.Name, 'Name should match in legacy DTO');
        System.assertEquals(testUser.Hobbies__c, dto.Hobbies, 'Hobbies should match in legacy DTO');
    }
}