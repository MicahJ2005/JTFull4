import { LightningElement, api } from 'lwc';
// Add an image static resource named 'ericPhoto' in your org and import it here
import ERIC_PHOTO from '@salesforce/resourceUrl/ericPhoto';


export default class EricProfile extends LightningElement {
@api name = 'Eric Parker';
@api title = 'Partner, Attorney & Family Law Mediator';


photoUrl = ERIC_PHOTO;


bio = `Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat.`;
approach = `Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis autem vel eum iriure dolor in hendrerit.`;


strengths = [
{ label: 'Advocacy', level: 4 },
{ label: 'Administration', level: 3 },
{ label: 'Discipline', level: 3 },
{ label: 'Responsibility', level: 2 },
{ label: 'Empathy', level: 1 }
];


// helper getter to produce arrays for rendering dots
get strengthList() {
return this.strengths;
}


// expose levelArray on each strength for the template
get strengths() {
// map to include levelArray used by template
return [
{ label: 'Advocacy', levelArray: this._levelArray(4) },
{ label: 'Administration', levelArray: this._levelArray(3) },
{ label: 'Discipline', levelArray: this._levelArray(3) },
{ label: 'Responsibility', levelArray: this._levelArray(2) },
{ label: 'Empathy', levelArray: this._levelArray(1) }
];
}


hobbies = [
'Playing hockey with my kids',
'Watching football with family and/or friends (SKOL Vikes!)',
'Hiking',
'Home renovations'
];


clientStories = [
{ author: 'Lucas T.', text: 'They came alongside me in the most difficult time in my life and helped me to calm down.' },
{ author: 'Bre', text: 'They are not only helpful with my divorce, but child custody, and parenting time.' }
];


_levelArray(level) {
    const arr = [];
    for (let i = 0; i < 5; i++) {
        arr.push({ class: i < level ? 'dot filled' : 'dot' });
    }
    return arr;
}


handleBack() {
// implement navigation logic if needed
const evt = new CustomEvent('back');
this.dispatchEvent(evt);
}
}