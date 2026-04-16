import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPassagersAutresPartie from '@salesforce/apex/PassagerController.getPassagersAutresPartie';
import resolveAccountByCIN from '@salesforce/apex/PassagerController.resolveAccountByCIN';

const STATE_CLASS_MAP = {
    Blessé: 'pm-state pm-state--blesse',
    Décédé: 'pm-state pm-state--deces',
    Indemne: 'pm-state pm-state--indemne'
};
const DEFAULT_STATE_CLASS = 'pm-state pm-state--default';

export default class PassagerAutresPartieList extends LightningElement {
    @api recordId;

    passagers;
    error;
    showModal = false;
    editRecordId;
    modalTitle = '';
    selectedTypeContact = '';

    _wiredResult;

    // --- Wire ---
    @wire(getPassagersAutresPartie, { caseId: '$recordId' })
    wiredPassagers(result) {
        this._wiredResult = result;
        const { data, error: err } = result;
        if (data) {
            this.passagers = data.map((r) => ({
                ...r,
                stateClass: STATE_CLASS_MAP[r.StateOfPerson__c] || DEFAULT_STATE_CLASS
            }));
            this.error = undefined;
        } else if (err) {
            this.error = err.body?.message || 'Erreur lors du chargement des participants.';
            this.passagers = undefined;
        }
    }

    // --- Getters ---
    get hasPassagers() {
        return Array.isArray(this.passagers) && this.passagers.length > 0;
    }

    get totalLabel() {
        const count = this.passagers?.length || 0;
        return `${count} participant${count > 1 ? 's' : ''}`;
    }

    get showContactField() {
        return !!this.selectedTypeContact;
    }

    // --- Type Contact change ---
    handleTypeContactChange(event) {
        this.selectedTypeContact = event.detail.value || '';
    }

    // --- Ajout ---
    handleAddPassager() {
        this.editRecordId = undefined;
        this.modalTitle = 'Ajouter un participant';
        this.selectedTypeContact = '';
        this.showModal = true;
    }


    // --- Modal Ajout/Modification ---
    handleCloseModal() {
        this.showModal = false;
        this.editRecordId = undefined;
        this.selectedTypeContact = '';
    }

    handleOverlayClick(event) {
        if (event.target === event.currentTarget) {
            this.handleCloseModal();
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    async handleFormSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        const cin = fields.CIN__c;

        if (!cin?.trim()) {
            this._showToast('Erreur', 'Le champ CIN est obligatoire.', 'error');
            return;
        }

        const trimmedCin = cin.trim().toLowerCase();
        const duplicate = this.passagers?.find(
            (p) =>
                p.CIN__c?.toLowerCase() === trimmedCin &&
                p.Id !== this.editRecordId
        );

        if (duplicate) {
            this._showToast(
                'Erreur',
                `Un participant avec le CIN "${cin}" existe déjà (${duplicate.Name__c || ''}).`,
                'error'
            );
            return;
        }

        try {
            const accountId = await resolveAccountByCIN({
                cin: cin.trim(),
                nom: fields.Name__c || ''
            });
            fields.Compte__c = accountId;
        } catch (err) {
            this._showToast('Erreur', err.body?.message || 'Erreur lors de la résolution du compte.', 'error');
            return;
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.handleCloseModal();
        this._showToast('Succès', 'Le participant a été enregistré avec succès.', 'success');
        return refreshApex(this._wiredResult);
    }

    handleError(event) {
        this._showToast('Erreur', event.detail.message || 'Une erreur est survenue.', 'error');
    }


    // --- Refresh ---
    handleRefresh() {
        return refreshApex(this._wiredResult);
    }

    // --- Toast helper ---
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}