import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getCoverages from '@salesforce/apex/DA_InsurancePolicyCoverageController.getCoverages';
import saveCoverages from '@salesforce/apex/DA_InsurancePolicyCoverageController.saveCoverages';
import COVERAGE_OBJECT from '@salesforce/schema/InsurancePolicyCoverage__c';
import TYPE_FIELD from '@salesforce/schema/InsurancePolicyCoverage__c.TypeGarantie__c';

const RC_NAME = 'Responsabilité civile (RC)';

export default class DA_lwc024_GarantiesPolice extends LightningElement {
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
        getCoverages({ policyId: this.recordId })
            .then((data) => {
                this._rawData = data;
                this._localState = new Map();
                data.forEach((cov) => {
                    this._localState.set(cov.Id, cov.GarantieUsed__c);
                });
            })
            .catch((err) => {
                this.error = err.body?.message || 'Erreur lors du chargement des garanties.';
                this._rawData = [];
            });
    }

    get coverages() {
        return this._rawData.map((cov) => {
            const isRC = cov.NomDeLaGarantie__c === RC_NAME;
            const isChecked = isRC ? true : (this._localState.get(cov.Id) ?? cov.GarantieUsed__c);
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
            if (cov.NomDeLaGarantie__c === RC_NAME) return false;
            return this._localState.get(cov.Id) !== cov.GarantieUsed__c;
        });
    }

    handleCheckboxChange(event) {
        const covId = event.target.dataset.id;
        const checked = event.target.checked;
        this._localState.set(covId, checked);
        this._localState = new Map(this._localState);
    }

    handleSave() {
        this.isSaving = true;
        const selectedIds = [];
        this._localState.forEach((checked, id) => {
            if (checked) selectedIds.push(id);
        });

        saveCoverages({ policyId: this.recordId, selectedIds })
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