import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

// Apex methods
import getRelatedPeople from '@salesforce/apex/RelatedPartiesController.getRelatedPeople';
import getRelatedProfessionals from '@salesforce/apex/RelatedPartiesController.getRelatedProfessionals';
import searchPersonAccounts from '@salesforce/apex/RelatedPartiesController.searchPersonAccounts';
import searchBusinessContacts from '@salesforce/apex/RelatedPartiesController.searchBusinessContacts';
import searchOrganizationAccounts from '@salesforce/apex/RelatedPartiesController.searchOrganizationAccounts';
import createRelatedPerson from '@salesforce/apex/RelatedPartiesController.createRelatedPerson';
import createRelatedProfessional from '@salesforce/apex/RelatedPartiesController.createRelatedProfessional';
import createPersonAndLink from '@salesforce/apex/RelatedPartiesController.createPersonAndLink';
import createProfessionalAndLink from '@salesforce/apex/RelatedPartiesController.createProfessionalAndLink';
import removeRelatedPerson from '@salesforce/apex/RelatedPartiesController.removeRelatedPerson';
import removeRelatedProfessional from '@salesforce/apex/RelatedPartiesController.removeRelatedProfessional';
import getMatterName from '@salesforce/apex/RelatedPartiesController.getMatterName';

// Grouping configuration
const PERSON_GROUPS = {
    'Family': ['Client', 'Client Relative'],
    'Other Related People': ['Witness', 'Opposing Party', 'Victim', 'Heir', 'Friend', 'Co-Defendant', 'Other']
};
const PERSON_GROUP_ORDER = ['Family', 'Other Related People'];

const PROFESSIONAL_GROUPS = {
    'Legal': ['Opposing Counsel', 'Co-Counsel', 'Judge', "Judge's Clerk", 'Judicial Officer', 'Court', 'County Attorney', 'Opposing Paralegal/Assistant'],
    'Specialists': ['Mediator', 'Arbitrator', 'Custody Evaluator', 'Parenting Consultant', 'Expert Witness', 'Appraiser', 'Receiver', 'Referee'],
    'Other Professionals': ['Creditor', 'Child Support Worker', 'Government', 'Professional Service', 'Professional Service Provider', 'Other']
};
const PROFESSIONAL_GROUP_ORDER = ['Legal', 'Specialists', 'Other Professionals'];

const PEOPLE_RELATIONSHIPS = [
    'Client', 'Client Relative', 'Friend', 'Heir', 'Opposing Party',
    'Victim', 'Witness', 'Co-Defendant', 'Other'
];

const PROFESSIONAL_RELATIONSHIPS = [
    'Appraiser', 'Arbitrator', 'Child Support Worker', 'Creditor',
    'Custody Evaluator', 'Expert Witness', 'Government', 'Judge',
    "Judge's Clerk", 'Mediator', 'Opposing Counsel', 'Opposing Paralegal/Assistant',
    'Parenting Consultant', 'Professional Service', 'Professional Service Provider',
    'Receiver', 'Referee', 'Co-Counsel', 'County Attorney', 'Court',
    'Judicial Officer', 'Other'
];

function getInitials(name) {
    if (!name) return '?';
    return name.split(' ').filter(Boolean).slice(0, 2).map(n => n[0].toUpperCase()).join('');
}

function groupFor(relationship, groupMap) {
    for (const [group, rels] of Object.entries(groupMap)) {
        if (rels.includes(relationship)) return group;
    }
    return Object.keys(groupMap).pop(); // last group as fallback
}

export default class RelatedParties extends NavigationMixin(LightningElement) {
    @api recordId; // Matter record Id

    // Data
    @track matterName = '';
    @track people = [];
    @track professionals = [];
    @track activeTab = 'people';
    @track searchQuery = '';

    get isPeopleTab() { return this.activeTab === 'people'; }
    get isProfessionalsTab() { return this.activeTab === 'professionals'; }

