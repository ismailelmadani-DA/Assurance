import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm'; // Popup confirm natif
import AdverseVehicleFormModal from 'c/adverseVehicleFormModal'; // Import modal
import getAdverseVehicles from '@salesforce/apex/VehiculeAdversesController.getAdverseVehicles';
import deleteAdverseVehicle from '@salesforce/apex/VehiculeAdversesController.deleteAdverseVehicle';

const ETAT_CLASS_MAP = {
    'Intact':    'badge badge-green',
    'Endommagé': 'badge badge-orange',
    'Épave':     'badge badge-red',
    'Inconnu':   'badge badge-gray'
};

export default class AdverseVehicleList extends NavigationMixin(LightningElement) {

    @api recordId;

    @track vehicles     = [];
    @track isLoading    = true;
    @track hasError     = false;
    @track errorMessage = '';

    _wiredResult;

    // ── Wire ──────────────────────────────────────────────────────────────
    @wire(getAdverseVehicles, { claimId: '$recordId' })
    wiredVehicles(result) {
        this._wiredResult = result;
        this.isLoading    = false;
        if (result.data) {
            this.vehicles   = result.data.map(v => this._enrich(v));
            this.hasError   = false;
        } else if (result.error) {
            this.hasError    = true;
            this.errorMessage = result.error?.body?.message || 'Erreur de chargement.';
        }
    }

    _enrich(v) {
        return { ...v, etatBadgeClass: ETAT_CLASS_MAP[v.EtatVehicule__c] || 'badge badge-gray' };
    }

    get hasVehicles() { return !this.isLoading && !this.hasError && this.vehicles.length > 0; }
    get isEmpty()     { return !this.isLoading && !this.hasError && this.vehicles.length === 0; }

    // ── Ouvrir popup AJOUT ────────────────────────────────────────────────
    async openAddModal() {
        const result = await AdverseVehicleFormModal.open({
            size:    'medium',
            claimId: this.recordId,
            record:  undefined
        });
        if (result === 'saved') {
            await refreshApex(this._wiredResult);
        }
    }

    // ── Ouvrir popup MODIFICATION ─────────────────────────────────────────
    async openEditModal(event) {
        const id    = event.currentTarget.dataset.id;
        const found = this.vehicles.find(v => v.Id === id);
        if (!found) return;

        // Retirer la propriété calculée avant de passer au modal
        const { etatBadgeClass, ...rawRecord } = found;

        const result = await AdverseVehicleFormModal.open({
            size:    'medium',
            claimId: this.recordId,
            record:  rawRecord
        });
        if (result === 'saved') {
            await refreshApex(this._wiredResult);
        }
    }

    // ── Suppression avec confirm natif ────────────────────────────────────
    async openDeleteConfirm(event) {
        const id = event.currentTarget.dataset.id;

        const confirmed = await LightningConfirm.open({
            message: 'Êtes-vous sûr de vouloir supprimer ce véhicule adverse ? Cette action est irréversible.',
            variant: 'destructive',
            label:   'Confirmer la suppression'
        });

        if (!confirmed) return;

        try {
            await deleteAdverseVehicle({ vehicleId: id });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Succès', message: 'Véhicule supprimé.', variant: 'success'
            }));
            await refreshApex(this._wiredResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Erreur',
                message: error?.body?.message || 'Impossible de supprimer.',
                variant: 'error'
            }));
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────
    navigateToRecord(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }
}