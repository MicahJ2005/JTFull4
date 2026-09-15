import { LightningElement, api, wire, track } from 'lwc';
import getReviewDoc from '@salesforce/apex/DocReviewQueueController.getReviewDoc';
import approveAndFile from '@salesforce/apex/DocReviewQueueController.approveAndFile';
import reject from '@salesforce/apex/DocReviewQueueController.reject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * Single-document review screen (jt-box-ingestion redaction pipeline).
 * Left: the redacted PDF (Box preview). Right: hold reason + EDITABLE metadata
 * (document type, target folder) + Approve & File / Reject. Metadata edits here feed the
 * naming/routing on approval. STATUS: scaffold on DocReviewQueueController mock data.
 *
 * Usage: <c-doc-review-screen document-id="..."></c-doc-review-screen>, or set via the
 * queue's row click (a future navigation wiring).
 */
export default class DocReviewScreen extends LightningElement {
    @api documentId;
    @track doc;
    @track editType;
    @track editFolder;
    buildTag = 'b0.1-scaffold';
    saving = false;

    @wire(getReviewDoc, { documentId: '$documentId' })
    wired({ data, error }) {
        if (data) {
            this.doc = data;
            this.editType = data.documentType;
            this.editFolder = data.targetFolder;
        } else if (error) {
            this.toast('Error loading document', this.errStr(error), 'error');
        }
    }

    handleTypeChange(e) { this.editType = e.detail.value; }
    handleFolderChange(e) { this.editFolder = e.detail.value; }

    get pdfPreviewUrl() {
        // Box file preview embed. Real: an authed Box preview/expiring-link URL from the
        // controller. Scaffold: the placeholder boxFileUrl.
        return this.doc ? this.doc.boxFileUrl : '#';
    }

    get metadataChanged() {
        return this.doc &&
            (this.editType !== this.doc.documentType || this.editFolder !== this.doc.targetFolder);
    }

    async handleApprove() {
        this.saving = true;
        try {
            await approveAndFile({
                documentId: this.doc.documentId,
                correctedType: this.editType,
                correctedFolder: this.editFolder
            });
            this.toast('Approved & filed', this.doc.fileName, 'success');
            this.dispatchEvent(new CustomEvent('resolved', {
                detail: { documentId: this.doc.documentId, action: 'approved' }
            }));
        } catch (e) {
            this.toast('Approve failed', this.errStr(e), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleReject() {
        const reason = window.prompt('Reason for rejection (e.g. unreadable scan, wrong client, needs attorney review):');
        if (!reason) return;
        this.saving = true;
        try {
            await reject({ documentId: this.doc.documentId, reason });
            this.toast('Rejected', this.doc.fileName, 'success');
            this.dispatchEvent(new CustomEvent('resolved', {
                detail: { documentId: this.doc.documentId, action: 'rejected', reason }
            }));
        } catch (e) {
            this.toast('Reject failed', this.errStr(e), 'error');
        } finally {
            this.saving = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errStr(e) {
        return (e && e.body && e.body.message) ? e.body.message : JSON.stringify(e);
    }
}