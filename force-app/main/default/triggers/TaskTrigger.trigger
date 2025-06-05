/**
 * @File Name          : TaskTrigger.trigger
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Brian Ezell (Slalom)
 * @Last Modified On   : 04-24-2022
 * @Modification Log   :
 * Ver       Date            Author      		    Modification
 * 1.0    1/27/2020   Revolution Group (Brian Ezell)     Initial Version
**/
trigger TaskTrigger on Task (before update) {

    List<Task> newTasks = Trigger.new;
    Map<Id, Task> oldTaskMap = (Map<Id, Task>) Trigger.oldMap;
    if(!System.isFuture()) {
        if(Trigger.isBefore && Trigger.isUpdate) {
            TaskTriggerHandler.updateTaskStatuses(newTasks, oldTaskMap);
        }
    }
}