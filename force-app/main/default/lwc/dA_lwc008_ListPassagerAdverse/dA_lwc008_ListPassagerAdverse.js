import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getPassagersAdverses from '@salesforce/apex/DA_PassagerAdverseController.getPassagersAdverses';
import getVehiculesAdverses  from '@salesforce/apex/DA_PassagerAdverseController.getVehiculesAdverses';
import savePassager          from '@salesforce/apex/DA_PassagerAdverseController.savePassager';
import deletePassager        from '@salesforce/apex/DA_PassagerAdverseController.deletePassager';

const EMPTY_FORM = { Vehicule__c: '' };

export default class DA_lwc008_ListPassagerAdverse extends LightningElement {

    @api recordId;

    @track passagers               = [];
    @track isLoading               = false;
    @track isSaving                = false;
    @track isModalOpen             = false;

    @track showDeleteModal         = false;
    @track selectedParticipantName = '';
    @track selectedParticipantId   = '';

    @track isEditMode              = false;
    @track currentRecordId         = null;
    @track formData                = { ...EMPTY_FORM };
    @track vehiculeOptions         = [];

    _wiredResult;

    /* ─────────────────────────── Wire ─────────────────────────── */

    @wire(getPassagersAdverses, { caseId: '$recordId' })
    wiredPassagers(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.passagers = result.data.map(r => this._enrichRecord(r));
        }
    }

    /* ───────────────────────── Lifecycle ──────────────────────── */

    connectedCallback() {
        this.isLoading = true;
        this._loadVehicules();
    }

    /* ───────────────────────── Getters ────────────────────────── */

    get hasPassagers() {
        return this.passagers && this.passagers.length > 0;
    }

    get totalLabel() {
        const n = this.passagers.length;
        return `${n} passager${n > 1 ? 's' : ''} adverse${n > 1 ? 's' : ''}`;
    }

    get modalTitle() {
        return this.isEditMode ? 'Modifier un passager adverse' : 'Ajouter un passager adverse';
    }

    get saveLabel() {
        return this.isEditMode ? 'Enregistrer les modifications' : 'Ajouter le passager';
    }

    /* ──────────────────────── Handlers UI ─────────────────────── */

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => { this.isLoading = false; });
    }

    handleAjouter() {
        this.isEditMode      = false;
        this.currentRecordId = null;
        this.formData        = { Vehicule__c: '' };
        this.isModalOpen     = true;
    }

    handleRowActionBtn(e) {
        const { id, action } = e.currentTarget.dataset;
        const row = this.passagers.find(p => p.Id === id);

        if (action === 'edit') {
            this.isEditMode      = true;
            this.currentRecordId = id;
            this.formData        = {
                Vehicule__c: row?.Vehicule__c || ''
            };
            this.isModalOpen = true;

        } else if (action === 'delete') {
            this.selectedParticipantId   = id;
            this.selectedParticipantName = row?.Name || id;
            this.showDeleteModal         = true;
        }
    }

    handleVehiculeChange(e) {
        this.formData = { ...this.formData, Vehicule__c: e.detail.value };
    }

    /* ─────────────────── Sauvegarde principale ───────────────── */

    async handleSauvegarderManuellement() {
        const fields = {};
        this.template
            .querySelectorAll('lightning-input-field')
            .forEach(field => {
                fields[field.fieldName] = field.value;
            });

        fields.Case__c     = this.recordId;
        fields.Vehicule__c = this.formData.Vehicule__c || null;
        fields.Roles__c    = 'Passager adverse';
        // Compte__c est géré automatiquement côté Apex (upsert Person Account)

        if (!fields.Name?.trim()) {
            this._toast('Erreur', 'Veuillez renseigner le nom et prénom.', 'error');
            return;
        }
        if (!fields.CIN__c?.trim()) {
            this._toast('Erreur', 'Veuillez renseigner le CIN.', 'error');
            return;
        }

        if (this.isEditMode && this.currentRecordId) {
            fields.Id = this.currentRecordId;
        }

        this.isSaving = true;
        try {
            await savePassager({ passagerData: fields });
            this._toast('Succès', 'Passager enregistré avec succès.', 'success');
            this.handleFermerModal();
            await refreshApex(this._wiredResult);
        } catch (error) {
    console.error('Full error:', JSON.stringify(error));
    const msg = error?.body?.message 
             || error?.body?.output?.errors?.[0]?.message
             || error?.message 
             || 'Erreur inconnue';
    this._toast('Erreur', msg, 'error');
} finally {
            this.isSaving = false;
        }
    }

    /* ────────────────────────── Suppression ───────────────────── */

    async confirmDelete() {
        this.isSaving = true;
        try {
            await deletePassager({ passagerId: this.selectedParticipantId });
            this._toast('Succès', 'Le passager adverse a été supprimé.', 'success');
            this.closeDeleteModal();
            await refreshApex(this._wiredResult);
        } catch (error) {
            this._toast('Erreur', error?.body?.message || 'Erreur lors de la suppression.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    closeDeleteModal() {
        this.showDeleteModal         = false;
        this.selectedParticipantId   = '';
        this.selectedParticipantName = '';
    }

    /* ─────────────────────── Fermeture modales ─────────────────── */

    handleFermerModal() {
        this.isModalOpen         = false;
        this.showDeleteModal     = false;
        this.currentRecordId     = null;
        this.isSaving            = false;
    }

    handleOverlayClick(e) {
        if (e.target === e.currentTarget) this.handleFermerModal();
    }

    stopPropagation(e) {
        e.stopPropagation();
    }

    /* ──────────────────────── Helpers privés ───────────────────── */

    _enrichRecord(r) {
        const stateClass = {
            'Blessé' : 'pm-state pm-state--blesse',
            'Décédé' : 'pm-state pm-state--deces',
            'Indemne': 'pm-state pm-state--indemne',
        }[r.StateOfPerson__c] || 'pm-state pm-state--default';

        return { ...r, stateClass };
    }

    _loadVehicules() {
        getVehiculesAdverses({ caseId: this.recordId })
            .then(data  => { this.vehiculeOptions = data; })
            .catch(err  => console.error('Erreur chargement véhicules :', err));
    }

    _toast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}