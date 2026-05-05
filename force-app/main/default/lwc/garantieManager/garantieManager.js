import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getGaranties from '@salesforce/apex/DA_GarantieController.getGaranties';
import saveGarantie from '@salesforce/apex/DA_GarantieController.saveGarantie';

const RC_DEVELOPER_NAME = 'Responsabilite_civile_RC';

export default class GarantieManager extends LightningElement {
    @track garanties = [];
    @track currentRecord = {};
    @track showModal = false;
    @track isLoading = false;
    @track isSaving = false;

    searchKey = '';
    selectedType = 'Tous';
    selectedStatus = 'Tous';

    sortBy = 'code';
    sortDirection = 'asc';

    currentPage = 1;
    pageSize = 10;

    wiredGarantiesResult;

    typeOptions = [
        { label: 'Générale', value: 'Générale' },
        { label: 'Matérielle', value: 'Matérielle' },
        { label: 'Corporelle', value: 'Corporelle' }
    ];

    filterTypeOptions = [
        { label: 'Tous les types', value: 'Tous' },
        { label: 'Générale', value: 'Générale' },
        { label: 'Matérielle', value: 'Matérielle' },
        { label: 'Corporelle', value: 'Corporelle' }
    ];

    statusOptions = [
        { label: 'Tous les statuts', value: 'Tous' },
        { label: 'Actives', value: 'Active' },
        { label: 'Inactives', value: 'Inactive' }
    ];

    pageSizeOptions = [
        { label: '5', value: '5' },
        { label: '10', value: '10' },
        { label: '15', value: '15' },
        { label: '20', value: '20' }
    ];

    @wire(getGaranties)
    wiredGaranties(result) {
        this.wiredGarantiesResult = result;

        if (result.data) {
            this.garanties = result.data;
            this.isLoading = false;
        }

        if (result.error) {
            this.isLoading = false;
            this.showToast(
                'Erreur',
                result.error?.body?.message || 'Erreur lors du chargement des garanties.',
                'error'
            );
        }
    }

    get totalGaranties() {
        return this.garanties.length;
    }

    get totalActives() {
        return this.garanties.filter(g => g.isActive).length;
    }

    get totalInactives() {
        return this.garanties.filter(g => !g.isActive).length;
    }

    get filteredGaranties() {
        let data = [...(this.garanties || [])];

        if (this.searchKey) {
            const key = this.searchKey.toLowerCase();

            data = data.filter(g =>
                (g.code || '').toLowerCase().includes(key) ||
                (g.label || '').toLowerCase().includes(key) ||
                (g.type || '').toLowerCase().includes(key) ||
                (g.developerName || '').toLowerCase().includes(key)
            );
        }

        if (this.selectedType !== 'Tous') {
            data = data.filter(g => g.type === this.selectedType);
        }

        if (this.selectedStatus !== 'Tous') {
            const isActive = this.selectedStatus === 'Active';
            data = data.filter(g => g.isActive === isActive);
        }

        data.sort((a, b) => {
            const valueA = a[this.sortBy] ?? '';
            const valueB = b[this.sortBy] ?? '';

            if (valueA > valueB) {
                return this.sortDirection === 'asc' ? 1 : -1;
            }

            if (valueA < valueB) {
                return this.sortDirection === 'asc' ? -1 : 1;
            }

            return 0;
        });

        return data;
    }

    get totalPages() {
        return Math.ceil(this.filteredGaranties.length / this.pageSize) || 1;
    }

