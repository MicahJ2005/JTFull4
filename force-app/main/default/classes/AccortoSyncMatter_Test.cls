/**
 * Test Trigger+Controller
 */
@IsTest
private class AccortoSyncMatter_Test {

    @IsTest
    static void testTrigger() {
        AcctSeed__Project__c matter = createMatter();
        System.assertNotEquals(null, matter.Project__c);

        accorto__Project__c pj = AccortoSyncMatter.loadProject(matter.Project__c);
        System.assertEquals(matter.AcctSeed__Account__c, pj.accorto__Account__c);
        System.assertEquals(matter.AcctSeed__Opportunity__c, pj.accorto__Opportunity__c);
        System.assertEquals(matter.Id, pj.Matter__c);
    }
    @IsTest
    static void testController() {
        AcctSeed__Project__c matter = createMatter();
        System.assertNotEquals(null, matter.Project__c);

        ApexPages.StandardController std = new ApexPages.StandardController(matter);
        AccortoMatterController ctrl = new AccortoMatterController(std);

        System.assertEquals(matter.Id, ctrl.theMatter.Id);
        System.assertEquals(matter.Project__c, ctrl.theProject.Id);

        System.assertEquals(null, ctrl.doSync());
        System.assertEquals(null, ctrl.doSync());
        System.assertNotEquals(null, ctrl.goBack());
    }


    /**
     * @return matter
     */
    static AcctSeed__Project__c createMatter() {
        AyTestDataSuite.init();

        //
        Account acct = new Account(
                Name = 'acct'
        );
        insert acct;
        // https://kapsten--partial.lightning.force.com/lightning/setup/ObjectManager/Opportunity/FieldsAndRelationships/00N5w00000QgTpX/view
        Opportunity opp = new Opportunity(
                Name = acct.Name + '-',
                AccountId = acct.Id,
                //        Billing_Attorney__c = UserInfo.getName(), // restricted picklist
                Area_of_Law__c = 'Mediation',
                StageName = 'Prospecting',
                CloseDate = System.today()
        );
        insert opp;

        // matter
        AcctSeed__Project__c matter = new AcctSeed__Project__c(
                Name = acct.Name,
                AcctSeed__Account__c = acct.Id,
                AcctSeed__Opportunity__c = opp.Id,
                AcctSeed__Status__c = 'Active'
        );
        insert matter;
        matter = AccortoSyncMatter.loadMatter(matter.Id);
        return matter;
    } // createMatter

}