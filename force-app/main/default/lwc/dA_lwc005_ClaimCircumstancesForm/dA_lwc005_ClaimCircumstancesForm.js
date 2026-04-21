import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';

// --- CORRECTION : On importe l'objet Case et ses champs ---
import CASE_OBJECT from '@salesforce/schema/Case';
import TRIGGER_FIELD from '@salesforce/schema/Case.TriggeringEventOfClaim__c';
import CAUSE_FIELD from '@salesforce/schema/Case.CausesOfClaim__c';
import PARTY_FIELD from '@salesforce/schema/Case.OpposingParty__c';

export default class DA_lwc005_ClaimCircumstancesForm extends LightningElement {
    @api claimSummary = {};
    
    @track _formData = {
        AnyDamage__c: false,
        CausesAndCircumstances__c: '',
        TriggeringEventOfClaim__c: '',
        CausesOfClaim__c: '',
        OpposingParty__c: '',
        Commentaire__c: '',
        PointsDeChoc__c: '',
        PrecisionsDommages__c: '',
        NumberOfVehiclesInvolved__c: 0
    };
    @track isDamageYes = false;

    @api
    get formData() {
        return this._formData;
    }

    @track triggerOptions = [];
    @track causeOptions = [];
    @track partyOptions = [];
    
    ouiNonOptions = [
        { label: 'Oui', value: 'true' }, 
        { label: 'Non', value: 'false' }
    ];

    // --- 1. Récupération des métadonnées de l'objet CASE ---
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseObjectInfo;

    // --- 2. Récupération dynamique des valeurs de Picklists depuis CASE ---
    @wire(getPicklistValues, { 
        recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: TRIGGER_FIELD 
    })
    wiredTriggerValues({ data, error }) {
        if (data) this.triggerOptions = data.values;
        else if (error) console.error('Erreur Trigger Picklist', error);
    }

    @wire(getPicklistValues, { 
        recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: CAUSE_FIELD 
    })
    wiredCauseValues({ data, error }) {
        if (data) this.causeOptions = data.values;
        else if (error) console.error('Erreur Cause Picklist', error);
    }

    @wire(getPicklistValues, { 
        recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: PARTY_FIELD 
    })
    wiredPartyValues({ data, error }) {
        if (data) this.partyOptions = data.values;
        else if (error) console.error('Erreur Party Picklist', error);
    }

    // --- 3. Gestion des changements des champs ---
    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;

        this._formData = { 
            ...this._formData, 
            [field]: value 
        };

        if (field === 'AnyDamage__c') {
            this.isDamageYes = (value === 'true');
            this._formData.AnyDamage__c = (value === 'true');
        }

        this.notifyParent();
    }

    handlePointChocUpdate(event) {
        this._formData = {
            ...this._formData,
            PointsDeChoc__c: event.detail.clickedParts,
            PrecisionsDommages__c: event.detail.precisionDommage
        };
        this.notifyParent();
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('formupdate', {
            detail: { ...this._formData }
        }));
    }

    @api
    validate() {
        const isFormValid = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

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