import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getNextStepInit from '@salesforce/apex/NextStepControllerLWC.getNextStepInit';
import createNextStepOpportunityFromMatter from '@salesforce/apex/NextStepControllerLWC.createNextStepOpportunityFromMatter';
import getTaskTrackerTemplates from '@salesforce/apex/NextStepControllerLWC.getTaskTrackerTemplates';
import createTaskTrackerForNextSteps from '@salesforce/apex/NextStepControllerLWC.createTaskTrackerForNextSteps';

const STEP_SELECT = 'select';   // Screen 1: product / name / area
const STEP_SCOPE = 'scope';     // Per-template task tree + hours
const STEP_DONE = 'done';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'name',
        type: 'taskName',
        typeAttributes: { level: { fieldName: 'level' }, isTask: { fieldName: 'isTask' } },
        wrapText: true
    },
    { label: 'Type', fieldName: 'type', type: 'text', fixedWidth: 90 },
    {
        label: 'Hours',
        fieldName: 'hours',
        type: 'number',
        editable: { fieldName: 'isTask' }, // only leaf Task rows are editable
        typeAttributes: { minimumFractionDigits: 2 },
        fixedWidth: 120,
        cellAttributes: { alignment: 'left' }
    }
];

export default class NextStep extends NavigationMixin(LightningElement) {
    @api recordId; // Matter (AcctSeed__Project__c) Id

    // ---- Screen 1 state ----
    productOptions = [];
    areaOfLawOptions = [];
    selectedTemplateIds = [];
    stepName = '';
    areaOfLaw = '';

    // ---- flow state ----
    step = STEP_SELECT;
    isLoading = true;
    isBusy = false;
    initError;
    actionError;
    buildTag = 'v1.0'; // version marker; confirms cache freshness after deploy

    // ---- scope (tree) state ----
    columns = COLUMNS;
    opportunityId;
    opportunityUrl;
    queue = [];              // remaining template Ids to finalize
    completedCount = 0;
    totalTemplates = 0;
    templateName = '';
    rows = [];               // flattened rows for the current template
    draftValues = [];        // datatable inline-edit drafts
    selectedRowIds = [];     // selected row keys (Case + Task)
    childrenByParent = {};    // parentId -> [descendant row ids] for cascade

    @wire(getNextStepInit, { matterId: '$recordId' })
    wiredInit({ data, error }) {
        if (data) {
            this.productOptions = data.productOptions.map((o) => ({ label: o.label, value: o.value }));
            this.areaOfLawOptions = data.areaOfLawOptions.map((o) => ({ label: o.label, value: o.value }));
            this.isLoading = false;
            this.initError = undefined;
        } else if (error) {
            this.isLoading = false;
            this.initError = this.reduceError(error);
        }
    }

    // ---------- getters ----------
    get isSelectStep() { return this.step === STEP_SELECT; }
    get isScopeStep() { return this.step === STEP_SCOPE; }
    get isDoneStep() { return this.step === STEP_DONE; }

    get productLabelById() {
        const map = {};
        this.productOptions.forEach((o) => { map[o.value] = o.label; });
        return map;
    }

    get canProceed() {
        return (
            this.selectedTemplateIds.length > 0 &&
            this.stepName && this.stepName.trim().length > 0 &&
            this.areaOfLaw
        );
    }

    get progress() {
        if (!this.totalTemplates) return 0;
        return Math.round((this.completedCount / this.totalTemplates) * 100);
    }

    get scopeHeading() {
        return `${this.templateName} (${this.completedCount + 1} of ${this.totalTemplates})`;
    }

    // ---------- Screen 1 handlers ----------
    handleProductChange(event) {
        this.selectedTemplateIds = event.detail.value;
        if (!this.stepName && this.selectedTemplateIds.length > 0) {
            this.stepName = this.productLabelById[this.selectedTemplateIds[0]] || '';
        }
    }
    handleNameChange(event) { this.stepName = event.detail.value; }
    handleAreaChange(event) { this.areaOfLaw = event.detail.value; }

