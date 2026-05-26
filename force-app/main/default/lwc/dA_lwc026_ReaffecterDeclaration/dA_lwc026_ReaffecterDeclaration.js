import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createRequeteReaffectation from '@salesforce/apex/DA_lwc026_ReaffectationController.createRequeteReaffectation';
import getEligibleUserIds from '@salesforce/apex/DA_lwc026_ReaffectationController.getEligibleUserIds';

export default class DA_lwc026_ReaffecterDeclaration extends LightningElement {

    @api recordId;

    @track isModalOpen    = false;
    @track isSaving       = false;
    @track selectedUserId = null;
    @track motif          = '';
    @track errors         = { utilisateur: '', motif: '' };

    // ── Wire : IDs des utilisateurs éligibles ─────────────────────
    _eligibleUserIds = [];

    @wire(getEligibleUserIds)
    wiredEligibleUsers({ data, error }) {
        if (data) {
            this._eligibleUserIds = data;
        } else if (error) {
            this._eligibleUserIds = [];
        }
    }

    // ── Filtre : uniquement les utilisateurs éligibles ────────────
    get userFilter() {
        if (!this._eligibleUserIds || this._eligibleUserIds.length === 0) {
            return {
                criteria: [
                    { fieldPath: 'IsActive', operator: 'eq', value: true }
                ]
            };
        }
        return {
            criteria: [
                { fieldPath: 'IsActive', operator: 'eq', value: true },
                { fieldPath: 'Id', operator: 'in', value: this._eligibleUserIds }
            ]
        };
    }

    renderedCallback() {
        if (this._styleInjected) return;
        this._styleInjected = true;

        const style = document.createElement('style');
        style.textContent = `
            lightning-record-picker .slds-listbox.slds-dropdown,
            lightning-record-picker [role="listbox"],
            lightning-record-picker .slds-dropdown_fluid {
                z-index: 99999 !important;
                position: absolute !important;
            }

            lightning-record-picker {
                position: relative !important;
                z-index: 99999 !important;
            }

            .fs-modal__body {
                overflow: visible !important;
            }

            .fs-modal {
                overflow: visible !important;
            }
        `;
        document.head.appendChild(style);
    }

    // ── Handlers Modal ─────────────────────────────────────────────
    @api
    handleOpenModal() {
        this.selectedUserId = null;
        this.motif          = '';
        this.errors         = { utilisateur: '', motif: '' };
        this.isModalOpen    = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    // ── Handlers Formulaire ────────────────────────────────────────
    handleUserChange(event) {
        this.selectedUserId = event.detail.recordId;
        if (this.selectedUserId) {
            this.errors = { ...this.errors, utilisateur: '' };
        }
    }

    handleMotifChange(event) {
        this.motif = event.target.value;
        if (this.motif && this.motif.trim() !== '') {
            this.errors = { ...this.errors, motif: '' };
        }
    }

    handleMotifBlur() {
        if (!this.motif || this.motif.trim() === '') {
            this.errors = { ...this.errors, motif: 'Ce champ est obligatoire.' };
        }
    }

    // ── Validation ─────────────────────────────────────────────────
    _validate() {
        const e = { utilisateur: '', motif: '' };
        let ok = true;

        if (!this.selectedUserId) {
            e.utilisateur = 'Ce champ est obligatoire.';
            ok = false;
        }
        if (!this.motif || this.motif.trim() === '') {
            e.motif = 'Ce champ est obligatoire.';
            ok = false;
        }

        this.errors = e;
        return ok;
    }

    // ── Confirmation ───────────────────────────────────────────────
    async handleConfirm() {
        if (!this._validate()) return;

        this.isSaving = true;
        try {
            await createRequeteReaffectation({
                declarationId : this.recordId,
                targetUserId  : this.selectedUserId,
                motif         : this.motif.trim()
            });

            this.showToast('Succès', 'La demande de réaffectation a été envoyée au manager.', 'success');
            this.isModalOpen = false;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { window.location.reload(); }, 500);

        } catch (error) {
            this.showToast('Erreur', this.extractError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ── Helpers ────────────────────────────────────────────────────
    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message)       return error.message;
        return 'Une erreur inattendue est survenue.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'sticky' }));
    }
}