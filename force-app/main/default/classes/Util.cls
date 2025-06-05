/**
 * @author  Kirk Lampert (Revolution Group)
 * @date    11/5/18
 *
 * @description  Common methods used by other Apex classes.  The existing Utility class has no dedicated
 *               test class and attempts to write one have resulted in many deployment issues that aren't
 *               feasible to debug at this time.
 */
public class Util
{
    /**
     * Helper method for exceptions
     */
    public static String getExceptionError(Exception e)
    {
        String error = e.getMessage() + ' [' + e.getLineNumber() + ']';
        System.debug(error);
        return error;
    }

    public static Boolean isAvailableField(String sObjectAPIName, String fieldAPIName) {
        // call to get the appropriate object's describe
        Map<String, Schema.SObjectType> mapGlobalDescribe = Schema.getGlobalDescribe();
        Schema.SObjectType objSObjectType = mapGlobalDescribe.get(sObjectAPIName);

        // field describe
        Schema.DescribeSObjectResult objectDescribe = objSObjectType.getDescribe();
        Map<String, Schema.SObjectField> mapFieldDescribe =
            objSObjectType.getDescribe().fields.getMap();

        // check if field exists in describe call
        return mapFieldDescribe.containsKey(fieldAPIName);
    }

    public static List<String> getDefaultRolesPicklistOptions(){
        List<String> pickListValuesList= new List<String>();
         Schema.DescribeFieldResult fieldResult = Default_Role__c.Role__c.getDescribe();
         List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
         for( Schema.PicklistEntry pickListVal : ple){
             pickListValuesList.add(pickListVal.getLabel());
         }
         return pickListValuesList;
     }

}