import { LightningElement, api } from 'lwc';

export default class SidebarResources extends LightningElement {
    @api title;
    @api blogUrl;
    @api videoUrl;
    @api consultUrl;
    @api welcomeUrl;
}