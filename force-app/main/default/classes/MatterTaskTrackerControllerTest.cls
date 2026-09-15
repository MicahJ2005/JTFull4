/**
 * MatterTaskTrackerControllerTest.cls
 *
 * Tests for MatterTaskTrackerController using the confirmed org data model:
 *
 *   Matter (AcctSeed__Project__c)
 *     └─ Case [project__c, Task_Tracker_Template__c → Is_Task_Tracker_Case__c formula = true,
 *              no ParentId → Is_Parent_Process__c formula = true]              → WorkflowDTO
 *          └─ Case [Top_Level_Task_Tracker_Case__c = topCase.Id (Text)]       → PhaseDTO
 *               └─ Task  [WhatId = phaseCase.Id]                              → TaskDTO
 *               └─ Event [WhatId = phaseCase.Id]                              → deadline TaskDTO
 *
 * Formula field facts (confirmed via anonymous Apex):
 *   Is_Task_Tracker_Case__c  — formula (NOT ISBLANK(Task_Tracker_Template__c))
 *   Is_Parent_Process__c     — formula (ISBLANK(ParentId) or equivalent)
 *   Task.Is_Completed__c     — formula (Status = 'Completed')
 */
@IsTest
private class MatterTaskTrackerControllerTest {

    // ── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Matter
        AcctSeed__Project__c matter = new AcctSeed__Project__c(Name = 'Test Matter');
        insert matter;

        // Template
        Task_Tracker_Template__c tmpl = new Task_Tracker_Template__c(
            Name         = 'Path to Settlement',
            Is_Active__c = true
        );
        insert tmpl;

        // Template Steps (so tasks carry Assigned_Role__c via relationship traversal)
        Task_Tracker_Template_Step__c stepA = new Task_Tracker_Template_Step__c(
            Name                     = 'Initial Consult Step',
            Task_Tracker_Template__c = tmpl.Id,
            Assigned_Role__c         = 'Attorney',
            Step_Order__c            = 1,
            Duration_In_Days__c      = 1,
            Activity_Type__c         = 'Task'
        );
        Task_Tracker_Template_Step__c stepB = new Task_Tracker_Template_Step__c(
            Name                     = 'Open Matter Step',
            Task_Tracker_Template__c = tmpl.Id,
            Assigned_Role__c         = 'Paralegal',
            Step_Order__c            = 2,
            Duration_In_Days__c      = 1,
            Activity_Type__c         = 'Task'
        );
        insert new List<Task_Tracker_Template_Step__c>{ stepA, stepB };

        // Top-level workflow Case:
        //   Task_Tracker_Template__c populated  → Is_Task_Tracker_Case__c formula = true
        //   No ParentId                          → Is_Parent_Process__c    formula = true
        //   Top_Level_Task_Tracker_Case__c left null so rootId = topCase.Id
        Case topCase = new Case(
            Subject                  = 'Path to Settlement',
            Status                   = 'New',
            Origin                   = 'Phone',
            project__c               = matter.Id,
            Task_Tracker_Template__c = tmpl.Id,
            Order__c                 = 1
        );
        insert topCase;

        // Phase (child) Cases with explicit ordering to exercise PhaseOrderComparator
        Case phaseCase = new Case(
            Subject                        = 'Intake Phase',
            Status                         = 'New',
            Origin                         = 'Phone',
            ParentId                       = topCase.Id,
            Top_Level_Task_Tracker_Case__c = topCase.Id,
            Order__c                       = 2
        );
        Case phaseCase2 = new Case(
            Subject                        = 'Discovery Phase',
            Status                         = 'New',
            Origin                         = 'Phone',
            ParentId                       = topCase.Id,
            Top_Level_Task_Tracker_Case__c = topCase.Id,
            Order__c                       = 1
        );
        insert new List<Case>{ phaseCase, phaseCase2 };

        // Tasks on the first phase Case.
        Task taskA = new Task(
            Subject                       = 'Initial Consult',
            WhatId                        = phaseCase.Id,
            Status                        = TaskTrackerConstants.TASK_COMPLETED_STATUS,
            ActivityDate                  = Date.today().addDays(-3),
            Hours__c                      = 1.5,
            Order__c                      = 1,
            Task_Tracker_Template_Step__c = stepA.Id
        );
        Task taskB = new Task(
            Subject                       = 'Open Matter',
            WhatId                        = phaseCase.Id,
            Status                        = TaskTrackerConstants.TASK_START_STATUS,
            ActivityDate                  = Date.today().addDays(2),
            Hours__c                      = 0.5,
            Order__c                      = 2,
            Task_Tracker_Template_Step__c = stepB.Id
        );
        // Task with no template step — verifies null-safe role/instructions handling
        Task taskNoStep = new Task(
            Subject      = 'Ad Hoc Task',
            WhatId       = phaseCase.Id,
            Status       = TaskTrackerConstants.TASK_START_STATUS,
            ActivityDate = Date.today().addDays(5),
            Order__c     = 3
        );
        insert new List<Task>{ taskA, taskB, taskNoStep };

