import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';

// Import de l'objet et des champs pour les picklists dynamiques
import CLAIM_OBJECT from '@salesforce/schema/Claim__c';
import TRIGGER_FIELD from '@salesforce/schema/Claim__c.TriggeringEventOfClaim__c';
import CAUSE_FIELD from '@salesforce/schema/Claim__c.CausesOfClaim__c';
import PARTY_FIELD from '@salesforce/schema/Claim__c.OpposingParty__c';

export default class DA_lwc005_ClaimCircumstancesForm extends LightningElement {
    @api claimSummary = {}; // Reçoit les infos du header (Date, Police, etc.)
    @track formData = {};   // Stocke l'ensemble des données du formulaire
    @track isDamageYes = false; // Gère l'affichage du composant Point de Choc

    // Options des listes déroulantes
    @track triggerOptions = [];
    @track causeOptions = [];
    @track partyOptions = [];
    ouiNonOptions = [
        { label: 'Oui', value: 'true' }, 
        { label: 'Non', value: 'false' }
    ];

    // --- 1. Récupération des métadonnées de l'objet Claim ---
    @wire(getObjectInfo, { objectApiName: CLAIM_OBJECT })
    claimObjectInfo;

    // --- 2. Récupération dynamique des valeurs de Picklists ---
    @wire(getPicklistValues, { 
        recordTypeId: '$claimObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: TRIGGER_FIELD 
    })
    wiredTriggerValues({ data, error }) {
        if (data) this.triggerOptions = data.values;
        else if (error) console.error('Erreur Trigger Picklist', error);
    }

    @wire(getPicklistValues, { 
        recordTypeId: '$claimObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: CAUSE_FIELD 
    })
    wiredCauseValues({ data, error }) {
        if (data) this.causeOptions = data.values;
        else if (error) console.error('Erreur Cause Picklist', error);
    }

    @wire(getPicklistValues, { 
        recordTypeId: '$claimObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: PARTY_FIELD 
    })
    wiredPartyValues({ data, error }) {
        if (data) this.partyOptions = data.values;
        else if (error) console.error('Erreur Party Picklist', error);
    }

    // --- 3. Gestion des changements des champs standards ---
    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;

        this.formData[field] = value;

        // Logique spécifique pour afficher/masquer le croquis lwc006
        if (field === 'AnyDamage__c') {
            this.isDamageYes = (value === 'true');
        }

        this.notifyParent();
    }

    // --- 4. Récupération des données du composant enfant (lwc006) ---
    handlePointChocUpdate(event) {
    this.formData.PointsDeChoc__c = event.detail.clickedParts;
    this.formData.PrecisionsDommages__c = event.detail.precisionDommage; // Récupère la valeur envoyée par l'enfant
    this.notifyParent();
}

    // --- 5. Notification du composant Wizard principal ---
    notifyParent() {
        this.dispatchEvent(new CustomEvent('formupdate', {
            detail: { ...this.formData }
        }));
    }

    // --- 6. Méthode de validation publique appelée par le Wizard ---
    @api
    validate() {
        // Validation des éléments HTML locaux (Combobox, Input, Textarea)
        const isFormValid = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        // Validation interne du composant Point de Choc (si affiché)
        let isPointChocValid = true;
        if (this.isDamageYes) {
            const pointChocCmp = this.template.querySelector('c-lwc006_-point-choc');
            if (pointChocCmp) {
                isPointChocValid = pointChocCmp.checkValidity();
            }
        }

        return isFormValid && isPointChocValid;
    }
}