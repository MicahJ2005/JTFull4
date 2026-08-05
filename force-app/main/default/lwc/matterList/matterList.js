import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMyMatters from '@salesforce/apex/MatterController.getMyMatters';

export default class MatterList extends NavigationMixin(LightningElement) {
    @wire(getMyMatters) matters;

    get hasMatters() {
        return this.matters.data && this.matters.data.length > 0;
    }

    navigateToRecord(event) {
        event.preventDefault();
        const recordId = event.target.dataset.recordId;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'AcctSeed__Project__c',
                actionName: 'view'
            }
        });
    }

    navigateToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'AcctSeed__Project__c', 
                actionName: 'list'
            },
            state: {
                filterName: 'Recent' 
            }
        });
    }
}