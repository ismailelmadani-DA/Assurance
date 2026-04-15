import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import saveVehicule from '@salesforce/apex/VehiculeAdverseController.saveVehicule';

import ETAT_FIELD from '@salesforce/schema/VehicleCaseAssignment__c.EtatVehicule__c';
import NB_FIELD   from '@salesforce/schema/VehicleCaseAssignment__c.NbDePassagerBlesses__c';

const FIELDS = [ETAT_FIELD, NB_FIELD];

export default class VehiculeAdverseForm extends LightningElement {
    @api vehiculeId;
    @api caseId;

    @track etatVehicule  = '';
    @track nbPassagers   = 0;
    @track errorMessage  = '';
    @track isSaving      = false;

    @wire(getRecord, { recordId: '$vehiculeId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.etatVehicule = getFieldValue(data, ETAT_FIELD) || '';
            this.nbPassagers  = getFieldValue(data, NB_FIELD)   || 0;
        }
        if (error) {
            console.error('Erreur chargement', error);
        }
    }

    get modalTitle() {
        return this.vehiculeId ? 'Modifier le véhicule' : 'Nouveau véhicule';
    }

    get etatOptions() {
        return [
            { label: 'Non Endommagé',  value: 'Non Endommagé'  },
            { label: 'Endommagé', value: 'Endommagé' },
        ];
    }

    get hasError() {
        return this.errorMessage !== '';
    }

    handleEtatChange(e) { this.etatVehicule = e.detail.value; }
    handleNbChange(e)   { this.nbPassagers  = e.detail.value; }

    handleSave() {
        // Reset erreur
        this.errorMessage = '';

        // Validation
        if (!this.etatVehicule) {
            this.errorMessage = 'Veuillez sélectionner l\'état du véhicule.';
            return;
        }

        if (!this.caseId) {
            this.errorMessage = 'Identifiant de déclaration manquant.';
            console.error('caseId est undefined ou null');
            return;
        }

        // Construction du record
        const record = {
            Claim__c:               this.caseId,
            EtatVehicule__c:        this.etatVehicule,
            NbDePassagerBlesses__c: parseInt(this.nbPassagers, 10) || 0,
            isOpposingCar__c:       true
        };

        if (this.vehiculeId) {
            record.Id = this.vehiculeId;
        }

        console.log('>>> Saving record:', JSON.stringify(record));

        this.isSaving = true;

        saveVehicule({ vehicule: record })
            .then(() => {
                this.isSaving = false;
                // ✅ On dispatch save sans toast (le parent gère le refresh)
                this.dispatchEvent(new CustomEvent('save'));
            })
            .catch(error => {
                this.isSaving = false;
                this.errorMessage = error.body?.message
                    || error.message
                    || 'Une erreur est survenue.';
                console.error('Erreur saveVehicule', error);
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}