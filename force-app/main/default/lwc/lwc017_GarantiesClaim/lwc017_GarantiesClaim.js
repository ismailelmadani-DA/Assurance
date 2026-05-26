import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getClaimCoveragesCatalog from '@salesforce/apex/DA_ClaimCoverageController.getClaimCoveragesCatalog';
import saveClaimCoverages from '@salesforce/apex/DA_ClaimCoverageController.saveClaimCoverages';
import COVERAGE_OBJECT from '@salesforce/schema/InsurancePolicyCoverage__c';
import TYPE_FIELD from '@salesforce/schema/InsurancePolicyCoverage__c.TypeGarantie__c';

const RC_CODE = '001';

export default class Lwc017_GarantiesClaim extends LightningElement {
    @api recordId;

    _rawData = [];
    _localState = new Map();
    _typeLabels = {};
    error;
    isSaving = false;

    @wire(getObjectInfo, { objectApiName: COVERAGE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: TYPE_FIELD
    })
    wiredTypePicklist({ data, error: err }) {
        if (data) {
            this._typeLabels = {};
            data.values.forEach((entry) => {
                this._typeLabels[entry.value] = entry.label;
            });
        } else if (err) {
            this._typeLabels = {};
        }
    }

    connectedCallback() {
        this.loadCoverages();
    }

    loadCoverages() {
        this.error = undefined;
        getClaimCoveragesCatalog({ claimId: this.recordId })
            .then((data) => {
                this._rawData = data;
                this._localState = new Map();
                data.forEach((cov) => {
                    this._localState.set(cov.CodeGarantie__c, cov.GarantieUsed__c);
                });
            })
            .catch((err) => {
                this.error = err.body?.message || 'Erreur lors du chargement des garanties.';
                this._rawData = [];
            });
    }

    get coverages() {
        return this._rawData.map((cov) => {
            const isRC = cov.CodeGarantie__c === RC_CODE;
            const isChecked = isRC ? true : (this._localState.get(cov.CodeGarantie__c) ?? cov.GarantieUsed__c);
            const typeLabel = this._typeLabels[cov.TypeGarantie__c] || cov.TypeGarantie__c || '';
            return {
                ...cov,
                isChecked,
                isDisabled: isRC,
                rowClass: isRC ? 'pm-row--rc' : '',
                checkboxClass: isRC ? 'pm-checkbox pm-checkbox--disabled' : 'pm-checkbox',
                typeLabel
            };
        });
    }

    get hasCoverages() {
        return this._rawData.length > 0;
    }

    get totalLabel() {
        const count = this._rawData.length;
        return `${count} garantie${count > 1 ? 's' : ''}`;
    }

    get hasChanges() {
        return this._rawData.some((cov) => {
            if (cov.CodeGarantie__c === RC_CODE) return false;
            return this._localState.get(cov.CodeGarantie__c) !== cov.GarantieUsed__c;
        });
    }

    handleCheckboxChange(event) {
        const code = event.target.dataset.id;
        const checked = event.target.checked;
        this._localState.set(code, checked);
        this._localState = new Map(this._localState);
    }

    handleSave() {
        this.isSaving = true;
        const selectedCodes = [];
        this._localState.forEach((checked, code) => {
            if (checked) selectedCodes.push(code);
        });

        saveClaimCoverages({ claimId: this.recordId, selectedCodes })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Succès',
                    message: 'Les garanties ont été mises à jour.',
                    variant: 'success'
                }));
                this.loadCoverages();
            })
            .catch((err) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message: err.body?.message || 'Erreur lors de la sauvegarde.',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleRefresh() {
        this.loadCoverages();
    }
}