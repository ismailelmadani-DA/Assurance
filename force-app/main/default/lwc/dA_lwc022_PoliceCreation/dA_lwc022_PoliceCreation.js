import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
    IsConsoleNavigation,
    EnclosingTabId,
    closeTab,
    openTab
} from 'lightning/platformWorkspaceApi';

import getGarantiesMetadata      from '@salesforce/apex/DA_lwc022_PoliceCreationController.getGarantiesMetadata';
import checkCin                  from '@salesforce/apex/DA_lwc022_PoliceCreationController.checkCin';
import checkImmatriculation      from '@salesforce/apex/DA_lwc022_PoliceCreationController.checkImmatriculation';
import creerPolice               from '@salesforce/apex/DA_lwc022_PoliceCreationController.creerPolice';

import getCategorieOptions       from '@salesforce/apex/DA_lwc022_PoliceCreationController.getCategorieOptions';
import getCanalOptions           from '@salesforce/apex/DA_lwc022_PoliceCreationController.getCanalOptions';
import getSituationPoliceOptions from '@salesforce/apex/DA_lwc022_PoliceCreationController.getSituationPoliceOptions';
import getSituationPrimeOptions  from '@salesforce/apex/DA_lwc022_PoliceCreationController.getSituationPrimeOptions';

import getPaysOptions            from '@salesforce/apex/DA_lwc022_PoliceCreationController.getPaysOptions';
import getDependentVilleOptions  from '@salesforce/apex/DA_lwc022_PoliceCreationController.getDependentVilleOptions';

import getTypeVehiculeOptions    from '@salesforce/apex/DA_lwc022_PoliceCreationController.getTypeVehiculeOptions';
import getMarqueOptions          from '@salesforce/apex/DA_lwc022_PoliceCreationController.getMarqueOptions';
import getDependentModeleOptions from '@salesforce/apex/DA_lwc022_PoliceCreationController.getDependentModeleOptions';
import getNextNumeroPolice       from '@salesforce/apex/DA_lwc022_PoliceCreationController.getNextNumeroPolice';

export default class DA_lwc022_PoliceCreation extends NavigationMixin(LightningElement) {

    @wire(IsConsoleNavigation) isConsole;
    @wire(EnclosingTabId)      tabId;

    // --- TABLEAU CUSTOM GARANTIES ---
    @track garSortField = 'nom';
    @track garSortDir   = 'asc';
    
    // --- PAGINATION GARANTIES (Logique LWC 020) ---
    @track currentPage = 1;
    @track pageSize = 10;

    @track showCinPopup           = false;
    @track showVehiculeBlockPopup = false;
    @track showVehiculeWarnPopup  = false;
    @track vehiculeWarnMessage    = '';

    @track cinConfirmed       = false;
    @track vehiculeConfirmed  = false;
    @track vehiculeExistantId = '';
    @track anciennePoliceId   = '';

    @track garanties         = [];
    @track selectedGaranties = [];

    @track categorieOptions       = [];
    @track canalOptions           = [];
    @track situationPoliceOptions = [];
    @track situationPrimeOptions  = [];

    @track paysOptions          = [];
    @track villeOptionsFiltrees = [];
    _dependentVilleOptions      = {};

    @track typeVehiculeOptions = [];
    @track marqueOptions       = [];
    @track modeleOptions       = [];
    _dependentModeleOptions    = {};

    @track formData = {
        numeroPolice:          '',
        categorie:             '',
        dateEffet:             '',
        dateExpiration:        '',
        canal:                 '',
        situationPolice:       '',
        situationPrime:        '',
        nomComplet:            '',
        cin:                   '',
        telephone:             '',
        email:                 '',
        pays:                  '',
        ville:                 '',
        adresse:               '',
        immatriculation:       '',
        typeVehicule:          '',
        marque:                '',
        modele:                '',
        numeroChassis:         '',
        numeroAttestation:     '',
        dateMiseEnCirculation: ''
    };

    @track sections = [
        { index: 0, num: 1, label: 'Informations de la police', isOpen: true,  isDone: false, isLast: false },
        { index: 1, num: 2, label: "Informations de l'assuré",  isOpen: false, isDone: false, isLast: false },
        { index: 2, num: 3, label: 'Informations du véhicule',  isOpen: false, isDone: false, isLast: false },
        { index: 3, num: 4, label: 'Choix des garanties',       isOpen: false, isDone: false, isLast: true  }
    ];

