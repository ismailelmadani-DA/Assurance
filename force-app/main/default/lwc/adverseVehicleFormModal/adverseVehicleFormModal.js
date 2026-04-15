import LightningModal from 'lightning/modal';
import { api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveAdverseVehicle from '@salesforce/apex/VehiculeAdversesController.saveAdverseVehicle';
import getEtatPicklistValues from '@salesforce/apex/VehiculeAdversesController.getEtatPicklistValues';

export default class AdverseVehicleFormModal extends LightningModal {

    // Reçus depuis le parent via LightningModal.open()
    @api claimId;
    @api record; // undefined = ajout | objet = modification

    @track formData = {
        EtatVehicule__c:        '',
        RegistrationNumber__c:  '',
        Marque__c:              '',
        NbDePassagerBlesses__c: null,
        CompagnieAdverse__c:    '',
        Pays__c:                '',
        AdversaireAssure__c:    false
    };

    @track etatOptions = [];
    @track errorMsg    = '';
    @track isSaving    = false;

    // ── Picklist Apex ─────────────────────────────────────────────────────
    @wire(getEtatPicklistValues)
    wiredEtat({ data, error }) {
        if (data) {
            this.etatOptions = data.map(i => ({ label: i.label, value: i.value }));
        } else if (error) {
            this.etatOptions = [
                { label: 'Intact',    value: 'Intact'    },
                { label: 'Endommagé', value: 'Endommagé' },
                { label: 'Épave',     value: 'Épave'     },
                { label: 'Inconnu',   value: 'Inconnu'   }
            ];
        }
    }

    // ── Pré-remplissage en modification ───────────────────────────────────
    connectedCallback() {
        if (this.record) {
            this.formData = {
                Id:                     this.record.Id,
                EtatVehicule__c:        this.record.EtatVehicule__c        || '',
                RegistrationNumber__c:  this.record.RegistrationNumber__c  || '',
                Marque__c:              this.record.Marque__c              || '',
                NbDePassagerBlesses__c: this.record.NbDePassagerBlesses__c || null,
                CompagnieAdverse__c:    this.record.CompagnieAdverse__c    || '',
                Pays__c:                this.record.Pays__c                || '',
                AdversaireAssure__c:    this.record.AdversaireAssure__c    || false
            };
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────
    get modalTitle() {
        return this.record ? 'Modifier le véhicule adverse' : 'Ajouter un véhicule adverse';
    }

    get saveLabel() {
        return this.isSaving ? 'Enregistrement...' : 'Enregistrer';
    }

    // ── Handlers champs ───────────────────────────────────────────────────
    handleChange(event) {
        const field = event.target.name;
        this.formData = { ...this.formData, [field]: event.target.value };
        this.errorMsg = '';
    }

    handleCheckbox(event) {
        const field = event.target.name;
        this.formData = { ...this.formData, [field]: event.target.checked };
    }

    // ── Sauvegarde ────────────────────────────────────────────────────────
    async handleSave() {
        this.isSaving = true;
        this.errorMsg = '';

        try {
            const vehicleToSave = {
                Claim__c:               this.claimId,
                isOpposingCar__c:       true,
                EtatVehicule__c:        this.formData.EtatVehicule__c        || null,
                RegistrationNumber__c:  this.formData.RegistrationNumber__c  || null,
                Marque__c:              this.formData.Marque__c              || null,
                NbDePassagerBlesses__c: this.formData.NbDePassagerBlesses__c || null,
                CompagnieAdverse__c:    this.formData.CompagnieAdverse__c    || null,
                Pays__c:                this.formData.Pays__c                || null,
                AdversaireAssure__c:    this.formData.AdversaireAssure__c    || false
            };

            if (this.record?.Id) {
                vehicleToSave.Id = this.record.Id;
            }

            await saveAdverseVehicle({ vehicle: vehicleToSave });

            this.dispatchEvent(new ShowToastEvent({
                title:   'Succès',
                message: this.record ? 'Véhicule modifié avec succès.' : 'Véhicule ajouté avec succès.',
                variant: 'success'
            }));

            // Fermer la modale et signaler le succès au parent
            this.close('saved');

        } catch (error) {
            console.error('Erreur save:', JSON.stringify(error));
            this.errorMsg =
                error?.body?.message ||
                error?.message ||
                'Une erreur est survenue.';
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.close('cancelled');
    }
}