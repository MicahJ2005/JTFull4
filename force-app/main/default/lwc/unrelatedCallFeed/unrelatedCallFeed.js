import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUnrelatedCalls from '@salesforce/apex/UnrelatedCallFeedController.getUnrelatedCalls';
import getUnrelatedCallsCount from '@salesforce/apex/UnrelatedCallFeedController.getUnrelatedCallsCount';
import searchMatters from '@salesforce/apex/UnrelatedCallFeedController.searchMatters';
import getSuggestedMatters from '@salesforce/apex/UnrelatedCallFeedController.getSuggestedMatters';
import relateCallToMatter from '@salesforce/apex/UnrelatedCallFeedController.relateCallToMatter';
import dismissCall from '@salesforce/apex/UnrelatedCallFeedController.dismissCall';
import undismissCall from '@salesforce/apex/UnrelatedCallFeedController.undismissCall';
import isViewAsEligible from '@salesforce/apex/UnrelatedCallFeedController.isViewAsEligible';
import searchUsers from '@salesforce/apex/UnrelatedCallFeedController.searchUsers';
import getFeedStats from '@salesforce/apex/UnrelatedCallFeedController.getFeedStats';

const SEARCH_DEBOUNCE_MS = 300;
const DEFAULT_DAYS_BACK = 7;
const CUSTOM_OPTION_VALUE = 'CUSTOM';
const PAGE_SIZE = 50;
const DAYS_BACK_OPTIONS = [
    { label: 'Last 7 days', value: '7' },
    { label: 'Last 30 days', value: '30' },
    { label: 'Last 60 days', value: '60' },
    { label: 'Last 90 days', value: '90' },
    { label: 'Custom…', value: CUSTOM_OPTION_VALUE }
];

export default class UnrelatedCallFeed extends NavigationMixin(LightningElement) {
    isLoading = false;
    loadError;
    calls = [];
    daysBack = String(DEFAULT_DAYS_BACK);
    daysBackOptions = DAYS_BACK_OPTIONS;
    customSinceDate; // yyyy-mm-dd string bound to the date input, only used when daysBack === CUSTOM_OPTION_VALUE

    // 0-indexed page number. Page 1 for humans = pageIndex 0 internally.
    pageIndex = 0;
    totalCount = 0;

    // Stats explaining a small "unrelated" count — e.g. "125 of your 128
    // recent calls are already linked via another Matter" — so a surprising
    // number isn't mistaken for a bug (confirmed live 2026-09-07).
    feedStats;

    searchTimeouts = {};

    // Active / Dismissed view toggle.
    viewDismissed = false;

    // Admin-only "View as" override — lets an admin preview another user's
    // feed (e.g. QA against real attorney data) without needing their login.
    // Enforcement is server-side (see UnrelatedCallFeedController.
    // resolveScopeUserId) regardless of what this control shows.
    isViewAsEligible = false;
    viewAsUserId;
    viewAsUserName = '';
    viewAsSearchTerm = '';
    viewAsOptions = [];
    viewAsShowResults = false;
    viewAsSearchTimeout;

    async connectedCallback() {
        try {
            this.isViewAsEligible = await isViewAsEligible();
        } catch (e) {
            this.isViewAsEligible = false;
        }
        this.loadCalls();
    }

    get isCustomDateSelected() {
        return this.daysBack === CUSTOM_OPTION_VALUE;
    }

    async loadCalls() {
        // With "Custom…" selected but no date chosen yet, don't fire a query
        // that would resolve to "no date bound at all" (a much bigger,
        // unintended result set) — wait for the user to actually pick a date.
        if (this.isCustomDateSelected && !this.customSinceDate) {
            this.calls = [];
            this.totalCount = 0;
            return;
        }

        this.isLoading = true;
        this.loadError = undefined;
        try {
            const daysBackParam = this.isCustomDateSelected ? null : Number(this.daysBack);
            const customSinceDateParam = this.isCustomDateSelected ? this.customSinceDate : null;
            const pageOffset = this.pageIndex * PAGE_SIZE;

            const [records, count, stats] = await Promise.all([
                getUnrelatedCalls({
                    daysBack: daysBackParam,
                    pageOffset,
                    customSinceDate: customSinceDateParam,
                    viewAsUserId: this.viewAsUserId || null,
                    viewDismissed: this.viewDismissed
                }),
                getUnrelatedCallsCount({
                    daysBack: daysBackParam,
                    customSinceDate: customSinceDateParam,
                    viewAsUserId: this.viewAsUserId || null,
                    viewDismissed: this.viewDismissed
                }),
                getFeedStats({
                    daysBack: daysBackParam,
                    customSinceDate: customSinceDateParam,
                    viewAsUserId: this.viewAsUserId || null,
                    viewDismissed: this.viewDismissed
                })
            ]);

            this.calls = records.map((r) => this.toRow(r));
            this.totalCount = count;
            this.feedStats = stats;
        } catch (e) {
            this.loadError = this.extractError(e);
        } finally {
            this.isLoading = false;
        }
    }

