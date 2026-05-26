import { LightningElement, api } from 'lwc';

export default class GarantieRow extends LightningElement {

    @api garantie;

    get isTouched() {
        return this.garantie && this.garantie.touchee === true;
    }

    get rowClass() {
        let classes = 'row';
        
        if (this.garantie?.isRC) {
            classes += ' row-rc';
        }
        
        if (this.isTouched) {
            classes += ' row-touched';
        }
        
        return classes;
    }
}