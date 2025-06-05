/**
 * Matter Controller
 */
public with sharing class AccortoMatterController {

    public AccortoMatterController(ApexPages.StandardController std) {
        matterId = std.getId();
    }

    public Id matterId { get; set; }
    public AcctSeed__Project__c theMatter {
        get {
            if (theMatter == null) {
                theMatter = AccortoSyncMatter.loadMatter(matterId);
            }
            return theMatter;
        }
        set;
    }

    public accorto__Project__c theProject {
        get {
            if (theProject == null && theMatter.Project__c != null) {
                theProject = AccortoSyncMatter.loadProject(theMatter.Project__c);
            }
            return theProject;
        }
        set;
    }

    public PageReference doSync() {
        AccortoSyncMatter sync = new AccortoSyncMatter();
        theProject = sync.syncMatter(theMatter);
        update theMatter;
        String info = sync.syncInfo;
        String error = sync.syncError;
        if (error != null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING,
                    info + ': ' + error));
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, info));
        }
        // re-query
        theMatter = null;
        theProject = null;
        return null;
    } // doSync

    public PageReference goBack() {
        PageReference ref = new PageReference('/' + theMatter.Id);
        return ref;
    }

} // AccortoMatterController