public with sharing class BalanceSheetController {
    
    @AuraEnabled(cacheable=true)
    public static BalanceSheetDTO loadData(Id recordId) {
        BalanceSheetDTO dto = new BalanceSheetDTO();

        if (recordId == null) return dto;

        try {
            // 1. Cargar Nombres
            List<XD_Facts__c> factsList = [SELECT Id, Client_s_Commonly_Known_First_Name__c, Opposing_Common_First_Name__c FROM XD_Facts__c WHERE Matter__c = :recordId LIMIT 1];
            dto.clientFirstName = 'Client';
            dto.opposingFirstName = 'Opposing';
            if (!factsList.isEmpty()) {
                if (factsList[0].Client_s_Commonly_Known_First_Name__c != null) dto.clientFirstName = factsList[0].Client_s_Commonly_Known_First_Name__c;
                if (factsList[0].Opposing_Common_First_Name__c != null) dto.opposingFirstName = factsList[0].Opposing_Common_First_Name__c;
            }

            // 2. NUEVO: Cargar LISTA de Pleadings (Cash Settlements)
            dto.pleadings = new List<PleadingRow>();
            for (XD_Pleadings__c pl : [SELECT Id, Name, Is_there_a_Cash_Settlement__c, Amount__c FROM XD_Pleadings__c WHERE Matter__c = :recordId ORDER BY Name]) {
                PleadingRow r = new PleadingRow();
                r.id = pl.Id;
                r.name = pl.Name; // O usa una descripción si tienes un campo mejor
                r.payor = pl.Is_there_a_Cash_Settlement__c; // Client Pays / Opposing Pays
                r.amount = parseDec(pl.Amount__c);
                dto.pleadings.add(r);
            }

            // 3. Cargar Assets (Real Estate)
            dto.realEstate = new List<AssetRow>();
            for (XD_Real_Property__c re : [
                SELECT Id, Name, Selected_FMV_RE__c, Rea_Estate_Total_Debts__c,
                       Client_s_Non_Marital_Interest_RE__c, Opp_s_Non_Mar_Interest_RE__c,
                       Net_Marital_Value_Real_Estate__c, Client_s_Marital_Real_Estate__c, Opp_s_Marital_Real_Estate__c
                FROM XD_Real_Property__c WHERE Matter__c = :recordId ORDER BY Name
            ]) {
                AssetRow r = mapRow(re, re.Name, parseDec(re.Selected_FMV_RE__c), parseDec(re.Rea_Estate_Total_Debts__c), 0, parseDec(re.Client_s_Non_Marital_Interest_RE__c), parseDec(re.Opp_s_Non_Mar_Interest_RE__c), parseDec(re.Net_Marital_Value_Real_Estate__c), parseDec(re.Client_s_Marital_Real_Estate__c), parseDec(re.Opp_s_Marital_Real_Estate__c));
                r.valueDate = null; 
                dto.realEstate.add(r);
            }

            // 4. Cargar Bank Accounts
            dto.bankAccounts = new List<AssetRow>();
            for (XD_Bank_Accounts__c ba : [SELECT Id, Name, InstitutionTypeLast4__c, BankBalanceDate__c, BankBalance__c, Client_s_Non_Marital_Interest__c, Opp_s_Non_Marital_Interest__c, Net_Marital_Value_Bank_Account__c, Client_s_Martial_Bank_Account__c, Opp_s_Marital_Bank_Account__c FROM XD_Bank_Accounts__c WHERE Matter__c = :recordId ORDER BY Name]) {
                AssetRow r = mapRow(ba, ba.InstitutionTypeLast4__c, parseDec(ba.BankBalance__c), 0, 0, parseDec(ba.Client_s_Non_Marital_Interest__c), parseDec(ba.Opp_s_Non_Marital_Interest__c), parseDec(ba.Net_Marital_Value_Bank_Account__c), parseDec(ba.Client_s_Martial_Bank_Account__c), parseDec(ba.Opp_s_Marital_Bank_Account__c));
                r.valueDate = parseDate(ba.BankBalanceDate__c); 
                dto.bankAccounts.add(r);
            }

            // 5. Cargar Businesses
            dto.businesses = new List<AssetRow>();
            for (XD_Business__c bu : [SELECT Id, Name, Date_of_Business_Valuation__c, BusinessValue__c, Client_s_Non_Mar_Interest_Business__c, Opp_s_Non_Mar_Interest_Business__c, Net_Martial_Value_Business__c, Client_s_Marital_Business__c, Opp_s_Marital_Business__c FROM XD_Business__c WHERE Matter__c = :recordId ORDER BY Name]) {
                AssetRow r = mapRow(bu, bu.Name, parseDec(bu.BusinessValue__c), 0, 0, parseDec(bu.Client_s_Non_Mar_Interest_Business__c), parseDec(bu.Opp_s_Non_Mar_Interest_Business__c), parseDec(bu.Net_Martial_Value_Business__c), parseDec(bu.Client_s_Marital_Business__c), parseDec(bu.Opp_s_Marital_Business__c));
                r.valueDate = parseDate(bu.Date_of_Business_Valuation__c);
                dto.businesses.add(r);
            }

            // 6. Cargar Stocks
            dto.stocks = new List<AssetRow>();
            for (XD_Stock__c st : [SELECT Id, Name, StockFMVDate__c, Value_of_Shares__c, Client_s_Non_Mar_Interest_Stock__c, Opp_s_Non_Mar_Interest_Stock__c, Net_Marital_Value_Stock__c, Client_s_Marital_Stock__c, Opp_s_Marital_Stock__c FROM XD_Stock__c WHERE Matter__c = :recordId ORDER BY Name]) {
                AssetRow r = mapRow(st, st.Name, parseDec(st.Value_of_Shares__c), 0, 0, parseDec(st.Client_s_Non_Mar_Interest_Stock__c), parseDec(st.Opp_s_Non_Mar_Interest_Stock__c), parseDec(st.Net_Marital_Value_Stock__c), parseDec(st.Client_s_Marital_Stock__c), parseDec(st.Opp_s_Marital_Stock__c));
                r.valueDate = parseDate(st.StockFMVDate__c);
                dto.stocks.add(r);
            }

            // 7. Cargar Vehicles
            dto.vehicles = new List<AssetRow>();
            for (XD_Vehicles__c ve : [SELECT Id, Name, VehicleFMVDate__c, VehicleFMV__c, VehicleLoanAmount__c, Client_s_Non_Mar_Interest_Vehicle__c, Opp_s_Non_Mar_Interest_Vehicle__c, Net_Marital_Vehicle_Value__c, Client_s_Marital_Vehicle__c, Opp_s_Marital_Vehicle__c FROM XD_Vehicles__c WHERE Matter__c = :recordId ORDER BY Name]) {
                AssetRow r = mapRow(ve, ve.Name, parseDec(ve.VehicleFMV__c), parseDec(ve.VehicleLoanAmount__c), 0, parseDec(ve.Client_s_Non_Mar_Interest_Vehicle__c), parseDec(ve.Opp_s_Non_Mar_Interest_Vehicle__c), parseDec(ve.Net_Marital_Vehicle_Value__c), parseDec(ve.Client_s_Marital_Vehicle__c), parseDec(ve.Opp_s_Marital_Vehicle__c));
                r.valueDate = parseDate(ve.VehicleFMVDate__c);
                dto.vehicles.add(r);
            }

            // 8. Cargar Life Insurance
            dto.lifeInsurance = new List<AssetRow>();
            for (XD_Life_Insurance_Policies__c li : [SELECT Id, Name, Date_of_Cash_Value__c, LifeInsCashV__c, LifeInsLoan__c, Client_s_Non_Mar_Interst_Life_Ins__c, Opp_s_Non_Mar_Interest_Life_Ins__c, Net_Marital_Value_Life_Ins__c, Client_s_Marital_Life_Insurance__c, Opp_s_Marital_Life_Insurance__c FROM XD_Life_Insurance_Policies__c WHERE Matter__c = :recordId ORDER BY Name]) {
                AssetRow r = mapRow(li, li.Name, parseDec(li.LifeInsCashV__c), parseDec(li.LifeInsLoan__c), 0, parseDec(li.Client_s_Non_Mar_Interst_Life_Ins__c), parseDec(li.Opp_s_Non_Mar_Interest_Life_Ins__c), parseDec(li.Net_Marital_Value_Life_Ins__c), parseDec(li.Client_s_Marital_Life_Insurance__c), parseDec(li.Opp_s_Marital_Life_Insurance__c));
                r.valueDate = parseDate(li.Date_of_Cash_Value__c);
                dto.lifeInsurance.add(r);
            }

            // 9. Cargar Debts
            dto.debts = new List<DebtRow>();
            for (XD_Debts__c db : [SELECT Id, Name, Date_of_Value__c, Balance__c, Client_s_Non_Mar_Interest_Debts__c, Opposing_s_Non_Mar_Interest_Debt__c, Net_Martital_Value_Debt__c, Client_s_Martial_Debt__c, Opp_s_Marital_Value_Debt__c FROM XD_Debts__c WHERE Matter__c = :recordId ORDER BY Name]) {
                DebtRow r = new DebtRow();
                r.id = db.Id; r.name = db.Name; r.valueDate = parseDate(db.Date_of_Value__c); r.balance = parseDec(db.Balance__c);
                r.clientNonMarital = parseDec(db.Client_s_Non_Mar_Interest_Debts__c); r.opposingNonMarital = parseDec(db.Opposing_s_Non_Mar_Interest_Debt__c);
                r.netValue = parseDec(db.Net_Martital_Value_Debt__c); r.clientMarital = parseDec(db.Client_s_Martial_Debt__c); r.opposingMarital = parseDec(db.Opp_s_Marital_Value_Debt__c);
                dto.debts.add(r);
            }

            // 10. Cargar Retirement
            dto.retirement = new List<RetirementRow>();
            for (XD_Retirement_Accounts__c rt : [SELECT Id, Name, RetireValDate__c, RetireValue__c, Retire401kLoan__c, Client_s_Non_Mar_Interest_Retirement__c, Opp_s_Non_Mar_Interest_Retirement__c, Net_Martial_Value_Retirement__c, Client_s_Marital_Retirement__c, Opp_s_Marital_Retirement__c FROM XD_Retirement_Accounts__c WHERE Matter__c = :recordId ORDER BY Name]) {
                RetirementRow r = new RetirementRow();
                r.id = rt.Id; r.name = rt.Name; r.valueDate = parseDate(rt.RetireValDate__c); r.value = parseDec(rt.RetireValue__c); r.debt = parseDec(rt.Retire401kLoan__c);
                r.clientNonMarital = parseDec(rt.Client_s_Non_Mar_Interest_Retirement__c); r.opposingNonMarital = parseDec(rt.Opp_s_Non_Mar_Interest_Retirement__c);
                r.netValue = parseDec(rt.Net_Martial_Value_Retirement__c); r.clientMarital = parseDec(rt.Client_s_Marital_Retirement__c); r.opposingMarital = parseDec(rt.Opp_s_Marital_Retirement__c);
                dto.retirement.add(r);
            }

        } catch (Exception e) { System.debug('Error: ' + e.getMessage()); }
        return dto;
    }

    @AuraEnabled
    public static void updateField(Id recordId, String fieldApiName, String value) {
        try {
            Schema.SObjectType sObjectType = recordId.getSobjectType();
            Schema.SObjectField field = sObjectType.getDescribe().fields.getMap().get(fieldApiName);
            Schema.DisplayType type = field.getDescribe().getType();
            SObject obj = sObjectType.newSObject(recordId);
            if (value == null || value == '') obj.put(fieldApiName, null);
            else if (type == Schema.DisplayType.Date) obj.put(fieldApiName, Date.valueOf(value));
            else if (type == Schema.DisplayType.Currency || type == Schema.DisplayType.Double) obj.put(fieldApiName, parseDec(value));
            else obj.put(fieldApiName, value);
            update obj;
        } catch (Exception e) { throw new AuraHandledException('Error saving field: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteItem(Id recordId) { try { Database.delete(recordId); } catch (Exception e) { throw new AuraHandledException(e.getMessage()); } }

    private static AssetRow mapRow(SObject obj, String displayName, Decimal val, Decimal d1, Decimal d2, Decimal cNM, Decimal oNM, Decimal net, Decimal cMar, Decimal oMar) {
        AssetRow r = new AssetRow();
        r.id = (String)obj.get('Id'); 
        r.name = (displayName != null) ? displayName : ''; 
        r.value = val; r.debt1 = d1; r.debt2 = d2; r.clientNonMarital = cNM; r.opposingNonMarital = oNM;
        r.netValue = net; r.clientMarital = cMar; r.opposingMarital = oMar;
        return r;   
    }

    private static Decimal parseDec(Object o) { if (o == null) return 0; if (o instanceof String) { try { String s = (String)o; if (String.isBlank(s)) return 0; return Decimal.valueOf(s.replaceAll('[^0-9.-]', '')); } catch(Exception e){ return 0; } } return (Decimal)o; }
    private static Date parseDate(Object o) { if (o == null) return null; if (o instanceof Date) return (Date)o; try { return Date.valueOf((String)o); } catch(Exception e){ return null; } }

    public class BalanceSheetDTO {
        @AuraEnabled public String clientFirstName;
        @AuraEnabled public String opposingFirstName;
        @AuraEnabled public List<PleadingRow> pleadings; 
        @AuraEnabled public List<AssetRow> realEstate;
        @AuraEnabled public List<AssetRow> bankAccounts;
        @AuraEnabled public List<AssetRow> businesses;
        @AuraEnabled public List<AssetRow> stocks;
        @AuraEnabled public List<AssetRow> vehicles;
        @AuraEnabled public List<AssetRow> lifeInsurance;
        @AuraEnabled public List<DebtRow> debts;
        @AuraEnabled public List<RetirementRow> retirement;
    }
    
    public class PleadingRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String payor; // Client Pays / Opposing Pays
        @AuraEnabled public Decimal amount;
    }

    public class AssetRow { @AuraEnabled public String id; @AuraEnabled public String name; @AuraEnabled public Date valueDate; @AuraEnabled public Decimal value; @AuraEnabled public Decimal debt1; @AuraEnabled public Decimal debt2; @AuraEnabled public Decimal clientNonMarital; @AuraEnabled public Decimal opposingNonMarital; @AuraEnabled public Decimal netValue; @AuraEnabled public Decimal clientMarital; @AuraEnabled public Decimal opposingMarital; }
    public class DebtRow { @AuraEnabled public String id; @AuraEnabled public String name; @AuraEnabled public Date valueDate; @AuraEnabled public Decimal balance; @AuraEnabled public Decimal clientNonMarital; @AuraEnabled public Decimal opposingNonMarital; @AuraEnabled public Decimal netValue; @AuraEnabled public Decimal clientMarital; @AuraEnabled public Decimal opposingMarital; }
    public class RetirementRow { @AuraEnabled public String id; @AuraEnabled public String name; @AuraEnabled public Date valueDate; @AuraEnabled public Decimal value; @AuraEnabled public Decimal debt; @AuraEnabled public Decimal clientNonMarital; @AuraEnabled public Decimal opposingNonMarital; @AuraEnabled public Decimal netValue; @AuraEnabled public Decimal clientMarital; @AuraEnabled public Decimal opposingMarital; }
}