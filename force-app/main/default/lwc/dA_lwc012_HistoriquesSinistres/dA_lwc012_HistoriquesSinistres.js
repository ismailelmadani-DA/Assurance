import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHistoriques from '@salesforce/apex/DA_HistoriquesSinistresController.getHistoriques';

const PAGE_SIZE = 10;

export default class DA_lwc012_HistoriquesSinistres extends NavigationMixin(LightningElement) {

    @api recordId;

    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track currentPage = 1;

    @wire(getHistoriques, { passagerId: '$recordId' })
    wiredHistoriques({ data, error }) {
        this.isLoading = true;
        if (data) {
            this.records = data.map(r => ({
                ...r,
                claimUrl: r.claimId ? `/lightning/r/${r.claimId}/view` : '',
                vehiculeUrl: r.vehiculeId ? `/lightning/r/${r.vehiculeId}/view` : '',
                hasVehicule: !!r.vehiculeId,
                hasClaim: !!r.claimId,
                displayClaimNumber: r.claimNumber || '',
                stateClass: this._stateClass(r.etat)
            }));
            this._applyPage();
            this.hasError = false;
        }
        if (error) {
            this.hasError = true;
            this.errorMessage = error?.body?.message || 'Une erreur est survenue.';
            this.records = [];
            this.filteredRecords = [];
        }
        this.isLoading = false;
    }

    _stateClass(etat) {
        const map = {
            'Blessé': 'hs-state hs-state--blesse',
            'Décédé': 'hs-state hs-state--deces',
            'Indemne': 'hs-state hs-state--indemne'
        };
        return map[etat] || 'hs-state hs-state--default';
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