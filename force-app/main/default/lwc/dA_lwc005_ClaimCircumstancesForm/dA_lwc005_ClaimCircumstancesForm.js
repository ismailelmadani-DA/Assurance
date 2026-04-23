import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import TRIGGER_FIELD from '@salesforce/schema/Case.TriggeringEventOfClaim__c';
import CAUSE_FIELD from '@salesforce/schema/Case.CausesOfClaim__c';
import PARTY_FIELD from '@salesforce/schema/Case.OpposingParty__c';

export default class DA_lwc005_ClaimCircumstancesForm extends LightningElement {

    @api claimSummary = {};

    // =========================================================
    // ✅ CORRECTION PRINCIPALE :
    // _formData stocke TOUTES les valeurs saisies.
    // Grâce au binding value={_formData.xxx} dans le HTML,
    // quand on revient sur ce composant les valeurs réapparaissent.
    // =========================================================
    @track _formData = {
        AnyDamage__c: false,
        CausesAndCircumstances__c: '',
        TriggeringEventOfClaim__c: '',
        CausesOfClaim__c: '',
        OpposingParty__c: '',
        Commentaire__c: '',
        PointsDeChoc__c: '',
        PrecisionsDommages__c: '',
        NumberOfVehiclesInvolved__c: null
    };

    @track isDamageYes = false;

    // =========================================================
    // ✅ CORRECTION : Getter pour convertir le booléen AnyDamage__c
    // en string 'true'/'false' pour que le combobox Oui/Non 
    // affiche la bonne valeur sélectionnée au retour
    // =========================================================
    get anyDamageStringValue() {
        if (this._formData.AnyDamage__c === true || this._formData.AnyDamage__c === 'true') {
            return 'true';
        }
        if (this._formData.AnyDamage__c === false || this._formData.AnyDamage__c === 'false') {
            return 'false';
        }
        return ''; // Pas encore sélectionné
    }

    // Exposé au parent pour lire les données
    @api
    get formData() {
        return this._formData;
    }

    // Options Picklists
    @track triggerOptions = [];
    @track causeOptions = [];
    @track partyOptions = [];

    ouiNonOptions = [
        { label: 'Oui', value: 'true' },
        { label: 'Non', value: 'false' }
    ];

    // =========================================================
    // WIRES : Récupération des picklists depuis l'objet Case
    // =========================================================
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseObjectInfo;

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

    // =========================================================
    // ✅ CORRECTION : handleChange sauvegarde dans _formData
    // avec spread operator pour forcer la réactivité LWC
    // =========================================================
    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;

        if (field === 'AnyDamage__c') {
            // On stocke le booléen ET on met à jour l'affichage conditionnel
            this._formData = {
                ...this._formData,
                AnyDamage__c: (value === 'true')
            };
            this.isDamageYes = (value === 'true');
        } else {
            this._formData = {
                ...this._formData,
                [field]: value
            };
        }

        this.notifyParent();
    }

    // Mise à jour des points de choc depuis l'enfant
    handlePointChocUpdate(event) {
        this._formData = {
            ...this._formData,
            PointsDeChoc__c: event.detail.clickedParts,
            PrecisionsDommages__c: event.detail.precisionDommage
        };
        this.notifyParent();
    }

    // Notifie le composant parent à chaque changement
    notifyParent() {
        this.dispatchEvent(new CustomEvent('formupdate', {
            detail: { ...this._formData }
        }));
    }

    // =========================================================
    // Validation appelée par le parent avant de passer à l'étape suivante
    // =========================================================
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