import { LightningElement, api, track, wire } from 'lwc';
import getPassengers from '@salesforce/apex/PassagerController.getPassengers';
import { refreshApex } from '@salesforce/apex';

const PAGE_SIZE = 10;

export default class DA_lwc007_listesPassagerAssure extends LightningElement {
    @api recordId;

    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track currentPage = 1;
    @track lastRefreshLabel = '';

    wiredPassengersResult;

    @wire(getPassengers, { caseId: '$recordId' })
    wiredPassengers(result) {
        this.wiredPassengersResult = result;

        if (result.data) {
            this.records = (result.data || []).map(r => this._enrichRecord(r));
            this._applyFilter();
            this.hasError = false;
            this.errorMessage = '';
        } else if (result.error) {
            this.records = [];
            this.filteredRecords = [];
            this.hasError = true;
            this.errorMessage = this._cleanError(result.error);
        }

        this.isLoading = false;
    }

    async handleRefresh() {
        if (!this.wiredPassengersResult) {
            return;
        }

        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';

        try {
            this.currentPage = 1;
            await refreshApex(this.wiredPassengersResult);

            const now = new Date();
            this.lastRefreshLabel =
                'Dernière actualisation : ' +
                now.toLocaleTimeString('fr-FR', {
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit'
                });
        } catch (e) {
            this.hasError = true;
            this.errorMessage = this._cleanError(e);
        } finally {
            this.isLoading = false;
        }
    }

    _enrichRecord(r) {
        const stateClass = {
            'Blessé': 'pm-state pm-state--blesse',
            'Décédé': 'pm-state pm-state--deces',
            'Indemne': 'pm-state pm-state--indemne'
        }[r.StateOfPerson__c] || 'pm-state pm-state--default';

        return { ...r, stateClass };
    }

    _applyFilter() {
        this.filteredRecords = this.records.slice(
            (this.currentPage - 1) * PAGE_SIZE,
            this.currentPage * PAGE_SIZE
        );
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.records.length / PAGE_SIZE));
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get hasPassengers() {
        return this.filteredRecords.length > 0;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get prevClass() {
        return `pm-btn pm-btn--page${this.isFirstPage ? ' pm-btn--disabled' : ''}`;
    }

    get nextClass() {
        return `pm-btn pm-btn--page${this.isLastPage ? ' pm-btn--disabled' : ''}`;
    }

    get totalLabel() {
        const n = this.records.length;
        return `${n} passager${n > 1 ? 's' : ''} assuré${n > 1 ? 's' : ''}`;
    }

    prevPage() {
        if (!this.isFirstPage) {
            this.currentPage--;
            this._applyFilter();
        }
    }

    nextPage() {
        if (!this.isLastPage) {
            this.currentPage++;
            this._applyFilter();
        }
    }

    _cleanError(e) {
        const raw = e?.body?.message || e?.message || '';

        if (!raw || raw.includes('FIELD_INTEGRITY') || raw.includes('EXCEPTION') || raw.includes('first error')) {
            return 'Une erreur est survenue lors du traitement. Veuillez réessayer.';
        }

        if (raw.includes('INSUFFICIENT_ACCESS')) {
            return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        }

        return raw;
    }
}