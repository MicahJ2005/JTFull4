import { LightningElement, api, wire, track } from 'lwc';
import getMatterDetails from '@salesforce/apex/LawFirmDashboardController.getMatterDetails';
import { NavigationMixin } from 'lightning/navigation';

export default class LawFirmMainColumn extends NavigationMixin(LightningElement) {
    @api recordId;
    @track dashboardData = {};
    
    allPhases = ['Phase 1', 'Phase 2', 'Phase 3', 'Phase 4'];

    @wire(getMatterDetails, { recordId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            let processedData = JSON.parse(JSON.stringify(data));
            
            processedData.phases = this.calculatePhases(processedData.currentPhase);
            
            processedData.currentPhaseNumber = processedData.currentPhase.replace('Phase ', '');

            this.dashboardData = processedData;
        } else if (error) {
            console.error('Error fetching dashboard data', error);
        }
    }

calculatePhases(currentPhase) {
        let phases = [];
        let foundCurrent = false;

        this.allPhases.forEach(label => {
            let cssClass = 'tracker-step '; 
            let isComplete = false;
            let isCurrent = false;

            if (label === currentPhase) {
                cssClass += 'step-current'; 
                foundCurrent = true;
                isCurrent = true;
            } else if (!foundCurrent) {
                cssClass += 'step-done'; 
                isComplete = true;
            } else {
                cssClass += 'step-future'; 
            }

            phases.push({ label, cssClass, isComplete, isCurrent });
        });
        return phases;
    }

    handleQuestionnaireClick() {
        console.log('Open Questionnaire');
    }

    handleTrackProgressClick() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home' 
            }
        });
    }
}