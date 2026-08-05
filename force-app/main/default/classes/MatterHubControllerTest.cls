/**
 * Tests for MatterHubController (real AcctSeed__Project__c fields).
 *
 * NOTE: AcctSeed__Project__c is a managed-package object. If your org enforces
 * extra required fields, add them in setupMatter() so the insert succeeds.
 */
@IsTest
private class MatterHubControllerTest {

    private static AcctSeed__Project__c setupMatter() {
        AcctSeed__Project__c m = new AcctSeed__Project__c(
            Name                         = 'Test Family Law Matter',
            Matter_Phase__c              = 'Phase 2',
            Current_Phase_Title__c       = 'Path to Settlement',
            Current_Phase_Description__c = 'You are here. We work toward a settlement.',
            Box_Matter_Folder_ID__c      = '1234567890',
            Box_Client_Upload_Link__c    = 'https://app.box.com/upload/abc',
            Client_Questionnaire_Link__c = 'https://example.com/client-questionnaire',
            ICMC_Date_and_Time__c        = System.now().addDays(3),
            Mediation__c                 = System.now().addDays(10),
            Trial__c                     = System.now().addDays(-5) // past -> excluded
        );
        insert m;
        return m;
    }

    @IsTest
    static void testOverview() {
        AcctSeed__Project__c m = setupMatter();

        Test.startTest();
        MatterHubController.MatterOverview ov = MatterHubController.getMatterOverview(m.Id);
        Test.stopTest();

        System.assertEquals('Test Family Law Matter', ov.matterName);
        System.assertEquals(2, ov.phaseIndex);
        System.assertEquals('Path to Settlement', ov.currentPhaseTitle);
        System.assertEquals('Client Questionnaire', ov.questionnaireLabel, 'Highest-priority link');
        System.assertEquals('https://example.com/client-questionnaire', ov.questionnaireUrl);
        System.assert(ov.boxFolderEmbedUrl.endsWith('/embed/folder/1234567890'), 'Embed URL built');
        System.assertEquals('https://app.box.com/upload/abc', ov.boxUploadUrl);
    }

    @IsTest
    static void testQuestionnairePriorityFallback() {
        AcctSeed__Project__c m = new AcctSeed__Project__c(
            Name = 'No Client Q',
            OFPHRO_Questionnaire_Link__c = 'https://example.com/ofphro'
        );
        insert m;

        Test.startTest();
        MatterHubController.MatterOverview ov = MatterHubController.getMatterOverview(m.Id);
        Test.stopTest();

        System.assertEquals('OFP/HRO Questionnaire', ov.questionnaireLabel);
        System.assertEquals('https://example.com/ofphro', ov.questionnaireUrl);
    }

    @IsTest
    static void testPhaseMapping() {
        System.assertEquals(1, MatterHubController.mapPhaseIndex(null));
        System.assertEquals(1, MatterHubController.mapPhaseIndex('Phase 1'));
        System.assertEquals(2, MatterHubController.mapPhaseIndex('Phase 2'));
        System.assertEquals(3, MatterHubController.mapPhaseIndex('Phase 3'));
        System.assertEquals(4, MatterHubController.mapPhaseIndex('Phase 4'));
    }

    @IsTest
    static void testUpcomingAppointments() {
        AcctSeed__Project__c m = setupMatter();

        Test.startTest();
        List<MatterHubController.AppointmentItem> appts =
            MatterHubController.getUpcomingAppointments(m.Id, 5);
        Test.stopTest();

        System.assertEquals(2, appts.size(), 'Only future dates (ICMC, Mediation); Trial excluded');
        System.assertEquals('ICMC', appts[0].subject, 'Soonest first');
        System.assertEquals('Mediation', appts[1].subject);
        System.assertNotEquals(null, appts[0].whenLabel);
    }

    @IsTest
    static void testCurrentTasks() {
        AcctSeed__Project__c m = setupMatter();
        // Subject is a restricted picklist on this org's Task, so we don't set it here.
        insert new List<Task>{
            new Task(Matter__c = m.Id, Status = 'Not Started',
                     IsVisibleInSelfService = true, ActivityDate = Date.today().addDays(-2)),
            new Task(Matter__c = m.Id, Status = 'Not Started',
                     IsVisibleInSelfService = true, ActivityDate = Date.today()),
            new Task(Matter__c = m.Id, Status = 'Not Started',
                     IsVisibleInSelfService = false, ActivityDate = Date.today().addDays(1)),
            new Task(Matter__c = m.Id, Status = 'Completed',
                     IsVisibleInSelfService = true, ActivityDate = Date.today().addDays(3))
        };

        Test.startTest();
        List<MatterHubController.TaskItem> visible =
            MatterHubController.getCurrentTasks(m.Id, 3, true);
        List<MatterHubController.TaskItem> all =
            MatterHubController.getCurrentTasks(m.Id, 5, false);
        Test.stopTest();

        // Visible + open only: the 2 client-visible, not-closed tasks
        System.assertEquals(2, visible.size(), 'Only client-visible open tasks');
        System.assertEquals('Overdue', visible[0].dueLabel, 'Soonest/overdue first');
        System.assert(visible[0].isOverdue);
        System.assertEquals('Due ASAP', visible[1].dueLabel);

        // All open (ignores visibility): 3 not-closed tasks (Completed excluded by IsClosed)
        System.assertEquals(3, all.size(), 'All open matter tasks regardless of visibility');
    }

    @IsTest
    static void testNullAndEmpty() {
        Test.startTest();
        System.assertEquals(1, MatterHubController.getMatterOverview(null).phaseIndex);
        System.assertEquals(0, MatterHubController.getCurrentTasks(null, 3, true).size());
        System.assertEquals(0, MatterHubController.getUpcomingAppointments(null, 3).size());
        Test.stopTest();
    }
}