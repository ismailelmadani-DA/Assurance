import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }      from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex }         from '@salesforce/apex';
import USER_ID                 from '@salesforce/user/Id';
import rejeterReaffectation    from '@salesforce/apex/DA_lwc026_ReaffectationController.rejeterReaffectation';
import getRequeteInfo          from '@salesforce/apex/DA_lwc026_ReaffectationController.getRequeteInfo';

import OWNER_ID_FIELD from '@salesforce/schema/Case.OwnerId';
import STATUS_FIELD   from '@salesforce/schema/Case.Status';

const CASE_FIELDS = [OWNER_ID_FIELD, STATUS_FIELD];

export default class DA_lwc028_RejeterReaffectation extends LightningElement {

    @api recordId;

    @track isModalOpen  = false;
    @track isSaving     = false;
    @track isLoading    = true;
    @track requeteInfo  = null;
    @track motifRejet   = '';

    // ── Wire ────────────────────────────────────────────────────────
    _wiredCaseResult;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
wiredCase(result) {
    this._wiredCaseResult = result;
    if (result.data) {
        this.isLoading = false;
        // ✅ Notifier le parent exactement comme lwc027
        this.dispatchEvent(new CustomEvent('ownerresolved', {
            detail: { isOwner: this.isOwner }
        }));
    } else if (result.error) {
        this.isLoading = false;
    }
}

    // ── Bouton visible : Owner courant + statut Initiale ────────────
    get isOwner() {
        if (!this._wiredCaseResult?.data) return false;
        const ownerId = getFieldValue(this._wiredCaseResult.data, OWNER_ID_FIELD);
        const status  = getFieldValue(this._wiredCaseResult.data, STATUS_FIELD);
        return ownerId === USER_ID && status === 'Initiale';
    }

    // ── Handlers Modal ──────────────────────────────────────────────
    @api
    async handleOpenModal() {
        this.motifRejet = '';
        try {
            this.requeteInfo = await getRequeteInfo({ requeteId: this.recordId });
        } catch (e) {
            this.requeteInfo = null;
        }
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
        this.dispatchEvent(new CustomEvent('modalclosed'));
    }

    handleMotifChange(event) {
        this.motifRejet = event.target.value;
    }

    // ── Confirmation ────────────────────────────────────────────────
    async handleConfirm() {
        if (!this.motifRejet || this.motifRejet.trim() === '') {
            this.showToast('Erreur', 'Le motif de rejet est obligatoire.', 'error');
            return;
        }

        this.isSaving = true;
        try {
            await rejeterReaffectation({
                requeteId : this.recordId,
                motif     : this.motifRejet.trim()
            });

            this.showToast(
                'Succès',
                'La réaffectation a été rejetée. Le demandeur a été notifié.',
                'success'
            );
            this.isModalOpen = false;
            this.dispatchEvent(new CustomEvent('modalclosed'));

            await refreshApex(this._wiredCaseResult);
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