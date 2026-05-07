import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin }                    from 'lightning/navigation';
import getVehicleHistory                      from '@salesforce/apex/VehicleHistoryController.getVehicleHistory';

const PAGE_SIZE = 5;

export default class VehicleHistory extends NavigationMixin(LightningElement) {

    @api recordId;

    @track _allVehicles = [];
    @track _filtered    = [];
    @track isLoading    = true;
    @track hasError     = false;
    @track currentPage  = 1;
    @track activeFilter = 'all';

    // ─── Wire ────────────────────────────────────────────────────────────────

    @wire(getVehicleHistory, { accountId: '$recordId' })
    wiredVehicles({ data, error }) {
        this.isLoading = false;

        if (data) {
            this._allVehicles = data.map(v => {
                const isDriver = v.isDriver === true;
                return {
                    ...v,
                    isDriver,
                    brandModel       : v.brandModel || this._composeBrandModel(v.brand, v.model),
                    driverLabel      : isDriver ? 'Oui' : 'Non',
                    driverBadgeClass : isDriver
                        ? 'pm-driver-tag pm-driver-tag--yes'
                        : 'pm-driver-tag pm-driver-tag--no'
                };
            });
            this._applyFilter();
            this.hasError = false;
        } else if (error) {
            console.error('[VehicleHistory] erreur wire :', JSON.stringify(error));
            this.hasError     = true;
            this._allVehicles = [];
            this._filtered    = [];
        }
    }

    _composeBrandModel(brand, model) {
        const b = (brand || '').trim();
        const m = (model || '').trim();
        if (b && m) return `${b} ${m}`;
        return b || m || '—';
    }

    // ─── Getters état ────────────────────────────────────────────────────────

    get isEmpty() {
        return !this.isLoading && !this.hasError && this._filtered.length === 0;
    }

    get hasData() {
        return !this.isLoading && !this.hasError && this._filtered.length > 0;
    }

    // ─── Pagination ──────────────────────────────────────────────────────────

    get totalPages() {
        return Math.max(1, Math.ceil(this._filtered.length / PAGE_SIZE));
    }

    get pagedVehicles() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this._filtered.slice(start, start + PAGE_SIZE);
    }

    get pageLabel() {
        return `Page ${this.currentPage} / ${this.totalPages}`;
    }

    get isPrevDisabled() { return this.currentPage <= 1; }
    get isNextDisabled() { return this.currentPage >= this.totalPages; }

    prevPage() { if (!this.isPrevDisabled) this.currentPage--; }
    nextPage() { if (!this.isNextDisabled) this.currentPage++; }

    // ─── Pills CSS ───────────────────────────────────────────────────────────

    get pillAll()       { return this._pill('all');       }
    get pillDriver()    { return this._pill('driver');    }
    get pillPassenger() { return this._pill('passenger'); }

    _pill(name) {
        return `pm-pill${this.activeFilter === name ? ' pm-pill--active' : ''}`;
    }

    // ─── Filtres ─────────────────────────────────────────────────────────────

    filterAll()       { this._setFilter('all');       }
    filterDriver()    { this._setFilter('driver');    }
    filterPassenger() { this._setFilter('passenger'); }

    _setFilter(name) {
        this.activeFilter = name;
        this.currentPage  = 1;
        this._applyFilter();
    }

    _applyFilter() {
        if (this.activeFilter === 'driver') {
            this._filtered = this._allVehicles.filter(v => v.isDriver === true);
        } else if (this.activeFilter === 'passenger') {
            this._filtered = this._allVehicles.filter(v => v.isDriver === false);
        } else {
            this._filtered = [...this._allVehicles];
        }
    }

    // ─── Navigation Véhicule ─────────────────────────────────────────────────

    handleNavigate(event) {
        event.preventDefault();
        const vehicleId = event.currentTarget.dataset.id;
        if (!vehicleId) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId      : vehicleId,
                objectApiName : 'Vehicule__c',
                actionName    : 'view'
            }
        });
    }

    // ─── Navigation Propriétaire ─────────────────────────────────────────────

    handleNavigateOwner(event) {
        event.preventDefault();
        const ownerId = event.currentTarget.dataset.id;
        if (!ownerId) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId      : ownerId,
                objectApiName : 'Account',
                actionName    : 'view'
            }
        });
    }
}