    get peopleTabClass() {
        return this.isPeopleTab ? 'tab-pill tab-pill-active' : 'tab-pill';
    }
    get professionalsTabClass() {
        return this.isProfessionalsTab ? 'tab-pill tab-pill-active' : 'tab-pill';
    }
    get peopleCountBadgeClass() {
        return this.isPeopleTab ? 'tab-count tab-count-active' : 'tab-count';
    }
    get professionalsCountBadgeClass() {
        return this.isProfessionalsTab ? 'tab-count tab-count-active' : 'tab-count';
    }
    get searchPlaceholder() {
        return this.isPeopleTab
            ? 'Filter by name or relationship...'
            : 'Filter by name, relationship, or organization...';
    }

    // Wired results for refresh
    _wiredPeople;
    _wiredProfessionals;

    // Remove modal
    @track showRemoveModal = false;
    @track removeTargetId = '';
    @track removeTargetName = '';
    @track removeTargetType = '';
    @track removeTargetAssistant = '';

    // Add modal
    @track showAddModal = false;
    @track addStep = 'choose'; // 'choose' | 'form'
    @track addType = 'person'; // 'person' | 'professional'
    @track addMode = 'find'; // 'find' | 'create'
    @track addSearchQuery = '';
    @track addSearchResults = [];
    @track addSelectedId = '';
    @track addRelationship = '';
    @track addFirstName = '';
    @track addLastName = '';
    @track addPhone = '';
    @track addEmail = '';
    @track addOrganization = '';
    @track addOrganizationAccountId = '';
    @track orgSearchResults = [];
    @track showOrgResults = false;

    // --- Wire adapters ---

    @wire(getMatterName, { matterId: '$recordId' })
    wiredMatterName({ data, error }) {
        if (data) this.matterName = data;
        if (error) console.error('Error loading matter name', error);
    }

    @wire(getRelatedPeople, { matterId: '$recordId' })
    wiredPeople(result) {
        this._wiredPeople = result;
        if (result.data) {
            this.people = result.data.map(rp => ({
                id: rp.Id,
                contactId: rp.Person_Account_Name__c,
                name: rp.Person_Account_Name__r?.Name || 'Unknown',
                relationship: rp.Related_People_Class__c || 'Other',
                phone: rp.Person_Account_Name__r?.PersonMobilePhone || rp.Person_Account_Name__r?.Phone || '',
                email: rp.Person_Account_Name__r?.PersonEmail || '',
                initials: getInitials(rp.Person_Account_Name__r?.Name),
                phoneHref: 'tel:' + (rp.Person_Account_Name__r?.PersonMobilePhone || rp.Person_Account_Name__r?.Phone || ''),
                emailHref: 'mailto:' + (rp.Person_Account_Name__r?.PersonEmail || ''),
                recordUrl: '/' + rp.Person_Account_Name__c
            }));
        }
        if (result.error) console.error('Error loading people', result.error);
    }

    @wire(getRelatedProfessionals, { matterId: '$recordId' })
    wiredProfessionals(result) {
        this._wiredProfessionals = result;
        if (result.data) {
            this.professionals = result.data.map(rp => ({
                junctionId: rp.Id,
                contactId: rp.Business_Contact__c,
                name: rp.Business_Contact__r?.Name || 'Unknown',
                relationship: rp.Related_Professional_Type__c || 'Other',
                serviceProvider: rp.Professional_Service_Provider__c || '',
                organization: rp.Business_Contact__r?.Account?.Name || '',
                phone: rp.Business_Contact__r?.Phone || '',
                email: rp.Business_Contact__r?.Email || '',
                // Linked assistant from the Business Contact's self-lookup
                linkedAssistantName: rp.Business_Contact__r?.Opposing_Paralegal_Assistant__r?.Name || '',
                linkedAssistantPhone: rp.Business_Contact__r?.Opposing_Paralegal_Assistant__r?.Phone || '',
                linkedAssistantEmail: rp.Business_Contact__r?.Opposing_Paralegal_Assistant__r?.Email || '',
                linkedAssistantId: rp.Business_Contact__r?.Opposing_Paralegal_Assistant__c || ''
            }));
        }
        if (result.error) console.error('Error loading professionals', result.error);
    }

    // --- Computed properties ---

    get peopleCount() { return this.people.length; }

    get professionalsCount() {
        let count = this.professionals.length;
        this.professionals.forEach(p => { if (p.linkedAssistantName) count++; });
        return count;
    }

