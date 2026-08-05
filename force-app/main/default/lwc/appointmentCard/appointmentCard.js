import { LightningElement, api, track } from 'lwc';

export default class AppointmentCard extends LightningElement {
    @api appt;
    @track showNotes = false;

    get isPast() { return this.appt && this.appt.isPast; }
    get hasNotes() { return !!(this.appt && this.appt.summaryNotes); }
    get hasLocation() { return !!(this.appt && this.appt.location); }
    get hasWith() { return !!(this.appt && this.appt.withWho); }

    toggleNotes() { this.showNotes = !this.showNotes; }

    downloadIcs() {
        const a = this.appt;
        if (!a) return;
        const lines = [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//Johnson Turner//Client Portal//EN',
            'BEGIN:VEVENT',
            `UID:${a.id}@johnsonturner`,
            a.icsStart ? `DTSTAMP:${a.icsStart}` : '',
            a.icsStart ? `DTSTART:${a.icsStart}` : '',
            a.icsEnd ? `DTEND:${a.icsEnd}` : '',
            `SUMMARY:${this.escapeIcs(a.subject || 'Appointment')}`,
            a.location ? `LOCATION:${this.escapeIcs(a.location)}` : '',
            'END:VEVENT',
            'END:VCALENDAR'
        ].filter(Boolean).join('\r\n');

        const blob = new Blob([lines], { type: 'text/calendar;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${(a.subject || 'event').replace(/\s+/g, '_')}.ics`;
        link.click();
        URL.revokeObjectURL(url);
    }

    escapeIcs(s) {
        return String(s).replace(/\\/g, '\\\\').replace(/([,;])/g, '\\$1').replace(/\n/g, '\\n');
    }
}