    @track errors = {
        numeroPolice:          '',
        categorie:             '',
        dateEffet:             '',
        dateExpiration:        '',
        situationPrime:        '',
        nomComplet:            '',
        cin:                   '',
        telephone:             '',
        email:                 '',
        pays:                  '',
        ville:                 '',
        immatriculation:       '',
        typeVehicule:          '',
        dateMiseEnCirculation: ''
    };


    connectedCallback() {
        this._loadPicklistsSection1();
        this._loadPaysVille();
        this._loadVehiculePicklists();
        this.loadGaranties();
        this._loadNextNumeroPolice();
    }

    // ─── CHARGEMENT ───────────────────────────────────────────────

    _loadPicklistsSection1() {
        getCategorieOptions()
            .then(data => { this.categorieOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('categorieOptions', err));
        getCanalOptions()
            .then(data => { this.canalOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('canalOptions', err));
        getSituationPoliceOptions()
            .then(data => { this.situationPoliceOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('situationPoliceOptions', err));
        getSituationPrimeOptions()
            .then(data => { this.situationPrimeOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('situationPrimeOptions', err));
    }

    _loadPaysVille() {
        getPaysOptions()
            .then(data => { this.paysOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('paysOptions', err));

        getDependentVilleOptions()
            .then(data => {
                this._dependentVilleOptions = data;
                if (data['Maroc']) {
                    this.villeOptionsFiltrees = [...data['Maroc']];
                    this.formData = { ...this.formData, pays: 'Maroc' };
                }
            })
            .catch(err => console.error('villeOptions', err));
    }

    _loadVehiculePicklists() {
        getTypeVehiculeOptions()
            .then(data => { this.typeVehiculeOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('typeVehiculeOptions', err));
        getMarqueOptions()
            .then(data => { this.marqueOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err => console.error('marqueOptions', err));
        getDependentModeleOptions()
            .then(data => { this._dependentModeleOptions = data; })
            .catch(err => console.error('modeleOptions', err));
    }

    loadGaranties() {
        getGarantiesMetadata()
            .then(result => {
                this.garanties = result;
                const rc = result.find(g => g.code === '001');
                if (rc && !this.selectedGaranties.includes(rc.id)) {
                    this.selectedGaranties = [rc.id];
                }
            })
            .catch(err => console.error('garanties', err));
    }

    _loadNextNumeroPolice() {
        getNextNumeroPolice()
            .then(num => {
                this.formData = { ...this.formData, numeroPolice: num };
            })
            .catch(err => console.error('numeroPolice', err));
    }

    // ─── HANDLER PRINCIPAL ────────────────────────────────────────

    handleChange(event) {
        const value = event.detail.value !== undefined
            ? event.detail.value
            : event.target.value;
        const name = event.target.name;
        if (!name) return;

        this.formData = { ...this.formData, [name]: value };

        // Effacer l'erreur du champ modifié
        if (this.errors[name] !== undefined) {
            this.errors = { ...this.errors, [name]: '' };
        }

        if (name === 'pays')   this._filterVilles(value);
        if (name === 'marque') this._filterModeles(value);
    }

    // ─── FILTRES DÉPENDANTS ───────────────────────────────────────

    _filterVilles(pays) {
        const options = this._dependentVilleOptions[pays];
        this.villeOptionsFiltrees = Array.isArray(options) ? [...options] : [];
        this.formData = { ...this.formData, ville: '' };
    }

    _filterModeles(marque) {
        const options = this._dependentModeleOptions[marque];
        this.modeleOptions = Array.isArray(options) ? [...options] : [];
        this.formData = { ...this.formData, modele: '' };
    }

    // ─── GETTERS — VALIDATION BOUTONS ─────────────────────────────

    get isSec0Valid() {
        return !!(
            this.formData.categorie &&
            this.formData.dateEffet &&
            this.formData.dateExpiration &&
            this.formData.situationPrime
        );
    }

    get isSec1Valid() {
        return !!(
            this.formData.nomComplet &&
            this.formData.cin &&
            this.formData.telephone &&
            this.formData.email &&
            this.formData.pays &&
            this.formData.ville
        );
    }

    get isSec2Valid() {
        return !!(
            this.formData.immatriculation &&
            this.formData.typeVehicule &&
            this.formData.dateMiseEnCirculation
        );
    }

    get isSec3Valid() {
        return this.selectedGaranties.length > 0;
    }

    get isSec0BtnDisabled() { return !this.isSec0Valid; }
    get isSec1BtnDisabled() { return !this.isSec1Valid; }
    get isSec2BtnDisabled() { return !this.isSec2Valid; }
    get isSec3BtnDisabled() { return !this.isSec3Valid; }

    get isConfirmDisabled() {
        return !(
            this.sections[0].isDone &&
            this.sections[1].isDone &&
            this.sections[2].isDone &&
            this.sections[3].isDone
        );
    }

    // ─── GETTERS — AFFICHAGE ET PAGINATION ────────────────────────

    /**
     * Retourne la liste complète triée (RC toujours en haut)
     */
    get sortedGaranties() {
        const dir = this.garSortDir === 'asc' ? 1 : -1;

        const pinned = this.garanties.filter(g => g.code === '001');
        const others = this.garanties.filter(g => g.code !== '001');

        const sorted = [...others].sort((a, b) => {
            const va = (a[this.garSortField] || '').toLowerCase();
            const vb = (b[this.garSortField] || '').toLowerCase();
            if (va < vb) return -1 * dir;
            if (va > vb) return  1 * dir;
            return 0;
        });

        return [...pinned, ...sorted].map(g => {
            const isSelected = this.selectedGaranties.includes(g.id);
            const isLocked   = g.code === '001';
            return {
                ...g,
                isLocked,
                rowClass  : `gar-tr${isSelected ? ' gar-tr--selected' : ''}${isLocked ? ' gar-tr--locked' : ''}`,
                checkClass: `gar-custom-check${isSelected ? ' gar-custom-check--checked' : ''}${isLocked ? ' gar-custom-check--locked' : ''}`
            };
        });
    }

    /**
     * Retourne uniquement les garanties de la page courante
     */
    get paginatedGaranties() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.sortedGaranties.slice(start, start + this.pageSize);
    }

    get totalPages() {
        return Math.ceil(this.garanties.length / this.pageSize) || 1;
    }

    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage()  { return this.currentPage === this.totalPages; }

    get rowsInfo() {
        const total = this.garanties.length;
        if (total === 0) return '0 garanties';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end   = Math.min(this.currentPage * this.pageSize, total);
        return `${start}-${end} sur ${total} garanties`;
    }

    get pageNumbers() {
        const total = this.totalPages;
        const current = this.currentPage;
        const pages = [];

        const addPage = (p) => pages.push({
            key: `p-${p}`,
            page: p,
            label: String(p),
            isEllipsis: false,
            btnClass: `ev-btn ev-btn--page${current === p ? ' ev-btn--page-active' : ''}`
        });
        const addEllipsis = (key) => pages.push({ key, page: null, label: '…', isEllipsis: true });

        if (total <= 5) {
            for (let i = 1; i <= total; i++) addPage(i);
        } else {
            addPage(1);
            if (current > 3) addEllipsis('e1');
            const start = Math.max(2, current - 1);
            const end = Math.min(total - 1, current + 1);
            for (let i = start; i <= end; i++) addPage(i);
            if (current < total - 2) addEllipsis('e2');
            addPage(total);
        }
        return pages;
    }

    get selectedCount()      { return this.selectedGaranties.length; }
    get isVilleDisabled()    { return !this.formData.pays;   }
    get isModeleDisabled()   { return !this.formData.marque; }

    get garThNomClass() {
        let c = 'gar-th gar-th--sortable';
        if (this.garSortField === 'nom') {
            c += ' gar-th--sorted ' + (this.garSortDir === 'asc' ? 'gar-th--asc' : 'gar-th--desc');
        }
        return c;
    }

    get garThCodeClass() {
        let c = 'gar-th gar-th--sortable';
        if (this.garSortField === 'code') {
            c += ' gar-th--sorted ' + (this.garSortDir === 'asc' ? 'gar-th--asc' : 'gar-th--desc');
        }
        return c;
    }

    get progressPercentage() {
        return Math.round((this.sections.filter(s => s.isDone).length / this.sections.length) * 100);
    }
    get progressStyle() { return `width: ${this.progressPercentage}%`; }
    get motivationMessage() {
        const p = this.progressPercentage;
        if (p === 0)   return "C'est parti !";
        if (p < 100)   return "Presque terminé !";
        return "Parfait, prêt à valider !";
    }
    get currentStepNumber() {
        const i = this.sections.findIndex(s => s.isOpen);
        return i >= 0 ? i + 1 : this.sections.filter(s => s.isDone).length;
    }
    get steps() {
        return this.sections.map(s => {
            const isActive = s.isOpen && !s.isDone;
            return {
                ...s,
                id       : `step-${s.index}`,
                isActive,
                cssClass : `sb-step${s.isOpen ? ' active' : ''}${s.isDone ? ' done' : ''}`,
                dotClass : `sb-dot${s.isDone ? ' done' : ''}${isActive ? ' active' : ''}`,
                lineClass: `step-line${s.isDone ? ' done' : ''}`
            };
        });
    }

    get section0Class() { return this._sectionClass(0); }
    get section1Class() { return this._sectionClass(1); }
    get section2Class() { return this._sectionClass(2); }
    get section3Class() { return this._sectionClass(3); }
    _sectionClass(idx) {
        let c = 'acc-item';
        if (this.sections[idx].isOpen) c += ' active';
        if (this.sections[idx].isDone) c += ' done';
        return c;
    }

    get accNum0() { return this._accNumClass(0); }
    get accNum1() { return this._accNumClass(1); }
    get accNum2() { return this._accNumClass(2); }
    get accNum3() { return this._accNumClass(3); }
    _accNumClass(idx) {
        let c = 'acc-num';
        if (this.sections[idx].isOpen) c += ' active';
        if (this.sections[idx].isDone) c += ' done';
        return c;
    }

    get sec0Open() { return this.sections[0].isOpen; }
    get sec1Open() { return this.sections[1].isOpen; }
    get sec2Open() { return this.sections[2].isOpen; }
    get sec3Open() { return this.sections[3].isOpen; }
    get sec0Done() { return this.sections[0].isDone; }
    get sec1Done() { return this.sections[1].isDone; }
    get sec2Done() { return this.sections[2].isDone; }
    get sec3Done() { return this.sections[3].isDone; }
    get sec0Arrow() { return this.sections[0].isOpen ? '▲' : '▼'; }
    get sec1Arrow() { return this.sections[1].isOpen ? '▲' : '▼'; }
    get sec2Arrow() { return this.sections[2].isOpen ? '▲' : '▼'; }
    get sec3Arrow() { return this.sections[3].isOpen ? '▲' : '▼'; }

    // ─── HANDLERS UI ──────────────────────────────────────────────

    handleGarantieRowClick(event) {
        const id     = event.currentTarget.dataset.id;
        const locked = event.currentTarget.dataset.locked === 'true';
        if (locked) return;
        const already = this.selectedGaranties.includes(id);
        this.selectedGaranties = already
            ? this.selectedGaranties.filter(s => s !== id)
            : [...this.selectedGaranties, id];
    }

    handleSelectAll() {
        const unlocked    = this.garanties.filter(g => g.code !== '001').map(g => g.id);
        const rcId        = (this.garanties.find(g => g.code === '001') || {}).id;
        const allSelected = unlocked.every(id => this.selectedGaranties.includes(id));
        const base        = rcId ? [rcId] : [];
        this.selectedGaranties = allSelected ? base : [...new Set([...base, ...unlocked])];
    }

    handleGarSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.garSortField === field) {
            this.garSortDir = this.garSortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.garSortField = field;
            this.garSortDir   = 'asc';
        }
        this.currentPage = 1; // Retour en page 1 après un tri
    }

    // --- NAVIGATION PAGINATION ---
    prevPage()  { if (this.currentPage > 1) this.currentPage--; }
    nextPage()  { if (this.currentPage < this.totalPages) this.currentPage++; }
    firstPage() { this.currentPage = 1; }
    lastPage()  { this.currentPage = this.totalPages; }

    goToPage(event) {
        const page = Number(event.currentTarget.dataset.page);
        if (page && page !== this.currentPage) this.currentPage = page;
    }

    markDone(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (!this._validateSection(idx)) return;
        this.sections = this.sections.map((s, i) => {
            if (i === idx)     return { ...s, isDone: true,  isOpen: false };
            if (i === idx + 1) return { ...s, isOpen: true };
            return s;
        });
    }

    handleStepClick(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.sections = this.sections.map((s, i) => ({ ...s, isOpen: i === idx }));
    }

    handleSectionToggle(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.sections = this.sections.map((s, i) => ({
            ...s, isOpen: i === idx ? !s.isOpen : s.isOpen
        }));
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'home' }
        });
    }

    async handleConfirm() {
        if (!this._validateAll()) return;
        try {
            if (!this.cinConfirmed) {
                const cinResult = await checkCin({ cin: this.formData.cin });
                if (cinResult.exists) { this.showCinPopup = true; return; }
                this.cinConfirmed = true;
            }
            if (!this.vehiculeConfirmed) {
                const immaResult = await checkImmatriculation({ immatriculation: this.formData.immatriculation });
                if (immaResult.exists) {
                    if (immaResult.isBlocked) { this.showVehiculeBlockPopup = true; return; }
                    this.vehiculeExistantId  = immaResult.vehiculeId;
                    this.anciennePoliceId    = immaResult.anciennePoliceId;
                    this.vehiculeWarnMessage = `Ce véhicule est déjà assigné à la police [${immaResult.numeroPolice}] - [${immaResult.situationPolice}], êtes-vous sûr de vouloir créer une nouvelle police ?`;
                    this.showVehiculeWarnPopup = true;
                    return;
                }
                this.vehiculeConfirmed = true;
            }
            await this._callCreerPolice();
        } catch (error) {
            this._showToast('Erreur', error?.body?.message || error?.message, 'error');
        }
    }

    async _callCreerPolice() {
        const garantiesData = this.garanties
            .filter(g => this.selectedGaranties.includes(g.id))
            .map(g => JSON.stringify({ nom: g.nom, code: g.code, type: g.type }));

        const newPoliceId = await creerPolice({
            formData:           JSON.stringify(this.formData),
            garanties:          garantiesData,
            cinConfirmed:       this.cinConfirmed,
            vehiculeConfirmed:  this.vehiculeConfirmed,
            vehiculeExistantId: this.vehiculeExistantId || '',
            anciennePoliceId:   this.anciennePoliceId   || ''
        });

        this._showToast('Succès !', "La police d'assurance a été créée avec succès.", 'success');
        const tabIdToClose = this.tabId;

        await openTab({
            pageReference: {
                type: 'standard__recordPage',
                attributes: { recordId: newPoliceId, objectApiName: 'InsurancePolicy__c', actionName: 'view' }
            },
            focus: true
        });

        if (tabIdToClose) await closeTab(tabIdToClose);
    }

    // ─── VALIDATIONS ──────────────────────────────────────────────

    _validateSection(idx) {
        let ok = true;

        if (idx === 0) {
            const e = { ...this.errors };
            if (!this.formData.dateEffet) {
                e.dateEffet = 'Ce champ est obligatoire.'; ok = false;
            } else { e.dateEffet = ''; }

            if (!this.formData.dateExpiration) {
                e.dateExpiration = 'Ce champ est obligatoire.'; ok = false;
            } else { e.dateExpiration = ''; }

            if (!this.formData.categorie) {
                e.categorie = 'Ce champ est obligatoire.'; ok = false;
            } else { e.categorie = ''; }

            if (!this.formData.situationPrime) {
                e.situationPrime = 'Ce champ est obligatoire.'; ok = false;
            } else { e.situationPrime = ''; }

            this.errors = e;
        }

        if (idx === 1) {
            const e = { ...this.errors };

            if (!this.formData.nomComplet) {
                e.nomComplet = 'Ce champ est obligatoire.'; ok = false;
            } else { e.nomComplet = ''; }

            if (!this.formData.cin) {
                e.cin = 'Ce champ est obligatoire.'; ok = false;
            } else { e.cin = ''; }

            if (!this.formData.telephone) {
                e.telephone = 'Ce champ est obligatoire.'; ok = false;
            } else { e.telephone = ''; }

            if (!this.formData.email) {
                e.email = 'Ce champ est obligatoire.'; ok = false;
            } else { e.email = ''; }

            if (!this.formData.pays) {
                e.pays = 'Ce champ est obligatoire.'; ok = false;
            } else { e.pays = ''; }

            if (!this.formData.ville) {
                e.ville = 'Ce champ est obligatoire.'; ok = false;
            } else { e.ville = ''; }

            this.errors = e;
        }

        if (idx === 2) {
            const e = { ...this.errors };

            if (!this.formData.immatriculation) {
                e.immatriculation = 'Ce champ est obligatoire.'; ok = false;
            } else { e.immatriculation = ''; }

            if (!this.formData.typeVehicule) {
                e.typeVehicule = 'Ce champ est obligatoire.'; ok = false;
            } else { e.typeVehicule = ''; }

            if (!this.formData.dateMiseEnCirculation) {
                e.dateMiseEnCirculation = 'Ce champ est obligatoire.'; ok = false;
            } else { e.dateMiseEnCirculation = ''; }

            this.errors = e;
        }

        return ok;
    }

    _validateAll() {
        if (this.selectedGaranties.length === 0) {
            this._showToast('Erreur', 'Sélectionnez au moins une garantie.', 'warning');
            return false;
        }
        return true;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─── POPUPS ───────────────────────────────────────────────────

    closeCinPopup()           { this.showCinPopup = false; }
    confirmCin()              { this.cinConfirmed = true; this.showCinPopup = false; this.handleConfirm(); }
    closeVehiculeBlockPopup() { this.showVehiculeBlockPopup = false; }
    closeVehiculeWarnPopup()  { this.showVehiculeWarnPopup = false; this.vehiculeConfirmed = false; }
    confirmVehicule()         { this.vehiculeConfirmed = true; this.showVehiculeWarnPopup = false; this.handleConfirm(); }
}