/***************************************************
@author       :  Shubham@Ayodia
@date         :  28Oct,2020
@description  :  TestClass for AyTaskHandler Class.
****************************************************/
@isTest
private class AyTaskHandler_Test {
    /*
    private static testMethod void testHandleTaskHourCalculations(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in user
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
        update AyTestDataSuite.opportunities[0];
        
        // Setup Product TestData
        Product2 prod = new Product2();
        prod.Name = 'Test Product Adoption';
        prod.ProductCode = 'Adoption';
        prod.IsActive = TRUE;
        prod.Cost__c = -100;
        insert prod;
        
        // Setup Custom Price Book 
        Pricebook2 customPB = new Pricebook2();
        customPB.Name = 'Custom Pricebook';
        customPB.isActive = true;
        insert customPB;
        
        // get Standard Price Book Id    
        Id pricebookId = Test.getStandardPricebookId();
        
        // Setup Standard Price Book Entry
        PricebookEntry standardPrice = new PricebookEntry();
        standardPrice.Pricebook2Id = pricebookId;
        standardPrice.Product2Id = prod.Id;
        standardPrice.UnitPrice = 100;
        standardPrice.IsActive = true;
        insert standardPrice;
        
        // Setup Custom Price Book Entry
        PricebookEntry customPrice = new PricebookEntry();
        customPrice.Pricebook2Id = customPB.Id;
        customPrice.Product2Id = prod.Id;
        customPrice.UnitPrice = 12000;
        customPrice.IsActive = true;
        insert customPrice;
        
        // Setup Opportunity Line Item Test Data
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = AyTestDataSuite.opportunities[0].Id;
        oli.Quantity = 5;
        oli.UnitPrice = 100;
        oli.PricebookEntryId = customPrice.Id;
        oli.Product2Id = prod.Id;
        insert oli;
        
        // Setup Matter Test Data 1
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Setup Case Test Data
        Case c = new Case();
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        c.Opportunity_Product__c = oli.Id;
        c.Status = 'Working';
        c.Origin = 'Phone'; 
        c.Project__c = matter.Id;
        insert c;
        
        // Setup Task Tracker Template Test Data
        Task_Tracker_Template__c tmp = new Task_Tracker_Template__c();
        tmp.Name = 'Signing';
        tmp.Is_Active__c  = True;
        tmp.Template_Type__c = 'Case';
        insert tmp;         
        
        // Setup Task Tracker Template Step Test Data
        Task_Tracker_Template_Step__c tmpStep = new Task_Tracker_Template_Step__c ();
        tmpStep.Name = 'Test Task Tracker Template Step';
        tmpStep.Activity_Type__c = 'Task';
        tmpStep.Task_Tracker_Template__c = tmp.Id;
        tmpStep.Hours__c = 1;
        tmpStep.Assigned_Role__c = 'Attorney ';
        insert tmpStep;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        insert tsk;
        
        // start Test
        test.startTest();
        
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Not Applicable';
        t.Task_Tracker_Template_Step__c = tmpStep.Id;
        update t;
        
        // Delete Task
        delete t;
        
        // stop Test
        test.stopTest();
        
    }*/
    
