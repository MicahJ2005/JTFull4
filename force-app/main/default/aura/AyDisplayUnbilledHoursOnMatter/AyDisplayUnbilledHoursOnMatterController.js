({
    doInIt : function(component, event, helper) {
        
        var recordId =  component.get("v.recordId"); 
        var action = component.get('c.getUnbilledHours');
        
        action.setParams({
            "matterId":recordId
        });
        
        action.setCallback(this,function(a){
            var recordData = a.getReturnValue();
            
            if(!$A.util.isEmpty(recordData) && !$A.util.isUndefinedOrNull(recordData)){
                component.set("v.totalUnbilledHours", recordData);    
            }
            
        });
        $A.enqueueAction(action);
    }  
})