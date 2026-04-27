import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getRIBsByAccountId from '@salesforce/apex/DA_RIBController.getRIBsByAccountId';
import getBanqueLabels from '@salesforce/apex/DA_RIBController.getBanqueLabels';

const PAGE_SIZE = 10;

export default class DA_lwc013_RIBList extends NavigationMixin(LightningElement) {

    @api recordId;

    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track currentPage = 1;

    _wiredResult;
    _banqueLabels = {};

    @wire(getBanqueLabels)
    wiredBanqueLabels({ data }) {
        if (data) this._banqueLabels = data;
    }

    @wire(getRIBsByAccountId, { accountId: '$recordId' })
    wiredRIBs(result) {
        this._wiredResult = result;
        const { data, error } = result;
        this.isLoading = true;
        if (data) {
            this.records = data.map(r => ({
                id: r.Id,
                name: r.Name || '',
                rib: r.RIB__c || '',
                banque: this._banqueLabels[r.CodeBanque__c] || r.CodeBanque__c || '',
                codeBanque: r.CodeBanque__c || '',
                actif: r.Actif__c,
                actifLabel: r.Actif__c ? 'Oui' : 'Non',
                actifClass: r.Actif__c ? 'rib-badge rib-badge--actif' : 'rib-badge rib-badge--inactif'
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

    _applyPage() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        this.filteredRecords = this.records.slice(start, start + PAGE_SIZE);
    }

    get hasRecords() { return this.records.length > 0; }
    get totalLabel() { return `${this.records.length} RIB${this.records.length > 1 ? 's' : ''}`; }
    get totalPages() { return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE)); }
    get showPagination() { return this.totalPages > 1; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get prevClass() { return `rib-btn rib-btn--page${this.isFirstPage ? ' rib-btn--disabled' : ''}`; }
    get nextClass() { return `rib-btn rib-btn--page${this.isLastPage ? ' rib-btn--disabled' : ''}`; }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => { this.isLoading = false; });
    }

    navigateToRecord(event) {
        const recId = event.currentTarget.dataset.id;
        if (recId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: recId, actionName: 'view' }
            });
        }
    }

    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyPage(); } }
    nextPage() { if (!this.isLastPage) { this.currentPage++; this._applyPage(); } }
}
