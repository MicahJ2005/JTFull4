import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SidebarCard extends NavigationMixin(LightningElement) {
    @api title;           // Ej: Client Questionnaire
    @api iconName;        // Ej: standard:question_feed
    @api variant;         // 'button' o 'text'
    @api imageUrl;
    @api buttonLabel;     // Ej: Fill Out Questionnaire
    @api subtitle;        // Ej: 3 Upcoming Appointments
    @api accentColor;     // Ej: #F2994A (Naranja) o #2F80ED (Azul)
    @api destinationUrl;  // URL (interna relativa o externa https) al hacer clic

    // --- Navegacion flexible (retrocompatible) ---
    @api pageApiName;            // Si se setea, navega a una pagina del site por su API Name
    @api openInNewTab = false;   // Para links externos (questionnaire, Box)

    get isButtonVariant() {
        return this.variant === 'button';
    }

    // Aplica el color de acento al subtitle por JS (evita style inline en el HTML)
    renderedCallback() {
        const el = this.refs ? this.refs.subtitleEl : null;
        if (el) {
            el.style.color = this.accentColor || '#333';
        }
    }

    handleNavigate() {
        // 1) Pagina interna del site por API Name (mas robusto: no depende de la URL)
        if (this.pageApiName) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: this.pageApiName }
            });
            return;
        }

        // 2) URL (interna relativa o externa)
        if (this.destinationUrl) {
            if (this.openInNewTab) {
                window.open(this.destinationUrl, '_blank');
                return;
            }
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: this.destinationUrl }
            });
        }
    }
}