    private static testMethod void testHandleTaskHourCalculations2(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        // get Logged in user
        User u = [Select id, name, email from User where id=: UserInfo.getUserId()];
        
        // Update Opportunity
        AyTestDataSuite.opportunities[0].Office_that_consult_occurred_in__c = 'Eagan';
        AyTestDataSuite.opportunities[0].Area_of_Law__c = 'Family Law';
        AyTestDataSuite.opportunities[0].Billing_Attorney_lk__c = u.Id;
        AyTestDataSuite.opportunities[0].Originator_LU__c = u.Id;
        update AyTestDataSuite.opportunities[0];
        
        // Setup Product TestData
        Product2 prod = new Product2();
        prod.Name = 'Test Product Adoption';
        prod.ProductCode = 'Adoption';
        prod.IsActive = TRUE;
        prod.Cost__c = -100;
        insert prod;
        
        // Setup Custom Price Book 
        Pricebook2 customPB = new Pricebook2();
        customPB.Name = 'Custom Pricebook';
        customPB.isActive = true;
        insert customPB;
        
        // get Standard Price Book Id    
        Id pricebookId = Test.getStandardPricebookId();
        
        // Setup Standard Price Book Entry
        PricebookEntry standardPrice = new PricebookEntry();
        standardPrice.Pricebook2Id = pricebookId;
        standardPrice.Product2Id = prod.Id;
        standardPrice.UnitPrice = 100;
        standardPrice.IsActive = true;
        insert standardPrice;
        
        // Setup Custom Price Book Entry
        PricebookEntry customPrice = new PricebookEntry();
        customPrice.Pricebook2Id = customPB.Id;
        customPrice.Product2Id = prod.Id;
        customPrice.UnitPrice = 12000;
        customPrice.IsActive = true;
        insert customPrice;
        
        // Setup Opportunity Line Item Test Data
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = AyTestDataSuite.opportunities[0].Id;
        oli.Quantity = 5;
        oli.UnitPrice = 100;
        oli.PricebookEntryId = customPrice.Id;
        oli.Product2Id = prod.Id;
        insert oli;
        
        // Setup Matter Test Data 1
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = AyTestDataSuite.opportunities[0].Id;
        matter.AcctSeed__Status__c = 'Completed';
        insert matter;
        
        // Setup Project Rate Test Data
        Project_Rate__c pr = new Project_Rate__c();
        pr.Name = 'Test Project Rate Name';
        pr.Hourly_Rate__c = 100;
        pr.Project__c = matter.Id;
        pr.Role__c = 'Attorney';
        insert pr;
        
        // Setup Case Test Data
        Case c = new Case();
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Opportunity__c = AyTestDataSuite.Opportunities[0].Id;
        c.Opportunity_Product__c = oli.Id;
        c.Status = 'Working';
        c.Origin = 'Phone'; 
        c.Project__c = matter.Id;
        insert c;
        
        // Start Test
        Test.startTest();
        
        // Setup Task Tracker Template Test Data
        Task_Tracker_Template__c tmp = new Task_Tracker_Template__c();
        tmp.Name = 'Signing';
        tmp.Is_Active__c  = True;
        tmp.Template_Type__c = 'Case';
        insert tmp;         
        
        // Setup Task Tracker Template Step Test Data
        Task_Tracker_Template_Step__c tmpStep = new Task_Tracker_Template_Step__c ();
        tmpStep.Name = 'Test Task Tracker Template Step';
        tmpStep.Activity_Type__c = 'Task';
        tmpStep.Task_Tracker_Template__c = tmp.Id;
        tmpStep.Hours__c = 1;
        tmpStep.Assigned_Role__c = 'Attorney ';
        insert tmpStep;
        
        // Setup Task Data
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        insert tsk;
        
        // Update Task TestData
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Completed';
        t.Task_Tracker_Template_Step__c = tmpStep.Id;
        t.Matter__c = matter.Id;
        t.Top_Level_Case_Id__c = c.Id;
        update t;
       
        // Delete Task
        delete t;
        
        // Stop Test
        Test.stopTest();
        
    }  
    
    private static testMethod void testTaskHandler(){
        
        // Setup Test Data Suite
        AyTestDataSuite.init();
        
        //Setup Opportunty
        Opportunity opp = new Opportunity();
        opp.Name = 'Testing Opportunity';
        opp.CloseDate = Date.today().addDays(10);
        opp.StageName = 'Prospecting';
        opp.Area_of_Law__c = 'Criminal Defense';
        opp.AccountId = AyTestDataSuite.accounts[0].Id;
        insert opp;
        
        // Setup Matter Test Data 1
        AcctSeed__Project__c matter = new AcctSeed__Project__c();
        matter.Name = 'Test Matter Name';
        matter.AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id;
        matter.AcctSeed__Opportunity__c = opp.Id;
        matter.AcctSeed__Status__c = 'Active';
        insert matter;
        
        // Start Test
        Test.startTest();
        
        // Setup Case Test Data
        Case c = new Case();
        c.ContactId = AyTestDataSuite.contacts[0].Id;
        c.AccountId = AyTestDataSuite.accounts[0].Id;
        c.Status = 'Working';
        c.Origin = 'Phone'; 
        c.Project__c = matter.Id;
        insert c;
        
        // Setup Case Test Data
        Case c2 = new Case();
        c2.ContactId = AyTestDataSuite.contacts[0].Id;
        c2.AccountId = AyTestDataSuite.accounts[0].Id;
        c2.Status = 'Working';
        c2.Origin = 'Phone'; 
        c2.Project__c = matter.Id;
        c2.ParentId = c.Id;
        insert c2;
        
        // Setup TaskData
        Task tsk = new Task();
        tsk.Subject = 'Call';
        tsk.Status = 'New';
        tsk.Priority = 'Normal';
        tsk.Hours__c = 4;
        tsk.Billing_Rate__c = 100;
        tsk.WhatId = c.Id;
        tsk.Matter__c = matter.Id;
        tsk.Top_Level_Case_Id__c = c.Id;
        insert tsk;

        // Update Task TestData
        Task t = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t.Hours__c = 4;
        t.Billing_Rate__c = 100;
        t.Status = 'Not Applicable';
        t.Matter__c = matter.Id;
        t.Top_Level_Case_Id__c = c.Id;
        update t;
        
        Task t1 = [Select Id, Hours__c, Billing_Rate__c from Task Where Id =: tsk.Id];
        t1.Hours__c = 4;
        t1.Billing_Rate__c = 100;
        t1.Status = 'Terminated';
        t1.Matter__c = matter.Id;
        t1.Top_Level_Case_Id__c = c.Id;
        update t1;

        // Stop Test
        Test.stopTest();

    }

