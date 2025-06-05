/**
 * @description       :
 * @author            : Revolution Group (Brian Ezell)
 * @group             :
 * @last modified on  : 12-07-2020
 * @last modified by  : Revolution Group (Brian Ezell)
 * Modifications Log
 * Ver   Date         Author                           Modification
 * 1.0   12-02-2020   Revolution Group (Brian Ezell)   Initial Version
**/
@IsTest
private class ClientMarkTaskCompleteControllerTest {

    @IsTest
    private static void testMarkTaskComplete() {
        Task t = new Task (
            Status = 'Not Started'
        );
        insert t;
        ClientMarkTaskCompleteController.markTaskComplete(t.Id);
        System.assertEquals('Completed', [SELECT Status FROM Task WHERE Id = :t.Id].Status);
    }

    @IsTest
    private static void testGetTaskStatus() {
        Task t = new Task (
            Status = 'Not Started'
        );
        insert t;

        String jsonResponse = ClientMarkTaskCompleteController.getTaskStatus(t.Id);
        ClientMarkTaskCompleteController.ObjectInformation objInfo = (ClientMarkTaskCompleteController.ObjectInformation) JSON.deserialize(jsonResponse, ClientMarkTaskCompleteController.ObjectInformation.class);

        String status = objInfo.Status;
        System.assertEquals('Not Started', status);
        System.assertEquals('Task', objInfo.ObjectTypeName);
    }

    @IsTest
    private static void testGetAccountObjectType() {
        Account act = new Account (
            Name = 'New Account'
        );
        insert act;

        String jsonResponse = ClientMarkTaskCompleteController.getTaskStatus(act.Id);
        ClientMarkTaskCompleteController.ObjectInformation objInfo = (ClientMarkTaskCompleteController.ObjectInformation) JSON.deserialize(jsonResponse, ClientMarkTaskCompleteController.ObjectInformation.class);
        System.assertEquals('Account', objInfo.ObjectTypeName);
    }
}