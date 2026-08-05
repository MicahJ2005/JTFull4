/**
 * MatterTaskTrackerV2Controller.cls
 *
 * Apex controller for the matterTaskTrackerV2 LWC (development/Timeline branch).
 *
 * Real data model (confirmed from existing org controllers):
 *
 *   Matter (AcctSeed__Project__c)
 *     └─ Case  [project__c = matterId, Is_Task_Tracker_Case__c = true]
 *          Top-level Cases (Is_Parent_Process__c = true)  → one accordion per Workflow
 *          Child Cases    (ParentId = top-level Case.Id)  → Phases within a Workflow
 *          └─ Task  [WhatId = Case.Id]   → swimlane task boxes
 *          └─ Event [WhatId = Case.Id]   → deadline vertical lines
 *
 * Custom fields confirmed on Task and Event:
 *   Is_Completed__c, Hours__c, Order__c, Task_Tracker_Template_Step__c
 *
 * Role and instructions traverse: Task_Tracker_Template_Step__r.Assigned_Role__c
 *                                  Task_Tracker_Template_Step__r.Instructions__c
 *
 * Task status values (TaskTrackerConstants):
 *   'Waiting On Other Tasks' → pending  (light-tint, no due date yet)
 *   'Not Started'            → active   (solid color, has due date)
 *   'Completed'              → complete (muted grey)
 *
 * Task-level dependencies: Task_Tracker_Task_Dependency__c
 *   Task_Depends_On_Id__c = predecessor task ID (Text storing an SF Id)
 *   Task_Id__c            = dependent task ID   (Text storing an SF Id)
 *   Case__c               = Case lookup
 */
