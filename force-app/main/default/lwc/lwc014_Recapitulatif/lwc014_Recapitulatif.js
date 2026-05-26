import { LightningElement, api, track } from 'lwc';
import getCaseCoverages from '@salesforce/apex/DA_CaseCoverageController.getCaseCoverages';

export default class Lwc014_Recapitulatif extends LightningElement {
    @api policy = {};
    @api caseData = {};
    @api caseNumber = '';
    @api dateSurvenance = '';
    @api driver = {};
    @api passengers = [];
    @api adverseVehicles = [];
    @api otherParties = [];

    @track coverages = [];

    _caseId;
    @api
    get caseId() { return this._caseId; }
    set caseId(value) {
        this._caseId = value;
        this.loadCoverages();
    }

    get hasAdverseVehicles() {
        return this.adverseVehicles && this.adverseVehicles.length > 0;
    }

    get hasOtherParties() {
        return this.otherParties && this.otherParties.length > 0;
    }

    get hasCoverages() {
        return this.coverages && this.coverages.length > 0;
    }

    get passengersCount() {
        return this.passengers ? this.passengers.length : 0;
    }

    async loadCoverages() {
        if (!this._caseId) return;
        try {
            const data = await getCaseCoverages({ caseId: this._caseId });
            this.coverages = (data || []).map(c => ({
                key: c.Id,
                code: c.CodeGarantie__c,
                name: c.Name,
                type: c.Insurance_Policy_Coverage__r ? c.Insurance_Policy_Coverage__r.TypeGarantie__c : ''
            }));
        } catch (e) {
            this.coverages = [];
        }
    }
}