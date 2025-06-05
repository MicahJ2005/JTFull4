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
public class ClientMarkTaskCompleteController {

    @AuraEnabled
    public static string getTaskStatus(String taskId){
        try {
            ObjectInformation info = new ObjectInformation();
            info.ObjectTypeName = Id.valueOf(taskId).getSobjectType().getDescribe().getLabel();

            List<Task> tasks =
                [
                    SELECT Id, Status
                    FROM Task
                    WHERE Id = :taskId
                ];
            if(!tasks.isEmpty()) {
                info.Status = tasks[0].Status;
            }
            return JSON.serialize(info);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string markTaskComplete(String taskId){
        try {
            Task t = new Task (
                Id = taskId,
                Status = 'Completed'
            );
            update t;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return '';
    }

    //Added to return information about the class rather than
    //just the status of the task.  That way
    //the object type can be displayed on the component
    public class ObjectInformation {
        public String Status;
        public String ObjectTypeName;
    }

}