    async handleNext() {
        this.actionError = undefined;
        if (!this.canProceed) {
            this.toast('Missing information', 'Pick at least one product, a name, and an area of law.', 'warning');
            return;
        }
        this.isBusy = true;
        try {
            // Create the Opportunity ONCE, server-side.
            this.opportunityId = await createNextStepOpportunityFromMatter({
                matterId: this.recordId,
                stepName: this.stepName.trim(),
                areaOfLaw: this.areaOfLaw
            });
            this.updateOpportunityUrl();
            this.queue = [...this.selectedTemplateIds];
            this.totalTemplates = this.queue.length;
            this.completedCount = 0;
            this.step = STEP_SCOPE;
            await this.loadNextTemplate();
        } catch (e) {
            // Surface inline (toasts can be hidden behind the action modal).
            this.actionError = this.reduceError(e);
            // eslint-disable-next-line no-console
            console.error('nextStep handleNext failed:', e);
            this.toast('Could not create Next Step', this.actionError, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    // ---------- Scope (tree) ----------
    async loadNextTemplate() {
        if (this.queue.length === 0) {
            this.step = STEP_DONE;
            return;
        }
        this.isBusy = true;
        const templateId = this.queue[0];
        try {
            const json = await getTaskTrackerTemplates({ templateId });
            const tree = JSON.parse(json);
            this.buildRows(tree);
        } catch (e) {
            this.toast('Could not load template', this.reduceError(e), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    buildRows(tree) {
        const rows = [];
        const childrenByParent = {};

        const walk = (node, level, parentId) => {
            const isTask = node.Type !== 'Case';
            const row = {
                id: node.Id,
                name: node.Name,
                type: node.Type,
                hours: isTask ? (node.Hours == null ? 0 : node.Hours) : null,
                level,
                isTask
            };
            rows.push(row);
            if (parentId) {
                (childrenByParent[parentId] = childrenByParent[parentId] || []).push(node.Id);
            }
            const kids = node._children || [];
            kids.forEach((k) => walk(k, level + 1, node.Id));
        };

        (tree || []).forEach((root) => walk(root, 0, null));

        this.templateName = (tree && tree[0] && tree[0].Name) || 'Template';
        this.rows = rows;
        this.childrenByParent = childrenByParent;
        this.selectedRowIds = []; // nothing pre-checked — staff select what they want
        this.draftValues = [];
    }

    handleCellChange(event) {
        // event.detail.draftValues only contains the row(s) just edited, not the
        // full set of pending edits — merge by id instead of overwriting, or
        // previously edited rows lose their draft and redisplay original data.
        const updates = event.detail.draftValues || [];
        const merged = [...this.draftValues];
        updates.forEach((update) => {
            const idx = merged.findIndex((d) => d.id === update.id);
            if (idx > -1) {
                merged[idx] = { ...merged[idx], ...update };
            } else {
                merged.push(update);
            }
        });
        this.draftValues = merged;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        let ids = selectedRows.map((r) => r.id);

        // Cascade: if a Case row's selection state changed, bring its descendants
        // along (mirrors the old tree grid behaviour).
        const config = event.detail.config || {};
        const action = config.action;
        const rowId = config.value;
        if ((action === 'rowSelect' || action === 'rowDeselect') && this.childrenByParent[rowId]) {
            const descendants = this.childrenByParent[rowId];
            const set = new Set(ids);
            if (action === 'rowSelect') {
                descendants.forEach((d) => set.add(d));
            } else {
                descendants.forEach((d) => set.delete(d));
            }
            ids = [...set];
        }
        this.selectedRowIds = ids;
    }

    async handleFinalize() {
        // Merge inline-edit drafts into a taskId -> hours map (Task rows only).
        const hoursByRow = {};
        this.rows.forEach((r) => { if (r.isTask) hoursByRow[r.id] = r.hours; });
        this.draftValues.forEach((d) => {
            if (d.id in hoursByRow) hoursByRow[d.id] = Number(d.hours);
        });

        const selectedTaskIds = this.selectedRowIds.filter(
            (id) => id in hoursByRow // only Task rows carry hours / get created
        );

        if (selectedTaskIds.length === 0) {
            this.toast('Nothing selected', 'Select at least one task to create.', 'warning');
            return;
        }

        this.isBusy = true;
        const templateId = this.queue[0];
        try {
            await createTaskTrackerForNextSteps({
                matterId: this.recordId,
                oppId: this.opportunityId,
                templateId,
                strMap: JSON.stringify(hoursByRow),
                selectedTaskIds
            });
            this.queue = this.queue.slice(1);
            this.completedCount += 1;
            if (this.queue.length > 0) {
                await this.loadNextTemplate();
            } else {
                this.step = STEP_DONE;
                this.toast('Next Step created', 'All cases and tasks were created.', 'success');
            }
        } catch (e) {
            this.toast('Could not create tasks', this.reduceError(e), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    updateOpportunityUrl() {
        this[NavigationMixin.GenerateUrl](this.opportunityPageRef).then((url) => {
            this.opportunityUrl = url;
        });
    }

    handleOpportunityClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate](this.opportunityPageRef);
    }

    get opportunityPageRef() {
        return {
            type: 'standard__recordPage',
            attributes: { recordId: this.opportunityId, actionName: 'view' }
        };
    }

    // ---------- utils ----------
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) return error.body.map((e) => e.message).join(', ');
        if (error?.body?.message) return error.body.message;
        if (typeof error?.message === 'string') return error.message;
        return 'Unknown error';
    }
}