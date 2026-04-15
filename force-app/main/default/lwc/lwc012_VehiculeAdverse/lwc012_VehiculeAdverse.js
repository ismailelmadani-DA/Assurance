import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import VEHICLE_ASSIGNMENT_OBJECT from '@salesforce/schema/VehicleCaseAssignment__c';

// Import du champ pour la Picklist Type Véhicule
import TYPE_VEHICULE_FIELD from '@salesforce/schema/VehicleCaseAssignment__c.TypeVehicule__c';

export default class Lwc012_VehiculeAdverse extends LightningElement {
    @api claimSummary;
    @track adverseVehicles = []; 
    @track isFormVisible = true; 

    // L'objet formData contient les clés exactes attendues par votre Apex
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
    optionsEtat = [{ label: 'Endommagé', value: 'Endommagé' }, { label: 'Intact', value: 'Intact' }];

    @wire(getObjectInfo, { objectApiName: VEHICLE_ASSIGNMENT_OBJECT })
    objectMetadata;

    @wire(getPicklistValues, { 
        recordTypeId: '$objectMetadata.data.defaultRecordTypeId', 
        fieldApiName: TYPE_VEHICULE_FIELD 
    })
    wiredType({ error, data }) {
        if (data) {
            this.typeOptions = data.values;
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleLookupChange(event) {
        this.formData.CompagnieAdverse__c = event.detail.recordId;
    }

    handleAjouter() {
        // Validation de tous les champs
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')]
            .reduce((v, i) => {
                if(i.reportValidity) i.reportValidity();
                return v && (i.checkValidity ? i.checkValidity() : true);
            }, true);

        if (allValid) {
            const newVehicle = { ...this.formData, key: Date.now() };
            this.adverseVehicles = [...this.adverseVehicles, newVehicle];
            
            this.resetForm();
            this.isFormVisible = false; // Masque le formulaire, affiche la liste
            this.notifyParent();
        }
    }

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
        
        // Vider le champ de recherche de compagnie manuellement
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) {
            picker.clearSelection();
        }
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('adversevehicleupdate', { detail: this.adverseVehicles }));
    }

    @api validate() {
        // Vérifie qu'au moins un véhicule adverse a été ajouté
        return this.adverseVehicles.length > 0;
    }
}