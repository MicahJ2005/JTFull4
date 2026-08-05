@IsTest
public class SOSLFlowSearch_Test {
 @isTest
    static void testSearchRecords_withAccountMatch() {
        // Create a test Account
        // Account acc = new Account(Name = 'TestAccountSOSL');
        // insert acc;

        Account acc = new Account(FirstName = 'John', LastName = 'Doe');
        insert acc;
        
        // Create a test Contact to ensure SOSL still prioritizes Account first
        Contact con = new Contact(FirstName = 'John', LastName = 'Doe');
        insert con;

        // Tell the test framework that SOSL should return this Account
        Test.setFixedSearchResults(new List<Id>{acc.Id});

        // Prepare input for the Invocable method
        List<String> searchTerms = new List<String>{'John Doe'};

        Test.startTest();
        List<SOSLFlowSearch.SearchResult> results = SOSLFlowSearch.searchRecords(searchTerms);
        Test.stopTest();

        // Verify results
        System.assertEquals(1, results.size(), 'Should return exactly one Account');
        System.assertEquals(acc.Id, results[0].recordId, 'Returned Id should match the inserted Account');
        // System.assertEquals(acc.Name, results[0].name, 'Returned name should match the inserted Account');
    }

    @isTest
    static void testSearchRecords_noResults() {
        // Nothing inserted with this name
        List<String> searchTerms = new List<String>{'NonExistentRecordXYZ'};

        Test.startTest();
        List<SOSLFlowSearch.SearchResult> results = SOSLFlowSearch.searchRecords(searchTerms);
        Test.stopTest();

        // Verify results are empty
        System.assertEquals(0, results.size(), 'No results should be returned for non-matching term');
    }

    @isTest
    static void testSearchRecords_emptyInput() {
        List<String> searchTerms = new List<String>();

        Test.startTest();
        List<SOSLFlowSearch.SearchResult> results = SOSLFlowSearch.searchRecords(searchTerms);
        Test.stopTest();

        // Verify results are empty
        System.assertEquals(0, results.size(), 'No results should be returned for empty input');
    }
}