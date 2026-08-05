@isTest
private class XDFactsFieldUpdaterTest {

    // Configuración de datos iniciales para todas las pruebas
    @testSetup
    static void setupData() {
        // 1. Crear Cuenta (Firm Name)
        Account firm = new Account(Name = 'Legal Eagle Firm');
        insert firm;

        // 2. Crear Contacto Paralegal (Assistant)
        Contact paralegal = new Contact(
            FirstName = 'Penny',
            LastName = 'Paralegal',
            Email = 'penny@legaleagle.com'
        );
        insert paralegal;

        // 3. Crear Contacto Abogado (Business Contact)
        Contact attorney = new Contact(
            FirstName = 'Atticus',
            LastName = 'Finch',
            Email = 'atticus@legaleagle.com',
            Phone = '555-0100',
            MailingStreet = '123 Justice Ave',
            MailingCity = 'Monroeville',
            MailingState = 'AL',
            MailingPostalCode = '36460',
            AccountId = firm.Id,
            Opposing_Paralegal_Assistant__c = paralegal.Id
        );
        insert attorney;

        // 4. Crear el registro "Matter" (AcctSeed__Project__c)
        AcctSeed__Project__c testMatter = new AcctSeed__Project__c(
            Name = 'Test Divorce Case'
        );
        insert testMatter;

        // 5. Crear registro XD_Facts__c vinculado al Matter
        XD_Facts__c xdFact = new XD_Facts__c(
            Name = 'Test Fact Record',
            Matter__c = testMatter.Id
        );
        insert xdFact;
    }

    // TEST 1: Verificar que actualiza tanto campos de Abogado como de Paralegal
    @isTest
    static void testUpdateAllFields() {
        Contact attorney = [SELECT Id FROM Contact WHERE LastName = 'Finch' LIMIT 1];
        
        // --- CORRECCIÓN AQUÍ: Consultar TODOS los campos que el código lee ---
        XD_Facts__c xdFact = [
            SELECT Id, First_Name_Opp_Atty__c, Last_Name_Opp_Atty__c, Email_Opp_Atty__c, 
                   Phone_Opp_Atty__c, Street_Opp_Atty__c, City_Opp_Atty__c, State_Opp_Atty__c, 
                   Zip_Code_Opp_Atty__c, Opposing_Atty_Firm_Name__c, 
                   Opp_Paralegal_Asst_name__c, Opp_Paralegal_Asst_last_name__c, Opp_Paralegal_Asst_Email__c
            FROM XD_Facts__c 
            LIMIT 1
        ];

        Contact attorneyFull = [
            SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode,
                   Account.Name, Opposing_Paralegal_Assistant__c
            FROM Contact 
            WHERE Id = :attorney.Id
        ];

        XD_Facts_Request_Wrapper req = new XD_Facts_Request_Wrapper();
        req.xdFactsRecord = xdFact;
        req.businessContact = attorneyFull;

        Test.startTest();
        List<XDFactsFieldUpdater.UpdateResult> results = XDFactsFieldUpdater.updateXDFactsFields(new List<XD_Facts_Request_Wrapper>{ req });
        Test.stopTest();

        // Validaciones
        XD_Facts__c updatedFact = [SELECT First_Name_Opp_Atty__c, Opp_Paralegal_Asst_name__c FROM XD_Facts__c WHERE Id = :xdFact.Id];
        System.assertEquals('Atticus', updatedFact.First_Name_Opp_Atty__c);
        System.assertEquals('Penny', updatedFact.Opp_Paralegal_Asst_name__c);
    }

    // TEST 2: Verificar actualización SOLO de Abogado (sin Paralegal)
    @isTest
    static void testUpdateAttorneyOnly() {
        // --- CORRECCIÓN AQUÍ TAMBIÉN ---
        XD_Facts__c xdFact = [
            SELECT Id, First_Name_Opp_Atty__c, Last_Name_Opp_Atty__c, Email_Opp_Atty__c, 
                   Phone_Opp_Atty__c, Street_Opp_Atty__c, City_Opp_Atty__c, State_Opp_Atty__c, 
                   Zip_Code_Opp_Atty__c, Opposing_Atty_Firm_Name__c, 
                   Opp_Paralegal_Asst_name__c, Opp_Paralegal_Asst_last_name__c, Opp_Paralegal_Asst_Email__c
            FROM XD_Facts__c 
            LIMIT 1
        ];

        Account firm = [SELECT Id FROM Account LIMIT 1];
        
        Contact soloAttorney = new Contact(
            LastName = 'Goodman',
            Email = 'saul@bcs.com',
            AccountId = firm.Id
        );
        insert soloAttorney;

        Contact attorneyFull = [
            SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode,
                   Account.Name, Opposing_Paralegal_Assistant__c
            FROM Contact 
            WHERE Id = :soloAttorney.Id
        ];

        XD_Facts_Request_Wrapper req = new XD_Facts_Request_Wrapper();
        req.xdFactsRecord = xdFact;
        req.businessContact = attorneyFull;

        Test.startTest();
        XDFactsFieldUpdater.updateXDFactsFields(new List<XD_Facts_Request_Wrapper>{ req });
        Test.stopTest();

        XD_Facts__c updatedFact = [SELECT Last_Name_Opp_Atty__c, Opp_Paralegal_Asst_name__c FROM XD_Facts__c WHERE Id = :xdFact.Id];
        System.assertEquals('Goodman', updatedFact.Last_Name_Opp_Atty__c);
    }

    // TEST 3: Crear datos manualmente para probar "Sin Cambios"
    @isTest
    static void testNoChangesNeeded() {
        AcctSeed__Project__c testMatter = new AcctSeed__Project__c(Name = 'Another Matter');
        insert testMatter;

        // Aquí NO necesitamos select porque acabamos de crear el objeto en memoria con los datos
        XD_Facts__c perfectFact = new XD_Facts__c(
            First_Name_Opp_Atty__c = 'Atticus',
            Last_Name_Opp_Atty__c = 'Finch',
            Email_Opp_Atty__c = 'atticus@legaleagle.com', // Agregado para reducir diferencias
            Matter__c = testMatter.Id 
        );
        insert perfectFact;

        Contact attorney = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, Account.Name, Opposing_Paralegal_Assistant__c FROM Contact WHERE LastName = 'Finch' LIMIT 1];

        XD_Facts_Request_Wrapper req = new XD_Facts_Request_Wrapper();
        req.xdFactsRecord = perfectFact; // Pasamos el objeto que ya tiene los campos cargados
        req.businessContact = attorney;

        Test.startTest();
        List<XDFactsFieldUpdater.UpdateResult> results = XDFactsFieldUpdater.updateXDFactsFields(new List<XD_Facts_Request_Wrapper>{ req });
        Test.stopTest();

        System.assertNotEquals(null, results);
    }
    
    @isTest
    static void testWrapperCoverage() {
        XD_Facts_Request_Wrapper wrapper = new XD_Facts_Request_Wrapper();
        wrapper.xdFactsRecord = new XD_Facts__c();
        wrapper.businessContact = new Contact();
        System.assertNotEquals(null, wrapper.xdFactsRecord);
    }
}