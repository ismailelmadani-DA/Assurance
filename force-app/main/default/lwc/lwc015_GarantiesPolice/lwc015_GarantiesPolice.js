import { LightningElement, api, track } from 'lwc';
import getCoverages from '@salesforce/apex/DA_InsurancePolicyCoverageController.getCoverages';
import saveCaseCoverages from '@salesforce/apex/DA_CaseCoverageController.saveCaseCoverages';
import getSelectedCoverageIds from '@salesforce/apex/DA_CaseCoverageController.getSelectedCoverageIds';

export default class Lwc015_GarantiesPolice extends LightningElement {

    @api claimSummary;
    @api policyId;
    @api caseId;

    @track coverages = [];
    @track isLoading = false;
    @track error;

    connectedCallback() {
        this.loadCoverages();
    }

    async loadCoverages() {
        if (!this.policyId) return;
        this.isLoading = true;
        this.error = undefined;
        try {
            const [data, selectedIds] = await Promise.all([
                getCoverages({ policyId: this.policyId }),
                this.caseId ? getSelectedCoverageIds({ caseId: this.caseId }) : Promise.resolve([])
            ]);
            const selectedSet = new Set(selectedIds || []);
            this.coverages = data.map(cov => ({
                ...cov,
                isChecked: selectedSet.has(cov.Id),
                isDisabled: false,
                rowClass: ''
            }));
        } catch (e) {
            this.error = e.body?.message || 'Erreur lors du chargement des garanties.';
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

    handleCheckboxChange(event) {
        const covId = event.target.dataset.id;
        const checked = event.target.checked;
        this.coverages = this.coverages.map(c =>
            c.Id === covId ? { ...c, isChecked: checked } : c
        );
    }

    @api
    async saveCoverages() {
        const selectedIds = this.coverages
            .filter(c => c.isChecked)
            .map(c => c.Id);

        await saveCaseCoverages({
            caseId: this.caseId,
            policyId: this.policyId,
            selectedCoverageIds: selectedIds
        });
    }
}
