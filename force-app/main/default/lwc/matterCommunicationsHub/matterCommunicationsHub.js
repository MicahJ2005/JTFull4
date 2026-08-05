/**
 * matterCommunicationsHub.js
 *
 * Unified communications hub for Matter (AcctSeed__Project__c) records.
 * Displays emails, calls, texts, and Zoom meetings in a two-panel
 * thread-list + reading-pane layout, translated from the approved
 * Lovable prototype (github.com/chrisjt-dev/matter-communications-hub).
 *
 * Data source: MatterCommunicationsController.getCommunications()
 *              MatterCommunicationsController.getEmailBody()
 *
 * @org     Johnson Turner Legal
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import { deleteRecord }                 from 'lightning/uiRecordApi';
import getCommunications                from '@salesforce/apex/MatterCommunicationsController.getCommunications';
import getEmailBody                     from '@salesforce/apex/MatterCommunicationsController.getEmailBody';

// ── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE        = 50;
const SEARCH_DEBOUNCE  = 300;   // ms
const SKELETON_COUNT   = 6;
const MOBILE_BREAKPOINT = 768;  // px

// Avatar colours — matched exactly to Lovable hashColor palette
const AVATAR_COLORS = [
    '#1b96ff','#04844b','#c23934','#8b6db0',
    '#d47500','#2e844a','#0d6efd','#6610f2',
    '#0f7b5f','#9c5700'
];

// Speaker colours for transcripts — matched to Lovable SPEAKER_COLORS
const SPEAKER_COLORS = [
    '#0176d3','#8B5CF6','#D97706','#059669','#DC2626','#7C3AED'
];

// Type-specific avatar background colours
const TYPE_BG = {
    CALL:    '#2e844a',   // call-green
    TEXT:    '#d47500',   // text-orange
    MEETING: '#8b6db0'    // meeting-purple
};


// ── Helpers ──────────────────────────────────────────────────────────────────

function getInitials(name) {
    if (!name) return '?';
    return name.trim().split(/\s+/).map(w => w[0]).join('').toUpperCase().slice(0, 2);
}

function hashColor(name) {
    if (!name) return AVATAR_COLORS[0];
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
        hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

function formatDate(date) {
    if (!date) return '';
    const d   = date instanceof Date ? date : new Date(date);
    const now  = new Date();
    const diff = now - d;
    const day  = 86400000;

    if (diff < day && d.getDate() === now.getDate()) {
        return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    }
    const startOfWeek = new Date(now);
    startOfWeek.setDate(now.getDate() - now.getDay());
    startOfWeek.setHours(0, 0, 0, 0);
    if (d >= startOfWeek) {
        return d.toLocaleDateString('en-US', { weekday: 'long' });
    }
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function formatDateTime(date) {
    if (!date) return '';
    const d = date instanceof Date ? date : new Date(date);
    return d.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
}

function formatDuration(seconds) {
    if (!seconds) return '';
    const mins = Math.floor(seconds / 60);
    if (mins >= 60) {
        const hrs = Math.floor(mins / 60);
        const rem = mins % 60;
        return rem > 0 ? `${hrs}h ${rem}m` : `${hrs} hour${hrs > 1 ? 's' : ''}`;
    }
    return `${mins} minutes`;
}

function parseTranscript(text) {
    if (!text) return [];
    const lines      = text.split('\n').map(l => l.trim()).filter(Boolean);
    const speakerMap = new Map();
    let colorIdx     = 0;
    const result     = [];

    // Detect Format 2 — structured as "User: Name / text: body" pairs
    const isFormat2 = lines.some(l => /^User:/i.test(l));

    if (isFormat2) {
        let i = 0;
        while (i < lines.length) {
            const line = lines[i];
            if (/^User:/i.test(line)) {
                const speaker   = line.slice(line.indexOf(':') + 1).trim();
                const bodyParts = [];
                i++;
                // Collect all following "text:" lines until the next "User:" block
                while (i < lines.length && !/^User:/i.test(lines[i])) {
                    const bodyLine = lines[i];
                    if (/^text:/i.test(bodyLine)) {
                        bodyParts.push(bodyLine.slice(bodyLine.indexOf(':') + 1).trim());
                    }
                    i++;
                }
                const body = bodyParts.join(' ');
                if (!body) continue;
                if (!speakerMap.has(speaker)) {
                    speakerMap.set(speaker, SPEAKER_COLORS[colorIdx % SPEAKER_COLORS.length]);
                    colorIdx++;
                }
                const idx = result.length;
                result.push({
                    idx,
                    speaker,
                    text: body,
                    rowClass    : `t-row ${idx % 2 === 0 ? 't-row-even' : 't-row-odd'}`,
                    speakerStyle: `color: ${speakerMap.get(speaker)}`
                });
            } else {
                i++;
            }
        }
    } else {
        // Format 1 — "Name: spoken text" per line
        lines.forEach((line, idx) => {
            const colonIdx = line.indexOf(':');
            const speaker  = colonIdx !== -1 ? line.slice(0, colonIdx).trim() : '';
            const body     = colonIdx !== -1 ? line.slice(colonIdx + 1).trim() : line;
            if (speaker && !speakerMap.has(speaker)) {
                speakerMap.set(speaker, SPEAKER_COLORS[colorIdx % SPEAKER_COLORS.length]);
                colorIdx++;
            }
            result.push({
                idx,
                speaker,
                text: body,
                rowClass    : `t-row ${idx % 2 === 0 ? 't-row-even' : 't-row-odd'}`,
                speakerStyle: `color: ${speakerMap.get(speaker) || '#706e6b'}`
            });
        });
    }

    return result;
}


// ── Component ────────────────────────────────────────────────────────────────

export default class MatterCommunicationsHub extends LightningElement {

    @api recordId;  // AcctSeed__Project__c Id — injected by Lightning record page

    // ── State ────────────────────────────────────────────────────────────────
    @track _items          = [];      // flat CommItem[] from Apex
    @track threadGroups    = [];      // computed display groups
    @track selectedItem    = null;    // enriched item for reading pane
    @track isLoading       = true;
    @track hasMore         = false;
    @track showUnrelateModal = false;
    @track isMobile        = false;
    @track error           = null;

    // Filter/search state
    @track search   = '';
    @track filter   = 'ALL';
    @track dateFrom = '';
    @track dateTo   = '';

    // Counts for badges
    @track counts = { total: 0, EMAIL: 0, CALL: 0, TEXT: 0, MEETING: 0 };

    // Internals
    _searchTimer      = null;
    _pageOffset       = 0;
    _selectedKey      = null;
    _pendingUnrelateId = null;
    _hasAutoSelected  = false;


    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        this._checkMobile();
        window.addEventListener('resize', this._onResize.bind(this));
        this._load();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._onResize.bind(this));
        clearTimeout(this._searchTimer);
    }

    _onResize() {
        this._checkMobile();
    }

    _checkMobile() {
        this.isMobile = window.innerWidth < MOBILE_BREAKPOINT;
    }


    // ── Data Loading ──────────────────────────────────────────────────────────

    async _load(append = false) {
        if (!this.recordId) return;
        if (!append) {
            this.isLoading   = true;
            this._pageOffset = 0;
        }

        try {
            const result = await getCommunications({
                matterId   : this.recordId,
                filterType : this.filter,
                searchTerm : this.search  || null,
                dateFrom   : this.dateFrom || null,
                dateTo     : this.dateTo   || null,
                pageSize   : PAGE_SIZE,
                pageOffset : this._pageOffset
            });

            const incoming = (result.items || []).map(i => ({
                ...i,
                messageDate: i.messageDate ? new Date(i.messageDate) : null
            }));

            this._items  = append ? [...this._items, ...incoming] : incoming;
            this.hasMore = result.hasMore;
            this.counts  = result.counts || { total: 0, EMAIL: 0, CALL: 0, TEXT: 0, MEETING: 0 };
            this.error   = null;

            this._buildGroups();

            // Auto-select first item on initial load
            if (!this._hasAutoSelected && this.threadGroups.length > 0) {
                this._selectGroup(this.threadGroups[0]);
                this._hasAutoSelected = true;
            }

        } catch (e) {
            this.error = e?.body?.message || e?.message || 'Unknown error';
        } finally {
            this.isLoading = false;
        }
    }


    // ── Thread Group Builder ──────────────────────────────────────────────────

    _buildGroups() {
        const threadMap = new Map();
        const standalone = [];

        for (const item of this._items) {
            if (item.commType === 'EMAIL' && item.threadId) {
                const bucket = threadMap.get(item.threadId) || [];
                bucket.push(item);
                threadMap.set(item.threadId, bucket);
            } else {
                standalone.push(item);
            }
        }

        const groups = [];

        // Email threads
        for (const [threadId, msgs] of threadMap) {
            msgs.sort((a, b) => (b.messageDate || 0) - (a.messageDate || 0));
            const latest = msgs[0];
            groups.push(this._buildGroup(threadId, latest, msgs));
        }

        // Standalone items (calls, texts, meetings, single emails)
        for (const item of standalone) {
            groups.push(this._buildGroup(item.recordId, item, [item]));
        }

        // Sort descending by latest date
        groups.sort((a, b) => {
            const da = a._date || 0;
            const db = b._date || 0;
            return db - da;
        });

        this.threadGroups = groups;
    }

    _buildGroup(key, latest, allItems) {
        const type      = latest.commType;
        const isEmail   = type === 'EMAIL';
        const isCall    = type === 'CALL';
        const isText    = type === 'TEXT';
        const isMeeting = type === 'MEETING';
        const selected  = this._selectedKey === key;

        // Avatar
        let avatarClass = 'thread-avatar';
        let avatarStyle = '';
        if (isEmail) {
            avatarStyle = `background-color: ${hashColor(latest.fromName)}`;
        } else {
            avatarStyle = `background-color: ${TYPE_BG[type]}`;
        }

        // Direction dot
        const dotClass = latest.isIncoming ? 'direction-dot dot-in' : 'direction-dot dot-out';

        // Thread count
        const threadCount = allItems.length;

        return {
            key,
            _date      : latest.messageDate,
            isEmail, isCall, isText, isMeeting,
            fromName   : latest.fromName,
            subject    : latest.subject,
            bodyPreview: (latest.bodyPreview || '').slice(0, 120),
            displayDate: formatDate(latest.messageDate),
            initials   : getInitials(latest.fromName),
            avatarClass,
            avatarStyle,
            dotClass,
            rowClass   : `thread-row${selected ? ' thread-row--selected' : ''}`,
            hasAttachment  : allItems.some(m => m.hasAttachment),
            showThreadCount: threadCount > 1,
            threadCountLabel: `${threadCount} messages`,
            _latest    : latest,
            _allItems  : allItems
        };
    }


    // ── Selection ─────────────────────────────────────────────────────────────

    _selectGroup(grp) {
        this._selectedKey = grp.key;
        this._buildGroups(); // re-render selection state

        const latest = grp._latest;
        const type   = latest.commType;

        const base = {
            key     : grp.key,
            subject : latest.subject,
            isEmail : type === 'EMAIL',
            isCall  : type === 'CALL',
            isText  : type === 'TEXT',
            isMeeting: type === 'MEETING',
            junctionId    : latest.junctionId,
            recordUrl     : '/' + latest.recordId,
            displayDateTime: formatDateTime(latest.messageDate),
            durationLabel : formatDuration(latest.durationSeconds)
        };

        if (type === 'EMAIL') {
            // Build mailto hrefs
            base.replyHref    = `mailto:${latest.fromAddress}?subject=RE: ${encodeURIComponent(latest.subject || '')}`;
            base.replyAllHref = `mailto:${latest.fromAddress},${latest.toAddress || ''}${latest.ccAddress ? ',' + latest.ccAddress : ''}?subject=RE: ${encodeURIComponent(latest.subject || '')}`;
            base.forwardHref  = `mailto:?subject=FW: ${encodeURIComponent(latest.subject || '')}`;

            // Build email cards — bodies loaded on demand
            base.emailCards = grp._allItems.map(em => ({
                id            : em.recordId,
                fromName      : em.fromName,
                fromAddress   : em.fromAddress,
                toAddress     : em.toAddress,
                ccAddress     : em.ccAddress,
                displayDateTime: formatDateTime(em.messageDate),
                initials      : getInitials(em.fromName),
                avatarStyle   : `background-color: ${hashColor(em.fromName)}`,
                htmlBody      : em.htmlBody  || null,
                textBody      : em.textBody  || null,
                isLoadingBody : !em.htmlBody && !em.textBody
            }));

            this.selectedItem = base;

            // Kick off body loading for cards that need it
            base.emailCards.forEach((card, idx) => {
                if (card.isLoadingBody) {
                    this._loadEmailBody(card.id, idx);
                }
            });

        } else if (type === 'CALL' || type === 'MEETING') {
            base.transcriptLines = parseTranscript(latest.transcriptBody || latest.textBody || '');
            this.selectedItem = base;

        } else if (type === 'TEXT') {
            base.textMessages = (latest.textMessages || []).map(msg => ({
                id           : msg.id,
                fromName     : msg.fromName,
                time         : msg.sentTime,
                body         : msg.body,
                bubbleRowClass: `bubble-row ${msg.incoming ? 'bubble-row-in' : 'bubble-row-out'}`,
                bubbleClass  : `bubble ${msg.incoming ? 'bubble-in' : 'bubble-out'}`
            }));
            this.selectedItem = base;
        }
    }

    async _loadEmailBody(emailId, cardIdx) {
        try {
            const full = await getEmailBody({ emailMessageId: emailId });
            // Immutably update the specific card
            const updatedCards = this.selectedItem.emailCards.map((c, i) =>
                i === cardIdx
                    ? { ...c, htmlBody: full.htmlBody, textBody: full.textBody, isLoadingBody: false }
                    : c
            );
            this.selectedItem = { ...this.selectedItem, emailCards: updatedCards };
        } catch (e) {
            const updatedCards = this.selectedItem.emailCards.map((c, i) =>
                i === cardIdx ? { ...c, isLoadingBody: false } : c
            );
            this.selectedItem = { ...this.selectedItem, emailCards: updatedCards };
        }
    }


    // ── Event Handlers ────────────────────────────────────────────────────────

    handleSearchInput(evt) {
        this.search = evt.target.value;
        clearTimeout(this._searchTimer);
        this._searchTimer = setTimeout(() => {
            this._selectedKey = null;
            this.selectedItem = null;
            this._hasAutoSelected = false;
            this._load();
        }, SEARCH_DEBOUNCE);
    }

    clearSearch() {
        this.search = '';
        this._selectedKey = null;
        this.selectedItem = null;
        this._hasAutoSelected = false;
        this._load();
    }

    handleFilterClick(evt) {
        const val = evt.currentTarget.dataset.value;
        if (val === this.filter) return;
        this.filter = val;
        this._selectedKey = null;
        this.selectedItem = null;
        this._hasAutoSelected = false;
        this._load();
    }

    handleDateFromChange(evt) {
        this.dateFrom = evt.target.value || '';
        this._selectedKey = null;
        this.selectedItem = null;
        this._hasAutoSelected = false;
        this._load();
    }

    handleDateToChange(evt) {
        this.dateTo = evt.target.value || '';
        this._selectedKey = null;
        this.selectedItem = null;
        this._hasAutoSelected = false;
        this._load();
    }

    clearDateFrom() {
        this.dateFrom = '';
        this._load();
    }

    clearDateTo() {
        this.dateTo = '';
        this._load();
    }

    handleThreadClick(evt) {
        const key = evt.currentTarget.dataset.key;
        const grp = this.threadGroups.find(g => g.key === key);
        if (!grp) return;
        this._selectGroup(grp);
    }

    handleBack() {
        this.selectedItem = null;
        this._selectedKey = null;
        this._buildGroups();
    }

    handleLoadMore() {
        this._pageOffset += PAGE_SIZE;
        this._load(true);
    }

    handleUnrelateClick() {
        if (!this.selectedItem?.junctionId) return;
        this._pendingUnrelateId = this.selectedItem.junctionId;
        this.showUnrelateModal  = true;
    }

    cancelUnrelate() {
        this.showUnrelateModal  = false;
        this._pendingUnrelateId = null;
    }

    async confirmUnrelate() {
        this.showUnrelateModal = false;
        try {
            await deleteRecord(this._pendingUnrelateId);
            this.dispatchEvent(new ShowToastEvent({
                title  : 'Done',
                message: 'Email unrelated from this matter.',
                variant: 'success'
            }));
            this.selectedItem      = null;
            this._selectedKey      = null;
            this._pendingUnrelateId = null;
            this._load();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title  : 'Error',
                message: e?.body?.message || e?.message || 'Could not unrelate.',
                variant: 'error'
            }));
        }
    }


    // ── Computed Properties ───────────────────────────────────────────────────

    get filterOptions() {
        const filters = [
            { value: 'ALL',     label: 'All'       },
            { value: 'EMAIL',   label: '✉ Email'   },
            { value: 'CALL',    label: '📞 Calls'   },
            { value: 'TEXT',    label: '💬 Texts'   },
            { value: 'MEETING', label: '🎥 Meetings' }
        ];
        return filters.map(f => ({
            ...f,
            cssClass: `filter-chip${this.filter === f.value ? ' chip-active' : ''}`
        }));
    }

    get skeletonRows() {
        return Array.from({ length: SKELETON_COUNT }, (_, i) => i);
    }

    get isEmpty() {
        return !this.isLoading && this.threadGroups.length === 0;
    }

    get threadListClass() {
        if (this.isMobile) {
            return this.selectedItem ? 'thread-list thread-list--hidden' : 'thread-list';
        }
        return 'thread-list';
    }

    get readingPaneClass() {
        if (this.isMobile) {
            return this.selectedItem ? 'reading-pane' : 'reading-pane reading-pane--hidden';
        }
        return 'reading-pane';
    }
}