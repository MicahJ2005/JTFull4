import { LightningElement, api } from 'lwc';

export default class NextStepNameCell extends LightningElement {
    @api value;
    @api level = 0;
    @api isTask = false;

    get indentStyle() {
        // 1.5rem per hierarchy level; leaf Tasks get a little extra.
        const base = Number(this.level || 0) * 1.5;
        return `padding-left:${base}rem;`;
    }

    get isCase() {
        return !this.isTask;
    }
}