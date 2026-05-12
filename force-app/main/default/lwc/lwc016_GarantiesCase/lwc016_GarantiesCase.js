import { LightningElement, api, track } from 'lwc';
import getCaseCoverages from '@salesforce/apex/DA_CaseCoverageController.getCaseCoverages';

export default class Lwc016_GarantiesCase extends LightningElement {
    @api recordId;

    @track coverages = [];
    @track isLoading = false;
    @track error;

    connectedCallback() {
        this.loadCoverages();
    }

    async loadCoverages() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.error = undefined;
        try {
            const data = await getCaseCoverages({ caseId: this.recordId });
            this.coverages = (data || []).map(c => ({
                key: c.Id,
                code: c.CodeGarantie__c,
                name: c.Name,
                type: c.Insurance_Policy_Coverage__r ? c.Insurance_Policy_Coverage__r.TypeGarantie__c : ''
            }));
        } catch (e) {
            this.error = e.body?.message || 'Erreur lors du chargement des garanties.';
            this.coverages = [];
        } finally {
            this.isLoading = false;
        }
    }

    get hasCoverages() {
        return this.coverages.length > 0;
    }

    get totalLabel() {
        const count = this.coverages.length;
        return `${count} garantie${count > 1 ? 's' : ''}`;
    }

    handleRefresh() {
        this.loadCoverages();
    }
}
