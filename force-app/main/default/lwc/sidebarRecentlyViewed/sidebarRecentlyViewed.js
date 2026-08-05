import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SidebarRecentlyViewed extends NavigationMixin(LightningElement) {
    @api title;
    @api itemName;
    @api destinationUrl;

    handleNavigate() {
        if (this.destinationUrl) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: this.destinationUrl
                }
            });
        }
    }
}