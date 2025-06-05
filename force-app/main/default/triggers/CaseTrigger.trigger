/**
 * @File Name          : CaseTrigger.trigger
 * @Description        :
 * @Author             : Revolution Group (Brian Ezell)
 * @Group              :
 * @Last Modified By   : Revolution Group (Brian Ezell)
 * @Last Modified On   : 1/30/2020, 12:24:37 PM
 * @Modification Log   :
 * Ver       Date            Author                 Modification
 * 1.0    1/28/2020   Revolution Group (Brian Ezell)     Initial Version
**/
trigger CaseTrigger on Case (after update) {

    CaseTriggerController.updateTaskTrackerCaseProgress(Trigger.new, Trigger.oldMap);

}