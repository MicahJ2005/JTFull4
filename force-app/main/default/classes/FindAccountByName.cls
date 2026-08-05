public with sharing class FindAccountByName {
    // Class to accept flow input
    public class AccountNameRequest {
        @InvocableVariable(required=true)
        public String accountName;
    }

    // Class to send flow output
    public class AccountIdResponse {
        @InvocableVariable
        public String accountId;
    }

    @InvocableMethod(
        label='Find Account by Name' 
        description='Searches for an Account by Name using SOSL and returns its Id'
    )
    public static List<AccountIdResponse> getAccountId(List<AccountNameRequest> requests) {
        List<AccountIdResponse> results = new List<AccountIdResponse>();

        for (AccountNameRequest req : requests) {
            AccountIdResponse res = new AccountIdResponse();

            if (String.isNotBlank(req.accountName)) {
                // SOSL to search for the Account Name
                List<List<SObject>> searchResults = [
                    FIND :req.accountName 
                    IN NAME FIELDS 
                    RETURNING Account(Id LIMIT 1)
                ];

                if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                    Account foundAccount = (Account) searchResults[0][0];
                    res.accountId = foundAccount.Id;
                } else {
                    res.accountId = null; // Not found
                }
            }
            results.add(res);
        }
        return results;
    }
}