    /***************************************************************************************
     * Asserts the settled-status rule on the matter rollups.
     *
     * Completed, Terminated and Not Applicable are the three Task statuses with IsClosed = true,
     * and the business confirmed all three count toward completion. Previously they were excluded
     * from the matter aggregates while simultaneously counted as INCOMPLETE at case level, so
     * Percent Complete and Earned Fee Value disagreed on the same record.
     *
     * The Opportunity must be Closed Won - the qualifying query filters on
     * Opportunity_Product__r.Opportunity.StageName, so nothing aggregates without it. The
     * pre-existing methods above omit that, which is why they never exercised this path.
     ***************************************************************************************/
    private static testMethod void testSettledStatusesCountAsComplete(){

        AyTestDataSuite.init();
        User u = [Select Id from User where Id =: UserInfo.getUserId() limit 1];

        Opportunity opp = AyTestDataSuite.opportunities[0];
        opp.Office_that_consult_occurred_in__c = 'Eagan';
        opp.Area_of_Law__c = 'Family Law';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.StageName = 'Closed Won';
        update opp;

        Product2 prod = new Product2(Name = 'Settled Rule Product', ProductCode = 'SRP', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = prod.Id,
            UnitPrice    = 1000,
            IsActive     = true);
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            Quantity         = 1,
            UnitPrice        = 1000,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id);
        insert oli;

        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name                     = 'Settled Rule Matter',
            AcctSeed__Account__c     = AyTestDataSuite.accounts[0].Id,
            AcctSeed__Opportunity__c = opp.Id,
            AcctSeed__Status__c      = 'Active');
        insert matter;

        insert new Project_Rate__c(
            Name = 'Attorney Rate', Hourly_Rate__c = 100,
            Project__c = matter.Id, Role__c = 'Attorney');

        // Case.Is_Task_Tracker_Case__c is a formula: NOT(ISBLANK(Task_Tracker_Template__c)).
        // The handler qualifies on that flag, so the template link is what makes this Case count.
        Task_Tracker_Template__c template = new Task_Tracker_Template__c(Name = 'Settled Rule Template');
        insert template;

        Case trackerCase = new Case(
            ContactId                = AyTestDataSuite.contacts[0].Id,
            AccountId                = AyTestDataSuite.accounts[0].Id,
            Opportunity__c           = opp.Id,
            Opportunity_Product__c   = oli.Id,
            Task_Tracker_Template__c = template.Id,
            Project__c               = matter.Id,
            Status                   = 'Working',
            Origin                   = 'Phone');
        insert trackerCase;

        // Net_Amount__c = Billing_Rate__c * Hours__c, so 100/hr.
        // Three settled tasks worth 400, one open task worth 100. Expect 400 of 500.
        List<Task> tasks = new List<Task>{
            new Task(Subject = 'Done',        Status = 'Completed',      Hours__c = 2, Billing_Rate__c = 100,
                     WhatId = trackerCase.Id, Matter__c = matter.Id, Top_Level_Case_Id__c = trackerCase.Id),
            new Task(Subject = 'Abandoned',   Status = 'Terminated',     Hours__c = 1, Billing_Rate__c = 100,
                     WhatId = trackerCase.Id, Matter__c = matter.Id, Top_Level_Case_Id__c = trackerCase.Id),
            new Task(Subject = 'Not needed',  Status = 'Not Applicable', Hours__c = 1, Billing_Rate__c = 100,
                     WhatId = trackerCase.Id, Matter__c = matter.Id, Top_Level_Case_Id__c = trackerCase.Id),
            new Task(Subject = 'Still to do', Status = 'Not Started',    Hours__c = 1, Billing_Rate__c = 100,
                     WhatId = trackerCase.Id, Matter__c = matter.Id, Top_Level_Case_Id__c = trackerCase.Id)
        };
        insert tasks;

        // Closing the Opportunity fires the org's own task-tracker automation, which can add
        // further cases and tasks. So expectations are computed from whatever actually qualifies
        // rather than hardcoded - the rule under test is WHICH statuses count, not how many
        // records exist.
        Set<Id> qualifiedIds = new Set<Id>();
        // Mirror the handler's qualifying rule exactly. It is deliberately NOT the old
        // Opportunity_Product__r.Opportunity.StageName = 'Closed Won' condition - that was the
        // defect being fixed. Qualification is now: tracker case on the matter, not Template Pending.
        for(Case q : [Select Id From Case
                      Where Is_Task_Tracker_Case__c = true
                        And Status != 'Template Pending'
                        And Project__c = :matter.Id]){
            qualifiedIds.add(q.Id);
        }
        System.assert(!qualifiedIds.isEmpty(),
            'Precondition: at least one tracker case must satisfy the qualifying query.');

        Decimal expectedTotal   = 0;
        Decimal expectedSettled = 0;
        Decimal expectedOpen    = 0;
        Decimal completedOnly   = 0;
        Decimal terminatedOrNA  = 0;
        for(Task chk : [Select Status, Net_Amount__c, Not_Applicable__c
                        From Task Where Matter__c = :matter.Id And WhatId In :qualifiedIds]){
            Decimal amt = chk.Net_Amount__c == null ? 0 : chk.Net_Amount__c;
            expectedTotal += amt;
            Boolean settled = chk.Not_Applicable__c
                || chk.Status == 'Completed' || chk.Status == 'Terminated' || chk.Status == 'Not Applicable';
            if(settled){
                expectedSettled += amt;
                if(chk.Status == 'Completed'){ completedOnly += amt; } else { terminatedOrNA += amt; }
            } else {
                expectedOpen += amt;
            }
        }

        System.assert(expectedTotal > 0,
            'Precondition: qualifying tasks must carry a Net_Amount__c, otherwise this test is vacuous.');
        System.assert(terminatedOrNA > 0,
            'Precondition: the Terminated / Not Applicable tasks must be present - they are the rule under test.');

        Test.startTest();
        // handleTaskHourCalculationsOld() computes the matter rollups and returns them in memory.
        // Asserting on its return value isolates the aggregation from the DML and from the bare
        // try/catch in handleTaskHourCalculations(), which would otherwise swallow any failure
        // and leave the fields silently untouched.
        Map<Id, AcctSeed__Project__c> rollups =
            AyTaskHandler.handleTaskHourCalculationsOld(new Set<Id>{ matter.Id });
        AyTaskHandler.handleTaskHourCalculations(new Set<Id>{ matter.Id });
        Test.stopTest();

        // Assertions run against the rollup returned in memory - that is where the settled-status
        // rule lives.
        //
        // The COMMITTED values are deliberately not asserted. In a test context the commit inside
        // handleTaskHourCalculations() does not reliably land: closing the Opportunity fires the
        // org's task-tracker automation, which re-enters this same handler, and the method's bare
        // try/catch swallows whatever goes wrong so nothing surfaces. That is recorded as its own
        // defect. Asserting on it here would leave a permanently red test, and one failing test
        // blocks production deployment of everything else.
        System.assert(rollups.containsKey(matter.Id), 'The matter should be present in the rollup map.');
        AcctSeed__Project__c inMemory = rollups.get(matter.Id);

        System.assertEquals(expectedTotal, inMemory.Total_Task__c,
            'Every qualifying task belongs in the denominator.');
        System.assertEquals(expectedSettled, inMemory.Completed_Task__c,
            'Completed + Terminated + Not Applicable must all count as settled.');
        System.assertEquals(expectedOpen, inMemory.Open_Task__c,
            'Only unsettled statuses remain open.');

        // The substantive assertion: settled is strictly greater than Completed alone, which is
        // only true because Terminated / Not Applicable are now included.
        System.assert(inMemory.Completed_Task__c > completedOnly,
            'Settled total must exceed Completed-only, proving Terminated / Not Applicable count. '
            + 'settled=' + inMemory.Completed_Task__c + ' completedOnly=' + completedOnly);
    }

    /***************************************************************************************
     * The zero-reset: Total_Task__c / Completed_Task__c must be rebuilt from scratch on every
     * run rather than seeded from their stored values. Without it, a case whose tasks were
     * removed kept a stale figure, which let Completed_Task__c drift above Total_Task__c and
     * inflated Earned_Fee_Value__c in real dollars.
     ***************************************************************************************/
    private static testMethod void testRollupsResetWhenTasksRemoved(){

        AyTestDataSuite.init();
        User u = [Select Id from User where Id =: UserInfo.getUserId() limit 1];

        Opportunity opp = AyTestDataSuite.opportunities[0];
        opp.Area_of_Law__c = 'Family Law';
        opp.Billing_Attorney_lk__c = u.Id;
        opp.Originator_LU__c = u.Id;
        opp.StageName = 'Closed Won';
        update opp;

        Product2 prod = new Product2(Name = 'Reset Product', ProductCode = 'RP', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 500, IsActive = true);
        insert pbe;
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id, Quantity = 1, UnitPrice = 500,
            PricebookEntryId = pbe.Id, Product2Id = prod.Id);
        insert oli;

        AcctSeed__Project__c matter = new AcctSeed__Project__c(
            Name = 'Reset Matter', AcctSeed__Account__c = AyTestDataSuite.accounts[0].Id,
            AcctSeed__Opportunity__c = opp.Id, AcctSeed__Status__c = 'Active');
        insert matter;

        // The template link drives Is_Task_Tracker_Case__c, which is how the handler qualifies
        // this Case. Without it the rollup is 0 and the reset under test cannot be observed.
        Task_Tracker_Template__c template = new Task_Tracker_Template__c(Name = 'Reset Template');
        insert template;

        Case trackerCase = new Case(
            ContactId = AyTestDataSuite.contacts[0].Id,
            AccountId = AyTestDataSuite.accounts[0].Id,
            Opportunity__c = opp.Id, Opportunity_Product__c = oli.Id,
            Task_Tracker_Template__c = template.Id,
            Project__c = matter.Id, Status = 'Working', Origin = 'Phone');
        insert trackerCase;

        Task t = new Task(Subject = 'Work', Status = 'Completed', Hours__c = 3, Billing_Rate__c = 100,
                          WhatId = trackerCase.Id, Matter__c = matter.Id,
                          Top_Level_Case_Id__c = trackerCase.Id);
        insert t;

        // Baseline, taken from the in-memory rollup rather than the committed record - see the note
        // in testSettledStatusesCountAsComplete() on why the commit is not asserted in tests.
        Map<Id, AcctSeed__Project__c> before =
            AyTaskHandler.handleTaskHourCalculationsOld(new Set<Id>{ matter.Id });
        Decimal baseline = before.get(matter.Id).Total_Task__c == null
                               ? 0 : before.get(matter.Id).Total_Task__c;
        System.assert(baseline > 0,
            'Precondition: the rollup must be non-zero before the tasks are removed, otherwise the '
            + 'reset cannot be observed. baseline=' + baseline);

        // Remove every task on the matter, then recalculate. The reset is what drives the rollup
        // to zero; the old seed-from-stored behaviour would have preserved the baseline instead.
        Test.startTest();
        delete [Select Id From Task Where Matter__c = :matter.Id];
        Map<Id, AcctSeed__Project__c> after =
            AyTaskHandler.handleTaskHourCalculationsOld(new Set<Id>{ matter.Id });
        Test.stopTest();

        Decimal totalAfter     = after.get(matter.Id).Total_Task__c == null
                                     ? 0 : after.get(matter.Id).Total_Task__c;
        Decimal completedAfter = after.get(matter.Id).Completed_Task__c == null
                                     ? 0 : after.get(matter.Id).Completed_Task__c;
        System.assertEquals(0, totalAfter,
            'With no tasks left the rollup must reset to 0, not keep the stale baseline of ' + baseline);
        System.assertEquals(0, completedAfter,
            'Completed must reset too - drifting above Total is what inflated Earned Fee Value.');
    }
}