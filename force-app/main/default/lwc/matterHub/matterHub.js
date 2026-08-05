import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMatterOverview from '@salesforce/apex/MatterHubController.getMatterOverview';
import getCurrentTasks from '@salesforce/apex/MatterHubController.getCurrentTasks';
import getUpcomingAppointments from '@salesforce/apex/MatterHubController.getUpcomingAppointments';

const DEFAULT_SUMMARY =
    'This page keeps you informed every step of the way. Below you can see what is ' +
    'happening in your matter, where you are in the process, and what comes next.';
const DEFAULT_WHATS_NEXT =
    'Your legal team is preparing for the next steps in your matter. We will reach out ' +
    'if we need anything from you, and you can always message your team using the options on this page.';

export default class MatterHub extends NavigationMixin(LightningElement) {
    @api recordId;

    // Configurable from Experience Builder
    @api matterTitleOverride = '';
    @api caseSummaryText = DEFAULT_SUMMARY;        // predetermined / static
    @api whatsNextText = DEFAULT_WHATS_NEXT;       // predetermined / static
    @api maxTasks = 3;
    @api maxAppointments = 3;
    @api showAllTasks = false;   // false (default) = only tasks flagged visible to the client
    @api showLegalTeam = false;

    // Site page API names for navigation
    @api taskTrackerPageName = 'Task_Tracker__c';
    @api calendarPageName = 'My_Calendar__c';
    @api legalTeamPageName = 'My_Legal_Team__c';

    @track overview;
    @track tasks = [];
    @track appointments = [];
    @track isMatterExpanded = true;

    // ---------------- Wires ----------------
    @wire(getMatterOverview, { recordId: '$recordId' })
    wiredOverview({ data, error }) {
        if (data) this.overview = data;
        else if (error) console.error('Error loading matter overview:', error);
    }

    @wire(getCurrentTasks, { recordId: '$recordId', maxTasks: '$maxTasks', clientVisibleOnly: '$clientVisibleOnly' })
    wiredTasks({ data, error }) {
        if (data) this.tasks = data;
        else if (error) { this.tasks = []; console.error('Error loading tasks:', error); }
    }

    @wire(getUpcomingAppointments, { recordId: '$recordId', maxEvents: '$maxAppointments' })
    wiredAppointments({ data, error }) {
        if (data) this.appointments = data;
        else if (error) { this.appointments = []; console.error('Error loading appointments:', error); }
    }

    // clientVisibleOnly is derived so the public boolean can default to false (LWC1099)
    get clientVisibleOnly() {
        return !this.showAllTasks;
    }

    // ---------------- Getters ----------------
    get matterTitle() {
        if (this.matterTitleOverride) return this.matterTitleOverride;
        const name = this.overview && this.overview.matterName;
        return name ? `My ${name}` : 'My Matter';
    }

    get toggleIcon() {
        return this.isMatterExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get hasQuestionnaire() {
        return !!(this.overview && this.overview.questionnaireUrl);
    }

    get questionnaireUrl() {
        return this.overview ? this.overview.questionnaireUrl : '';
    }

    // LWC: los booleanos a componentes hijos deben venir de una propiedad/getter (no atributo pelon)
    get openLinksInNewTab() {
        return true;
    }

    get questionnaireLabel() {
        return (this.overview && this.overview.questionnaireLabel) || 'Client Questionnaire';
    }

    get hasCurrentPhase() {
        return !!(this.overview &&
            (this.overview.currentPhaseTitle || this.overview.currentPhaseDescription));
    }

    get currentPhaseHeading() {
        if (!this.overview) return '';
        const idx = this.overview.phaseIndex || 1;
        const title = this.overview.currentPhaseTitle;
        return title ? `Phase ${idx}: ${title}` : `Phase ${idx}`;
    }

    get phaseSteps() {
        const current = (this.overview && this.overview.phaseIndex) || 1;
        return [1, 2, 3, 4].map((n) => {
            let state = 'upcoming';
            if (n < current) state = 'complete';
            else if (n === current) state = 'current';
            return { key: n, label: `Phase ${n}`, className: `phase-step phase-${state}` };
        });
    }

    get hasTasks() { return this.tasks && this.tasks.length > 0; }
    get hasAppointments() { return this.appointments && this.appointments.length > 0; }

    get appointmentSummary() {
        const n = this.appointments ? this.appointments.length : 0;
        if (n === 0) return 'No upcoming events';
        const next = this.appointments[0];
        if (next && next.whenLabel) {
            return `Next: ${next.subject} \u2013 ${next.whenLabel}`;
        }
        return `${n} Upcoming Appointment${n === 1 ? '' : 's'}`;
    }

    get hasDocuments() {
        return !!(this.overview && this.overview.boxFolderEmbedUrl);
    }
    get documentsUrl() {
        return this.overview ? this.overview.boxFolderEmbedUrl : '';
    }
    get hasUploadLink() {
        return !!(this.overview && this.overview.boxUploadUrl);
    }
    get uploadUrl() {
        return this.overview ? this.overview.boxUploadUrl : '';
    }

    // ---------------- Handlers ----------------
    handleToggleMatter() { this.isMatterExpanded = !this.isMatterExpanded; }

    handleFillQuestionnaire() {
        if (this.hasQuestionnaire) window.open(this.overview.questionnaireUrl, '_blank');
    }

    handleUploadDocuments() {
        if (this.hasUploadLink) window.open(this.uploadUrl, '_blank');
    }

    handleTrackProgress() { this.navigateToPage(this.taskTrackerPageName); }
    handleSeeAllTasks() { this.navigateToPage(this.taskTrackerPageName); }
    handleViewAppointments() { this.navigateToPage(this.calendarPageName); }
    handleViewTeamPage() { this.navigateToPage(this.legalTeamPageName); }

    navigateToPage(pageName) {
        if (!pageName) return;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageName }
        });
    }
}