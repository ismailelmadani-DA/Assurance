import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import saveVehicule from '@salesforce/apex/VehiculeAdverseController.saveVehicule';

const FIELDS = [
    'VehicleCaseAssignment__c.EtatVehicule__c',
    'VehicleCaseAssignment__c.NbDePassagerBlesses__c'
];

export default class VehiculeAdverseForm extends LightningElement {
    @api vehiculeId;   // null = création, sinon = modification
    @api caseId;

    @track etatVehicule = '';
    @track nbPassagers = 0;

    // Charger les données si modification
    @wire(getRecord, { recordId: '$vehiculeId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) {
            this.etatVehicule = data.fields.EtatVehicule__c.value;
            this.nbPassagers  = data.fields.NbDePassagerBlesses__c.value;
        }
    }

    get modalTitle() {
        return this.vehiculeId ? 'Modifier le véhicule' : 'Nouveau véhicule';
    }

    // Adaptez les valeurs à votre picklist EtatVehicule__c
    get etatOptions() {
        return [
            { label: 'Bon état',    value: 'Bon état' },
            { label: 'Endommagé',   value: 'Endommagé' },
            { label: 'Épave',       value: 'Epave' },
        ];
    }

    handleEtatChange(e)  { this.etatVehicule = e.detail.value; }
    handleNbChange(e)    { this.nbPassagers  = e.detail.value; }

    handleSave() {
        const record = {
            Id:                      this.vehiculeId || undefined,
            Claim__c:                this.caseId,
            EtatVehicule__c:         this.etatVehicule,
            NbDePassagerBlesses__c:  this.nbPassagers,
            isOpposingCar__c:        true
        };

        saveVehicule({ vehicule: record })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Succès',
                    message: 'Véhicule enregistré.',
                    variant: 'success'
                }));
                this.dispatchEvent(new CustomEvent('save'));
            })
            .catch(e => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message: e.body.message,
                    variant: 'error'
                }));
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}