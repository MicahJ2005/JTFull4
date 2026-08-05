import { LightningElement, api, wire } from 'lwc';
// Importamos el método de la clase Apex que acabas de modificar
import getMemberDetails from '@salesforce/apex/TeamHubController.getMemberDetails';

export default class TeamMemberProfile extends LightningElement {
    @api recordId; // User ID
    @api contactId; // Contact ID of the logged-in client
    @api userRole; // Role from team assignment (passed from parent)
    @api userTitle; // Title from User object (passed from parent)
    member;
    error;
    isLoading = true;

    // Usamos el método Apex para saltarnos las reglas de visibilidad (Sharing Rules)
    @wire(getMemberDetails, { userId: '$recordId' })
    wiredUser({ error, data }) {
        this.isLoading = false;
        if (data) {
            // Apex devuelve el objeto simple, asignamos directamente
            this.member = {
                Id: data.Id,
                Name: data.Name,
                Email: data.Email,
                Title: data.Title,
                Hobbies: data.Hobbies__c,
                Hobbie2: data.Hobbie2__c,
                Hobby3: data.Hobby3__c,
                Hobby4: data.Hobby4__c,
                ClientStories: data.ClientStories__c,
                ClientStory2: data.ClientStory2__c,
                ClientName1: data.Client_Name_1__c,
                ClientName2: data.Client_Name_2__c,
                FunFact: data.FunFact__c,
                Strengths: data.Strengths__c,
                ProfilePic: data.ProfilePic__c,
                AboutMe: data.AboutMe,
                UserBio: data.UserBio__c,
                UserApproach: data.UserApproach__c,
                SOBookingPage: data.SO_Portal_Booking_Page__c
            };
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.member = null;
            console.error('Error fetching user data via Apex:', error);
            // CORREGIDO: Usamos this.recordId en lugar de $recordId
            console.log('USER ID:', this.recordId);
        }
    }

    // DYNAMIC TITLE LOGIC
    get displayTitle() {
        let displayTitle = 'Team Member'; // Default fallback

        // Priority 1: Use userTitle passed from parent
        if (this.userTitle && this.userTitle.trim() !== '') {
            displayTitle = this.userTitle;
        }
        // Priority 2: Use Title from the wire adapter
        else if (this.member && this.member.Title && this.member.Title.trim() !== '') {
            displayTitle = this.member.Title;
        }
        // Priority 3: Fallback to Role
        else if (this.userRole && this.userRole.trim() !== '') {
            displayTitle = this.userRole;
        }

        return displayTitle.toUpperCase();
    }

    renderedCallback() {
        // Render Bio content
        if (this.member && this.member.UserBio) {
            const bioDiv = this.template.querySelector('.bio-section .bio-content');
            if (bioDiv && !bioDiv.hasAttribute('data-rendered')) {
                const cleanHTML = this.sanitizeHTML(this.member.UserBio);
                bioDiv.innerHTML = cleanHTML;
                bioDiv.setAttribute('data-rendered', 'true');
            }
        }
        
        // Render Approach content
        if (this.member && this.member.UserApproach) {
            const approachDiv = this.template.querySelector('.approach-section .approach-content');
            if (approachDiv && !approachDiv.hasAttribute('data-rendered')) {
                const cleanHTML = this.sanitizeHTML(this.member.UserApproach);
                approachDiv.innerHTML = cleanHTML;
                approachDiv.setAttribute('data-rendered', 'true');
            }
        }
    }

    sanitizeHTML(htmlString) {
        if (!htmlString) return '';
        
        let cleaned = htmlString.replace(/<br\s*\/?>/gi, ' ');
        cleaned = cleaned.replace(/<p>/gi, '<p style="text-align: justify; margin: 0 0 1rem 0;">');
        cleaned = cleaned.replace(/<p\s+/gi, '<p style="text-align: justify; margin: 0 0 1rem 0;" ');
        
        return cleaned;
    }

    get hasMember() {
        return this.member !== null && this.member !== undefined;
    }

    get memberStrengths() {
        if (!this.member || !this.member.Strengths) {
            return [];
        }
        return this.member.Strengths.split(',').map(s => s.trim()).filter(s => s);
    }

    get memberHobbies() {
        if (!this.member) return [];
        const hobbies = [];
        if (this.member.Hobbies) hobbies.push(this.member.Hobbies);
        if (this.member.Hobbie2) hobbies.push(this.member.Hobbie2);
        if (this.member.Hobby3) hobbies.push(this.member.Hobby3);
        if (this.member.Hobby4) hobbies.push(this.member.Hobby4);
        return hobbies;
    }

    get hasHobbies() {
        return this.memberHobbies.length > 0;
    }

    get clientStories() {
        if (!this.member) return [];
        const stories = [];
        if (this.member.ClientStories) {
            stories.push({
                text: this.member.ClientStories,
                author: this.member.ClientName1 || 'Client'
            });
        }
        if (this.member.ClientStory2) {
            stories.push({
                text: this.member.ClientStory2,
                author: this.member.ClientName2 || 'Client'
            });
        }
        return stories;
    }

    get hasClientStories() {
        return this.clientStories.length > 0;
    }

    get profileImage() {
        return this.member?.ProfilePic || 'https://via.placeholder.com/300x400?text=No+Image';
    }

    handleBackToTeam() {
        const backEvent = new CustomEvent('backtoteam', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(backEvent);
    }
}