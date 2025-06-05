import { LightningElement, api, wire } from 'lwc';
import {getRecord, getFieldValue } from 'lightning/uiRecordApi';

import MATTER_NAME from '@salesforce/schema/AcctSeed__Project__c.Name';

export default class Dex_matterRecordLWC extends LightningElement {
    @api recordId;
    
    @wire(getRecord, { recordId: '$recordId', fields: [MATTER_NAME]})
    matter;

    get matterName() {
        return getFieldValue(this.matter.data, MATTER_NAME);
    }
}