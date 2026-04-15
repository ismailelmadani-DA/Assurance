import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAdverseVehicles from '@salesforce/apex/VehiculeAdverseController.getAdverseVehicles';
import deleteAdverseVehicle from '@salesforce/apex/VehiculeAdverseController.deleteAdverseVehicle';

// Mapping état → classe CSS badge
const ETAT_CLASS_MAP = {
    'Intact':    'badge badge-green',
    'Endommagé': 'badge badge-orange',
    'Épave':     'badge badge-red',
    'Inconnu':   'badge badge-gray'
};

export default class AdverseVehicleList extends NavigationMixin(LightningElement) {

    @api recordId; // Id de la déclaration (Case)

    @track vehicles    = [];
    @track isLoading   = true;
    @track hasError    = false;
    @track errorMessage = '';

    // Formulaire
    @track showForm      = false;
    @track selectedRecord = null; // null = ajout, objet = modif

    // Suppression
    @track showDeleteConfirm = false;
    @track vehicleToDelete   = null;
    @track isDeleting        = false;

    // Référence pour refreshApex
    _wiredResult;

    // ── Wire ─────────────────────────────────────────────────────────────
    @wire(getAdverseVehicles, { claimId: '$recordId' })
    wiredVehicles(result) {
        this._wiredResult = result;
        this.isLoading    = false;

        if (result.data) {
            this.vehicles   = result.data.map(v => this._enrichVehicle(v));
            this.hasError   = false;
        } else if (result.error) {
            this.hasError    = true;
            this.errorMessage =
                result.error?.body?.message ||
                'Impossible de charger les véhicules.';
        }
    }

    // ── Enrichissement (badge CSS) ────────────────────────────────────────
    _enrichVehicle(v) {
        return {
            ...v,
            etatBadgeClass: ETAT_CLASS_MAP[v.EtatVehicule__c] || 'badge badge-gray'
        };
    }

    // ── Getters ───────────────────────────────────────────────────────────
    get hasVehicles() {
        return !this.isLoading && !this.hasError && this.vehicles.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.vehicles.length === 0;
    }

    // ── Ouvrir formulaire AJOUT ───────────────────────────────────────────
    openAddModal() {
        this.selectedRecord = null;
        this.showForm       = true;
    }

    // ── Ouvrir formulaire MODIFICATION ───────────────────────────────────
    openEditModal(event) {
        const id = event.currentTarget.dataset.id;
        // Passer le record brut (sans la propriété etatBadgeClass)
        const found = this.vehicles.find(v => v.Id === id);
        if (found) {
            // eslint-disable-next-line no-unused-vars
            const { etatBadgeClass, ...rawRecord } = found;
            this.selectedRecord = rawRecord;
            this.showForm       = true;
        }
    }

    // ── Fermer formulaire ─────────────────────────────────────────────────
    closeForm() {
        this.showForm       = false;
        this.selectedRecord = null;
    }

    // ── Callback après sauvegarde ─────────────────────────────────────────
    async onFormSaved() {
        this.closeForm();
        await refreshApex(this._wiredResult);
    }

    // ── Navigation vers l'enregistrement ─────────────────────────────────
    navigateToRecord(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:   id,
                actionName: 'view'
            }
        });
    }

    // ── Ouvrir confirmation suppression ───────────────────────────────────
    openDeleteConfirm(event) {
        this.vehicleToDelete  = event.currentTarget.dataset.id;
        this.showDeleteConfirm = true;
    }

    cancelDelete() {
        this.showDeleteConfirm = false;
        this.vehicleToDelete   = null;
    }

    // ── Exécuter suppression ──────────────────────────────────────────────
    async confirmDelete() {
        this.isDeleting = true;
        try {
            await deleteAdverseVehicle({ vehicleId: this.vehicleToDelete });

            this.dispatchEvent(new ShowToastEvent({
                title:   'Succès',
                message: 'Véhicule supprimé avec succès.',
                variant: 'success'
            }));

            this.showDeleteConfirm = false;
            this.vehicleToDelete   = null;
            await refreshApex(this._wiredResult);

        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Erreur',
                message: error?.body?.message || 'Impossible de supprimer le véhicule.',
                variant: 'error'
            }));
        } finally {
            this.isDeleting = false;
        }
    }
}