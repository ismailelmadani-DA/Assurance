// vehicleHistory.js
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin }                    from 'lightning/navigation';
import getVehicleHistory                      from '@salesforce/apex/VehicleHistoryController.getVehicleHistory';

const PAGE_SIZE = 5;

const ROLE_BADGE_MAP = {
    'Passager assuré'  : 'pm-badge pm-badge--assured',
    'Passager adverse' : 'pm-badge pm-badge--adverse',
    'Autres partie'    : 'pm-badge pm-badge--other'
};

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
        console.log('[VehicleHistory] wire appelé — recordId:', this.recordId);
        this.isLoading = false;

        if (data) {
            console.log('[VehicleHistory] data reçue :', JSON.stringify(data));
            this._allVehicles = data.map(v => ({
                ...v,
                uniqueKey      : (v.vehicleId || '') + '_' + (v.claimId || ''),
                isDriver       : v.isDriver === true,
                roleBadgeClass : ROLE_BADGE_MAP[v.role] || 'pm-badge pm-badge--other'
            }));
            this._applyFilter();
            this.hasError = false;
        } else if (error) {
            console.error('[VehicleHistory] erreur wire :', JSON.stringify(error));
            this.hasError     = true;
            this._allVehicles = [];
            this._filtered    = [];
        }
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
        console.log('[VehicleHistory] filtrés :', this._filtered.length);
    }

    // ─── Navigation Véhicule ─────────────────────────────────────────────────

    handleNavigate(event) {
        event.preventDefault();
        const vehicleId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId      : vehicleId,
                objectApiName : 'Vehicule__c',
                actionName    : 'view'
            }
        });
    }

    // ─── Navigation Sinistre ─────────────────────────────────────────────────

    handleNavigateClaim(event) {
        event.preventDefault();
        const claimId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId      : claimId,
                objectApiName : 'Sinistre__c',
                actionName    : 'view'
            }
        });
    }
}