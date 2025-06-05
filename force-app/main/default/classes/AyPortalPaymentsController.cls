public class AyPortalPaymentsController{

    @AuraEnabled
    public static void checkExistingPaymentMethods(Id accountId){
        map<String,Object> existingPaymentDetailsMap = new map<String,Object>();
        existingPaymentDetailsMap = affinipay.AffiniPayService.checkContactLink('Account',accountId, null,false);

        //if(existingPaymentDetailsMap != null && existingPaymentDetailsMap.values().size() > 0){
            System.debug('****existingPaymentDetailsMap=='+existingPaymentDetailsMap);
        //}
    }   
    
}