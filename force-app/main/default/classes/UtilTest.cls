/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 09-22-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   09-22-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class UtilTest {

    @IsTest
    private static void testGetExceptionError() {
        Boolean isError = false;

        try {
            throw new UtilTestException('Throw Me!');
        } catch (Exception e) {
            isError = true;
            String stringError = Util.getExceptionError(e);
        }
        System.assertEquals(true, isError);
    }

    @IsTest
    private static void testIsAvailableField() {
        System.assertEquals(false, Util.isAvailableField('Account', 'This_Would_Never_Exist'));
        System.assertEquals(true, Util.isAvailableField('Account', 'Name'));
    }

    @IsTest
    private static void testGetDefaultRolesPicklistOptions() {
        List<String> options = Util.getDefaultRolesPicklistOptions();
        System.assertNotEquals(0, options.size());
    }

    private class UtilTestException extends Exception {}

}