    toRow(dto) {
        const relatedRowCount = dto.relatedRowCount || 1;
        const callStartDate = dto.callStartDateTime ? new Date(dto.callStartDateTime) : null;
        const dismissedDate = dto.dismissedDate ? new Date(dto.dismissedDate) : null;
        return {
            id: dto.id,
            callTranscriptId: dto.callTranscriptId,
            callTranscriptName: dto.callTranscriptName,
            hasCallTranscript: !!dto.callTranscriptId,
            voiceCallId: dto.voiceCallId,
            hasVoiceCall: !!dto.voiceCallId,
            callDateDisplay: callStartDate ? callStartDate.toLocaleDateString() : '',
            callTimeDisplay: callStartDate ? callStartDate.toLocaleTimeString() : '',
            hasCallStart: !!dto.callStartDateTime,
            durationDisplay: this.formatDuration(dto.callDurationInSeconds),
            hasDuration: dto.callDurationInSeconds != null && dto.callDurationInSeconds > 0,
            otherPartyPhone: dto.otherPartyPhone,
            otherPartyName: dto.otherPartyName,
            hasOtherPartyPhone: !!dto.otherPartyPhone,
            hasOtherPartyName: !!dto.otherPartyName,
            hasOtherRelation: !!dto.otherRelationLabel,
            otherRelationLabel: dto.otherRelationLabel,
            matchedContactId: dto.matchedContactId,
            relatedRowCount,
            // This call may be represented by several junction rows (one per
            // Opportunity/Account/Lead it touches — a junction row can only
            // reference one at a time). Relating it updates ALL of them at
            // once, so the button says so when there's more than one.
            relateButtonLabel:
                relatedRowCount > 1 ? `Relate to Matter (${relatedRowCount} linked rows)` : 'Relate to Matter',
            isDismissed: !!dto.isDismissed,
            dismissedInfo:
                dismissedDate && dto.dismissedByName
                    ? `Dismissed by ${dto.dismissedByName} on ${dismissedDate.toLocaleDateString()}`
                    : '',
            isEditing: false,
            matterSearchTerm: '',
            matterOptions: [],
            showResults: false,
            noResults: false,
            suggestedMatters: [],
            isLoadingSuggestions: false,
            showSuggestions: false
        };
    }

