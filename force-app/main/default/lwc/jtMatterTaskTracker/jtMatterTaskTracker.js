import { LightningElement, api, wire, track } from 'lwc';
import getMatterOverview from '@salesforce/apex/MatterHubController.getMatterOverview';
import getTaskProgress from '@salesforce/apex/MatterHubController.getTaskProgress';
import getCurrentTasks from '@salesforce/apex/MatterHubController.getCurrentTasks';

export default class JtMatterTaskTracker extends LightningElement {
    @api recordId;
    @api matterTitleOverride = '';
    @api trackerEmbedUrl = '';        
    @api showAllTasks = false;        
    @api maxTasks = 50;               

    @track overview;
    @track progress;
    @track tasks = [];
    @track isExpanded = true;

    @wire(getMatterOverview, { recordId: '$recordId' })
    wiredOverview({ data, error }) {
        if (data) this.overview = data;
        else if (error) console.error('Overview error:', error);
    }

    @wire(getTaskProgress, { recordId: '$recordId' })
    wiredProgress({ data, error }) {
        if (data) this.progress = data;
        else if (error) console.error('Progress error:', error);
    }

    @wire(getCurrentTasks, { recordId: '$recordId', maxTasks: '$maxTasks', clientVisibleOnly: '$clientVisibleOnly' })
    wiredTasks({ data, error }) {
        if (data) this.tasks = data;
        else if (error) { this.tasks = []; console.error('Tasks error:', error); }
    }

    get clientVisibleOnly() { return !this.showAllTasks; }

    get matterTitle() {
        if (this.matterTitleOverride) return this.matterTitleOverride;
        const n = this.overview && this.overview.matterName;
        return n ? `My ${n}` : 'My Matter';
    }

    get toggleIcon() { return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown'; }
    get hasTasks() { return this.tasks && this.tasks.length > 0; }
    get hasEmbed() { return !!this.trackerEmbedUrl; }
    get hasProgress() { return this.progress && this.progress.total > 0; }
    get percent() { return this.progress ? this.progress.percentComplete : 0; }
    get progressLabel() {
        if (!this.progress) return '';
        return `${this.progress.completed} of ${this.progress.total} tasks completed`;
    }

    renderedCallback() {
        const el = this.refs ? this.refs.fillEl : null;
        if (el) {
            el.style.width = `${this.percent}%`;
        }
    }

    handleToggle() { this.isExpanded = !this.isExpanded; }
}