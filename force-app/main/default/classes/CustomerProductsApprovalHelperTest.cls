/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 04-26-2022
 * @last modified by  : Brian Ezell (Slalom)
**/
@IsTest
private class CustomerProductsApprovalHelperTest {
    
    @testSetup static void setup() {
        Id personAccountTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account act = new Account (
            FirstName = 'John',
            LastName = 'Smith',
            PersonMobilePhone = '123',
            RecordTypeId = personAccountTypeId
        );
        insert act;

        Opportunity opp = new Opportunity (
            Name = 'Opp 001',
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(5),
            AccountId = act.Id,
            Conflict_Check_Status__c = 'Not Done Yet',
            Rate_Type__c = 'Flat Fee',
            Case_Commencement_Call__c = 'Yes- Zoom',
            Office_that_consult_occurred_in__c = 'Maple Grove',
            Preferred_Office_for_Meeting__c = 'Forest Lake',
            Notes_for_Legal_Team_Consult_Notes__c = 'Notes go here',
            Send_Statement_Method__c = 'Email',
            Payment_Status__c = 'Paid in Full',
            Urgent__c = 'No',
            Billing_Attorney__c = 'Brad Palmer',
            Area_of_Law__c = 'Family Law'
        );
        insert opp;
        
        Product2 prod = new Product2 (
            IsActive = true,
            ProductCode = 'Prod1',
            Name = 'Prod1'
        );
        insert prod;
        Id pricebookId = Test.getStandardPricebookId();

        PricebookEntry standardPrice = new PricebookEntry (
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert standardPrice;

        OpportunityLineItem orderLine = new OpportunityLineItem (
            OpportunityId = opp.Id,
            UnitPrice = 1,
            Quantity = 1,
            PricebookEntryId = standardPrice.Id
        );
        insert orderLine;
    }
    
    
    @IsTest
    private static void testUpdateTasksWithApproval() {

        Opportunity opp = 
        [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        Account act = 
            [
                SELECT Id
                FROM Account
                LIMIT 1
            ];

        Product2 prod = 
            [
                SELECT Id
                FROM Product2
                LIMIT 1
            ];

        opp.AccountId = act.Id;
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();
        opp.Kapsten_Matter__c = 'Yes';
        update opp;

        Customer_Products_Approval__c approval = new Customer_Products_Approval__c (
            Opportunity__c = opp.Id,
            Product__c = prod.Id
        );

        insert approval;

        test.startTest();

        List<Customer_Products_Approval__c> approvalList = new List<Customer_Products_Approval__c> {
            approval
        };

        CustomerProductsApprovalHelper.updateTasksWithApproval(approvalList);

        test.stopTest();
    }

    @IsTest
    private static void testUpdateTasksWithApprovalFuture() {

        Opportunity opp = 
        [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        Account act = 
            [
                SELECT Id
                FROM Account
                LIMIT 1
            ];

        Product2 prod = 
            [
                SELECT Id
                FROM Product2
                LIMIT 1
            ];

        opp.AccountId = act.Id;
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Next Step').getRecordTypeId();
        opp.Kapsten_Matter__c = 'Yes';
        update opp;

        Customer_Products_Approval__c approval = new Customer_Products_Approval__c (
            Opportunity__c = opp.Id,
            Product__c = prod.Id
        );

        insert approval;

        test.startTest();

        CustomerProductsApprovalHelper.updateTasksWithApprovalFuture(new Set<Id> { approval.Id });
        CustomerProductsApprovalHelper.testPadding();
        test.stopTest();

    }

}