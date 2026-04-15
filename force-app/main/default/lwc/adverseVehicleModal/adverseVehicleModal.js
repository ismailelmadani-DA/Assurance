import { LightningElement, api, track } from 'lwc';
import upsertAdverseVehicle from '@salesforce/apex/VehiculeAdverseController.upsertAdverseVehicle';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AdverseVehicleModal extends LightningElement {

    @api claimId;
    @api vehicleRecord; // null = création, objet = modification

    @track formData = {
        EtatVehicule__c: '',
        NbDePassagerBlesses__c: null,
        isOpposingCar__c: true
    };

    @track errorMessage = '';
    @track isSaving = false;

    // Options pour l'état du véhicule (à adapter selon vos valeurs de picklist)
    etatOptions = [
        { label: 'Non Endommagé', value: 'Intact' },
        { label: 'Endommagé', value: 'Endommagé' },
    ];

    connectedCallback() {
        // Si modification, pré-remplir le formulaire
        if (this.vehicleRecord) {
            this.formData = { ...this.vehicleRecord };
        } else {
            // Lier à la déclaration courante
            this.formData.Claim__c = this.claimId;
        }
    }

    get modalTitle() {
        return this.vehicleRecord
            ? 'Modifier le véhicule adverse'
            : 'Ajouter un véhicule adverse';
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.formData = {
            ...this.formData,
            [field]: event.target.value
        };
    }

    async handleSave() {
        // Validation basique
        if (!this.formData.RegistrationNumber__c) {
            this.errorMessage = 'Le numéro d\'immatriculation est obligatoire.';
            return;
        }

        this.isSaving = true;
        this.errorMessage = '';

        try {
            const vehicleToSave = {
                ...this.formData,
                Claim__c: this.claimId,
                isOpposingCar__c: true
            };

            await upsertAdverseVehicle({ vehicle: vehicleToSave });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Succès',
                message: 'Véhicule enregistré avec succès.',
                variant: 'success'
            }));

            // Notifier le parent pour rafraîchir
            this.dispatchEvent(new CustomEvent('saved'));

        } catch (error) {
            this.errorMessage = error.body?.message || 'Une erreur est survenue.';
        } finally {
            this.isSaving = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}