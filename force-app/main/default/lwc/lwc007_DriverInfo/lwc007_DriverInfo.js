import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';

// Import des schémas de champs
import CIVILITY_FIELD from '@salesforce/schema/Account.Civility__c';
import PAYS_FIELD from '@salesforce/schema/Account.Pays__c';
import VILLE_FIELD from '@salesforce/schema/Account.Ville__c';
import ORIGINE_PERMIS_FIELD from '@salesforce/schema/Account.Origine_du_permis__c';
import TYPE_PERMIS_FIELD from '@salesforce/schema/Account.TypeOfLicense__c';
import CONDITION_FIELD from '@salesforce/schema/Account.ConditionOfPerson__c';
import MARITAL_FIELD from '@salesforce/schema/Account.MaritalStatus__c';

import getInsuredDetails from '@salesforce/apex/ClaimSearchController.getInsuredDetails';

export default class Lwc007_DriverInfo extends LightningElement {
    @api claimSummary;
    @api policyId;

    @track formData = {
        QuiEstConducteur__c: '',
        NumberOfInjuredPassengers__c: 0,
        CIN__c: '',
        FirstName: '',
        LastName: '',
        Civility__c: '',
        Pays__c: '',
        Ville__c: '',
        Adresse__c: '',
        DateDeNaissance__c: null,
        Origine_du_permis__c: '',
        TypeOfLicense__c: '',
        LicenseNumber__c: '',
        DateOfIssue__c: null,
        ConditionOfPerson__c: '',
        MaritalStatus__c: ''
    };

    // Options pour les combos
    quiEstConducteurOptions = [{ label: 'Assuré', value: 'Assuré' }, { label: 'Autre', value: 'Autre' }];
    @track civilityOptions = [];
    @track paysOptions = [];
    @track villeOptions = [];
    @track originePermisOptions = [];
    @track typePermisOptions = [];
    @track conditionPersonOptions = [];
    @track maritalStatusOptions = [];

    // --- Récupération des infos de l'objet Account ---
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountMetadata;

    // --- Récupération des valeurs de Picklist ---
    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: CIVILITY_FIELD })
    wiredCivility({ data }) { if (data) this.civilityOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: PAYS_FIELD })
    wiredPays({ data }) { if (data) this.paysOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: VILLE_FIELD })
    wiredVille({ data }) { if (data) this.villeOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: ORIGINE_PERMIS_FIELD })
    wiredOrigine({ data }) { if (data) this.originePermisOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: TYPE_PERMIS_FIELD })
    wiredType({ data }) { if (data) this.typePermisOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: CONDITION_FIELD })
    wiredCondition({ data }) { if (data) this.conditionPersonOptions = data.values; }

    @wire(getPicklistValues, { recordTypeId: '$accountMetadata.data.defaultRecordTypeId', fieldApiName: MARITAL_FIELD })
    wiredMarital({ data }) { if (data) this.maritalStatusOptions = data.values; }

    // --- Handlers ---
    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.formData[field] = value;
        
        // Auto-remplissage si "Assuré" est sélectionné
        if (field === 'QuiEstConducteur__c' && value === 'Assuré') {
            this.fillWithInsuredData();
        }
        
        this.notifyParent();
    }

    async fillWithInsuredData() {
        try {
            const data = await getInsuredDetails({ policyId: this.policyId });
            if (data) {
                // On mappe Name sur LastName et on remplit le reste
                this.formData = { ...this.formData, ...data, LastName: data.Name };
            }
        } catch (error) {
            console.error('Erreur auto-remplissage', error);
        }
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('driverupdate', { detail: this.formData }));
    }

    @api
    validate() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);
        return allValid;
    }
}