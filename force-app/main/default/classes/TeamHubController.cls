/**
 * Exposes a cacheable, read-only service for Lightning (LWC/Aura) that resolves the
 * team members (assignees) related to a Matter (AcctSeed__Project__c).
 * Retrieves team members directly from Matter lookup fields.
 * @Date 15 October 2025
 */
global without sharing class TeamHubController {
    
    /**
     * Gets all assigned team members from Matter lookup fields
     * Returns only users that are assigned and active
     */
    @AuraEnabled(cacheable=true)
    public static List<TeamMemberDTO> getAssigneesByRecord(Id recordId) {
        
        List<TeamMemberDTO> result = new List<TeamMemberDTO>();
        
        if (recordId == null) return result;
        
        try {
            AcctSeed__Project__c matter = [
                SELECT Id, Name,
                    Billing_Attorney_LU__c,
                    Attorney_Two__c,
                    Paralegal_LU__c,
                    CSS__c,
                    Coach_LU__c,
                    CES__c
                FROM AcctSeed__Project__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (matter == null) return result;
            
            // Collect all non-null user IDs with their roles
            Map<Id, String> userIdToRole = new Map<Id, String>();
            
            if (matter.Billing_Attorney_LU__c != null) {
                userIdToRole.put(matter.Billing_Attorney_LU__c, 'Attorney One');
            }
            if (matter.Attorney_Two__c != null) {
                userIdToRole.put(matter.Attorney_Two__c, 'Attorney Two');
            }
            if (matter.Paralegal_LU__c != null) {
                userIdToRole.put(matter.Paralegal_LU__c, 'Paralegal');
            }
            if (matter.CSS__c != null) {
                userIdToRole.put(matter.CSS__c, 'CSS');
            }
            if (matter.Coach_LU__c != null) {
                userIdToRole.put(matter.Coach_LU__c, 'Coach');
            }
            if (matter.CES__c != null) {
                userIdToRole.put(matter.CES__c, 'CES');
            }
            
            // If no team members assigned, return empty list
            if (userIdToRole.isEmpty()) return result;
            
            // Query all assigned users
            List<User> users = [
                SELECT Id, Name, Email, IsActive, Phone, Title,
                    Hobbies__c, Hobbie2__c, Hobby3__c, Hobby4__c, 
                    ClientStories__c, ClientStory2__c, 
                    Client_Name_1__c, Client_Name_2__c,
                    FunFact__c, Strengths__c, ProfilePic__c, 
                    AboutMe, UserBio__c, UserApproach__c,
                    SO_Portal_Booking_Page__c
                FROM User
                WHERE Id IN :userIdToRole.keySet()
                AND IsActive = true
            ];
            
            // Build result list with role information
            for (User u : users) {
                String role = userIdToRole.get(u.Id);
                result.add(new TeamMemberDTO(u, role));
            }
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error getting assignees: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return result;
        }
    }


    @AuraEnabled(cacheable=true)
    public static User getMemberDetails(String userId) {
        return [
            SELECT Id, Name, Email, Title, 
                   Hobbies__c, Hobbie2__c, Hobby3__c, Hobby4__c,
                   ClientStories__c, ClientStory2__c, Client_Name_1__c, Client_Name_2__c,
                   FunFact__c, Strengths__c, ProfilePic__c, AboutMe, 
                   UserBio__c, UserApproach__c, SO_Portal_Booking_Page__c
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static String getProjectName(Id recordId) {
        try {
            if (recordId == null) return 'General';
            
            AcctSeed__Project__c project = [
                SELECT Id, Name
                FROM AcctSeed__Project__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            return project != null ? project.Name : 'General';
        } catch (Exception e) {
            System.debug('Error getting project name: ' + e.getMessage());
            return 'General';
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Id getContactIdFromProject(Id recordId) {
        try {
            AcctSeed__Project__c project = [
                SELECT Id, AcctSeed__Opportunity__r.AccountId
                FROM AcctSeed__Project__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (project != null && project.AcctSeed__Opportunity__r.AccountId != null) {
                List<Contact> contacts = [
                    SELECT Id
                    FROM Contact
                    WHERE AccountId = :project.AcctSeed__Opportunity__r.AccountId
                    LIMIT 1
                ];
                
                if (!contacts.isEmpty()) {
                    return contacts[0].Id;
                }
            }
        } catch (Exception e) {
            System.debug('Error getting Contact ID: ' + e.getMessage());
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static String getBillingAttorneyId(Id recordId) {
        try {
            acctSeed__Project__c project = [
                SELECT Billing_Attorney_LU__c 
                FROM acctSeed__Project__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];
            return project.Billing_Attorney_LU__c;
        } catch (Exception e) {
            System.debug('Error getting billing attorney: ' + e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static String createCaseForTeam(Id recordId, String subject, String description) {
        try {
            // Get the Matter and related data including CSS and Paralegal
            AcctSeed__Project__c matter = [
                SELECT Id, Name, 
                    AcctSeed__Opportunity__r.AccountId,
                    CSS__c,  // CSS field
                    Paralegal_LU__c  // Paralegal field
                FROM AcctSeed__Project__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (matter == null) {
                throw new AuraHandledException('Matter not found');
            }
            
            // Get Contact ID
            Id contactId = null;
            if (matter.AcctSeed__Opportunity__r.AccountId != null) {
                List<Contact> contacts = [
                    SELECT Id
                    FROM Contact
                    WHERE AccountId = :matter.AcctSeed__Opportunity__r.AccountId
                    LIMIT 1
                ];
                
                if (!contacts.isEmpty()) {
                    contactId = contacts[0].Id;
                }
            }
            
            // Determine Case Owner: CSS first, then Paralegal
            Id caseOwnerId = null;
            String ownerType = null;
            
            if (matter.CSS__c != null) {
                caseOwnerId = matter.CSS__c;
                ownerType = 'CSS';
                System.debug('Case Owner set to CSS: ' + matter.CSS__c);
            } else if (matter.Paralegal_LU__c != null) {
                caseOwnerId = matter.Paralegal_LU__c;
                ownerType = 'Paralegal';
                System.debug('Case Owner set to Paralegal: ' + matter.Paralegal_LU__c);
            } else {
                System.debug('WARNING: No CSS or Paralegal assigned to Matter');
                throw new AuraHandledException('No CSS or Paralegal assigned to this matter. Please contact your administrator.');
            }
            
            // Create the Case
            Case newCase = new Case();
            newCase.Subject = subject;
            newCase.Status = 'New';
            newCase.Origin = 'Web';
            newCase.Priority = 'Medium';
            newCase.Description = 'Matter: ' + matter.Name + '\n\n' + description;
            newCase.OwnerId = caseOwnerId;
            
            if (contactId != null) {
                newCase.ContactId = contactId;
            }
            
            if (matter.AcctSeed__Opportunity__r.AccountId != null) {
                newCase.AccountId = matter.AcctSeed__Opportunity__r.AccountId;
            }
            
            // Ignore Assignment Rules to preserve manual owner assignment
            Database.DMLOptions dmo = new Database.DMLOptions();
            dmo.assignmentRuleHeader.useDefaultRule = false;
            newCase.setOptions(dmo);
            
            insert newCase;
            
            System.debug('Case created successfully with ID: ' + newCase.Id);
            System.debug('Case assigned to ' + ownerType + ' with ID: ' + newCase.OwnerId);
            
            return newCase.Id;
            
        } catch (Exception e) {
            System.debug('Error creating case: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }
    
    /**
     * DTO that includes role information
     */
    public class TeamMemberDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Email;
        @AuraEnabled public String Phone;
        @AuraEnabled public Boolean IsActive;
        @AuraEnabled public String Role;
        @AuraEnabled public String Title;
        @AuraEnabled public String Hobbies;
        @AuraEnabled public String Hobbie2;
        @AuraEnabled public String Hobby3;
        @AuraEnabled public String Hobby4;
        @AuraEnabled public String ClientStories;
        @AuraEnabled public String ClientStory2;
        @AuraEnabled public String ClientName1;
        @AuraEnabled public String ClientName2;
        @AuraEnabled public String FunFact;
        @AuraEnabled public String Strengths;
        @AuraEnabled public String ProfilePic;
        @AuraEnabled public String AboutMe;
        @AuraEnabled public String UserBio;
        @AuraEnabled public String UserApproach;
        @AuraEnabled public String SOBookingPage;
        
        public TeamMemberDTO(User u, String role) {
            this.Id = u.Id;
            this.Name = u.Name;
            this.Email = u.Email;
            this.Phone = u.Phone;
            this.IsActive = u.IsActive;
            this.Role = role;
            this.Title = u.Title;
            this.Hobbies = u.Hobbies__c;
            this.Hobbie2 = u.Hobbie2__c;
            this.Hobby3 = u.Hobby3__c;
            this.Hobby4 = u.Hobby4__c;
            this.ClientStories = u.ClientStories__c;
            this.ClientStory2 = u.ClientStory2__c;
            this.ClientName1 = u.Client_Name_1__c;
            this.ClientName2 = u.Client_Name_2__c;
            this.FunFact = u.FunFact__c;
            this.Strengths = u.Strengths__c;
            this.ProfilePic = u.ProfilePic__c;
            this.AboutMe = u.AboutMe;
            this.UserBio = u.UserBio__c;
            this.UserApproach = u.UserApproach__c;
            this.SOBookingPage = u.SO_Portal_Booking_Page__c;
        }
    }
    
    // Keep old DTO for backward compatibility if needed
    public class UserDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Email;
        @AuraEnabled public String Phone;
        @AuraEnabled public Boolean IsActive;
        @AuraEnabled public String Hobbies;
        @AuraEnabled public String Hobbie2;
        @AuraEnabled public String Hobby3;
        @AuraEnabled public String Hobby4;
        @AuraEnabled public String ClientStories;
        @AuraEnabled public String ClientStory2;
        @AuraEnabled public String ClientName1;
        @AuraEnabled public String ClientName2;
        @AuraEnabled public String FunFact;
        @AuraEnabled public String Strengths;
        @AuraEnabled public String ProfilePic;
        @AuraEnabled public String AboutMe;
        @AuraEnabled public String UserBio;
        @AuraEnabled public String UserApproach;
        @AuraEnabled public String SOBookingPage;
        
        public UserDTO(User u) {
            this.Id = u.Id;
            this.Name = u.Name;
            this.Email = u.Email;
            this.Phone = u.Phone;
            this.IsActive = u.IsActive;
            this.Hobbies = u.Hobbies__c;
            this.Hobbie2 = u.Hobbie2__c;
            this.Hobby3 = u.Hobby3__c;
            this.Hobby4 = u.Hobby4__c;
            this.ClientStories = u.ClientStories__c;
            this.ClientStory2 = u.ClientStory2__c;
            this.ClientName1 = u.Client_Name_1__c;
            this.ClientName2 = u.Client_Name_2__c;
            this.FunFact = u.FunFact__c;
            this.Strengths = u.Strengths__c;
            this.ProfilePic = u.ProfilePic__c;
            this.AboutMe = u.AboutMe;
            this.UserBio = u.UserBio__c;
            this.UserApproach = u.UserApproach__c;
            this.SOBookingPage = u.SO_Portal_Booking_Page__c;
        }
    }
}