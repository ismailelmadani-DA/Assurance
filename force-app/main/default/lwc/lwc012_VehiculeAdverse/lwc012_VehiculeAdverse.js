import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import VEHICLE_ASSIGNMENT_OBJECT from '@salesforce/schema/VehicleCaseAssignment__c';
import TYPE_VEHICULE_FIELD from '@salesforce/schema/VehicleCaseAssignment__c.TypeVehicule__c';

// IMPORT POUR LES NOTIFICATIONS TOAST
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Lwc012_VehiculeAdverse extends LightningElement {
    @api claimSummary;
    @track adverseVehicles = []; 
    @track isFormVisible = true;

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

    @track typeOptions = [];
    optionsAssure = [{ label: 'Oui', value: 'true' }, { label: 'Non', value: 'false' }];
    optionsEtat = [{ label: 'Endommagé', value: 'Endommagé' }, { label: 'Pas de dommage', value: 'Pas de dommage' }];

    // --- 1. Récupération des métadonnées pour les types de véhicules ---
    @wire(getObjectInfo, { objectApiName: VEHICLE_ASSIGNMENT_OBJECT })
    objectMetadata;

    @wire(getPicklistValues, { 
        recordTypeId: '$objectMetadata.data.defaultRecordTypeId', 
        fieldApiName: TYPE_VEHICULE_FIELD 
    })
    wiredType({ error, data }) {
        if (data) {
            this.typeOptions = data.values;
        } else if (error) {
            console.error('Erreur Picklist Type:', error);
        }
    }

    // --- 2. Gestion des saisies ---
    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleLookupChange(event) {
        this.formData.CompagnieAdverse__c = event.detail.recordId;
    }

    // --- 3. Logique d'ajout à la liste ---
    handleAjouter() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')]
            .reduce((v, i) => {
                if(i.reportValidity) i.reportValidity();
                return v && (i.checkValidity ? i.checkValidity() : true);
            }, true);

        if (allValid) {
            const newVehicle = { ...this.formData, key: Date.now() };
            this.adverseVehicles = [...this.adverseVehicles, newVehicle];
            
            // DÉCLENCHEMENT DU TOAST DE SUCCÈS
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Succès',
                    message: 'Le véhicule adverse a été ajouté à la liste.',
                    variant: 'success',
                })
            );
            
            this.resetForm();
            this.isFormVisible = false; 
            this.notifyParent();
        }
    }

    // --- NOUVELLE MÉTHODE : Suppression d'un véhicule ---
    handleDelete(event) {
        const keyToDelete = event.currentTarget.dataset.key;
        this.adverseVehicles = this.adverseVehicles.filter(v => v.key.toString() !== keyToDelete.toString());
        
        if (this.adverseVehicles.length === 0) {
            this.isFormVisible = true; // Réaffiche le formulaire si la liste est vide
        }
        
        this.notifyParent();
    }

    // --- 4. COMMUNICATION AVEC LE PARENT ---
    @api
    get adverseVehicleData() {
        return this.adverseVehicles;
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('adversevehicleupdate', { 
            detail: this.adverseVehicles 
        }));
    }

    @api 
    validate() {
        // CORRECTION DU BUG : On renvoie toujours true pour que l'absence de véhicule adverse
        // ne bloque plus le passage à l'étape suivante.
        return true;
    }

    // --- 5. Gestion de l'UI ---
    handleAnnuler() {
        this.resetForm();
        if (this.adverseVehicles.length > 0) {
            this.isFormVisible = false;
        }
    }

    showForm() {
        this.isFormVisible = true;
    }

    resetForm() {
        this.formData = { 
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

        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) {
            picker.clearSelection();
        }
    }
}