    get paginatedGaranties() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        return this.filteredGaranties.slice(start, end).map(g => {
            let typeClass = 'gm-type-pill';

            if (g.type === 'Générale') {
                typeClass += ' gm-type-pill--blue';
            } else if (g.type === 'Matérielle') {
                typeClass += ' gm-type-pill--green';
            } else if (g.type === 'Corporelle') {
                typeClass += ' gm-type-pill--red';
            } else {
                typeClass += ' gm-type-pill--neutral';
            }

            return {
                ...g,
                activeLabel: g.isActive ? 'Active' : 'Inactive',
                activeClass: g.isActive
                    ? 'gm-badge gm-badge--active'
                    : 'gm-badge gm-badge--inactive',
                typeClass
            };
        });
    }

    get hasGaranties() {
        return this.paginatedGaranties.length > 0;
    }

    get pageInfo() {
        return `Page ${this.currentPage} sur ${this.totalPages}`;
    }

    get resultInfo() {
        const total = this.filteredGaranties.length;
        const start = total === 0 ? 0 : ((this.currentPage - 1) * this.pageSize) + 1;
        const end = Math.min(this.currentPage * this.pageSize, total);

        return `${start}-${end} sur ${total} garanties`;
    }

    get disablePrevious() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    get modalTitle() {
        return this.currentRecord.id ? 'Modifier la garantie' : 'Nouvelle garantie';
    }

    get isRC() {
        return this.currentRecord.developerName === RC_DEVELOPER_NAME;
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
        this.currentPage = 1;
    }

    handleTypeFilter(event) {
        this.selectedType = event.detail.value;
        this.currentPage = 1;
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.detail.value;
        this.currentPage = 1;
    }

    handlePageSizeChange(event) {
        this.pageSize = Number(event.detail.value);
        this.currentPage = 1;
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;

        if (this.sortBy === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortBy = field;
            this.sortDirection = 'asc';
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    async handleRefresh() {
        this.isLoading = true;

        try {
            await refreshApex(this.wiredGarantiesResult);
        } finally {
            this.isLoading = false;
        }
    }

    handleNew() {
        this.currentRecord = {
            id: null,
            label: '',
            code: '',
            type: 'Générale',
            isActive: true,
            developerName: ''
        };

        this.showModal = true;
    }

    handleEdit(event) {
        const recordId = event.currentTarget.dataset.id;
        const row = this.garanties.find(g => g.id === recordId);

        if (row) {
            this.currentRecord = { ...row };
            this.showModal = true;
        }
    }

    handleLabelChange(event) {
        this.currentRecord = { ...this.currentRecord, label: event.detail.value };
    }

    handleCodeChange(event) {
        this.currentRecord = { ...this.currentRecord, code: event.detail.value };
    }

    handleTypeChange(event) {
        this.currentRecord = { ...this.currentRecord, type: event.detail.value };
    }

    handleActiveChange(event) {
        this.currentRecord = { ...this.currentRecord, isActive: event.detail.checked };
    }

    handleCancel() {
        this.showModal = false;
        this.currentRecord = {};
    }

    async handleSave() {
        const codeRegex = /^\d{3}$/;

        if (!this.currentRecord.label || !this.currentRecord.type || !this.currentRecord.code) {
            this.showToast('Champs manquants', 'Veuillez renseigner tous les champs obligatoires.', 'error');
            return;
        }

        if (!codeRegex.test(this.currentRecord.code)) {
            this.showToast(
                'Format invalide',
                'Le code doit contenir exactement 3 chiffres, par exemple : 001, 015, 120.',
                'error'
            );
            return;
        }

        const codeExistant = this.garanties.find(g =>
            g.code === this.currentRecord.code &&
            g.id !== this.currentRecord.id
        );

        if (codeExistant) {
            this.showToast(
                'Code déjà utilisé',
                `Le code "${this.currentRecord.code}" appartient déjà à "${codeExistant.label}".`,
                'error'
            );
            return;
        }

        this.isSaving = true;
        this.showModal = false;
        this.isLoading = true;

        try {
            await saveGarantie({
                record: JSON.stringify(this.currentRecord)
            });

            this.showToast('Enregistrement en cours', 'La garantie a été soumise.', 'info');

            await this.delay(4000);
            await refreshApex(this.wiredGarantiesResult);

            this.showToast('Succès', 'La liste des garanties a été mise à jour.', 'success');
            this.currentRecord = {};
        } catch (error) {
            this.showModal = true;
            this.showToast(
                'Erreur',
                error?.body?.message || 'Une erreur est survenue lors de l’enregistrement.',
                'error'
            );
        } finally {
            this.isSaving = false;
            this.isLoading = false;
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}