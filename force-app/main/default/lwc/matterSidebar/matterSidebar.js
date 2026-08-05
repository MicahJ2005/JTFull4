import { LightningElement, api, wire, track } from 'lwc';
import getMatterDetails from '@salesforce/apex/LawFirmDashboardController.getMatterDetails';

export default class MatterSidebar extends LightningElement {
    @api recordId;
    @track dashboardData = {};

    @wire(getMatterDetails, { recordId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.dashboardData = data;
        }
    }
}