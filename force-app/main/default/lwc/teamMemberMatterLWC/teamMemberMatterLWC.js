import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTeamMatter from '@salesforce/apex/TeamHubController.getAssigneesByRecord';
import getProjectName from '@salesforce/apex/TeamHubController.getProjectName';
import getContactIdFromProject from '@salesforce/apex/TeamHubController.getContactIdFromProject';
import createCaseForTeam from '@salesforce/apex/TeamHubController.createCaseForTeam';
import getBillingAttorneyId from '@salesforce/apex/TeamHubController.getBillingAttorneyId';

export default class TeamMemberMatterLWC extends NavigationMixin(LightningElement) {
  @api recordId;
  @track teamMembers = [];
  @track error;
  @track isLoading = true;
  @track selectedUserId = null;
  @track selectedUserBookingPage = null;
  @track showGrid = true;
  @track contactId = null;
  @track showPhoneDropdown = false;
  @track matterName = 'General';
  @track billingAttorneyId = null;

  // Case Modal properties
  @track showCaseModal = false;
  @track caseSubject = '';
  @track caseDescription = '';
  @track isCreatingCase = false;

  @wire(getContactIdFromProject, { recordId: '$recordId' })
  wiredContactId({ error, data }) {
    if (data) {
      this.contactId = data;
    } else if (error) {
      console.error('Error loading contact ID:', error);
    }
  }

  @wire(getProjectName, { recordId: '$recordId' })
  wiredProjectName({ error, data }) {
    if (data) {
      this.matterName = data;
      console.log('Matter name loaded:', this.matterName);
    } else if (error) {
      console.error('Error loading project name:', error);
      this.matterName = 'General';
    }
  }

  @wire(getBillingAttorneyId, { recordId: '$recordId' })
wiredBillingAttorney({ error, data }) {
  if (data) {
    this.billingAttorneyId = data;
    console.log('Billing Attorney ID loaded:', this.billingAttorneyId);
  } else if (error) {
    console.error('Error loading billing attorney ID:', error);
    this.billingAttorneyId = null;
  }
}

  @wire(getTeamMatter, { recordId: '$recordId' })
  wiredTeamMembers({ error, data }) {
    this.isLoading = false;
    if (data) {
      console.log('=== TEAM MEMBERS DEBUG ===');
      console.log('Raw data from Apex:', JSON.stringify(data, null, 2));
      console.log('Number of members:', data.length);

      // Log each member's Title field specifically
      data.forEach((member, index) => {
        console.log(`Member ${index + 1}:`, member.Name);
        console.log(`  - Title field:`, member.Title);
        console.log(`  - Title type:`, typeof member.Title);
        console.log(`  - Title is null?`, member.Title === null);
        console.log(`  - Title is undefined?`, member.Title === undefined);
        console.log(`  - Role:`, member.Role);
        console.log(`  - Billing_Attorney_LU__c:`, member.Billing_Attorney_LU__c);
      });

      this.teamMembers = data;
      this.error = undefined;
      console.log('Team members loaded:', this.teamMembers.length);
      console.log('CSS Phone:', this.cssPhone);
      console.log('=========================');
    } else if (error) {
      this.error = error;
      this.teamMembers = [];
      console.error('Error loading team members:', error);
    }
  }

  // Getter reactivo que se actualiza cuando matterName o teamMembers cambian
  get teamsByMatter() {
    if (this.teamMembers && this.teamMembers.length > 0) {
      // Add displayTitle with robust fallback logic
      const membersWithDisplayTitle = this.teamMembers.map(member => {
        let displayTitle = 'Team Member'; // Default fallback

        // Check Title field first
        if (member.Title && member.Title.trim() !== '') {
          displayTitle = member.Title;
        }
        // Fallback to Role if Title is empty
        else if (member.Role && member.Role.trim() !== '') {
          displayTitle = member.Role;
        }

        console.log(`Display title for ${member.Name}: "${displayTitle}" (from ${member.Title ? 'Title' : 'Role'})`);

        return {
          ...member,
          displayTitle: displayTitle
        };
      });

      return [{
        id: 'matter_1',
        title: `My Team for Matter: ${this.matterName}`,
        members: membersWithDisplayTitle,
        isExpanded: true
      }];
    }
    return [];
  }

  get hasTeams() {
    return this.teamMembers && this.teamMembers.length > 0;
  }

  // NEW: Get CSS (Client Support Specialist) or Paralegal member with fallback
  get cssMember() {
    if (!this.hasTeams) return null;

    // First try to find CSS
    const css = this.teamMembers.find(member => member.Role === 'CSS');
    if (css) return css;

    // If no CSS, try to find Paralegal (note: Role is 'Paralegal', not 'Paralegal LU')
    const paralegal = this.teamMembers.find(member => member.Role === 'Paralegal');
    return paralegal || null;
  }

  // NEW: Get the role type of the current support member
  get supportMemberRole() {
    if (!this.cssMember) return null;
    return this.cssMember.Role;
  }

  // NEW: Check if the support member is CSS
  get isSupportCSS() {
    return this.supportMemberRole === 'CSS';
  }

