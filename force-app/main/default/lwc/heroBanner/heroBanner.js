import { LightningElement, wire, api } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';

export default class HeroBanner extends LightningElement {
    @api backgroundImage; // Propiedad que llenaremos en el Builder
    userName;

    @wire(getRecord, { recordId: USER_ID, fields: [USER_FIRST_NAME_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.userName = data.fields.FirstName.value;
        } else {
            this.userName = 'Client';
        }
    }

    get backgroundStyle() {
        const gradient = 'linear-gradient(90deg, rgba(0, 51, 102, 0.85) 0%, rgba(0, 51, 102, 0.5) 100%)';
        
        if (this.backgroundImage) {
            return `background: ${gradient}, url('${this.backgroundImage}'); background-size: cover; background-position: center;`;
        }
        return `background: ${gradient};`;
    }
}