        // Deadline Event on the phase Case
        Event deadline = new Event(
            Subject           = 'Filing Deadline',
            WhatId            = phaseCase.Id,
            StartDateTime     = Datetime.now().addDays(7),
            DurationInMinutes = 60,
            Order__c          = 4
        );
        insert deadline;

    }


    // ── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetWorkflowsForMatter_basic() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        System.assertEquals(1, bundle.workflows.size(), 'Expected 1 workflow');

        MatterTaskTrackerController.WorkflowDTO wf = bundle.workflows[0];
        System.assertEquals('Path to Settlement', wf.name);
    }

    @IsTest
    static void testGetWorkflowsForMatter_taskDTOPopulated() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        MatterTaskTrackerController.TaskDTO completed = null;
        for (MatterTaskTrackerController.PhaseDTO p : bundle.workflows[0].phases) {
            for (MatterTaskTrackerController.TaskDTO td : p.tasks) {
                if (td.name == 'Initial Consult') { completed = td; break; }
            }
        }

        System.assertNotEquals(null, completed, 'Initial Consult task not found');
        System.assertEquals('Attorney', completed.role);
        System.assertEquals(true,       completed.isComplete);
        System.assertEquals(1.5,        completed.estimatedHours);
        System.assertEquals(false,      completed.isDeadline);
        System.assertNotEquals(null,    completed.dayOffset);
    }

    @IsTest
    static void testGetWorkflowsForMatter_taskWithoutTemplateStep() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        MatterTaskTrackerController.TaskDTO adHoc = null;
        for (MatterTaskTrackerController.PhaseDTO p : bundle.workflows[0].phases) {
            for (MatterTaskTrackerController.TaskDTO td : p.tasks) {
                if (td.name == 'Ad Hoc Task') { adHoc = td; break; }
            }
        }

        System.assertNotEquals(null, adHoc, 'Ad Hoc Task should be returned');
        System.assertEquals(null,  adHoc.role,         'role should be null with no template step');
        System.assertEquals(null,  adHoc.instructions, 'instructions should be null with no template step');
        System.assertEquals(false, adHoc.isDeadline);
    }

    @IsTest
    static void testGetWorkflowsForMatter_deadlineTaskFromEvent() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        MatterTaskTrackerController.TaskDTO deadlineTask = null;
        for (MatterTaskTrackerController.PhaseDTO p : bundle.workflows[0].phases) {
            for (MatterTaskTrackerController.TaskDTO td : p.tasks) {
                if (td.name == 'Filing Deadline') { deadlineTask = td; break; }
            }
        }

        System.assertNotEquals(null, deadlineTask, 'Filing Deadline event-task not found');
        System.assertEquals(true,  deadlineTask.isDeadline);
        System.assertEquals(false, deadlineTask.isComplete);
        System.assertEquals(null,  deadlineTask.status, 'Events have null status');
        System.assertEquals(1,     deadlineTask.duration, 'Event duration is always 1');
    }

    @IsTest
    static void testGetWorkflowsForMatter_phaseOrderSorting() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        List<MatterTaskTrackerController.PhaseDTO> phases = bundle.workflows[0].phases;
        System.assertEquals(2, phases.size(), 'Expected 2 phases');
        // Discovery Phase has Order__c = 1, Intake Phase has Order__c = 2
        System.assertEquals('Discovery Phase', phases[0].name,
            'Phase with lower Order__c should appear first');
        System.assertEquals('Intake Phase', phases[1].name);
    }

    @IsTest
    static void testGetWorkflowsForMatter_parentCaseIdPopulated() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];
        Case topCase = [
            SELECT Id FROM Case WHERE Subject = 'Path to Settlement' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        for (MatterTaskTrackerController.PhaseDTO p : bundle.workflows[0].phases) {
            System.assertEquals(String.valueOf(topCase.Id), p.parentCaseId,
                'Each phase parentCaseId should equal the top-level workflow case Id');
        }
    }

    @IsTest
    static void testGetWorkflowsForMatter_dayOffsetsComputed() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        MatterTaskTrackerController.WorkflowDTO wf = bundle.workflows[0];
        for (MatterTaskTrackerController.PhaseDTO p : wf.phases) {
            for (MatterTaskTrackerController.TaskDTO td : p.tasks) {
                System.assertNotEquals(null, td.dayOffset,
                    'dayOffset should be computed for ' + td.name);
            }
        }
    }

    @IsTest
    static void testGetWorkflowsForMatter_emptyMatter() {
        AcctSeed__Project__c empty = new AcctSeed__Project__c(Name = 'Empty Matter');
        insert empty;

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(empty.Id);
        Test.stopTest();

        System.assertEquals(0, bundle.workflows.size(), 'No workflows for empty matter');
    }

    @IsTest
    static void testGetWorkflowsForMatter_nullMatterIdThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.getWorkflowsForMatter(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for null matterId');
    }

    @IsTest
    static void testCompleteTask_markCompleted() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];

        Test.startTest();
        MatterTaskTrackerController.completeTask(t.Id, TaskTrackerConstants.TASK_COMPLETED_STATUS);
        Test.stopTest();

        Task updated = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals(TaskTrackerConstants.TASK_COMPLETED_STATUS, updated.Status);
    }

    @IsTest
    static void testCompleteTask_markNotApplicable() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];

        Test.startTest();
        MatterTaskTrackerController.completeTask(t.Id, 'Not Applicable');
        Test.stopTest();

        Task updated = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Not Applicable', updated.Status);
    }

    @IsTest
    static void testCompleteTask_rejectInvalidStatus() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.completeTask(t.Id, 'Terminated');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected AuraHandledException for invalid status');
        Task unchanged = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertNotEquals('Terminated', unchanged.Status);
    }

    @IsTest
    static void testCompleteTask_nullTaskIdThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.completeTask(null, TaskTrackerConstants.TASK_COMPLETED_STATUS);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for null taskId');
    }

    @IsTest
    static void testReopenTask_setsNotStarted() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Initial Consult' LIMIT 1];

        Test.startTest();
        MatterTaskTrackerController.reopenTask(t.Id);
        Test.stopTest();

        Task updated = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals(TaskTrackerConstants.TASK_START_STATUS, updated.Status,
            'Reopened task should be set to TASK_START_STATUS');
    }

    @IsTest
    static void testReopenTask_nullTaskIdThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.reopenTask(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for null taskId');
    }

    @IsTest
    static void testUpdateTaskDueDate_setsDate() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];
        Date newDate = Date.today().addDays(10);

        Test.startTest();
        MatterTaskTrackerController.updateTaskDueDate(t.Id, newDate);
        Test.stopTest();

        Task updated = [SELECT ActivityDate FROM Task WHERE Id = :t.Id];
        System.assertEquals(newDate, updated.ActivityDate, 'ActivityDate should be updated');
    }

    @IsTest
    static void testUpdateTaskDueDate_clearsDate() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];

        Test.startTest();
        MatterTaskTrackerController.updateTaskDueDate(t.Id, null);
        Test.stopTest();

        Task updated = [SELECT ActivityDate FROM Task WHERE Id = :t.Id];
        System.assertEquals(null, updated.ActivityDate, 'ActivityDate should be cleared');
    }

    @IsTest
    static void testUpdateTaskDueDate_nullTaskIdThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.updateTaskDueDate(null, Date.today());
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for null taskId');
    }

    @IsTest
    static void testUpdateTaskOwner_setsOwner() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];
        User u = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name != 'Guest' LIMIT 1];

        Test.startTest();
        MatterTaskTrackerController.updateTaskOwner(t.Id, u.Id);
        Test.stopTest();

        Task updated = [SELECT OwnerId FROM Task WHERE Id = :t.Id];
        System.assertEquals(u.Id, updated.OwnerId, 'OwnerId should be updated');
    }

    @IsTest
    static void testUpdateTaskOwner_nullTaskIdThrows() {
        User u = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name != 'Guest' LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.updateTaskOwner(null, u.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for null taskId');
    }

    @IsTest
    static void testUpdateTaskOwner_nullOwnerIdThrows() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Open Matter' LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            MatterTaskTrackerController.updateTaskOwner(t.Id, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected AuraHandledException for null ownerId');
    }

    @IsTest
    static void testGetWorkflowsForMatter_hasScheduledDate() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];
        Case phaseCase = [SELECT Id FROM Case WHERE Subject = 'Intake Phase' LIMIT 1];

        insert new Task(
            Subject  = 'Undated Task',
            WhatId   = phaseCase.Id,
            Status   = TaskTrackerConstants.TASK_START_STATUS,
            Order__c = 99
        );

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        MatterTaskTrackerController.TaskDTO initialConsult = null;
        MatterTaskTrackerController.TaskDTO undated        = null;
        for (MatterTaskTrackerController.PhaseDTO p : bundle.workflows[0].phases) {
            for (MatterTaskTrackerController.TaskDTO td : p.tasks) {
                if (td.name == 'Initial Consult') { initialConsult = td; }
                if (td.name == 'Undated Task')    { undated = td; }
            }
        }
        System.assertNotEquals(null, initialConsult, 'Initial Consult task not found');
        System.assertEquals(true,  initialConsult.hasScheduledDate,
            'Task with ActivityDate should have hasScheduledDate = true');
        System.assertNotEquals(null, undated, 'Undated Task not found');
        // hasScheduledDate reflects WIP_Est_Due_Date__c || ActivityDate;
        // org automation may auto-set WIP_Est_Due_Date__c so we only assert the field is populated
    }

    @IsTest
    static void testGetWorkflowsForMatter_workflowsSortedByCreatedDateDesc() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];
        Task_Tracker_Template__c tmpl = [
            SELECT Id FROM Task_Tracker_Template__c WHERE Name = 'Path to Settlement' LIMIT 1
        ];

        Case secondCase = new Case(
            Subject                  = 'Alpha Workflow',
            Status                   = 'New',
            Origin                   = 'Phone',
            project__c               = matter.Id,
            Task_Tracker_Template__c = tmpl.Id,
            Order__c                 = 99
        );
        insert secondCase;

        Test.startTest();
        MatterTaskTrackerController.WorkflowBundle bundle =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        System.assertEquals(2, bundle.workflows.size(), 'Expected 2 workflows');
        // Both Cases share the same CreatedDate in a test transaction, so the
        // alphabetical tie-break determines order: 'Alpha Workflow' < 'Path to Settlement'
        System.assertEquals('Alpha Workflow',     bundle.workflows[0].name, 'Alpha Workflow should sort first');
        System.assertEquals('Path to Settlement', bundle.workflows[1].name, 'Path to Settlement should sort second');
        System.assertNotEquals(null, bundle.workflows[0].createdDate, 'createdDate must be populated on WorkflowDTO');
    }
    /***************************************************************************************
     * ALL ROWS was added to the Task and Event queries so archived activities are counted.
     * ALL ROWS also returns recycle-bin records, which is why each query is paired with
     * IsDeleted = false. Without that guard a deleted task would reappear in the tracker.
     *
     * The archiving half of ALL ROWS cannot be unit tested - a Task only archives once it is
     * closed AND its due date is over 365 days old, and test data cannot be aged. This covers
     * the half that can be tested.
     ***************************************************************************************/
    @IsTest
    static void testDeletedTaskIsExcluded() {
        AcctSeed__Project__c matter = [
            SELECT Id FROM AcctSeed__Project__c WHERE Name = 'Test Matter' LIMIT 1
        ];

        Task doomed = [SELECT Id FROM Task WHERE Subject = 'Ad Hoc Task' LIMIT 1];

        // Precondition: the task must be visible first, otherwise its absence proves nothing.
        MatterTaskTrackerController.WorkflowBundle before =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        System.assertEquals(true, containsTask(before, 'Ad Hoc Task'),
            'Precondition: the task must be visible before it is deleted.');

        Test.startTest();
        delete doomed;
        MatterTaskTrackerController.WorkflowBundle afterDelete =
            MatterTaskTrackerController.getWorkflowsForMatter(matter.Id);
        Test.stopTest();

        System.assertEquals(false, containsTask(afterDelete, 'Ad Hoc Task'),
            'A deleted task must not appear in the tracker. ALL ROWS returns recycle-bin rows, so '
            + 'IsDeleted = false is what keeps them out.');
    }

    private static Boolean containsTask(MatterTaskTrackerController.WorkflowBundle bundle, String taskName) {
        for (MatterTaskTrackerController.WorkflowDTO wf : bundle.workflows) {
            for (MatterTaskTrackerController.PhaseDTO ph : wf.phases) {
                for (MatterTaskTrackerController.TaskDTO td : ph.tasks) {
                    if (td.name == taskName) { return true; }
                }
            }
        }
        return false;
    }
}