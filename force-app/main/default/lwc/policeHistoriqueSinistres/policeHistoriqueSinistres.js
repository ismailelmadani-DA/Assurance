import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getSinistresByPolice from '@salesforce/apex/PoliceSinistresController.getSinistresByPolice';

const PAGE_SIZE = 10;

export default class PoliceHistoriqueSinistres extends NavigationMixin(LightningElement) {

    @api recordId;

    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track currentPage = 1;

    _wiredResult;

    @wire(getSinistresByPolice, { policyId: '$recordId' })
    wiredSinistres(result) {
        this._wiredResult = result;
        const { data, error } = result;
        this.isLoading = true;
        if (data) {
            this.records = data.map((r) => ({
                id: r.id,
                claimNumber: r.claimNumber || '',
                vehiculeId: r.vehiculeId,
                immatriculation: r.immatriculation || '',
                dateSurvenance: r.dateSurvenance,
                lieuSurvenance: r.lieuSurvenance || '',
                statut: r.statut || '',
                createdById: r.createdById,
                createdByName: r.createdByName || '',
                hasVehicule: !!r.vehiculeId && !!r.immatriculation,
                hasCreator: !!r.createdById,
                hasDate: !!r.dateSurvenance,
                hasLieu: !!r.lieuSurvenance,
                statutClass: this._statutClass(r.statut)
            }));
            this._applyPage();
            this.hasError = false;
            this.errorMessage = '';
        }
        if (error) {
            this.hasError = true;
            this.errorMessage = error?.body?.message || 'Une erreur est survenue.';
            this.records = [];
            this.filteredRecords = [];
        }
        this.isLoading = false;
    }

    _statutClass(statut) {
        const map = {
            'Ouvert': 'hs-state hs-state--open',
            'En cours': 'hs-state hs-state--inprogress',
            "En cours d'instruction": 'hs-state hs-state--inprogress',
            'Clôturé': 'hs-state hs-state--closed',
            'Cloturé': 'hs-state hs-state--closed',
            'Rejeté': 'hs-state hs-state--rejected'
        };
        return map[statut] || 'hs-state hs-state--default';
    }

    _applyPage() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        this.filteredRecords = this.records.slice(start, start + PAGE_SIZE);
    }

    get hasRecords() { return this.records.length > 0; }
    get totalLabel() { return `${this.records.length} sinistre${this.records.length > 1 ? 's' : ''}`; }
    get totalPages() { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get prevClass() { return `hs-btn hs-btn--page${this.isFirstPage ? ' hs-btn--disabled' : ''}`; }
    get nextClass() { return `hs-btn hs-btn--page${this.isLastPage ? ' hs-btn--disabled' : ''}`; }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => { this.isLoading = false; });
    }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyPage(); } }
    nextPage() { if (!this.isLastPage) { this.currentPage++; this._applyPage(); } }

    navigateToRecord(event) {
        const recId = event.currentTarget.dataset.id;
        if (recId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: recId, actionName: 'view' }
            });
        }
    }
}