import { LightningElement, api, wire, track } from 'lwc';
import getGaranties from '@salesforce/apex/DA_GarantiesSinistreController.getGaranties';

export default class SinistreGaranties extends LightningElement {
    @api recordId;

    @track garanties = [];
    @track isLoading = true;
    @track error;

    @wire(getGaranties, { sinistreId: '$recordId' })
    wiredGaranties({ data, error }) {
        if (data) {
            this.garanties = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Erreur lors du chargement des garanties.';
            this.garanties = [];
        }
        this.isLoading = false;
    }

    get nombreTouchees() {
        return this.garanties.filter(g => g.touchee).length;
    }

    get hasGaranties() {
        return this.garanties.length > 0;
    }

    get hasError() {
        return !!this.error;
    }
}