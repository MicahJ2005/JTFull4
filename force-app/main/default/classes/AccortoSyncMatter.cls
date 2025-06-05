/**
 * Sync Matter (AcctSeed__Project__c) to Accorto Project
 *
 * --------------------------------------------------------
 * Meta Data:
 *  Project
 *      Field:  Matter__c - lookup (AcctSeed__Project__c)
 *
 *  AcctSeed__Project__c
 *      Field:  Project__c - lookup
 *      Button: Sync Project - Layouts
 *
 *  Apex Class
 *      AccortoSyncMatter/_Test
 *      AccortoMatterController
 *
 *  VisualForce
 *      AccortoMatter
 *
 *  Apex Trigger
 *      AccortoSync - on AcctSeed__Project__c
 *
 *  PermissionSet
 *      AccortoSync
 *
 * --------------------------------------------------------
 * Questions:
 * - should all matters be automatically synchronized (status, ..)
 *
 */
public with sharing class AccortoSyncMatter {


    public AccortoSyncMatter() {
    }

    public String syncError { get; set; }
    public String syncInfo { get; set; }

    /**
     * @param matters before trigger
     */
    public void syncTrigger(List<AcctSeed__Project__c> matters) {
        // load projects
        List<Id> projectIds = new List<Id>();
        for (AcctSeed__Project__c matter : matters) {
            if (matter.Project__c != null) {
                projectIds.add(matter.Project__c);
            }
        }
        cacheProjects(projectIds);

        // create projects
        for (AcctSeed__Project__c matter : matters) {
            accorto__Project__c project = syncMatter(matter);
            if (project != null && project.Id != null) {
                matter.Project__c = project.Id;
            }
        }
    } // syncTrigger

    /**
     * Update created Projects with Matter id
     * @param matters after insert trigger
     */
    public void syncTriggerIds(List<AcctSeed__Project__c> matters) {
        List<Id> projectIds = new List<Id>();
        for (AcctSeed__Project__c matter : matters) {
            if (matter.Project__c != null) {
                projectIds.add(matter.Project__c);
            }
        }
        cacheProjects(projectIds);

        List<accorto__Project__c> projects = new List<accorto__Project__c>();
        for (AcctSeed__Project__c matter : matters) {
            if (matter.Project__c != null) {
                accorto__Project__c project = loadProject(matter.Project__c);
                if (project.Matter__c == null) {
                    project.Matter__c = matter.Id;
                    projects.add(project);
                }
            }
        }
        if (!projects.isEmpty()) {
            update projects;
        }
    } // syncTriggerIds


    /**
     * @param matter master
     * @return updated, saved project
     */
    public accorto__Project__c syncMatter(AcctSeed__Project__c matter) {
        syncInfo = 'Updated ';
        syncError = null;
        accorto__Project__c project = loadProject(matter.Project__c);
        if (project == null) {
            project = new accorto__Project__c();
            syncInfo = 'New ';
        }
        syncInfo += matter.Name;
        //
        project.Name = matter.Name;
        project.accorto__Code__c = null;
        project.accorto__Opportunity__c = matter.AcctSeed__Opportunity__c;
        project.accorto__Account__c = matter.AcctSeed__Account__c;
        project.OwnerId = matter.OwnerId;
        project.Matter__c = matter.Id;
        if (matter.Billing_Attorney__c != null) {
            List<User> users = [SELECT Id, Name
            FROM User WHERE Name = :matter.Billing_Attorney__c];
            if (users.size() > 0) {
                project.accorto__Manager__c = users.get(0).Id;
            }
        }

        try {
            upsert project;
        } catch (Exception ex) {
            System.debug('syncMatter ' + ex);
            syncError = ex.getMessage();
            return null;
        }

        // default roles
        // roles and hours

        return project;
    }

    /**
     * Load Cache
     * @param projectIds project ids
     */
    public static void cacheProjects(List<Id> projectIds) {
        if (!projectIds.isEmpty()) {
            projectMap = new Map<Id, accorto__Project__c>([
                    SELECT Id, Name, OwnerId, accorto__Code__c,
                            accorto__Account__c, accorto__Opportunity__c,
                            accorto__Status__c, Matter__c
                    FROM accorto__Project__c
                    WHERE Id IN :projectIds
            ]);
        }
    } // cacheProjects
    /**
     * Load cached project
     * @param projectId project id
     * @return project
     */
    public static accorto__Project__c loadProject(Id projectId) {
        accorto__Project__c pj = projectMap.get(projectId);
        if (pj == null && projectId != null) {
            cacheProjects(new List<Id>{projectId});
            pj = projectMap.get(projectId);
            if (pj == null) {
                System.debug('AccortoSyncMatter.loadProject NotFound ' + projectId);
            }
        }
        return pj;
    }
    private static Map<Id, accorto__Project__c> projectMap = new Map<Id, accorto__Project__c>();


    public static AcctSeed__Project__c loadMatter(Id matterId) {
        List<AcctSeed__Project__c> matters = [
                SELECT Id, Name, OwnerId,
                        AcctSeed__Opportunity__c, AcctSeed__Account__c,
                        Billing_Attorney__c,
                        Project__c
                FROM AcctSeed__Project__c
                WHERE Id = :matterId
        ];
        if (matters.size() > 0) {
            return matters.get(0);
        }
        return null;
    }

}