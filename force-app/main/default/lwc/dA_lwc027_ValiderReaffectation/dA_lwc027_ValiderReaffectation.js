import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import validerReaffectation from '@salesforce/apex/DA_lwc026_ReaffectationController.validerReaffectation';
import getRequeteInfo    from '@salesforce/apex/DA_lwc026_ReaffectationController.getRequeteInfo';

// Champs Case (Requête) nécessaires
import OWNER_ID_FIELD      from '@salesforce/schema/Case.OwnerId';
import STATUS_FIELD        from '@salesforce/schema/Case.Status';

const CASE_FIELDS = [OWNER_ID_FIELD, STATUS_FIELD];

export default class DA_lwc027_ValiderReaffectation extends LightningElement {

    @api recordId;          // Id de la Requête courante

    // ── État ────────────────────────────────────────────────────────
    @track isModalOpen   = false;
    @track isSaving      = false;
    @track isLoading     = true;
    @track requeteInfo   = null;

    // ── Wire : données du Case (Requête) ────────────────────────────
    _wiredCaseResult;
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
wiredCase(result) {
    this._wiredCaseResult = result;
    if (result.data) {
        this.isLoading = false;
        // ← AJOUT : notifier le parent
        this.dispatchEvent(new CustomEvent('ownerresolved', {
            detail: { isOwner: this.isOwner }
        }));
    } else if (result.error) {
        this.isLoading = false;
    }
}

    // ── Computed : visible uniquement pour le Owner ─────────────────
    get isOwner() {
        if (!this._wiredCaseResult?.data) return false;
        const ownerId = getFieldValue(this._wiredCaseResult.data, OWNER_ID_FIELD);
        const status  = getFieldValue(this._wiredCaseResult.data, STATUS_FIELD);
        // Bouton visible seulement si Owner = currentUser ET statut = 'Initiale'
        return ownerId === USER_ID && status === 'Initiale';
    }

    // ── Handlers Modal ──────────────────────────────────────────────
    @api
    async handleOpenModal() {
        try {
            this.requeteInfo = await getRequeteInfo({ requeteId: this.recordId });
        } catch (e) {
            this.requeteInfo = null;
        }
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    // ── Confirmation ────────────────────────────────────────────────
    async handleConfirm() {
        this.isSaving = true;
        try {
            await validerReaffectation({ requeteId: this.recordId });

            this.showToast(
                'Succès',
                'La réaffectation a été validée. L\'utilisateur a été notifié.',
                'success'
            );
            this.isModalOpen = false;

            // Rafraîchir le wire pour recalculer isOwner
            await refreshApex(this._wiredCaseResult);

            // Recharger la page après un court délai
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { window.location.reload(); }, 600);

        } catch (error) {
            this.showToast('Erreur', this.extractError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────
    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message)       return error.message;
        return 'Une erreur inattendue est survenue.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'sticky' }));
    }
}