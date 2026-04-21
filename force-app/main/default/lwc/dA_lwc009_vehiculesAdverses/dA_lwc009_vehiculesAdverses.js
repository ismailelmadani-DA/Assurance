import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent }                     from 'lightning/platformShowToastEvent';
import getVehiculesAdverses                   from '@salesforce/apex/DA_VehiculeAdverseController.getVehiculesAdverses';

export default class DA_lwc009_vehiculesAdverses extends LightningElement {

    @api recordId;

    @track vehicules = [];
    @track isLoading = true;

    // ── Getters ───────────────────────────────────────────────────────────
    get isEmpty() {
        return !this.isLoading && (!this.vehicules || this.vehicules.length === 0);
    }

    // ── Wire : données ────────────────────────────────────────────────────
    @wire(getVehiculesAdverses, { recordId: '$recordId' })
    wiredVehicules(result) {
        this.isLoading = false;

        if (result.data) {
            this.vehicules = result.data.map(v => ({
                ...v,
                nomVehicule     : v.Vehicule__r ? v.Vehicule__r.Name                  || '—' : '—',
                immatriculation : v.Vehicule__r ? v.Vehicule__r.RegistrationNumber__c || '—' : '—',
                marqueAffichee  : v.Vehicule__r ? v.Vehicule__r.Brand__c              || '—' : '—',
                etatBadgeClass  : v.EtatVehicule__c === 'Endommagé'
                    ? 'pm-state pm-state--blesse'
                    : v.EtatVehicule__c === 'Pas de dommage'
                    ? 'pm-state pm-state--indemne'
                    : 'pm-state pm-state--default'
            }));
        } else if (result.error) {
            this.showToast('Erreur', result.error.body?.message ?? 'Erreur inconnue', 'error');
        }
    }

    // ── Toast ─────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}