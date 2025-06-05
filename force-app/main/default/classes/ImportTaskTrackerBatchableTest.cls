/**
 * @description       : 
 * @author            : Brian Ezell (Slalom)
 * @group             : 
 * @last modified on  : 01-11-2022
 * @last modified by  : Brian Ezell (Slalom)
**/
@IsTest
private class ImportTaskTrackerBatchableTest {

    @IsTest
    private static void testImportBatch() {
        TaskTrackerTestDataFactory.createAllTestData();
        AcctSeed__Project__c matter = createMatter();
        createOneProlawConversion(matter);
 
        Test.startTest();

        Id batchJobId = Database.executeBatch(new ImportTaskTrackerBatchable(), 200);
        System.debug('Job Id = ' + batchJobId);

        Test.stopTest();

        System.assertNotEquals(0, [SELECT Id FROM Case WHERE Project__c = :matter.Id].size(), 'There should be cases on this matter now.');
    }

    private static AcctSeed__Project__c createMatter() {
        Task_Tracker_Template__c temp = 
        [
            SELECT Id
            FROM Task_Tracker_Template__c
            WHERE Is_Master_Template__c = true
            LIMIT 1
        ];

        //Set up matter and assoicated items
        User attorney = 
            [
                SELECT Id
                FROM User
                WHERE IsActive = true
                    AND Profile.Name = 'Attorney'
                LIMIT 1
            ];

        User paralegal = 
            [
                SELECT Id
                FROM User
                WHERE IsActive = true
                    AND Profile.Name LIKE 'Paralegal%'
                LIMIT 1
            ];

        User ces = 
            [
                SELECT Id
                FROM User
                WHERE IsActive = true
                    AND Profile.Name = 'Client Engagement Specialist'
                LIMIT 1
        ];   

    Product2 prod = 
        [
            SELECT Id
            FROM Product2
            LIMIT 1
        ];

    Account act = 
        [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        AcctSeed__Project__c matter = new AcctSeed__Project__c (
            Assigned_Attorney__c = attorney.Id,
            Assigned_Ces__c = ces.Id,
            Assigned_Paralegal__c = paralegal.Id,
            
            AcctSeed__Account__c = act.Id,
            AcctSeed__Status__c = 'Conversion',
            AcctSeed__Template_Project__c = false,
            Billing_Attorney_LU__c = attorney.Id,
            //Billing__c = 'a0HS0000008CkYvMAK',
            CES__c = ces.Id,
            Coach__c = 'Matt Tuttle',
            Current_Billing_Balance__c = 1495,
            Imported_For_Task_Tracker__c = false,
            Name = 'My Matter',
            Open_Hours__c = 8.2,
            Open_Task__c = 1960,
            Originator_LU__c = attorney.Id,
            Product__c = prod.Id,
            OwnerId = attorney.Id
        );
        insert matter;
        return matter;
    }

    private static void createOneProlawConversion(AcctSeed__Project__c matter) {
        insert new Prolaw_Conversion__c (
            Assigned_Attorney_Id__c = matter.Billing_Attorney_LU__c,
            Assigned_Paralegal_Id__c = matter.Assigned_Paralegal__c,
            CES_Id__c = matter.CES__c,
            Matter_Name__c = matter.Name,
            Product_Id__c = matter.Product__c,
            Related_Matter__c = matter.Id,
            Total_Attorney_Hrs__c = 10,
            Total_Paralegal_Hrs__c = 5,
            Total_Matter_Prices__c = 995,
            Was_Processed__c = false
        );
    }
}