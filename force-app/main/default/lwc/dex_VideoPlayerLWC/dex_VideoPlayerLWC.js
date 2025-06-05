import { LightningElement, wire, api } from 'lwc';
import getTaskList from '@salesforce/apex/dex_VideoPlayerLWCController.getTaskList';

export default class Dex_VideoPlayerLWC extends LightningElement {
    @api recordId;
    tasks = [];
    showTasks = false;

    @wire(getTaskList, { recordId : '$recordId' })
    getTasks({ data }) {
        if(data) {
            this.tasks = JSON.parse(data);
            if(this.tasks && this.tasks.length > 0) {
                this.showTasks = true;
            }
        }
    }
}