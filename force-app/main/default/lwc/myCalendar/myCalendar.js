import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMyAppointments from '@salesforce/apex/myCalendarController.getMyAppointments';

const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

export default class myCalendar extends NavigationMixin(LightningElement) {
    // Configurable from Experience Builder
    @api contactPageName = 'Contact_My_Team__c';
    @api scheduleText = 'Need to schedule something? Reach out and your team will help you find a time that works.';

    @track data;
    @track viewYear;
    @track viewMonth;          // 0-11
    @track selectedDateKey;

    connectedCallback() {
        const now = new Date();
        this.viewYear = now.getFullYear();
        this.viewMonth = now.getMonth();
    }

    @wire(getMyAppointments)
    wired({ data, error }) {
        if (data) this.data = data;
        else if (error) console.error('Calendar error:', error);
    }

    // ---------- grouped lists ----------
    get next14() { return this.data ? this.data.next14 : []; }
    get future() { return this.data ? this.data.future : []; }
    get past() { return this.data ? this.data.past : []; }
    get hasNext14() { return this.next14.length > 0; }
    get hasFuture() { return this.future.length > 0; }
    get hasPast() { return this.past.length > 0; }
    get hasAny() { return this.hasNext14 || this.hasFuture || this.hasPast; }

    get apptDaySet() {
        return new Set(this.data ? this.data.daysWithAppts : []);
    }

    get allByDate() {
        const map = {};
        if (this.data) {
            [...this.data.next14, ...this.data.future, ...this.data.past].forEach((a) => {
                if (!a.dateKey) return;
                if (!map[a.dateKey]) map[a.dateKey] = [];
                map[a.dateKey].push(a);
            });
        }
        return map;
    }

    // ---------- calendar header ----------
    get monthLabel() {
        return new Date(this.viewYear, this.viewMonth, 1)
            .toLocaleString('en-US', { month: 'long', year: 'numeric' })
            .toUpperCase();
    }
    get weekdayHeaders() {
        return WEEKDAYS.map((d, i) => ({ key: i, label: d }));
    }

    // ---------- calendar grid ----------
    get weeks() {
        const year = this.viewYear;
        const month = this.viewMonth;
        const apptDays = this.apptDaySet;
        const todayKey = this.toKey(new Date());
        const startDow = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrev = new Date(year, month, 0).getDate();

        const cells = [];
        for (let i = startDow - 1; i >= 0; i--) {
            cells.push(this.makeCell(year, month - 1, daysInPrev - i, false, apptDays, todayKey));
        }
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push(this.makeCell(year, month, d, true, apptDays, todayKey));
        }
        let nxt = 1;
        while (cells.length % 7 !== 0) {
            cells.push(this.makeCell(year, month + 1, nxt++, false, apptDays, todayKey));
        }

        const weeks = [];
        for (let i = 0; i < cells.length; i += 7) {
            weeks.push({ id: i, days: cells.slice(i, i + 7) });
        }
        return weeks;
    }

    makeCell(year, month, day, inMonth, apptDays, todayKey) {
        const dt = new Date(year, month, day);
        const key = this.toKey(dt);
        const hasAppt = apptDays.has(key);
        let cls = 'cal-day';
        if (!inMonth) cls += ' cal-out';
        if (hasAppt) cls += ' cal-has';
        if (key === todayKey) cls += ' cal-today';
        if (key === this.selectedDateKey) cls += ' cal-selected';
        return { key, day, hasAppt, cssClass: cls };
    }

    toKey(dt) {
        return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;
    }

    // ---------- selected day ----------
    get selectedAppts() {
        return this.selectedDateKey ? (this.allByDate[this.selectedDateKey] || []) : [];
    }
    get hasSelected() { return this.selectedAppts.length > 0; }

    // ---------- handlers ----------
    handlePrevMonth() {
        if (this.viewMonth === 0) { this.viewMonth = 11; this.viewYear -= 1; }
        else { this.viewMonth -= 1; }
    }
    handleNextMonth() {
        if (this.viewMonth === 11) { this.viewMonth = 0; this.viewYear += 1; }
        else { this.viewMonth += 1; }
    }
    handleDayClick(event) {
        const key = event.currentTarget.dataset.key;
        if (this.apptDaySet.has(key)) {
            this.selectedDateKey = (this.selectedDateKey === key) ? null : key;
        }
    }
    handleContactTeam() {
        if (!this.contactPageName) return;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.contactPageName }
        });
    }
}