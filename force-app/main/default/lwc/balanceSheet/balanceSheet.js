import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation'; 
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils'; 
import loadData from '@salesforce/apex/BalanceSheetController.loadData';
import deleteItem from '@salesforce/apex/BalanceSheetController.deleteItem';
import updateField from '@salesforce/apex/BalanceSheetController.updateField';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const toNumber = (v) => {
    if (v === '' || v === null || v === undefined) return 0;
    if (typeof v === 'string') v = v.replace(/[^0-9.-]+/g,"");
    const n = parseFloat(v);
    return Number.isFinite(n) ? n : 0;
};

const OBJECT_MAP = {
    realEstate: 'XD_Real_Property__c',
    bankAccount: 'XD_Bank_Accounts__c',
    business: 'XD_Business__c',
    stock: 'XD_Stock__c',
    vehicle: 'XD_Vehicles__c',
    lifeInsurance: 'XD_Life_Insurance_Policies__c',
    debt: 'XD_Debts__c',
    retirement: 'XD_Retirement_Accounts__c',
    pleading: 'XD_Pleadings__c'
};

export default class BalanceSheet extends NavigationMixin(LightningElement) {
    @api recordId;
    @track clientName = "CLIENT";
    @track opposingName = "OPPOSING";

    @track realEstateAssets = [];
    @track bankAccounts = [];
    @track businesses = []; 
    @track stocks = [];     
    @track vehicles = [];
    @track lifeInsurance = [];
    @track debts = [];
    @track retirementAccounts = [];
    @track pleadings = [];

    @track isDeleteModalOpen = false;
    @track pendingDeleteId = '';
    @track pendingDeleteType = '';

    @track showSaveButton = false;
    @track isSaving = false;
    pendingChanges = new Map(); 

    wiredDataResult;
    
    _syncingLeft = false;
    _syncingRight = false;

    @wire(loadData, { recordId: '$recordId' })
    wiredData(result) {
        this.wiredDataResult = result;
        const { data, error } = result;

        if (data) {
            this.clientName = data.clientFirstName ? this.formatName(data.clientFirstName) : "HUSBAND'S";
            this.opposingName = data.opposingFirstName ? this.formatName(data.opposingFirstName) : "WIFE'S";

            this.pleadings        = (data.pleadings || []).map(r => this.mapPleadingRow(r));
            this.realEstateAssets = (data.realEstate || []).map(r => this.mapRow(r, 'realEstate'));
            this.bankAccounts     = (data.bankAccounts || []).map(r => this.mapRow(r, 'bankAccount'));
            this.businesses       = (data.businesses || []).map(r => this.mapRow(r, 'business'));
            this.stocks           = (data.stocks || []).map(r => this.mapRow(r, 'stock'));
            this.vehicles         = (data.vehicles || []).map(r => this.mapRow(r, 'vehicle'));
            this.lifeInsurance    = (data.lifeInsurance || []).map(r => this.mapRow(r, 'lifeInsurance'));
            this.debts            = (data.debts || []).map(r => this.mapDebtRow(r));
            this.retirementAccounts = (data.retirement || []).map(r => this.mapRetirementRow(r));
            
            this.showSaveButton = false;
            this.pendingChanges.clear();

        } else if (error) {
            console.error('Error loading data', error);
        }
    }

    
    renderedCallback() {
        const dataContainer = this.template.querySelector('.data-scroll-container');
        const dummy = this.template.querySelector('.dummy-scrollbar-content');
        
        if (dataContainer && dummy) {
            const w = dataContainer.scrollWidth;
            if(w > 0) dummy.style.width = `${w}px`;
        }
    }

    handleScrollTop(event) {
        if (this._syncingRight) { this._syncingRight = false; return; }
        this._syncingLeft = true;
        const top = this.template.querySelector('.top-scrollbar-container');
        const data = this.template.querySelector('.data-scroll-container');
        if (top && data) data.scrollLeft = top.scrollLeft;
    }

    handleScrollData(event) {
        if (this._syncingLeft) { this._syncingLeft = false; return; }
        this._syncingRight = true;
        const top = this.template.querySelector('.top-scrollbar-container');
        const data = this.template.querySelector('.data-scroll-container');
        if (top && data) top.scrollLeft = data.scrollLeft;
    }

