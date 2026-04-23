import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import VEHICLE_ASSIGNMENT_OBJECT from '@salesforce/schema/VehicleCaseAssignment__c';
import TYPE_VEHICULE_FIELD from '@salesforce/schema/VehicleCaseAssignment__c.TypeVehicule__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Lwc012_VehiculeAdverse extends LightningElement {
    @api claimSummary;
    @track adverseVehicles = []; 
    @track isFormVisible = true;

    // --- Données du Véhicule ---
    @track formData = {
        VehicleIsDamaged__c: '',
        Adversaire_Assure__c: 'false',
        TypeVehicule__c: '',
        RegistrationNumber__c: '',
        DateMiseEnCirculation__c: null,
        Marque__c: '', 
        CompagnieAdverse__c: '',
        Numéro_de_contrat__c: '',
        NbDePassagerBlesses__c: 0
    };

    // --- NOUVEAU : Données de la Modale Passager ---
    @track isPassengerModalOpen = false;
    currentVehicleKey = null; // Permet de savoir à quel véhicule on rattache le passager
    @track passengerData = { Nom__c: '', Prenom__c: '', CIN__c: '', StateOfPerson__c: '' };

    @track typeOptions = [];
    optionsAssure = [{ label: 'Oui', value: 'true' }, { label: 'Non', value: 'false' }];
    optionsEtat = [{ label: 'Endommagé', value: 'Endommagé' }, { label: 'Pas de dommage', value: 'Pas de dommage' }];
    etatPersonneOptions = [
        { label: 'Indemne', value: 'Indemne' }, 
        { label: 'Blessé', value: 'Blessé' }, 
        { label: 'Décédé', value: 'Décédé' }
    ];

    @wire(getObjectInfo, { objectApiName: VEHICLE_ASSIGNMENT_OBJECT })
    objectMetadata;

    @wire(getPicklistValues, { recordTypeId: '$objectMetadata.data.defaultRecordTypeId', fieldApiName: TYPE_VEHICULE_FIELD })
    wiredType({ error, data }) {
        if (data) this.typeOptions = data.values;
    }

    handleInputChange(event) {
        this.formData[event.target.dataset.field] = event.target.value;
    }

    handleLookupChange(event) {
        this.formData.CompagnieAdverse__c = event.detail.recordId;
    }

    // --- GESTION DES VÉHICULES ---
    handleAjouter() {
        const allValid = [...this.template.querySelectorAll('lightning-input[data-field], lightning-combobox[data-field], lightning-record-picker')]
            .reduce((v, i) => {
                if(i.reportValidity) i.reportValidity();
                return v && (i.checkValidity ? i.checkValidity() : true);
            }, true);

        if (allValid) {
            // NOUVEAU : On ajoute "passengers: []" dans l'objet véhicule
            const newVehicle = { ...this.formData, key: Date.now(), passengers: [] };
            this.adverseVehicles = [...this.adverseVehicles, newVehicle];
            
            this.dispatchEvent(new ShowToastEvent({ title: 'Succès', message: 'Le véhicule adverse a été ajouté.', variant: 'success' }));
            this.resetForm();
            this.isFormVisible = false; 
            this.notifyParent();
        }
    }

    handleDelete(event) {
        const keyToDelete = event.currentTarget.dataset.key;
        this.adverseVehicles = this.adverseVehicles.filter(v => v.key.toString() !== keyToDelete.toString());
        if (this.adverseVehicles.length === 0) this.isFormVisible = true;
        this.notifyParent();
    }

    // --- NOUVEAU : GESTION DES PASSAGERS ---
    openPassengerModal(event) {
        this.currentVehicleKey = event.currentTarget.dataset.key;
        this.passengerData = { Nom__c: '', Prenom__c: '', CIN__c: '', StateOfPerson__c: '' };
        this.isPassengerModalOpen = true;
    }

    closePassengerModal() {
        this.isPassengerModalOpen = false;
        this.currentVehicleKey = null;
    }

    handlePassInputChange(event) {
        this.passengerData[event.target.dataset.passfield] = event.target.value;
    }

    handleSavePassenger() {
        const allValid = [...this.template.querySelectorAll('lightning-input[data-passfield], lightning-combobox[data-passfield]')]
            .reduce((v, i) => { if(i.reportValidity) i.reportValidity(); return v && i.checkValidity(); }, true);

        if (allValid) {
            const newPass = { ...this.passengerData, key: Date.now() };
            
            // On trouve le véhicule cliqué et on injecte le passager dans sa liste
            this.adverseVehicles = this.adverseVehicles.map(veh => {
                if (veh.key.toString() === this.currentVehicleKey.toString()) {
                    veh.passengers.push(newPass);
                }
                return veh;
            });

            this.dispatchEvent(new ShowToastEvent({ title: 'Succès', message: 'Passager lié au véhicule.', variant: 'success' }));
            this.closePassengerModal();
            this.notifyParent();
        }
    }

    handleDeletePassenger(event) {
        const vehKey = event.currentTarget.dataset.vehkey;
        const passKey = event.currentTarget.dataset.passkey;

        this.adverseVehicles = this.adverseVehicles.map(veh => {
            if (veh.key.toString() === vehKey.toString()) {
                veh.passengers = veh.passengers.filter(p => p.key.toString() !== passKey.toString());
            }
            return veh;
        });
        this.notifyParent();
    }

    // --- MÉTHODES GLOBALES ---
    @api get adverseVehicleData() { return this.adverseVehicles; }
    @api validate() { return true; }
    
    notifyParent() { this.dispatchEvent(new CustomEvent('adversevehicleupdate', { detail: this.adverseVehicles })); }
    
    handleAnnuler() {
        this.resetForm();
        if (this.adverseVehicles.length > 0) this.isFormVisible = false;
    }
    showForm() { this.isFormVisible = true; }
    
    resetForm() {
        this.formData = { VehicleIsDamaged__c: '', Adversaire_Assure__c: 'false', TypeVehicule__c: '', RegistrationNumber__c: '', DateMiseEnCirculation__c: null, Marque__c: '', CompagnieAdverse__c: '', Numéro_de_contrat__c: '', NbDePassagerBlesses__c: 0 };
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) picker.clearSelection();
    }
}