    get totalCount() { return this.peopleCount + this.professionalsCount; }

    get peopleTabLabel() { return `People (${this.peopleCount})`; }
    get professionalsTabLabel() { return `Professionals (${this.professionalsCount})`; }

    get filteredPeopleGroups() {
        const q = (this.searchQuery || '').toLowerCase();
        const filtered = this.people.filter(p => {
            if (!q) return true;
            return p.name.toLowerCase().includes(q) ||
                   p.relationship.toLowerCase().includes(q);
        });

        const groups = [];
        for (const groupLabel of PERSON_GROUP_ORDER) {
            const rels = PERSON_GROUPS[groupLabel];
            const items = filtered.filter(p => rels.includes(p.relationship));
            if (items.length > 0) {
                groups.push({ label: groupLabel, count: items.length, items });
            }
        }
        return groups;
    }

    get hasPeopleResults() {
        return this.filteredPeopleGroups.length > 0;
    }

    get filteredProfessionalGroups() {
        const q = (this.searchQuery || '').toLowerCase();
        const groups = [];

        for (const groupLabel of PROFESSIONAL_GROUP_ORDER) {
            const rels = PROFESSIONAL_GROUPS[groupLabel];
            const items = [];

            this.professionals.forEach(p => {
                if (!rels.includes(p.relationship)) return;

                const parentMatches = !q ||
                    p.name.toLowerCase().includes(q) ||
                    p.relationship.toLowerCase().includes(q) ||
                    (p.organization && p.organization.toLowerCase().includes(q));

                const derivedMatches = p.linkedAssistantName && (!q ||
                    p.linkedAssistantName.toLowerCase().includes(q));

                if (parentMatches || derivedMatches) {
                    // Add parent card
                    items.push({
                        id: p.junctionId,
                        junctionId: p.junctionId,
                        contactId: p.contactId,
                        name: p.name,
                        relationship: p.relationship,
                        displayRelationship: p.serviceProvider || p.relationship,
                        organization: p.organization,
                        organizationDisplay: p.organization,
                        phone: p.phone,
                        email: p.email,
                        phoneHref: 'tel:' + p.phone,
                        emailHref: 'mailto:' + p.email,
                        initials: getInitials(p.name),
                        isDerived: false,
                        linkedAssistantName: p.linkedAssistantName,
                        recordUrl: '/' + p.contactId,
                        cardClass: 'party-card slds-box slds-p-around_small slds-m-bottom_x-small',
                        avatarClass: 'avatar-circle slds-m-right_small'
                    });

                    // Add derived assistant card if exists
                    if (p.linkedAssistantName && (derivedMatches || parentMatches)) {
                        const assistantRole = p.relationship === 'Judge' || p.relationship === 'Judicial Officer'
                            ? 'Clerk' : 'Paralegal/Assistant';
                        items.push({
                            id: p.junctionId + '::assistant',
                            junctionId: p.junctionId,
                            contactId: p.linkedAssistantId,
                            name: p.linkedAssistantName,
                            relationship: assistantRole,
                            displayRelationship: `${p.relationship}'s ${assistantRole}`,
                            organization: p.organization,
                            organizationDisplay: 'via ' + p.name,
                            phone: p.linkedAssistantPhone,
                            email: p.linkedAssistantEmail,
                            phoneHref: 'tel:' + p.linkedAssistantPhone,
                            emailHref: 'mailto:' + p.linkedAssistantEmail,
                            initials: getInitials(p.linkedAssistantName),
                            isDerived: true,
                            linkedAssistantName: '',
                            recordUrl: '/' + p.linkedAssistantId,
                            cardClass: 'party-card party-card-derived slds-box slds-p-around_small slds-m-bottom_x-small slds-m-left_large',
                            avatarClass: 'avatar-circle avatar-derived slds-m-right_small'
                        });
                    }
                }
            });

            if (items.length > 0) {
                groups.push({ label: groupLabel, count: items.length, items });
            }
        }
        return groups;
    }

    get hasProfessionalResults() {
        return this.filteredProfessionalGroups.length > 0;
    }

    // --- Add modal computed ---

