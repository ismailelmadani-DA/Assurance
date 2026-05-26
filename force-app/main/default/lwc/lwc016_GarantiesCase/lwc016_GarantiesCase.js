import { LightningElement, api, wire, track } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getCoveragesCatalog from '@salesforce/apex/DA_CaseCoverageController.getCaseCoveragesCatalog';
import COVERAGE_OBJECT from '@salesforce/schema/InsurancePolicyCoverage__c';
import TYPE_FIELD from '@salesforce/schema/InsurancePolicyCoverage__c.TypeGarantie__c';

export default class Lwc016_GarantiesCase extends LightningElement {
    @api recordId;

    @track _rawData = [];
    _typeLabels = {};
    @track error;
    @track isLoading = false;

    @wire(getObjectInfo, { objectApiName: COVERAGE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: TYPE_FIELD
    })
    wiredTypePicklist({ data }) {
        if (data) {
            this._typeLabels = {};
            data.values.forEach(entry => { this._typeLabels[entry.value] = entry.label; });
        }
    }

    connectedCallback() {
        this.loadCoverages();
    }

    async loadCoverages() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.error = undefined;
        try {
            this._rawData = await getCoveragesCatalog({ caseId: this.recordId });
        } catch (e) {
            this.error = e.body?.message || 'Erreur lors du chargement des garanties.';
            this._rawData = [];
        } finally {
            this.isLoading = false;
        }
    }

    get coverages() {
        return this._rawData.map(cov => ({
            ...cov,
            isChecked: cov.GarantieUsed__c === true,
            typeLabel: this._typeLabels[cov.TypeGarantie__c] || cov.TypeGarantie__c || ''
        }));
    }

    get hasCoverages() {
        return this._rawData.length > 0;
    }

    get totalLabel() {
        const count = this._rawData.length;
        return `${count} garantie${count > 1 ? 's' : ''}`;
    }

    handleRefresh() {
        this.loadCoverages();
    }
}