    formatDuration(seconds) {
        if (seconds == null || seconds <= 0) return '';
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${String(secs).padStart(2, '0')}`;
    }

    handleOpenCallTranscript(event) {
        const callTranscriptId = event.currentTarget.dataset.ctId;
        if (!callTranscriptId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: callTranscriptId,
                objectApiName: 'Call_Transcript__c',
                actionName: 'view'
            }
        });
    }

    handleOpenVoiceCall(event) {
        const voiceCallId = event.currentTarget.dataset.vcId;
        if (!voiceCallId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: voiceCallId,
                objectApiName: 'VoiceCall',
                actionName: 'view'
            }
        });
    }

    get hasCalls() {
        return this.calls && this.calls.length > 0;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE));
    }

    get currentPageDisplay() {
        return this.pageIndex + 1;
    }

    get pageLabel() {
        return `Page ${this.currentPageDisplay} of ${this.totalPages}`;
    }

    get isFirstPage() {
        return this.pageIndex === 0;
    }

    get isLastPage() {
        return this.currentPageDisplay >= this.totalPages;
    }

    get activeViewVariant() {
        return this.viewDismissed ? 'neutral' : 'brand';
    }

    get dismissedViewVariant() {
        return this.viewDismissed ? 'brand' : 'neutral';
    }

    get emptyStateMessage() {
        return this.viewDismissed
            ? 'No dismissed calls in this window.'
            : "No unrelated calls in this window — you're all caught up.";
    }

    get alreadyLinkedMessage() {
        // Only meaningful for the Active view — dismissed calls were already
        // excluded from this comparison, and showing it there would be
        // confusing. Only show it when it explains something (>0 already
        // linked) — an all-genuinely-unrelated window needs no explanation.
        if (this.viewDismissed || !this.feedStats || !this.feedStats.alreadyLinkedCount) {
            return '';
        }
        const { alreadyLinkedCount, totalDistinctCalls } = this.feedStats;
        return `${alreadyLinkedCount} of your ${totalDistinctCalls} recent calls in this window are already linked via another Matter — only the rest show below.`;
    }

    handleRefresh() {
        this.pageIndex = 0;
        this.loadCalls();
    }

    handleShowActive() {
        if (!this.viewDismissed) return;
        this.viewDismissed = false;
        this.pageIndex = 0;
        this.loadCalls();
    }

    handleShowDismissed() {
        if (this.viewDismissed) return;
        this.viewDismissed = true;
        this.pageIndex = 0;
        this.loadCalls();
    }

    handleDaysBackChange(event) {
        this.daysBack = event.detail.value;
        this.pageIndex = 0;
        if (this.isCustomDateSelected) {
            // Don't fire a query yet — wait for the user to actually pick a
            // date via handleCustomDateChange. Clear stale results so the
            // list doesn't keep showing the previous filter's rows.
            this.calls = [];
            this.totalCount = 0;
            return;
        }
        this.loadCalls();
    }

    handleCustomDateChange(event) {
        this.customSinceDate = event.detail.value;
        this.pageIndex = 0;
        this.loadCalls();
    }

    handlePreviousPage() {
        if (this.isFirstPage) return;
        this.pageIndex -= 1;
        this.loadCalls();
    }

    handleNextPage() {
        if (this.isLastPage) return;
        this.pageIndex += 1;
        this.loadCalls();
    }

    handleViewAsSearchChange(event) {
        const term = event.target.value;
        this.viewAsSearchTerm = term;

        if (this.viewAsSearchTimeout) {
            clearTimeout(this.viewAsSearchTimeout);
        }
        this.viewAsSearchTimeout = setTimeout(() => this.runViewAsSearch(term), SEARCH_DEBOUNCE_MS);
    }

    async runViewAsSearch(term) {
        if (!term || term.length < 2) {
            this.viewAsOptions = [];
            this.viewAsShowResults = false;
            return;
        }
        try {
            this.viewAsOptions = await searchUsers({ searchTerm: term });
            this.viewAsShowResults = true;
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'User search failed',
                    message: this.extractError(e),
                    variant: 'error'
                })
            );
        }
    }

    handlePickViewAsUser(event) {
        const userId = event.currentTarget.dataset.userId;
        const userName = event.currentTarget.dataset.userName;
        this.viewAsUserId = userId;
        this.viewAsUserName = userName;
        this.viewAsSearchTerm = userName;
        this.viewAsShowResults = false;
        this.pageIndex = 0;
        this.loadCalls();
    }

    handleClearViewAs() {
        this.viewAsUserId = undefined;
        this.viewAsUserName = '';
        this.viewAsSearchTerm = '';
        this.viewAsOptions = [];
        this.viewAsShowResults = false;
        this.pageIndex = 0;
        this.loadCalls();
    }

    get isViewingAsOther() {
        return !!this.viewAsUserId;
    }

    handleStartRelate(event) {
        const id = event.target.dataset.id;
        this.calls = this.calls.map((c) =>
            c.id === id
                ? { ...c, isEditing: true }
                : { ...c, isEditing: false, showResults: false }
        );
        this.loadSuggestedMatters(id);
    }

    async loadSuggestedMatters(callId) {
        const call = this.calls.find((c) => c.id === callId);
        if (!call || !call.matchedContactId) {
            return;
        }

        this.calls = this.calls.map((c) =>
            c.id === callId ? { ...c, isLoadingSuggestions: true } : c
        );

        try {
            const suggestions = await getSuggestedMatters({ contactId: call.matchedContactId });
            this.calls = this.calls.map((c) =>
                c.id === callId
                    ? {
                          ...c,
                          suggestedMatters: suggestions.map((s) => ({ ...s, isSelected: false })),
                          isLoadingSuggestions: false,
                          showSuggestions: suggestions.length > 0
                      }
                    : c
            );
        } catch (e) {
            // Suggestions are a convenience, not a hard requirement — fail
            // quietly (still let the user search/relate manually) rather than
            // toasting an error for a background enhancement.
            this.calls = this.calls.map((c) =>
                c.id === callId ? { ...c, isLoadingSuggestions: false } : c
            );
        }
    }

    handlePickSuggestedMatter(event) {
        const callId = event.currentTarget.dataset.callId;
        const matterId = event.currentTarget.dataset.matterId;
        const matterName = event.currentTarget.dataset.matterName;

        // Pre-fill the search box and show it as the one result, letting the
        // user confirm via the same click-to-relate flow as a typed search —
        // never relate immediately from a suggestion click. Keep ALL
        // suggestion chips visible and re-clickable (multiple suggestions
        // are common — a client can have several matters, or a professional
        // can be opposing counsel on more than one) so the user can restage
        // a different suggestion as many times as they want before
        // confirming; just highlight which one is currently staged.
        this.calls = this.calls.map((c) =>
            c.id === callId
                ? {
                      ...c,
                      matterSearchTerm: matterName,
                      matterOptions: [{ id: matterId, name: matterName }],
                      showResults: true,
                      noResults: false,
                      suggestedMatters: c.suggestedMatters.map((s) => ({
                          ...s,
                          isSelected: s.id === matterId
                      }))
                  }
                : c
        );
    }

    handleCancelRelate(event) {
        const id = event.target.dataset.id;
        this.calls = this.calls.map((c) =>
            c.id === id
                ? {
                      ...c,
                      isEditing: false,
                      matterSearchTerm: '',
                      matterOptions: [],
                      showResults: false,
                      suggestedMatters: []
                  }
                : c
        );
    }

    handleMatterSearchChange(event) {
        const id = event.target.dataset.id;
        const term = event.target.value;

        // Typing a manual search invalidates whichever suggestion chip was
        // staged (if any) — clear the highlight so it doesn't misleadingly
        // suggest that suggestion is still what will get confirmed.
        this.calls = this.calls.map((c) =>
            c.id === id
                ? {
                      ...c,
                      matterSearchTerm: term,
                      suggestedMatters: c.suggestedMatters.map((s) => ({ ...s, isSelected: false }))
                  }
                : c
        );

        if (this.searchTimeouts[id]) {
            clearTimeout(this.searchTimeouts[id]);
        }
        this.searchTimeouts[id] = setTimeout(() => this.runSearch(id, term), SEARCH_DEBOUNCE_MS);
    }

    async runSearch(id, term) {
        if (!term || term.length < 2) {
            this.calls = this.calls.map((c) =>
                c.id === id ? { ...c, matterOptions: [], showResults: false, noResults: false } : c
            );
            return;
        }
        try {
            const results = await searchMatters({ searchTerm: term });
            this.calls = this.calls.map((c) =>
                c.id === id
                    ? {
                          ...c,
                          matterOptions: results,
                          showResults: true,
                          noResults: results.length === 0
                      }
                    : c
            );
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Search failed',
                    message: this.extractError(e),
                    variant: 'error'
                })
            );
        }
    }

    async handlePickMatter(event) {
        const callId = event.currentTarget.dataset.callId;
        const matterId = event.currentTarget.dataset.matterId;
        const matterName = event.currentTarget.dataset.matterName;

        try {
            await relateCallToMatter({
                relatedCallTranscriptId: callId,
                matterId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Related',
                    message: `Call related to ${matterName}.`,
                    variant: 'success'
                })
            );

            this.removeCallFromCurrentView(callId);
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not relate call',
                    message: this.extractError(e),
                    variant: 'error'
                })
            );
        }
    }

    async handleDismiss(event) {
        const callId = event.currentTarget.dataset.id;
        try {
            await dismissCall({ relatedCallTranscriptId: callId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Dismissed',
                    message: 'Call dismissed. Find it under "Dismissed" if you need to undo this.',
                    variant: 'success'
                })
            );
            this.removeCallFromCurrentView(callId);
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not dismiss call',
                    message: this.extractError(e),
                    variant: 'error'
                })
            );
        }
    }

    async handleRestore(event) {
        const callId = event.currentTarget.dataset.id;
        try {
            await undismissCall({ relatedCallTranscriptId: callId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Restored',
                    message: 'Call restored to the active list.',
                    variant: 'success'
                })
            );
            this.removeCallFromCurrentView(callId);
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not restore call',
                    message: this.extractError(e),
                    variant: 'error'
                })
            );
        }
    }

    // Remove the now-actioned call from the current page's list, and reflect
    // the drop in the total count so "Page X of Y" and the Next-arrow
    // disabled state stay accurate without a full reload — used by relate,
    // dismiss, and restore, since all three remove the row from whichever
    // view (active/dismissed) is currently showing.
    removeCallFromCurrentView(callId) {
        this.calls = this.calls.filter((c) => c.id !== callId);
        this.totalCount = Math.max(0, this.totalCount - 1);
    }

    extractError(e) {
        if (e && e.body && e.body.message) return e.body.message;
        if (e && e.message) return e.message;
        return 'Unknown error';
    }
}