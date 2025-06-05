({
    onloadScript: function(component, event, helper){
        console.log("script loaded successfully!!");
        helper.HostedFields = window.AffiniPay.HostedFields;

        // initialize cc fields on load
        //helper.initCreditCardFields(component, helper);
    },

    doInIt: function(component, event, helper){

      // fetch settings for public key
      var action = component.get("c.initAction");

      action.setParams({
        accountId: component.get("v.recordId")
      });

      action.setCallback(this, function(response){
        var state = response.getState();
        if(state === "SUCCESS") {
          console.log("success getting settings");
          var retObj = response.getReturnValue();
          var json = JSON.parse(retObj.jsonStr);
          component.set("v.settings", json);
          component.set("v.dataWrapper",retObj);
          component.set("v.recordId", retObj.accountId);
          //component.set("v.depositAccountId",retObj.depositAccount);
          var visibleAccounts = json.deposit_accounts
            ? json.deposit_accounts.filter((m) => m.selectable === true)
            : [];
          component.set("v.apAccounts", { results: visibleAccounts });
          component.set("v.apAccounts2", { results: visibleAccounts });
          component.set("v.relatedTypes", json.related_types);
          
          // matters
          var result = retObj.matters;
          var mattersMap = [];
            for(var key in result){
              mattersMap.push({key: key, value: result[key]});
            }
          component.set("v.mattersMap", mattersMap);
            
          // transaction type
          var result2 = retObj.transactionType;
          var tTypeMap = [];
            for(var key in result2){
              tTypeMap.push({key: key, value: result2[key]});
            }
          component.set("v.tTypeMap", tTypeMap);

          if (json.related_types && json.related_types.length > 0) {
            component.set(
              "v.selectedRelatedType",
              json.related_types[0].api_name
            );
          }
          component.set(
            "v.canCharge",
            json.canCreateTransaction
          );

          //helper.initTableColumns(component, event, helper);

          // ensure the contact is linked to an affinipay contact
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
          component.set("v.isAchBusiness", true);
          component.set("v.isAchIndividual", false);
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

    doCharge: function(component, event, helper){
        console.log("running charge for: " + component.get("v.recordId"));
        var activeAccordianSection = component.find("accordion").get("v.activeSectionName");
        console.log("activeAccordianSection==" + activeAccordianSection);
        if(activeAccordianSection === "existingPaymentMethod") {
            helper.doMethodCharge(component, helper);
        }else{
            var isCreditCardCharge = component.get("v.isCreditCardVisible");
            if(isCreditCardCharge){
                //console.log("month:" + component.find("cc-month").get("v.value"));
                //console.log("year:" + component.find("cc-year").get("v.value"));
                //console.log("postal code:" + component.find("postalCode").get("v.value"));
                helper.doCreditCardCharge(component, helper);
            }else{
                helper.doAchCharge(component, helper);
            }
      }
    },

    closeComp: function(component, event, helper){
        $A.get('e.force:refreshView').fire(); 
        $A.get("e.force:closeQuickAction").fire();  
    },

    toggleThirdParty : function(component, event, helper){
      var thirdPartyPayment = component.find("cc-tpan-pm").get("v.checked");

      if(thirdPartyPayment){
          component.set("v.displayTPDetails", true);
      }else{
          component.set("v.displayTPDetails", false);
      }
    }
});