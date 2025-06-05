({
    onloadScript: function(component, event, helper){
        console.log("script loaded successfully!!");
        try{
          helper.HostedFields = window.AffiniPay.HostedFields;

          // initialize cc fields on load
          //helper.initCreditCardFields(component, helper);
        }catch(e){
          console.log(e);
        }
    },

    doInIt: function(component, event, helper){

      //var myPageRef = component.get("v.pageReference");
      //var cpaRecordId = myPageRef.state.c__cpaId;

      var sPageURL = decodeURIComponent(window.location.search.substring(1)); 
      var sURLVariables = sPageURL.split('&');
      var sParameterName;
      var cpaRecordId;
      var i;
      
     // console.log('sURLVariables.length='+sURLVariables.length);
      for(i = 0; i < sURLVariables.length; i++){
          sParameterName = sURLVariables[i].split('=');

          if(sParameterName[0] === 'cpaId') {
              cpaRecordId = sParameterName[1];
          }
      }
      
      console.log('cpaId:'+cpaRecordId);
      
      component.set("v.cpaId", cpaRecordId);
      component.set("v.isEditable",true);
      
      // fetch settings for public key
      var action = component.get("c.initAction");

      action.setParams({
        cpaId: cpaRecordId
      });

      action.setCallback(this, function(response){
        var state = response.getState();
        if(state === "SUCCESS"){
          console.log("success getting settings");
          var retObj = response.getReturnValue();
          var json = JSON.parse(retObj.jsonStr);
          component.set("v.settings", json);
          component.set("v.dataWrapper",retObj);
          
          helper.refreshContact(component, event, helper, null);

          helper.initCreditCardFields(component, helper);
        }
      });
      $A.enqueueAction(action);

    },

    handleActiveTab: function(component, event, helper){
      var tab = event.getSource();
      switch (tab.get("v.id")) {
        case "creditcard":
          component.set("v.isCreditCardVisible", true);
          component.set("v.isAchVisible", false);
          if (!helper.getCcPaymentToken) {
            window.setTimeout(
              $A.getCallback(function () {
                helper.initCreditCardFields(component, helper);
              }),
              1
            );
          }
          break;
        case "ach":
          component.set("v.isAchVisible", true);
          //component.set("v.isAchBusiness", true);
          //component.set("v.isAchIndividual", false);
          component.set("v.isCreditCardVisible", false);
          if (!helper.getAchPaymentToken) {
            window.setTimeout(
              $A.getCallback(function () {
                helper.initAchFields(component, helper);
              }),
              1
            );
          }
          break;
      }
    },

    closeModal: function(component, event, helper){
      component.set("v.isEditable",false);

      var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
        "url": "/customer-products-approval/"+component.get("v.cpaId")
        });
        urlEvent.fire();  
    },

    doStoreMethod : function(component, event, helper) {
      helper.clearErrors(component);
          component.set("v.actionsDisabled", true);
          console.log('running charge for: ' + component.get("v.cpaId"));
  
          var isCreditCardCharge = component.get("v.isCreditCardVisible");
          if(isCreditCardCharge){
              console.log('month:' + component.find("cc-month").get("v.value"));
              console.log('year:' + component.find("cc-year").get("v.value"));
              console.log('postal code:' + component.find("postalCode").get("v.value"));
              helper.doStoreCreditCard(component, helper);
          }else{
              helper.doStoreAch(component, helper);
          }
    }
   
});