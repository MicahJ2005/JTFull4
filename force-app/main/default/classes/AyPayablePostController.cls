/***
 * @description : Class to handle payable post service
 * @author      : Shubham@ayodia 
 * @contents    : 
 ***/

public class AyPayablePostController {
    
    // @description - Method to post payable
    // @param       - list<Id> payIds
    // @return      - void
    @InvocableMethod
    public static void postPayable(List<Id> payIds){
        
        if(payIds.size() > 0){
            List<AcctSeed__Account_Payable__c > payListToPost = new List<AcctSeed__Account_Payable__c >();
            
            for(AcctSeed__Account_Payable__c pay : [Select Id FROM AcctSeed__Account_Payable__c  WHERE Id IN : payIds]){
                payListToPost.add(pay);
            }
            
            if(payListToPost.size() > 0){
                // Call the post service
                AcctSeed.PostResult[] postResults = AcctSeed.AccountPayablePostService.postAccountPayables(payListToPost); 
            }
        }
    }
}