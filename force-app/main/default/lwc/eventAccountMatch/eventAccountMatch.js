import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord, getFieldValue, refreshApex } from 'lightning/uiRecordApi';
import WHAT_ID_FIELD from '@salesforce/schema/Event.WhatId';
import WHO_ID_FIELD from '@salesforce/schema/Event.WhoId';
import ID_FIELD from '@salesforce/schema/Event.Id';
import getPotentialMatches from '@salesforce/apex/EventAccountMatchController.getPotentialMatches';

export default class EventAccountMatch extends LightningElement {
    @api recordId;
    @track accountOptions = [];
    selectedAccountId = '';
    selectedRecordType = '';
    isLoading = false;
    isSaveSuccessful = false;
    eventRecordResult;

    @wire(getRecord, { recordId: '$recordId', fields: [WHAT_ID_FIELD, WHO_ID_FIELD] })
    eventRecord(result) {
        this.eventRecordResult = result;
        const { data, error } = result;

        if (data) {
            console.log('Fetched Event record:', data);
            const currentWhatId = getFieldValue(data, WHAT_ID_FIELD);
            const currentWhoId = getFieldValue(data, WHO_ID_FIELD);
            // If neither WhatId nor WhoId is set, load candidate matches from Agentforce action/Apex.
            if (!currentWhatId && !currentWhoId) {
                this.fetchAccountMatches();
            } else {
                this.accountOptions = [];
            }
        } else if (error) {
            console.error('Error fetching Event record:', error);
        }
    }

    async fetchAccountMatches() {
        this.isLoading = true;
        try {
            // Apex returns a list of AccountMatchWrapper objects, not Account sObjects.
            const matches = await getPotentialMatches({ eventId: this.recordId });
            console.log('Fetched potential matches:', matches);
            this.accountOptions = matches.map(match => {
                const recordTypeLabel = match.recordType === 'Lead' ? 'Lead' : 'Person Account';
                const activeMatterMatches = (match.activeMatterMatches || []).map(matter => ({
                    ...matter,
                    hasRole: !!matter.role
                }));
                return {
                    label: `${match.name} (${match.email || 'No Email'}) - ${recordTypeLabel}`,
                    value: match.id,
                    name: match.name,
                    email: match.email || 'No Email',
                    recordType: match.recordType || 'PersonAccount',
                    recordTypeLabel,
                    richDescription: match.richTextNotes || '',
                    isTopMatchCandidate: !!match.isTopMatchCandidate,
                    activeMatterMatches,
                    hasActiveMatterMatches: activeMatterMatches.length > 0,
                    isSelected: false,
                    cardClass: 'slds-box slds-box_x-small slds-m-bottom_small match-card'
                };
            });
        } catch (error) {
            console.error('Error fetching matches:', error);
        } finally {
            this.isLoading = false;
        }
    }

    get selectedMatch() {
        return this.accountOptions.find(option => option.value === this.selectedAccountId) || null;
    }

    get selectedMatchRichText() {
        return this.selectedMatch ? this.selectedMatch.richDescription : '';
    }

    handleCardClick(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.applySelection(selectedId);
    }

    applySelection(selectedId) {
        const selectedOption = this.accountOptions.find(option => option.value === selectedId);
        this.selectedAccountId = selectedOption ? selectedOption.value : '';
        this.selectedRecordType = selectedOption ? selectedOption.recordType : '';

        this.accountOptions = this.accountOptions.map(option => {
            const isSelected = option.value === this.selectedAccountId;
            return {
                ...option,
                isSelected,
                cardClass: isSelected
                    ? 'slds-box slds-box_x-small slds-m-bottom_small match-card match-card_selected'
                    : 'slds-box slds-box_x-small slds-m-bottom_small match-card'
            };
        });
    }

    async handleSave() {
        if (!this.selectedAccountId) return;
        this.isLoading = true;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;

        if (this.selectedRecordType === 'Lead') {
            fields[WHO_ID_FIELD.fieldApiName] = this.selectedAccountId;
            fields[WHAT_ID_FIELD.fieldApiName] = null;
        } else {
            fields[WHAT_ID_FIELD.fieldApiName] = this.selectedAccountId;
            fields[WHO_ID_FIELD.fieldApiName] = null;
        }

        try {
            await updateRecord({ fields });
            this.isSaveSuccessful = true;
            this.accountOptions = [];
            this.selectedAccountId = '';
            this.selectedRecordType = '';
            // Optionally fire a toast notification here
        } catch (error) {
            console.error('Error updating Event relationship:', error);
            this.isSaveSuccessful = false;
        } finally {
            this.isLoading = false;
        }
    }
}