  // NEW: Check if the support member is Paralegal
  get isSupportParalegal() {
    return this.supportMemberRole === 'Paralegal';
  }

  // NEW: Get CSS phone number specifically
  get cssPhone() {
    if (this.cssMember && this.cssMember.Phone) {
      return this.cssMember.Phone;
    }
    return null;
  }

  // UPDATED: Use CSS phone instead of primary phone
  get primaryPhone() {
    return this.cssPhone;
  }

  get hasPhoneNumber() {
    return this.primaryPhone !== null;
  }

  get formattedPhone() {
    return this.primaryPhone || 'No phone available';
  }

  get chevronIconName() {
    return this.showPhoneDropdown ? 'utility:chevronup' : 'utility:chevrondown';
  }

  // Get CSS or Paralegal name for display
  get cssName() {
    if (!this.cssMember) return 'Support Contact';

    if (this.isSupportCSS) {
      return this.cssMember.Name;
    } else if (this.isSupportParalegal) {
      return this.cssMember.Name;
    }

    return this.cssMember.Name;
  }

  get primaryBookingPage() {
    if (!this.hasTeams) return null;

    for (const member of this.teamMembers) {
      if (member.SOBookingPage) {
        return member.SOBookingPage;
      }
    }
    return null;
  }

  get matterTitle() {
    return this.matterName || 'My Matter';
  }

  get showProfileView() {
    return !this.showGrid && this.selectedUserId;
  }

get hasBillingAttorney() {
  const hasBillingAttorney = this.billingAttorneyId && 
                             this.billingAttorneyId !== null && 
                             this.billingAttorneyId !== '';
  
  console.log('Has Billing Attorney assigned?', hasBillingAttorney);
  console.log('Billing Attorney ID:', this.billingAttorneyId);
  
  return hasBillingAttorney;
}

  handleToggleSection(event) {
    const matterId = event.currentTarget.dataset.matterId;
    this.isLoading = false;
  }

  handleViewProfile(event) {
    const userId = event.currentTarget.dataset.userId;
    this.selectedUserId = userId;
    this.showGrid = false;
  }

  handleBackToTeam() {
    this.selectedUserId = null;
    this.showGrid = true;
  }

  togglePhoneDropdown() {
    this.showPhoneDropdown = !this.showPhoneDropdown;
  }

  handleScheduleCall() {
    const bookingPage = this.primaryBookingPage;

    if (!bookingPage) {
      this.showToast(
        'Booking Page Not Available',
        'There is no booking page configured for your team.',
        'warning'
      );
      return;
    }

    let scheduleUrl = bookingPage;
    if (this.contactId) {
      scheduleUrl = `${bookingPage}?sosfContactId=${this.contactId}`;
    }

    window.open(scheduleUrl, '_blank');

    this.showToast(
      'Opening Booking Page',
      'Schedule a call with your attorney',
      'success'
    );
  }

  handleOpenCaseModal() {
    // Check if CSS or Paralegal exists before opening modal
    if (!this.cssMember) {
      this.showToast(
        'Support Contact Not Found',
        'There is no CSS or Paralegal assigned to this matter. Please contact your administrator.',
        'error'
      );
      return;
    }

    this.showCaseModal = true;
    this.caseSubject = `Question regarding: ${this.matterTitle}`;
  }

  handleCloseCaseModal() {
    this.showCaseModal = false;
    this.caseSubject = '';
    this.caseDescription = '';
  }

  handleSubjectChange(event) {
    this.caseSubject = event.target.value;
  }

  handleDescriptionChange(event) {
    this.caseDescription = event.target.value;
  }

  handleCreateCase() {
    // Validate fields
    if (!this.caseSubject || !this.caseDescription) {
      this.showToast(
        'Required Fields Missing',
        'Please fill in both Subject and Description fields.',
        'error'
      );
      return;
    }

    // Validate CSS or Paralegal exists
    if (!this.cssMember) {
      this.showToast(
        'Support Contact Not Found',
        'Cannot send message: No CSS or Paralegal assigned to this matter.',
        'error'
      );
      return;
    }

    this.isCreatingCase = true;

    createCaseForTeam({
      recordId: this.recordId,
      subject: this.caseSubject,
      description: this.caseDescription
    })
      .then(caseId => {
        this.showToast(
          'Success',
          `Message sent successfully and assigned to ${this.cssName}!`,
          'success'
        );

        this.handleCloseCaseModal();

        // Navigate to the created case
        this[NavigationMixin.Navigate]({
          type: 'standard__recordPage',
          attributes: {
            recordId: caseId,
            objectApiName: 'Case',
            actionName: 'view'
          }
        });
      })
      .catch(error => {
        console.error('Error sending message:', error);
        let errorMessage = 'An error occurred while creating the case. Please try again.';

        if (error.body && error.body.message) {
          errorMessage = error.body.message;
        }

        this.showToast(
          'Error sending message',
          errorMessage,
          'error'
        );
      })
      .finally(() => {
        this.isCreatingCase = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}