    get addStepIsForm() { return this.addStep === 'form'; }
    get addIsProfessional() { return this.addType === 'professional'; }
    get addTypeLabel() { return this.addType === 'person' ? 'Person' : 'Professional'; }

    get addSearchPlaceholder() {
        return this.addType === 'person'
            ? 'Search existing people...'
            : 'Search existing professionals...';
    }

    get addRelationshipOptions() {
        const list = this.addType === 'person' ? PEOPLE_RELATIONSHIPS : PROFESSIONAL_RELATIONSHIPS;
        return list.map(r => ({ label: r, value: r }));
    }

    get hasAddSearchResults() {
        return this.addSearchResults.length > 0;
    }

    get hasOrgResults() {
        return this.orgSearchResults.length > 0;
    }

    // --- Event handlers ---

    handleSelectPeopleTab() {
        this.activeTab = 'people';
        this.searchQuery = '';
    }

    handleSelectProfessionalsTab() {
        this.activeTab = 'professionals';
        this.searchQuery = '';
    }

    handleSearchChange(event) {
        this.searchQuery = event.target.value;
    }

    // --- Remove handlers ---

    handleRemoveClick(event) {
        this.removeTargetId = event.currentTarget.dataset.id;
        this.removeTargetName = event.currentTarget.dataset.name;
        this.removeTargetType = event.currentTarget.dataset.type;
        this.removeTargetAssistant = event.currentTarget.dataset.assistant || '';
        this.showRemoveModal = true;
    }

    handleRemoveCancel() {
        this.showRemoveModal = false;
    }