public with sharing class MatterTaskTrackerV2Controller {

    // ── DTOs ──────────────────────────────────────────────────────────────────

    public class WorkflowBundle {
        @AuraEnabled public List<WorkflowDTO> workflows { get; set; }
        public WorkflowBundle() {
            workflows = new List<WorkflowDTO>();
        }
    }

    public class WorkflowDTO {
        @AuraEnabled public Id                  id           { get; set; }
        @AuraEnabled public String              name         { get; set; }
        @AuraEnabled public List<PhaseDTO>      phases       { get; set; }
        @AuraEnabled public List<DependencyDTO> dependencies { get; set; }
        public WorkflowDTO() {
            phases       = new List<PhaseDTO>();
            dependencies = new List<DependencyDTO>();
        }
    }

    public class PhaseDTO {
        @AuraEnabled public String        id           { get; set; }
        @AuraEnabled public String        name         { get; set; }
        @AuraEnabled public Integer       orderIndex   { get; set; }
        @AuraEnabled public String        parentCaseId { get; set; }
        @AuraEnabled public List<TaskDTO> tasks        { get; set; }
        public PhaseDTO() { tasks = new List<TaskDTO>(); }
    }

    public class TaskDTO {
        @AuraEnabled public Id      id             { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  role           { get; set; }
        @AuraEnabled public String  phaseId        { get; set; }
        @AuraEnabled public Integer dayOffset      { get; set; }
        @AuraEnabled public Integer duration       { get; set; }
        @AuraEnabled public Date    dueDate          { get; set; }   // ActivityDate — displayed in panel
        @AuraEnabled public Boolean hasScheduledDate { get; set; }   // true if WIP_Est_Due_Date__c or ActivityDate is set
        @AuraEnabled public Boolean isComplete       { get; set; }
        @AuraEnabled public Boolean isDeadline       { get; set; }
        @AuraEnabled public Decimal estimatedHours   { get; set; }
        @AuraEnabled public String  instructions     { get; set; }
        @AuraEnabled public String  ownerName        { get; set; }
        @AuraEnabled public String  status           { get; set; }
    }

    public class DependencyDTO {
        @AuraEnabled public Id      id             { get; set; }
        @AuraEnabled public Id      fromTaskId     { get; set; }
        @AuraEnabled public Id      toTaskId       { get; set; }
        @AuraEnabled public Integer durationInDays { get; set; }
        @AuraEnabled public Boolean adjustDueDate  { get; set; }
    }

    // ── getWorkflowsForMatter ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static WorkflowBundle getWorkflowsForMatter(Id matterId) {
        if (matterId == null) {
            throw new AuraHandledException('matterId is required.');
        }

        WorkflowBundle bundle  = new WorkflowBundle();

        // 1. Top-level workflow Cases on this Matter
        List<Case> topLevelCases = [
            SELECT Id, Subject, Top_Level_Task_Tracker_Case__c, Order__c
            FROM Case
            WHERE project__c = :matterId
              AND Is_Task_Tracker_Case__c = true
              AND Is_Parent_Process__c    = true
              AND Status != 'Template Pending'
            ORDER BY Order__c NULLS LAST, Subject
        ];

        if (topLevelCases.isEmpty()) return bundle;

        // 2. Collect all Cases in each workflow tree (top-level + all children)
        Set<Id> rootIds = new Set<Id>();
        for (Case c : topLevelCases) {
            rootIds.add(
                c.Top_Level_Task_Tracker_Case__c != null
                    ? c.Top_Level_Task_Tracker_Case__c : c.Id
            );
        }

        List<Case> allCases = [
            SELECT Id, Subject, ParentId, Top_Level_Task_Tracker_Case__c, Order__c
            FROM Case
            WHERE Top_Level_Task_Tracker_Case__c IN :rootIds
            ORDER BY Order__c NULLS LAST, Subject
        ];

        Set<Id> allCaseIds = new Map<Id, Case>(allCases).keySet();

        // 3. Tasks (WhatId = Case.Id)
        List<Task> taskRecords = [
            SELECT Id, Subject, Status, ActivityDate, WIP_Est_Due_Date__c,
                   OwnerId, Owner.Name,
                   Is_Completed__c, Order__c, Hours__c, WhatId,
                   Task_Tracker_Template_Step__c,
                   Task_Tracker_Template_Step__r.Assigned_Role__c,
                   Task_Tracker_Template_Step__r.Instructions__c
            FROM Task
            WHERE WhatId IN :allCaseIds
            ORDER BY Order__c NULLS LAST, Subject
        ];

        // 4. Events (WhatId = Case.Id) — treated as deadline lines in the swimlane
        List<Event> eventRecords = [
            SELECT Id, Subject, ActivityDate, OwnerId, Owner.Name,
                   Is_Completed__c, Order__c, Hours__c, WhatId,
                   Task_Tracker_Template_Step__r.Assigned_Role__c,
                   Task_Tracker_Template_Step__r.Instructions__c
            FROM Event
            WHERE WhatId IN :allCaseIds
            ORDER BY Order__c NULLS LAST, Subject
        ];

        // 5. (Step-level dependencies resolved after task loop — see step 9b)

        // 6. Build Workflow → Phase maps
        Map<Id, WorkflowDTO> workflowMap    = new Map<Id, WorkflowDTO>();
        Map<Id, Id>          caseToWorkflow = new Map<Id, Id>();
        Map<Id, PhaseDTO>    phaseMap       = new Map<Id, PhaseDTO>();

        for (Case top : topLevelCases) {
            Id rootId = top.Top_Level_Task_Tracker_Case__c != null
                ? top.Top_Level_Task_Tracker_Case__c : top.Id;
            if (!workflowMap.containsKey(rootId)) {
                WorkflowDTO wf = new WorkflowDTO();
                wf.id   = top.Id;
                wf.name = top.Subject;
                workflowMap.put(rootId, wf);
            }
        }

        for (Case c : allCases) {
            Id rootId = c.Top_Level_Task_Tracker_Case__c != null
                ? c.Top_Level_Task_Tracker_Case__c : c.Id;
            caseToWorkflow.put(c.Id, rootId);

            // Skip the top-level workflow case itself — it is the container, not a phase column.
            if (c.Id == rootId) continue;

            WorkflowDTO wf = workflowMap.get(rootId);
            if (wf == null) continue;

            PhaseDTO phase        = new PhaseDTO();
            phase.id             = c.Id;
            phase.name           = c.Subject;
            phase.orderIndex     = c.Order__c != null ? (Integer) c.Order__c : 0;
            phase.parentCaseId   = c.ParentId != null ? String.valueOf(c.ParentId) : null;
            phaseMap.put(c.Id, phase);
            wf.phases.add(phase);
        }

        for (WorkflowDTO wf : workflowMap.values()) {
            wf.phases.sort(new PhaseOrderComparator());
        }

        // 7. Build TaskDTOs from Task records
        // taskPosDate holds WIP_Est_Due_Date__c ?? ActivityDate per task — used for dayOffset
        // calculation in step 9 without needing to carry it on the DTO.
        Map<Id, Date> earliest    = new Map<Id, Date>();
        Map<Id, Date> taskPosDate = new Map<Id, Date>();
        Set<Id>       allDtoIds   = new Set<Id>();
        Map<Id, Id>   stepToTask  = new Map<Id, Id>(); // templateStepId → taskId
        Map<Id, Id>   taskToWf    = new Map<Id, Id>(); // taskId → workflow rootId

        for (Task t : taskRecords) {
            PhaseDTO    phase = phaseMap.get((Id) t.WhatId);
            if (phase == null) continue;
            Id          wfId  = caseToWorkflow.get((Id) t.WhatId);
            WorkflowDTO wf    = workflowMap.get(wfId);
            if (wf == null) continue;

            TaskDTO dto = dtoFromTask(t, phase.id);
            phase.tasks.add(dto);
            allDtoIds.add(dto.id);
            taskToWf.put(dto.id, wfId);
            if (t.Task_Tracker_Template_Step__c != null) {
                stepToTask.put(t.Task_Tracker_Template_Step__c, t.Id);
            }

            Date posDate = t.WIP_Est_Due_Date__c != null ? t.WIP_Est_Due_Date__c : t.ActivityDate;
            taskPosDate.put(dto.id, posDate);
            if (posDate != null) {
                Date e = earliest.get(wfId);
                if (e == null || posDate < e) earliest.put(wfId, posDate);
            }
        }

        // 8. Build TaskDTOs from Event records
        for (Event ev : eventRecords) {
            PhaseDTO    phase = phaseMap.get((Id) ev.WhatId);
            if (phase == null) continue;
            Id          wfId  = caseToWorkflow.get((Id) ev.WhatId);
            WorkflowDTO wf    = workflowMap.get(wfId);
            if (wf == null) continue;

            TaskDTO dto = dtoFromEvent(ev, phase.id);
            phase.tasks.add(dto);
            allDtoIds.add(dto.id);
            taskPosDate.put(dto.id, ev.ActivityDate);

            if (ev.ActivityDate != null) {
                Date e = earliest.get(wfId);
                if (e == null || ev.ActivityDate < e) earliest.put(wfId, ev.ActivityDate);
            }
        }

        // 9b. Query step-level dependencies and build resolution map
        List<Task_Tracker_Step_Dependency__c> stepDeps = stepToTask.isEmpty()
            ? new List<Task_Tracker_Step_Dependency__c>()
            : [
                SELECT Id, Step__c, Depends_On_Step__c, Adjust_Due_Date__c
                FROM Task_Tracker_Step_Dependency__c
                WHERE Step__c IN :stepToTask.keySet()
                   OR Depends_On_Step__c IN :stepToTask.keySet()
              ];

        // 9. Compute dayOffsets relative to each workflow's earliest date
        for (Id rootId : workflowMap.keySet()) {
            WorkflowDTO wf        = workflowMap.get(rootId);
            Date        startDate = earliest.get(rootId);
            if (startDate == null) continue;
            for (PhaseDTO phase : wf.phases) {
                for (TaskDTO td : phase.tasks) {
                    Date posDate = taskPosDate.get(td.id);
                    td.dayOffset = posDate != null ? startDate.daysBetween(posDate) : 0;
                }
            }
        }

        // 10. Build DependencyDTOs from template step dependencies
        //     Resolve step IDs → task IDs using the stepToTask map built in step 7.
        //     Adjust_Due_Date__c = true → green arrow (shifts due dates); false → red dashed (completion-triggered).
        for (Task_Tracker_Step_Dependency__c sd : stepDeps) {
            Id fromTaskId = stepToTask.get(sd.Depends_On_Step__c);
            Id toTaskId   = stepToTask.get(sd.Step__c);
            if (fromTaskId == null || toTaskId == null) continue;
            if (!allDtoIds.contains(fromTaskId) || !allDtoIds.contains(toTaskId)) continue;

            Id wfId = taskToWf.get(toTaskId);
            WorkflowDTO wf = workflowMap.get(wfId);
            if (wf == null) continue;

            DependencyDTO dep  = new DependencyDTO();
            dep.id             = sd.Id;
            dep.fromTaskId     = fromTaskId;
            dep.toTaskId       = toTaskId;
            dep.durationInDays = 0;
            dep.adjustDueDate  = sd.Adjust_Due_Date__c == true;
            wf.dependencies.add(dep);
        }

        // 11. Finalise bundle
        bundle.workflows.addAll(workflowMap.values());

        return bundle;
    }


    // ── completeTask ──────────────────────────────────────────────────────────

    @AuraEnabled
    public static void completeTask(Id taskId, String status) {
        if (taskId == null) {
            throw new AuraHandledException('taskId is required.');
        }
        final Set<String> allowed = new Set<String>{
            TaskTrackerConstants.TASK_COMPLETED_STATUS,
            'Not Applicable'
        };
        if (!allowed.contains(status)) {
            throw new AuraHandledException('status must be "Completed" or "Not Applicable".');
        }
        try {
            update new Task(Id = taskId, Status = status);
        } catch (DmlException e) {
            throw new AuraHandledException('Could not update task: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateTaskDueDate(Id taskId, Date dueDate) {
        if (taskId == null) {
            throw new AuraHandledException('taskId is required.');
        }
        try {
            update new Task(Id = taskId, ActivityDate = dueDate);
        } catch (DmlException e) {
            throw new AuraHandledException('Could not update due date: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void reopenTask(Id taskId) {
        if (taskId == null) {
            throw new AuraHandledException('taskId is required.');
        }
        try {
            update new Task(Id = taskId, Status = TaskTrackerConstants.TASK_START_STATUS);
        } catch (DmlException e) {
            throw new AuraHandledException('Could not reopen task: ' + e.getMessage());
        }
    }


    // ── Private helpers ───────────────────────────────────────────────────────

    private static TaskDTO dtoFromTask(Task t, String phaseId) {
        Task_Tracker_Template_Step__c step = t.Task_Tracker_Template_Step__r;
        TaskDTO dto        = new TaskDTO();
        dto.id             = t.Id;
        dto.name           = t.Subject;
        dto.role           = step != null ? step.Assigned_Role__c : null;
        dto.phaseId        = phaseId;
        dto.dueDate          = t.ActivityDate;
        dto.hasScheduledDate = t.WIP_Est_Due_Date__c != null || t.ActivityDate != null;
        dto.isComplete       = t.Is_Completed__c == true;
        dto.isDeadline       = false;
        dto.estimatedHours   = t.Hours__c;
        dto.instructions     = step != null ? step.Instructions__c : null;
        dto.ownerName        = t.Owner != null ? t.Owner.Name : null;
        dto.status         = t.Status;
        dto.duration       = t.Hours__c != null
            ? Math.max(1, (Integer) Math.ceil(t.Hours__c / 8.0)) : 1;
        return dto;
    }

    private static TaskDTO dtoFromEvent(Event ev, String phaseId) {
        Task_Tracker_Template_Step__c step = ev.Task_Tracker_Template_Step__r;
        TaskDTO dto        = new TaskDTO();
        dto.id             = ev.Id;
        dto.name           = ev.Subject;
        dto.role           = step != null ? step.Assigned_Role__c : null;
        dto.phaseId        = phaseId;
        dto.dueDate          = ev.ActivityDate;
        dto.hasScheduledDate = ev.ActivityDate != null;
        dto.isComplete       = ev.Is_Completed__c == true;
        dto.isDeadline       = true;
        dto.estimatedHours = ev.Hours__c;
        dto.instructions   = step != null ? step.Instructions__c : null;
        dto.ownerName      = ev.Owner != null ? ev.Owner.Name : null;
        dto.status         = null;
        dto.duration       = 1;
        return dto;
    }

    private class PhaseOrderComparator implements Comparator<PhaseDTO> {
        public Integer compare(PhaseDTO a, PhaseDTO b) {
            Integer ao = a.orderIndex != null ? a.orderIndex : 0;
            Integer bo = b.orderIndex != null ? b.orderIndex : 0;
            return ao < bo ? -1 : ao > bo ? 1 : 0;
        }
    }
}