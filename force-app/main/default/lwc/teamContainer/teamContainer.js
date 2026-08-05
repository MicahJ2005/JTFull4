import { LightningElement, api } from 'lwc';

export default class TeamContainer extends LightningElement {
    @api recordId; // Project ID
    selectedUserId = null;
    showGrid = true;

    // Handle when user clicks "View Profile" from the grid
    handleViewProfile(event) {
        this.selectedUserId = event.detail.userId;
        this.showGrid = false;
    }

    // Handle when user clicks "Back to Team" from profile
    handleBackToTeam() {
        this.selectedUserId = null;
        this.showGrid = true;
    }

    get showProfileView() {
        return !this.showGrid && this.selectedUserId;
    }
}