    async handleRemoveConfirm() {
        try {
            if (this.removeTargetType === 'people') {
                await removeRelatedPerson({ junctionId: this.removeTargetId });
            } else {
                await removeRelatedProfessional({ junctionId: this.removeTargetId });
            }

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `${this.removeTargetName} removed from this matter`,
                variant: 'success'
            }));

            this.showRemoveModal = false;
            await this._refreshData();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to remove party',
                variant: 'error'
            }));
        }
    }

    // --- Add handlers ---

    handleAddClick() {
        this.showAddModal = true;
        this.addStep = 'choose';
        this._resetAddForm();
    }

    handleAddCancel() {
        this.showAddModal = false;
        this._resetAddForm();
    }

    handleAddBack() {
        this.addStep = 'choose';
        this._resetAddForm();
    }

    handleChoosePerson() {
        this.addType = 'person';
        this.addStep = 'form';
        this.addMode = 'find';
        this._resetAddForm();
    }

    handleChooseProfessional() {
        this.addType = 'professional';
        this.addStep = 'form';
        this.addMode = 'find';
        this._resetAddForm();
    }

    handleAddModeFind() { this.addMode = 'find'; }
    handleAddModeCreate() { this.addMode = 'create'; }

    async handleAddSearchChange(event) {
        this.addSearchQuery = event.target.value;
        if (this.addSearchQuery.length < 2) {
            this.addSearchResults = [];
            return;
        }

        try {
            let results;
            if (this.addType === 'person') {
                results = await searchPersonAccounts({ searchTerm: this.addSearchQuery });
            } else {
                results = await searchBusinessContacts({ searchTerm: this.addSearchQuery });
            }

            this.addSearchResults = results.map(r => ({
                id: r.Id,
                name: r.Name,
                subtitle: this.addType === 'professional'
                    ? (r.Account?.Name ? r.Account.Name + ' · ' : '') + (r.Email || '')
                    : r.PersonEmail || r.Email || '',
                isSelected: this.addSelectedId === r.Id,
                selectedClass: this.addSelectedId === r.Id
                    ? 'lookup-item lookup-item-selected slds-p-around_small'
                    : 'lookup-item slds-p-around_small'
            }));
        } catch (error) {
            console.error('Search error', error);
            this.addSearchResults = [];
        }
    }

    handleSelectExisting(event) {
        const id = event.currentTarget.dataset.id;
        this.addSelectedId = this.addSelectedId === id ? '' : id;
        // Update selection visual
        this.addSearchResults = this.addSearchResults.map(r => ({
            ...r,
            isSelected: r.id === this.addSelectedId,
            selectedClass: r.id === this.addSelectedId
                ? 'lookup-item lookup-item-selected slds-p-around_small'
                : 'lookup-item slds-p-around_small'
        }));
    }

    handleAddRelationshipChange(event) { this.addRelationship = event.detail.value; }
    handleAddFirstNameChange(event) { this.addFirstName = event.target.value; }
    handleAddLastNameChange(event) { this.addLastName = event.target.value; }
    handleAddPhoneChange(event) { this.addPhone = event.target.value; }
    handleAddEmailChange(event) { this.addEmail = event.target.value; }
    async handleAddOrgChange(event) {
        this.addOrganization = event.target.value;
        this.addOrganizationAccountId = ''; // typing invalidates a prior selection
        if (this.addOrganization.length < 2) {
            this.orgSearchResults = [];
            this.showOrgResults = false;
            return;
        }
        try {
            const results = await searchOrganizationAccounts({ searchTerm: this.addOrganization });
            this.orgSearchResults = results.map(r => ({ id: r.Id, name: r.Name }));
            this.showOrgResults = true;
        } catch (error) {
            console.error('Organization search error', error);
            this.orgSearchResults = [];
        }
    }

    handleSelectOrg(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.addOrganizationAccountId = id;
        this.addOrganization = name;
        this.orgSearchResults = [];
        this.showOrgResults = false;
    }

    handleOrgInputBlur() {
        // Delay so a click on a dropdown result registers before the list hides
        setTimeout(() => { this.showOrgResults = false; }, 200);
    }

    async handleAddSave() {
        if (!this.addRelationship) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select a relationship',
                variant: 'error'
            }));
            return;
        }

        try {
            if (this.addMode === 'find') {
                if (!this.addSelectedId) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'Please select a record',
                        variant: 'error'
                    }));
                    return;
                }

                if (this.addType === 'person') {
                    await createRelatedPerson({
                        matterId: this.recordId,
                        personAccountId: this.addSelectedId,
                        relationship: this.addRelationship
                    });
                } else {
                    await createRelatedProfessional({
                        matterId: this.recordId,
                        businessContactId: this.addSelectedId,
                        relationship: this.addRelationship
                    });
                }
            } else {
                // Create new
                if (!this.addFirstName || !this.addLastName) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'First and last name are required',
                        variant: 'error'
                    }));
                    return;
                }

                if (this.addType === 'person') {
                    await createPersonAndLink({
                        matterId: this.recordId,
                        firstName: this.addFirstName,
                        lastName: this.addLastName,
                        phone: this.addPhone,
                        email: this.addEmail,
                        relationship: this.addRelationship
                    });
                } else {
                    await createProfessionalAndLink({
                        matterId: this.recordId,
                        firstName: this.addFirstName,
                        lastName: this.addLastName,
                        phone: this.addPhone,
                        email: this.addEmail,
                        organization: this.addOrganization,
                        organizationAccountId: this.addOrganizationAccountId || null,
                        relationship: this.addRelationship
                    });
                }
            }

            const selectedName = this.addMode === 'find'
                ? this.addSearchResults.find(r => r.id === this.addSelectedId)?.name
                : `${this.addFirstName} ${this.addLastName}`;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `${selectedName} added to this matter`,
                variant: 'success'
            }));

            this.showAddModal = false;
            this._resetAddForm();
            await this._refreshData();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to add party',
                variant: 'error'
            }));
        }
    }

    // --- Helpers ---

    _resetAddForm() {
        this.addSearchQuery = '';
        this.addSearchResults = [];
        this.addSelectedId = '';
        this.addRelationship = '';
        this.addFirstName = '';
        this.addLastName = '';
        this.addPhone = '';
        this.addEmail = '';
        this.addOrganization = '';
        this.addOrganizationAccountId = '';
        this.orgSearchResults = [];
        this.showOrgResults = false;
    }

    async _refreshData() {
        const promises = [];
        if (this._wiredPeople) promises.push(refreshApex(this._wiredPeople));
        if (this._wiredProfessionals) promises.push(refreshApex(this._wiredProfessionals));
        await Promise.all(promises);
    }
}