import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';

import CASE_OBJECT from '@salesforce/schema/Case';
import TRIGGER_FIELD from '@salesforce/schema/Case.TriggeringEventOfClaim__c';
import CAUSE_FIELD from '@salesforce/schema/Case.CausesOfClaim__c';
import PARTY_FIELD from '@salesforce/schema/Case.OpposingParty__c';

export default class DA_lwc005_ClaimCircumstancesForm extends LightningElement {
    @api claimSummary = {};

    @api
    get savedFormData() {
        return this._formData;
    }
    set savedFormData(value) {
        if (value) {
            this._formData = { ...this._formData, ...value };
            if (value.AnyDamage__c === true || value.AnyDamage__c === 'true') {
                this.isDamageYes = true;
            }
            if (value.PointsDeChoc__c) {
                this._savedPointsDeChoc = value.PointsDeChoc__c;
                this._savedPrecisions = value.PrecisionsDommages__c;
            }
        }
    }

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

    _savedPointsDeChoc = '';
    _savedPrecisions = '';

    @api
    get formData() {
        return this._formData;
    }

    @track triggerOptions = [];
    @track _allCauseValues = [];
    @track _causeControllerValues = {};
    @track partyOptions = [];

    ouiNonOptions = [
        { label: 'Oui', value: 'true' },
        { label: 'Non', value: 'false' }
    ];

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseObjectInfo;

    get declarationRecordTypeId() {
        const infos = this.caseObjectInfo && this.caseObjectInfo.data && this.caseObjectInfo.data.recordTypeInfos;
        if (!infos) return undefined;
        for (const id in infos) {
            const info = infos[id];
            if (!info.master && (info.name === 'Declaration' || info.developerName === 'Declaration')) {
                return info.recordTypeId;
            }
        }
        return this.caseObjectInfo.data.defaultRecordTypeId;
    }

    @wire(getPicklistValues, {
        recordTypeId: '$declarationRecordTypeId',
        fieldApiName: TRIGGER_FIELD
    })
    wiredTriggerValues({ data, error }) {
        if (data) this.triggerOptions = data.values;
    }

    @wire(getPicklistValues, {
        recordTypeId: '$declarationRecordTypeId',
        fieldApiName: CAUSE_FIELD
    })
    wiredCauseValues({ data, error }) {
        if (data) {
            this._allCauseValues = data.values;
            this._causeControllerValues = data.controllerValues || {};
        }
    }

    get causeOptions() {
        const trigger = this._formData.TriggeringEventOfClaim__c;
        if (!trigger) {
            return [];
        }
        const controllerIndex = this._causeControllerValues[trigger];
        if (controllerIndex === undefined) {
            return [];
        }
        return this._allCauseValues
            .filter((v) => Array.isArray(v.validFor) && v.validFor.includes(controllerIndex))
            .map((v) => ({ label: v.label, value: v.value }));
    }

    @wire(getPicklistValues, {
        recordTypeId: '$declarationRecordTypeId',
        fieldApiName: PARTY_FIELD
    })
    wiredPartyValues({ data, error }) {
        if (data) this.partyOptions = data.values;
    }

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

        if (field === 'TriggeringEventOfClaim__c') {
            this._formData = { ...this._formData, CausesOfClaim__c: '' };
        }

        this.notifyParent();
    }

    handlePointChocUpdate(event) {
        this._formData = {
            ...this._formData,
            PointsDeChoc__c: event.detail.clickedParts,
            PrecisionsDommages__c: event.detail.precisionDommage
        };
        this._savedPointsDeChoc = event.detail.clickedParts;
        this._savedPrecisions = event.detail.precisionDommage;
        this.notifyParent();
    }

    notifyParent() {
        this.dispatchEvent(new CustomEvent('formupdate', {
            detail: { ...this._formData }
        }));
    }

    get pointsDeChocSaved() {
        return this._savedPointsDeChoc;
    }

    get precisionsSaved() {
        return this._savedPrecisions;
    }

    get anyDamageValue() {
        if (this._formData.AnyDamage__c === true) return 'true';
        if (this._formData.AnyDamage__c === false) return 'false';
        return this._formData.AnyDamage__c; 
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