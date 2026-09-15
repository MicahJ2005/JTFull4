import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getNextStepInit from '@salesforce/apex/NextStepControllerLWC.getNextStepInit';
import createNextStepQuick from '@salesforce/apex/NextStepControllerLWC.createNextStepQuick';
import addProductToNextStepQuick from '@salesforce/apex/NextStepControllerLWC.addProductToNextStepQuick';
import abortNextStepQuick from '@salesforce/apex/NextStepControllerLWC.abortNextStepQuick';

// Step machine deliberately retained (not collapsed to a single screen) so the
// planned complexity-score pricing screen drops in between SELECT and DONE
// without restructuring this component.
const STEP_SELECT = 'select';
const STEP_BUILD = 'build';
const STEP_DONE = 'done';

export default class NextStepQuick extends NavigationMixin(LightningElement) {
    @api recordId; // Matter (AcctSeed__Project__c) Id

    productOptions = [];
    areaOfLawOptions = [];
    selectedTemplateIds = [];
    stepName = '';
    areaOfLaw = '';

    step = STEP_SELECT;
    isLoading = true;
    isBusy = false;
    initError;
    actionError;
    buildTag = 'quick-v1.0';

    opportunityId;
    opportunityUrl;

    // progress across the per-product round-trips
    builtCount = 0;
    totalProducts = 0;
    currentProductLabel = '';

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

    get isSelectStep() { return this.step === STEP_SELECT; }
    get isBuildStep() { return this.step === STEP_BUILD; }
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
        if (!this.totalProducts) return 0;
        return Math.round((this.builtCount / this.totalProducts) * 100);
    }

    get buildHeading() {
        return `Creating ${this.currentProductLabel} (${Math.min(this.builtCount + 1, this.totalProducts)} of ${this.totalProducts})`;
    }

    handleProductChange(event) {
        this.selectedTemplateIds = event.detail.value;
        if (!this.stepName && this.selectedTemplateIds.length > 0) {
            this.stepName = this.productLabelById[this.selectedTemplateIds[0]] || '';
        }
    }
    handleNameChange(event) { this.stepName = event.detail.value; }
    handleAreaChange(event) { this.areaOfLaw = event.detail.value; }

    /**
     * Finish: create the Opportunity, then build each selected product in its
     * OWN round-trip.
     *
     * The per-product loop is NOT an optimisation miss — building two product
     * trees in one Apex transaction blows the org's flow/process-builder limit
     * ("XD Facts Populate Fields" LIMIT_EXCEEDED, verified in jt-full4).
     * Each product must land in its own transaction. Do not batch these.
     *
     * If any product fails, we call abortNextStepQuick to delete the whole
     * Opportunity, so staff never land on a half-built Next Step.
     */
    async handleFinish() {
        this.actionError = undefined;
        if (!this.canProceed) {
            this.toast('Missing information', 'Pick at least one product, a name, and an area of law.', 'warning');
            return;
        }

        this.isBusy = true;
        this.builtCount = 0;
        this.totalProducts = this.selectedTemplateIds.length;
        let createdOppId;

        try {
            createdOppId = await createNextStepQuick({
                matterId: this.recordId,
                stepName: this.stepName.trim(),
                areaOfLaw: this.areaOfLaw
            });
            this.opportunityId = createdOppId;
            this.step = STEP_BUILD;

            // Sequential on purpose — see method comment.
            for (const templateId of this.selectedTemplateIds) {
                this.currentProductLabel = this.productLabelById[templateId] || 'product';
                // eslint-disable-next-line no-await-in-loop
                await addProductToNextStepQuick({
                    matterId: this.recordId,
                    oppId: createdOppId,
                    templateId
                });
                this.builtCount += 1;
            }

            this.updateOpportunityUrl();
            this.step = STEP_DONE;
            this.toast('Next Step created', 'Products, cases and tasks were created at template defaults.', 'success');

            // Chris confirmed: land the user on the new Opportunity.
            this[NavigationMixin.Navigate](this.opportunityPageRef);

        } catch (e) {
            this.actionError = this.reduceError(e);
            // eslint-disable-next-line no-console
            console.error('nextStepQuick handleFinish failed:', e);

            // Compensating rollback: unwind the partially built Next Step.
            if (createdOppId) {
                try {
                    await abortNextStepQuick({ oppId: createdOppId });
                    this.actionError +=
                        ' — nothing was saved; the partially created Next Step was removed.';
                } catch (cleanupError) {
                    // eslint-disable-next-line no-console
                    console.error('nextStepQuick cleanup failed:', cleanupError);
                    this.actionError +=
                        ` — WARNING: cleanup also failed. Opportunity ${createdOppId} may be partially built and needs manual review.`;
                }
                this.opportunityId = undefined;
            }

            this.step = STEP_SELECT;
            this.toast('Could not create Next Step', this.actionError, 'error');
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