    createNewRecord(objectApiName) {
        const defaultValues = encodeDefaultFieldValues({ Matter__c: this.recordId });
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: objectApiName, actionName: 'new' }, state: { defaultFieldValues: defaultValues } });
    }
    handleAddRealEstate() { this.createNewRecord('XD_Real_Property__c'); }
    handleAddBankAccount() { this.createNewRecord('XD_Bank_Accounts__c'); }
    handleAddBusiness() { this.createNewRecord('XD_Business__c'); }
    handleAddStock() { this.createNewRecord('XD_Stock__c'); } 
    handleAddVehicle() { this.createNewRecord('XD_Vehicles__c'); }
    handleAddLifeInsurance() { this.createNewRecord('XD_Life_Insurance_Policies__c'); }
    handleAddDebt() { this.createNewRecord('XD_Debts__c'); }
    handleAddRetirement() { this.createNewRecord('XD_Retirement_Accounts__c'); }
    handleAddPleading() { this.createNewRecord('XD_Pleadings__c'); }

    handleRefresh() { refreshApex(this.wiredDataResult); }
    handleRequestDelete(e) { this.pendingDeleteId = e.target.dataset.id; this.pendingDeleteType = e.target.dataset.type; this.isDeleteModalOpen = true; }
    closeDeleteModal() { this.isDeleteModalOpen = false; }
    confirmDelete() {
        this.isDeleteModalOpen = false;
        const id = this.pendingDeleteId; const type = this.pendingDeleteType;
        let arr = '';
        if(type==='debt') arr='debts'; 
        else if(type==='retirement') arr='retirementAccounts';
        else if(type==='pleading') arr='pleadings';
        else arr = {realEstate:'realEstateAssets',bankAccount:'bankAccounts',business:'businesses',stock:'stocks',vehicle:'vehicles',lifeInsurance:'lifeInsurance'}[type];
        const item = this[arr]?.find(i=>i.id===id);
        if(item && item.isSaved) deleteItem({recordId:id}).then(()=>refreshApex(this.wiredDataResult));
        else if(arr) this[arr] = this[arr].filter(i=>i.id!==id);
    }
    registerChange(id, type, fieldAlias, value) {
        this.showSaveButton = true;
        const key = `${id}-${fieldAlias}`; 
        this.pendingChanges.set(key, { id: id, type: type, fieldAlias: fieldAlias, value: value });
    }
    async handleSaveChanges() {
        this.isSaving = true;
        const promises = [];
        this.pendingChanges.forEach((change) => {
            const apiName = this.getFieldApiName(change.type, change.fieldAlias);
            if(apiName) { 
                if (!(change.type === 'bankAccount' && change.fieldAlias === 'debt1')) {
                    const p = updateField({ recordId: change.id, fieldApiName: apiName, value: change.value });
                    promises.push(p);
                }
            }
        });
        try {
            await Promise.all(promises);
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Records updated successfully', variant: 'success' }));
            await refreshApex(this.wiredDataResult);
            this.pendingChanges.clear();
            this.showSaveButton = false;
        } catch (error) {
            console.error('Error saving:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error saving records', message: error.body ? error.body.message : error.message, variant: 'error' }));
        } finally {
            this.isSaving = false;
        }
    }
    
    getFieldApiName(type, fieldAlias) {
        const mapping = {
            realEstate: { name: 'Name', valueDate: null, value: 'Selected_FMV_RE__c', debt1: 'Rea_Estate_Total_Debts__c' },
            bankAccount: { name: 'InstitutionTypeLast4__c', valueDate: 'BankBalanceDate__c', value: 'BankBalance__c', debt1: 'Dummy_Debt__c' }, 
            business: { name: 'Name', valueDate: 'Date_of_Business_Valuation__c', value: 'BusinessValue__c' },
            stock: { name: 'Name', valueDate: 'StockFMVDate__c', value: 'Value_of_Shares__c' },
            vehicle: { name: 'Name', valueDate: 'VehicleFMVDate__c', value: 'VehicleFMV__c', debt1: 'VehicleLoanAmount__c' },
            lifeInsurance: { name: 'Name', valueDate: 'Date_of_Cash_Value__c', value: 'LifeInsCashV__c', debt1: 'LifeInsLoan__c' },
            debt: { name: 'Name', valueDate: 'Date_of_Value__c', balance: 'Balance__c' },
            retirement: { name: 'Name', valueDate: 'RetireValDate__c', value: 'RetireValue__c', debt: 'Retire401kLoan__c' },
            pleading: { name: 'Name', payor: 'Is_there_a_Cash_Settlement__c', amount: 'Amount__c' }
        };
        if (mapping[type]) return mapping[type][fieldAlias] || fieldAlias;
        return fieldAlias;
    }

    handleAssetChange(event) {
        const id = event.target.dataset.id; const field = event.target.dataset.field; const type = event.target.dataset.type; const raw = event.target.value;
        const arrName = {realEstate:'realEstateAssets',bankAccount:'bankAccounts',business:'businesses',stock:'stocks',vehicle:'vehicles',lifeInsurance:'lifeInsurance'}[type];
        if(arrName) {
            this[arrName] = this[arrName].map(a => {
                if(a.id === id) {
                    const u = {...a, [field]: raw};
                    const net = toNumber(u.value) - toNumber(u.debt1) - toNumber(u.debt2) - toNumber(u.clientNonMarital) - toNumber(u.opposingNonMarital);
                    u.netValue = net; u.formattedNetValue = this.formatCurrency(net); u.rawNetValue = net;
                    u.netValueClass = net < 0 ? 'result-cell negative-value' : 'result-cell positive-value';
                    if(field === 'value') u.formattedValue = this.formatCurrency(raw);
                    if(field === 'debt1') u.formattedDebt1 = this.formatCurrency(raw);
                    if (field === 'valueDate' && type !== 'realEstate') u.dateClass = raw ? 'date-cell-wrapper' : 'date-cell-wrapper empty-date';
                    if(u.isSaved) this.registerChange(id, u.rowType, field, raw);
                    return u;
                } return a;
            });
        }
    }
    handleDebtChange(event) {
        const id = event.target.dataset.id; const field = event.target.dataset.field; const raw = event.target.value;
        this.debts = this.debts.map(d => {
            if(d.id === id) {
                const u = {...d, [field]: raw};
                const net = -toNumber(u.balance) + toNumber(u.clientNonMarital) + toNumber(u.opposingNonMarital);
                u.netValue = net; u.formattedNetValue = this.formatCurrency(net); u.rawNetValue = net;
                u.netValueClass = net < 0 ? 'result-cell negative-value' : 'result-cell positive-value';
                if (field === 'valueDate') u.dateClass = raw ? 'date-cell-wrapper' : 'date-cell-wrapper empty-date';
                if(u.isSaved) this.registerChange(id, 'debt', field, raw);
                return u;
            } return d;
        });
    }
    handleRetirementChange(event) {
        const id = event.target.dataset.id; const field = event.target.dataset.field; const raw = event.target.value;
        this.retirementAccounts = this.retirementAccounts.map(r => {
            if(r.id === id) {
                const u = {...r, [field]: raw};
                const net = toNumber(u.value) - toNumber(u.debt) - toNumber(u.clientNonMarital) - toNumber(u.opposingNonMarital);
                u.netValue = net; u.formattedNetValue = this.formatCurrency(net); u.rawNetValue = net;
                u.netValueClass = net < 0 ? 'result-cell negative-value' : 'result-cell positive-value';
                if (field === 'valueDate') u.dateClass = raw ? 'date-cell-wrapper' : 'date-cell-wrapper empty-date';
                if(u.isSaved) this.registerChange(id, 'retirement', field, raw);
                return u;
            } return r;
        });
    }

    handlePleadingChange(event) {
        const id = event.target.dataset.id; const field = event.target.dataset.field; const raw = event.target.value;
        this.pleadings = this.pleadings.map(p => {
            if(p.id === id) {
                const u = {...p, [field]: raw};
                const amt = toNumber(u.amount);
                
                let cImp = 0; let oImp = 0;
                if (u.payor === 'Client Pays') {
                    cImp = -amt; oImp = amt; 
                } else if (u.payor === 'Opposing Pays') {
                    oImp = -amt; cImp = amt; 
                }

                u.formattedAmount = this.formatCurrency(amt);
                u.rawClient = cImp; u.rawOpposing = oImp;
                u.formattedClientImpact = this.formatCurrency(cImp);
                u.formattedOpposingImpact = this.formatCurrency(oImp);

                u.clientClass = cImp < 0 ? 'result-cell negative-value' : (cImp > 0 ? 'result-cell positive-value' : 'text-cell');
                u.opposingClass = oImp < 0 ? 'result-cell negative-value' : (oImp > 0 ? 'result-cell positive-value' : 'text-cell');

                u.isClientPays = u.payor === 'Client Pays';
                u.isOpposingPays = u.payor === 'Opposing Pays';
                u.isNoSelection = !u.payor;

                if(u.isSaved) this.registerChange(id, 'pleading', field, raw);
                return u;
            } return p;
        });
    }

    mapRow(r, type) {
        const objName = OBJECT_MAP[type] || 'AcctSeed__Project__c';
        return {
            id: r.id, isSaved: true, rowType: type, recordUrl: `/lightning/r/${objName}/${r.id}/view`,
            name: r.name || '', valueDate: r.valueDate || '', dateClass: r.valueDate ? 'date-cell-wrapper' : 'date-cell-wrapper empty-date',
            value: r.value, debt1: r.debt1, debt2: r.debt2, 
            formattedValue: this.formatCurrency(r.value), formattedDebt1: this.formatCurrency(r.debt1), 
            clientNonMarital: this.formatCurrency(r.clientNonMarital), opposingNonMarital: this.formatCurrency(r.opposingNonMarital),
            formattedNetValue: this.formatCurrency(r.netValue), netValueClass: r.netValue < 0 ? 'result-cell negative-value' : 'result-cell positive-value',
            clientMarital: this.formatCurrency(r.clientMarital), opposingMarital: this.formatCurrency(r.opposingMarital),
            rawNetValue: r.netValue, rawClient: r.clientMarital, rawOpposing: r.opposingMarital
        };
    }
    mapDebtRow(r) {
        return {
            id: r.id, isSaved: true, rowType: 'debt', recordUrl: `/lightning/r/XD_Debts__c/${r.id}/view`,
            name: r.name || '', valueDate: r.valueDate || '', balance: r.balance, dateClass: r.valueDate ? 'date-cell-wrapper' : 'date-cell-wrapper empty-date',
            clientNonMarital: this.formatCurrency(r.clientNonMarital), opposingNonMarital: this.formatCurrency(r.opposingNonMarital),
            formattedNetValue: this.formatCurrency(r.netValue), netValueClass: r.netValue < 0 ? 'result-cell negative-value' : 'result-cell positive-value',
            clientMarital: this.formatCurrency(r.clientMarital), opposingMarital: this.formatCurrency(r.opposingMarital),
            rawNetValue: r.netValue, rawClient: r.clientMarital, rawOpposing: r.opposingMarital
        };
    }
    mapRetirementRow(r) {
        return {
            id: r.id, isSaved: true, rowType: 'retirement', recordUrl: `/lightning/r/XD_Retirement_Accounts__c/${r.id}/view`,
            name: r.name || '', valueDate: r.valueDate || '', value: r.value, debt: r.debt, dateClass: r.valueDate ? 'date-cell-wrapper' : 'date-cell-wrapper empty-date',
            clientNonMarital: this.formatCurrency(r.clientNonMarital), opposingNonMarital: this.formatCurrency(r.opposingNonMarital),
            formattedNetValue: this.formatCurrency(r.netValue), netValueClass: r.netValue < 0 ? 'result-cell negative-value' : 'result-cell positive-value',
            clientMarital: this.formatCurrency(r.clientMarital), opposingMarital: this.formatCurrency(r.opposingMarital),
            rawNetValue: r.netValue, rawClient: r.clientMarital, rawOpposing: r.opposingMarital
        };
    }

    mapPleadingRow(r) {
        const amt = toNumber(r.amount);
        let cImp = 0; let oImp = 0;
        
        if (r.payor === 'Client Pays') { cImp = -amt; oImp = amt; } 
        else if (r.payor === 'Opposing Pays') { oImp = -amt; cImp = amt; }

        return {
            id: r.id, isSaved: true, rowType: 'pleading', recordUrl: `/lightning/r/XD_Pleadings__c/${r.id}/view`,
            name: r.name || '', payor: r.payor || '', amount: amt,
            formattedAmount: this.formatCurrency(amt),
            rawClient: cImp, rawOpposing: oImp,
            formattedClientImpact: this.formatCurrency(cImp),
            formattedOpposingImpact: this.formatCurrency(oImp),
            clientClass: cImp < 0 ? 'result-cell negative-value' : (cImp > 0 ? 'result-cell positive-value' : 'text-cell'),
            opposingClass: oImp < 0 ? 'result-cell negative-value' : (oImp > 0 ? 'result-cell positive-value' : 'text-cell'),
            isClientPays: r.payor === 'Client Pays',
            isOpposingPays: r.payor === 'Opposing Pays',
            isNoSelection: !r.payor
        };
    }

    get assetsSubtotal() { 
        let net=0,cl=0,op=0; 
        [...this.realEstateAssets,...this.bankAccounts,...this.businesses,...this.stocks,...this.vehicles,...this.lifeInsurance].forEach(a=>{
            if(a.isSaved){net+=toNumber(a.rawNetValue);cl+=toNumber(a.rawClient);op+=toNumber(a.rawOpposing);}
        }); 
        return {netValue:net,client:cl,opposing:op}; 
    }
    get formattedAssetsNetValue() { return this.formatCurrency(this.assetsSubtotal.netValue); }
    get formattedAssetsClient() { return this.formatCurrency(this.assetsSubtotal.client); }
    get formattedAssetsOpposing() { return this.formatCurrency(this.assetsSubtotal.opposing); }
    get debtsSubtotal() { let net=0,cl=0,op=0; this.debts.forEach(d=>{if(d.isSaved){net+=toNumber(d.rawNetValue);cl+=toNumber(d.rawClient);op+=toNumber(d.rawOpposing);}}); return {netValue:net,client:cl,opposing:op}; }
    get formattedDebtsNetValue() { return this.formatCurrency(this.debtsSubtotal.netValue); }
    get formattedDebtsClient() { return this.formatCurrency(this.debtsSubtotal.client); }
    get formattedDebtsOpposing() { return this.formatCurrency(this.debtsSubtotal.opposing); }
    
    get pleadingsSubtotal() {
        let cl=0, op=0;
        this.pleadings.forEach(p => {
            if(p.isSaved) { cl+=toNumber(p.rawClient); op+=toNumber(p.rawOpposing); }
        });
        return { client: cl, opposing: op };
    }
    get formattedPleadingsClient() { return this.formatCurrency(this.pleadingsSubtotal.client); }
    get formattedPleadingsOpposing() { return this.formatCurrency(this.pleadingsSubtotal.opposing); }


    get netTotal() { return this.assetsSubtotal.netValue + this.debtsSubtotal.netValue; }
    
    get netTotalClient() { return this.assetsSubtotal.client + this.debtsSubtotal.client + this.pleadingsSubtotal.client; }
    get netTotalOpposing() { return this.assetsSubtotal.opposing + this.debtsSubtotal.opposing + this.pleadingsSubtotal.opposing; }
    
    get formattedNetTotal() { return this.formatCurrency(this.netTotal); }
    get formattedNetTotalClient() { return this.formatCurrency(this.netTotalClient); }
    get formattedNetTotalOpposing() { return this.formatCurrency(this.netTotalOpposing); }
    
    get eachPartyEntitled() { return this.netTotal / 2; }
    get formattedEachPartyEntitled() { return this.formatCurrency(this.eachPartyEntitled); }
    
    get equalizerClient() { return this.eachPartyEntitled - this.netTotalClient; }
    get equalizerOpposing() { return this.eachPartyEntitled - this.netTotalOpposing; }
    get formattedEqualizerClient() { return this.formatCurrency(this.equalizerClient); }
    get formattedEqualizerOpposing() { return this.formatCurrency(this.equalizerOpposing); }
    
    get resultingClient() { return this.netTotalClient + this.equalizerClient; }
    get resultingOpposing() { return this.netTotalOpposing + this.equalizerOpposing; }
    
    get formattedResultingClient() { return this.formatCurrency(this.resultingClient); }
    get formattedResultingOpposing() { return this.formatCurrency(this.resultingOpposing); }
    
    get retirementSubtotal() { let net=0,cl=0,op=0; this.retirementAccounts.forEach(r=>{if(r.isSaved){net+=toNumber(r.rawNetValue);cl+=toNumber(r.rawClient);op+=toNumber(r.rawOpposing);}}); return {netValue:net,client:cl,opposing:op}; }
    get formattedRetirementNetValue() { return this.formatCurrency(this.retirementSubtotal.netValue); }
    get formattedRetirementClient() { return this.formatCurrency(this.retirementSubtotal.client); }
    get formattedRetirementOpposing() { return this.formatCurrency(this.retirementSubtotal.opposing); }
    get retirementEachPartyEntitled() { return this.retirementSubtotal.netValue / 2; }
    get formattedRetirementEqualizerClient() { return this.formatCurrency(this.retirementEachPartyEntitled - this.retirementSubtotal.client); }
    get formattedRetirementEqualizerOpposing() { return this.formatCurrency(this.retirementEachPartyEntitled - this.retirementSubtotal.opposing); }
    get clientNonMarHeader() { return `${this.clientName} NON-MAR`; }
    get opposingNonMarHeader() { return `${this.opposingName} NON-MAR`; }
    formatCurrency(value) { return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 }).format(toNumber(value)); }
    formatName(name) { return name ? (name.toUpperCase().endsWith('S') ? name.toUpperCase() + "'" : name.toUpperCase() + "'S") : "CLIENT'S"; }
    get currentDate() { return new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }); }
}