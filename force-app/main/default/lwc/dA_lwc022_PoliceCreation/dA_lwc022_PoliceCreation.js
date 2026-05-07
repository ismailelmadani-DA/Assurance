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

export default class DA_lwc022_PoliceCreation extends NavigationMixin(LightningElement) {

    @wire(IsConsoleNavigation) isConsole;
    @wire(EnclosingTabId)      tabId;

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

    connectedCallback() {
        this._loadPicklistsSection1();
        this._loadPaysVille();
        this._loadVehiculePicklists();
        this.loadGaranties();
    }

    _loadPicklistsSection1() {
        getCategorieOptions()
            .then(data => { this.categorieOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getCategorieOptions:', err));
        getCanalOptions()
            .then(data => { this.canalOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getCanalOptions:', err));
       
        getSituationPoliceOptions()
            .then(data => { this.situationPoliceOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getSituationPoliceOptions:', err));
        getSituationPrimeOptions()
            .then(data => { this.situationPrimeOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getSituationPrimeOptions:', err));
    }

    _loadPaysVille() {
        const p1 = getPaysOptions()
            .then(data => { this.paysOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getPaysOptions:', err));
        const p2 = getDependentVilleOptions()
            .then(data => {
                this._dependentVilleOptions = data;
                if (this._dependentVilleOptions['Maroc']) {
                    this.formData             = { ...this.formData, pays: 'Maroc' };
                    this.villeOptionsFiltrees = this._dependentVilleOptions['Maroc'];
                }
            })
            .catch(err => console.error('getDependentVilleOptions:', err));
        return Promise.all([p1, p2]);
    }

    _loadVehiculePicklists() {
        const p1 = getTypeVehiculeOptions()
            .then(data => { this.typeVehiculeOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getTypeVehiculeOptions:', err));
        const p2 = getMarqueOptions()
            .then(data => { this.marqueOptions = data.map(o => ({ label: o.label, value: o.value })); })
            .catch(err  => console.error('getMarqueOptions:', err));
        const p3 = getDependentModeleOptions()
            .then(data => { this._dependentModeleOptions = data; })
            .catch(err  => console.error('getDependentModeleOptions:', err));
        return Promise.all([p1, p2, p3]);
    }

    _filterVilles(paysValue) {
        this.villeOptionsFiltrees = this._dependentVilleOptions[paysValue] || [];
        const still = this.villeOptionsFiltrees.find(v => v.value === this.formData.ville);
        if (!still) this.formData = { ...this.formData, ville: '' };
    }

    _filterModeles(marqueValue) {
        this.modeleOptions = this._dependentModeleOptions[marqueValue] || [];
        this.formData = { ...this.formData, modele: '' };
    }

    loadGaranties() {
    getGarantiesMetadata()
        .then(result => {
            this.garanties = result;
            // Présélectionner Responsabilité civile (code 001)
            const rc = result.find(g => g.code === '001');
            if (rc && !this.selectedGaranties.includes(rc.id)) {
                this.selectedGaranties = [...this.selectedGaranties, rc.id];
            }
        })
        .catch(error => console.error('Erreur chargement garanties:', error));
}

    // ── Getters ──────────────────────────────────────────────────

    get progressPercentage() {
        return Math.round((this.sections.filter(s => s.isDone).length / this.sections.length) * 100);
    }
    get progressStyle()    { return `width: ${this.progressPercentage}%`; }
    get motivationMessage() {
        const p = this.progressPercentage;
        if (p === 0)  return "C'est parti !";
        if (p < 100)  return "Presque terminé !";
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

    get sec0Open()  { return this.sections[0].isOpen; }
    get sec1Open()  { return this.sections[1].isOpen; }
    get sec2Open()  { return this.sections[2].isOpen; }
    get sec3Open()  { return this.sections[3].isOpen; }
    get sec0Done()  { return this.sections[0].isDone; }
    get sec1Done()  { return this.sections[1].isDone; }
    get sec2Done()  { return this.sections[2].isDone; }
    get sec3Done()  { return this.sections[3].isDone; }
    get sec0Arrow() { return this.sections[0].isOpen ? '▲' : '▼'; }
    get sec1Arrow() { return this.sections[1].isOpen ? '▲' : '▼'; }
    get sec2Arrow() { return this.sections[2].isOpen ? '▲' : '▼'; }
    get sec3Arrow() { return this.sections[3].isOpen ? '▲' : '▼'; }

    get isVilleDisabled()  { return !this.formData.pays;   }
    get isModeleDisabled() { return !this.formData.marque; }

    // ── Handlers ─────────────────────────────────────────────────

    handleChange(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
        if (name === 'pays')   this._filterVilles(value);
        if (name === 'marque') this._filterModeles(value);
    }

    handleGarantieSelection(event) {
    const rc = this.garanties.find(g => g.code === '001');
    let selected = event.detail.selectedRows.map(r => r.id);
    // Réinjecter RC si elle a été décochée
    if (rc && !selected.includes(rc.id)) {
        selected = [rc.id, ...selected];
    }
    this.selectedGaranties = selected;
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
        this.sections = this.sections.map((s, i) => ({ ...s, isOpen: (i === idx) }));
    }

    handleSectionToggle(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.sections = this.sections.map((s, i) => ({
            ...s, isOpen: (i === idx) ? !s.isOpen : s.isOpen
        }));
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'home' }
        });
    }

    // ── Confirmation ─────────────────────────────────────────────

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
                    this.vehiculeExistantId    = immaResult.vehiculeId;
                    this.anciennePoliceId      = immaResult.anciennePoliceId;
                    this.vehiculeWarnMessage   = `Ce véhicule est déjà assigné à la police [${immaResult.numeroPolice}] - [${immaResult.situationPolice}], êtes vous sûr de vouloir créer une nouvelle police`;
                    this.showVehiculeWarnPopup = true; return;
                }
                this.vehiculeConfirmed = true;
            }
            await this._callCreerPolice();
        } catch (error) {
            // Affiche le vrai message d'erreur pour faciliter le debug
            const msg = error?.body?.message || error?.message || JSON.stringify(error);
            this._showToast('Erreur', msg, 'error');
        }
    }

    async _callCreerPolice() {
        const garantiesData = this.garanties
            .filter(g => this.selectedGaranties.includes(g.id))
            .map(g => JSON.stringify({
                nom:  g.nom,
                code: g.code,
                type: g.type
            }));

        const newPoliceId = await creerPolice({
            formData:           JSON.stringify(this.formData),
            garanties:          garantiesData,
            cinConfirmed:       this.cinConfirmed,
            vehiculeConfirmed:  this.vehiculeConfirmed,
            vehiculeExistantId: this.vehiculeExistantId || '',
            anciennePoliceId:   this.anciennePoliceId   || ''
        });

        this._showToast('Succès !', "La police d'assurance a été créée avec succès.", 'success');

        // Récupérer l'ID de l'onglet courant (capturé par @wire au chargement)
        const tabIdToClose = this.tabId;

        // Ouvrir la police créée dans un nouvel onglet
        await openTab({
            pageReference: {
                type: 'standard__recordPage',
                attributes: {
                    recordId:      newPoliceId,
                    objectApiName: 'InsurancePolicy__c',
                    actionName:    'view'
                }
            },
            focus: true
        });

        // Fermer l'onglet "Creation de Police" après ouverture du nouveau
        if (tabIdToClose) {
            await closeTab(tabIdToClose);
        }
    }

    // ── Validations ───────────────────────────────────────────────

    _validateSection(idx) {
        if (idx === 0 && (!this.formData.numeroPolice || !this.formData.dateEffet || !this.formData.dateExpiration)) {
            this._showToast('Champs manquants', "Veuillez remplir les informations de police.", 'warning');
            return false;
        }
        if (idx === 1 && (!this.formData.nomComplet || !this.formData.cin)) {
            this._showToast('Champs manquants', 'Veuillez remplir le nom et le CIN.', 'warning');
            return false;
        }
        if (idx === 2 && !this.formData.immatriculation) {
            this._showToast('Champs manquants', "Veuillez renseigner l'immatriculation.", 'warning');
            return false;
        }
        return true;
    }

    _validateAll() {
        if (!this.formData.numeroPolice || !this.formData.cin || !this.formData.immatriculation) {
            this._showToast('Erreur', 'Champs obligatoires manquants.', 'warning');
            return false;
        }
        if (this.selectedGaranties.length === 0) {
            this._showToast('Erreur', 'Sélectionnez au moins une garantie.', 'warning');
            return false;
        }
        return true;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ── Popups ────────────────────────────────────────────────────

    closeCinPopup()           { this.showCinPopup = false; }
    confirmCin()              { this.cinConfirmed = true; this.showCinPopup = false; this.handleConfirm(); }
    closeVehiculeBlockPopup() { this.showVehiculeBlockPopup = false; }
    closeVehiculeWarnPopup()  { this.showVehiculeWarnPopup = false; this.vehiculeConfirmed = false; }
    confirmVehicule()         { this.vehiculeConfirmed = true; this.showVehiculeWarnPopup = false; this.handleConfirm(); }

    garantiesColumns = [
        { label: 'Nom de la garantie', fieldName: 'nom',  type: 'text' },
        { label: 'Code',               fieldName: 'code', type: 'text' }
    ];
}