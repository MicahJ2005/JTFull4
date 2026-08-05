public with sharing class SOSLFlowSearch {
    public class SearchResult {
        @InvocableVariable
        public String recordId;
        @InvocableVariable
        public String name;
    }

    @InvocableMethod(label='Search with SOSL')
    public static List<SearchResult> searchRecords(List<String> searchTerms) {
        List<SearchResult> results = new List<SearchResult>();
        if (searchTerms.isEmpty()) {
            return results;
        }

        String searchTerm = searchTerms[0]; // Assuming one search term for simplicity

        // Your SOSL query
        List<List<SObject>> searchResultsList = Search.query(
            'FIND :searchTerm IN ALL FIELDS RETURNING Account(Id, Name), Contact(Id, Name)'
        );

        // Only return the first Account if found
        if (!searchResultsList.isEmpty() && !searchResultsList[0].isEmpty()) {
            Account acc = (Account)searchResultsList[0][0];
            SearchResult res = new SearchResult();
            res.recordId = acc.Id;
            res.name = acc.Name;
            results.add(res);
        }
        return results;
    }
}