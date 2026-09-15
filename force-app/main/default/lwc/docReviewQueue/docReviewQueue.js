import { LightningElement, wire, track } from 'lwc';
import getReviewQueue from '@salesforce/apex/DocReviewQueueController.getReviewQueue';
import approveAndFile from '@salesforce/apex/DocReviewQueueController.approveAndFile';
import reject from '@salesforce/apex/DocReviewQueueController.reject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

/**
 * Document Review Queue (jt-box-ingestion redaction pipeline).
 * Groups held documents CSS -> Matter -> aging (oldest first). First-touch resolution:
 * Approve & File, or Reject-with-reason (no separate escalation tier, per Chris 2026-08-06).
 * STATUS: UI scaffold wired to DocReviewQueueController mock data; real Supabase read/write
 * lands once matters.css_name + the authed documents endpoint are ready.
 */
export default class DocReviewQueue extends LightningElement {
    @track groups = [];          // [{ cssName, matters: [{ matterName, docs: [...] }] }]
    wiredResult;
    buildTag = 'b0.1-scaffold';

    @wire(getReviewQueue)
    wired(result) {
        this.wiredResult = result;
        if (result.data) {
            this.groups = this.buildGroups(result.data);
        } else if (result.error) {
            this.toast('Error loading queue', this.errStr(result.error), 'error');
        }
    }

    // CSS -> Matter -> docs(aging asc). Input already sorted css,matter,age by the controller;
    // we just fold it into the nested display shape.
    buildGroups(rows) {
        const byCss = new Map();
        for (const r of rows) {
            const css = r.cssName || '(Unassigned CSS)';
            if (!byCss.has(css)) byCss.set(css, new Map());
            const byMatter = byCss.get(css);
            const m = r.matterName || '(Unknown Matter)';
            if (!byMatter.has(m)) byMatter.set(m, []);
            byMatter.get(m).push(r);
        }
        const out = [];
        for (const [cssName, byMatter] of byCss) {
            const matters = [];
            for (const [matterName, docs] of byMatter) {
                docs.sort((a, b) => (b.ageDays || 0) - (a.ageDays || 0)); // oldest first
                matters.push({ key: cssName + '|' + matterName, matterName, docs });
            }
            out.push({ key: cssName, cssName, matters, docCount: this.countDocs(matters) });
        }
        return out;
    }

    countDocs(matters) {
        return matters.reduce((n, m) => n + m.docs.length, 0);
    }

    async handleApprove(event) {
        const { docid, folder, dtype } = event.currentTarget.dataset;
        try {
            await approveAndFile({ documentId: docid, correctedType: dtype, correctedFolder: folder });
            this.toast('Approved & filed', docid, 'success');
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast('Approve failed', this.errStr(e), 'error');
        }
    }

    async handleReject(event) {
        const { docid } = event.currentTarget.dataset;
        const reason = window.prompt('Reason for rejection:');
        if (!reason) return;
        try {
            await reject({ documentId: docid, reason });
            this.toast('Rejected', docid, 'success');
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast('Reject failed', this.errStr(e), 'error');
        }
    }

    get isEmpty() {
        return !this.groups || this.groups.length === 0;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errStr(e) {
        return (e && e.body && e.body.message) ? e.body.message : JSON.stringify(e);
    }
}