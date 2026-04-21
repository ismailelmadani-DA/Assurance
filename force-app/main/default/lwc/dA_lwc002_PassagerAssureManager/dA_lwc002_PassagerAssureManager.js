import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CLAIM_PARTICIPANT_OBJECT from '@salesforce/schema/ClaimParticipant__c';
import ROLES_FIELD from '@salesforce/schema/ClaimParticipant__c.Roles__c';
import PAYS_FIELD from '@salesforce/schema/ClaimParticipant__c.Pays__c';
import VILLE_FIELD from '@salesforce/schema/ClaimParticipant__c.Ville__c';
import STATE_OF_PERSON_FIELD from '@salesforce/schema/ClaimParticipant__c.StateOfPerson__c';
import SEXE_FIELD from '@salesforce/schema/ClaimParticipant__c.Sexe__c';
import MARITAL_STATUS_FIELD from '@salesforce/schema/ClaimParticipant__c.MaritalStatus__c';
import TYPE_CONTACT_FIELD from '@salesforce/schema/ClaimParticipant__c.TypeContact__c';

import getParticipants from '@salesforce/apex/DA_PassagerGenerateTable.getParticipants';
import getParticipantById from '@salesforce/apex/DA_PassagerGenerateTable.getParticipantById';
import upsertPassager from '@salesforce/apex/DA_PassagerGenerateTable.upsertPassager';
import deletePassager from '@salesforce/apex/DA_PassagerGenerateTable.deletePassager';
import checkDuplicate from '@salesforce/apex/DA_PassagerGenerateTable.checkDuplicate';
import resolveAccountByCIN from '@salesforce/apex/PassagerController.resolveAccountByCIN';
import getVehiclesForClaim from '@salesforce/apex/DA_PassagerGenerateTable.getVehiclesForClaim';
import getCompagniesAdverses from '@salesforce/apex/DA_PassagerGenerateTable.getCompagniesAdverses';

const CIVILITY_SEX_MAP = { Mr: '1', Mme: '2' };

// Options statiques de civilité (pas de picklist SF pour ça)
const CIVILITY_OPTIONS = [
    { label: 'M.', value: 'Mr' },
    { label: 'Mme', value: 'Mme' },
];

const EMPTY_FORM = () => ({
    participantId: '',
    accountId: '',
    roles: '',
    civility: '',
    sexe: '',
    nom: '',
    prenom: '',
    dateNaissance: '',
    cni: '',
    situationFamiliale: '',
    pays: '',
    ville: '',
    adresse: '',
    typeContact: '',
    telephone: '',
    email: '',
    etatPassager: '',
    compagnieAdverse: '',
    itt: null,
    ipp: null,
    dateDeces: '',
    revenuAnnuel: null,
    conducteur: false,
    vehiculeId: '',
});

const EMPTY_ERRORS = () => ({
    roles: '', civility: '', nom: '', prenom: '', cni: '',
    pays: '', ville: '', etatPassager: '',
    telephone: '', email: '', dateNaissance: '', dateDeces: '',
});

export default class PassagerManager extends LightningElement {

    /** Id du sinistre (obligatoire) */
    @api recordId;
    /** Id du véhicule lié (optionnel) */
    @api vehiculeId;
    /** Mode lecture seule */
    @api isReadonly = false;
    /** Nombre de conducteurs déjà enregistrés (pour désactiver la checkbox) */
    @api driverCount = 0;

    /** Configuration - Titre de la liste */
    @api listTitle = 'Gestion des Passagers';
    /** Configuration - Rôles autorisés (virgule séparés, vide = tous) */
    @api allowedRoles = '';
    /** Configuration - Champs visibles (virgule séparés, vide = tous) */
    @api visibleFields = '';
    /** Configuration - Afficher colonne Actions */
    @api showActionColumn = false;
    /** Configuration - Afficher filtres rapides */
    @api showFilterPills = false;
    /** Configuration - Afficher bouton Ajouter */
    @api showAddButton = false;
    /** Configuration - Nombre de lignes par page */
    @api pageSize = '10';

    /* ─── état interne ─── */
    @track records = [];
    @track filteredRecords = [];
    @track isLoading = false;
    @track isFormLoading = false;
    @track isSaving = false;
    @track hasError = false;
    @track errorMessage = '';

    @track showFormModal = false;
    @track showDeleteModal = false;
    @track isUpdateMode = false;

    @track form = EMPTY_FORM();
    @track errors = EMPTY_ERRORS();

    @track activeFilter = 'all';
    @track currentPage = 1;

    selectedParticipantId = null;
    selectedParticipantName = '';

    /* ─── picklists depuis ClaimParticipant__c ─── */
    @track claimParticipantRecordTypeId;
    @track rolesOptions = [];
    @track paysOptions = [];
    @track allVilleOptions = [];
    @track filteredVilleOptions = [];
    @track etatPassagerOptions = [];
    @track sexeOptions = [];
    @track situationFamilialeOptions = [];
    @track typeContactOptions = [];
    @track vehiculesOptions = [];
    @track compagniesAdversesOptions = [];
    civilityOptions = CIVILITY_OPTIONS;

    /* ══════════════════════════════════════
       LIFECYCLE
    ══════════════════════════════════════ */
    connectedCallback() {
        this.loadParticipants();
    }

    /* ══════════════════════════════════════
       WIRE – Object info & picklists depuis ClaimParticipant__c
    ══════════════════════════════════════ */
    @wire(getObjectInfo, { objectApiName: CLAIM_PARTICIPANT_OBJECT })
    wiredCPInfo({ data, error }) {
        if (data) {
            // Si pas de record types, utiliser le master record type ID
            const rtis = data.recordTypeInfos;
            const masterRT = Object.keys(rtis).find(id => rtis[id].master === true);
            this.claimParticipantRecordTypeId = masterRT;
        }
        if (error) console.error('getObjectInfo ClaimParticipant error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: ROLES_FIELD })
    wiredRoles({ data, error }) {
        if (data) {
            this.rolesOptions = data.values;
            // Filtrer selon allowedRoles configurés
            if (this.allowedRoles?.trim()) {
                const allowed = this.allowedRoles.split(',').map(r => r.trim());
                this.rolesOptions = data.values.filter(v => allowed.includes(v.value));
            }
        }
        if (error) console.error('Roles picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: PAYS_FIELD })
    wiredPays({ data, error }) {
        if (data) {
            this.paysOptions = data.values;
        }
        if (error) console.error('Pays picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: VILLE_FIELD })
    wiredVille({ data, error }) {
        if (data) {
            this.allVilleOptions = data.values;
            // Si un pays est déjà sélectionné (mode édition), recharger les villes
            if (this.form.pays) {
                this._updateVilleOptions();
            }
        }
        if (error) console.error('Ville picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: STATE_OF_PERSON_FIELD })
    wiredState({ data, error }) {
        if (data) this.etatPassagerOptions = data.values;
        if (error) console.error('StateOfPerson picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: SEXE_FIELD })
    wiredSexe({ data, error }) {
        if (data) this.sexeOptions = data.values;
        if (error) console.error('Sexe picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: MARITAL_STATUS_FIELD })
    wiredMarital({ data, error }) {
        if (data) this.situationFamilialeOptions = data.values;
        if (error) console.error('MaritalStatus picklist error', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$claimParticipantRecordTypeId', fieldApiName: TYPE_CONTACT_FIELD })
    wiredTypeContact({ data, error }) {
        if (data) this.typeContactOptions = data.values;
        if (error) console.error('TypeContact picklist error', error);
    }

    /* ══════════════════════════════════════
       CHARGEMENT DONNÉES
    ══════════════════════════════════════ */
    async loadParticipants() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.hasError = false;
        try {
            const raw = await getParticipants({ claimId: this.recordId });
            this.records = raw.map(r => this._enrichRecord(r));
            this._applyFilter();
        } catch (e) {
            this.hasError = true;
            this.errorMessage = e.body?.message || e.message || 'Erreur de chargement';
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Charge les véhicules associés au claim pour les passagers adverses
     */
    async loadVehicles() {
        if (!this.recordId) {
            this.vehiculesOptions = [];
            return;
        }
        try {
            const vehicles = await getVehiclesForClaim({ claimId: this.recordId });
            this.vehiculesOptions = vehicles;
        } catch (e) {
            console.error('Erreur lors du chargement des véhicules:', e);
            this._toast('Erreur', 'Impossible de charger les véhicules', 'error');
            this.vehiculesOptions = [];
        }
    }

    /**
     * Charge la liste des compagnies adverses
     */
    async loadCompagniesAdverses() {
        try {
            const compagnies = await getCompagniesAdverses();
            this.compagniesAdversesOptions = compagnies;
        } catch (e) {
            console.error('Erreur lors du chargement des compagnies adverses:', e);
            this._toast('Erreur', 'Impossible de charger les compagnies adverses', 'error');
            this.compagniesAdversesOptions = [];
        }
    }

    _enrichRecord(r) {
        const stateClass = {
            'Blessé': 'pm-state pm-state--blesse',
            'Décédé': 'pm-state pm-state--deces',
            'Indemne': 'pm-state pm-state--indemne',
        }[r.StateOfPerson__c] || 'pm-state pm-state--default';

        const roleClass = (r.Roles__c || '').toLowerCase().includes('adverse')
            ? 'pm-role pm-role--adverse'
            : 'pm-role pm-role--assure';

        return {
            ...r,
            stateClass,
            roleClass,
            civility: r.ParticipantAccount__r?.Civility__c || '',
            accountName: r.ParticipantAccount__r?.Name || '',
            participantUrl: `/lightning/r/ClaimParticipant__c/${r.Id}/view`,
        };
    }

    /* ══════════════════════════════════════
       FILTRES & PAGINATION
    ══════════════════════════════════════ */
    get effectivePageSize() {
        return parseInt(this.pageSize) || 10;
    }

    _applyFilter() {
        let base = [...this.records];

        if (this.allowedRoles?.trim()) {
            const rolesArray = this.allowedRoles.split(',').map(r => r.trim());
            base = base.filter(r => rolesArray.includes(r.Roles__c));
        }

        if (this.activeFilter !== 'all') {
            base = base.filter(r => r.Roles__c === this.activeFilter);
        }

        this.filteredRecords = base.slice(
            (this.currentPage - 1) * this.effectivePageSize,
            this.currentPage * this.effectivePageSize
        );
    }

    get totalPages() {
        let base = [...this.records];
        if (this.allowedRoles?.trim()) {
            const rolesArray = this.allowedRoles.split(',').map(r => r.trim());
            base = base.filter(r => rolesArray.includes(r.Roles__c));
        }
        if (this.activeFilter !== 'all') {
            base = base.filter(r => r.Roles__c === this.activeFilter);
        }
        return Math.max(1, Math.ceil(base.length / this.effectivePageSize));
    }

    /* ══════════════════════════════════════
       COLONNES DYNAMIQUES
    ══════════════════════════════════════ */
    get parsedVisibleFields() {
        if (!this.visibleFields?.trim()) {
            return ['Conducteur', 'Civilité', 'Nom complet', 'Rôle', 'CNI', 'Pays', 'Ville', 'État'];
        }
        return this.visibleFields.split(',').map(f => f.trim()).filter(f => f);
    }

    get showColConducteur() { return this.parsedVisibleFields.includes('Conducteur'); }
    get showColCivilite() { return this.parsedVisibleFields.includes('Civilité'); }
    get showColNom() { return this.parsedVisibleFields.includes('Nom complet'); }
    get showColRole() { return this.parsedVisibleFields.includes('Rôle'); }
    get showColCNI() { return this.parsedVisibleFields.includes('CNI'); }
    get showColPays() { return this.parsedVisibleFields.includes('Pays'); }
    get showColVille() { return this.parsedVisibleFields.includes('Ville'); }
    get showColEtat() { return this.parsedVisibleFields.includes('État'); }

    get showPagination() { return this.totalPages > 1; }
    get hasRecords() { return this.filteredRecords.length > 0; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get prevClass() { return `pm-btn pm-btn--page${this.isFirstPage ? ' pm-btn--disabled' : ''}`; }
    get nextClass() { return `pm-btn pm-btn--page${this.isLastPage ? ' pm-btn--disabled' : ''}`; }
    get totalLabel() { return `${this.records.length} passager${this.records.length > 1 ? 's' : ''}`; }

    get pillAllClass() { return `pm-pill${this.activeFilter === 'all' ? ' pm-pill--active' : ''}`; }
    get pillAssureClass() { return `pm-pill${this.activeFilter === 'Passager assuré' ? ' pm-pill--active' : ''}`; }
    get pillAdverseClass() { return `pm-pill${this.activeFilter === 'Passager adverse' ? ' pm-pill--active' : ''}`; }

    filterAll() { this.activeFilter = 'all'; this.currentPage = 1; this._applyFilter(); }
    filterRole(e) { this.activeFilter = e.target.dataset.role; this.currentPage = 1; this._applyFilter(); }
    prevPage() { if (!this.isFirstPage) { this.currentPage--; this._applyFilter(); } }
    nextPage() { if (!this.isLastPage) { this.currentPage++; this._applyFilter(); } }

    /* ══════════════════════════════════════
       FORMULAIRE – helpers getters
    ══════════════════════════════════════ */
    get showIttIpp() { return this.form.etatPassager === 'Blessé'; }
    get showDecesFields() { return this.form.etatPassager === 'Décédé'; }
    // "Passager adverse" est la valeur réelle dans votre org (pas "Partie adverse")
    get isAdverse() { return (this.form.roles || '').toLowerCase().includes('adverse'); }
    get isPhoneRequired() { return this.form.typeContact === 'Téléphone'; }
    get isEmailRequired() { return this.form.typeContact === 'Mail'; }
    get isDriverDisabled() { return this.driverCount >= 1 && !this.form.conducteur; }
    get modalTitle() { return this.isUpdateMode ? 'Modifier le passager' : 'Ajouter un passager'; }
    get saveLabel() { return this.isUpdateMode ? 'Enregistrer les modifications' : 'Ajouter le passager'; }

    // Déterminer si la ville est disponible (pays sélectionné + villes chargées)
    get isVilleDisabled() { return !this.form.pays || this.filteredVilleOptions.length === 0; }

    /* ══════════════════════════════════════
       ACTIONS HEADER
    ══════════════════════════════════════ */
    handleAdd() {
        this.isUpdateMode = false;
        this.form = EMPTY_FORM();
        this.errors = EMPTY_ERRORS();
        this.filteredVilleOptions = [];

        // Pré-remplir le rôle si un seul rôle est autorisé (cas paramétré)
        if (this.allowedRoles?.trim()) {
            const allowed = this.allowedRoles.split(',').map(r => r.trim());
            if (allowed.length === 1) {
                this.form = { ...this.form, roles: allowed[0] };
            }
        }

        // Charger les véhicules et compagnies adverses
        this.loadVehicles();
        this.loadCompagniesAdverses();

        this.showFormModal = true;
    }

    handleRefresh() { this.loadParticipants(); }

    /* ══════════════════════════════════════
       ACTIONS LIGNES
    ══════════════════════════════════════ */
    async handleRowAction(e) {
        const { id, action } = e.currentTarget.dataset;
        if (action === 'edit') this._openEditModal(id);
        if (action === 'delete') this._openDeleteModal(id);
    }

    async _openEditModal(participantId) {
        this.isFormLoading = true;
        this.showFormModal = true;
        this.isUpdateMode = true;
        this.errors = EMPTY_ERRORS();

        // Charger les véhicules et compagnies adverses au cas où
        this.loadVehicles();
        this.loadCompagniesAdverses();

        try {
            console.log('🔍 Chargement du participant:', participantId);
            const data = await getParticipantById({ participantId });
            console.log('✅ Données reçues:', data);

            const fmtDate = v => {
                if (!v) return '';
                if (/^\d{2}\/\d{2}\/\d{4}$/.test(v)) {
                    const [d, m, y] = v.split('/');
                    return `${y}-${m}-${d}`;
                }
                return v;
            };

            this.form = {
                participantId: data.participantId || '',
                accountId: data.accountId || '',
                roles: data.roles || '',
                civility: data.civility || '',
                sexe: data.sexe || '',
                nom: data.nom || '',
                prenom: data.prenom || '',
                cni: data.cni || '',
                dateNaissance: fmtDate(data.dateNaissance),
                situationFamiliale: data.situationFamiliale || '',
                pays: data.pays || '',
                ville: data.ville || '',
                adresse: data.adresse || '',
                typeContact: data.typeContact || '',
                telephone: data.telephone || '',
                email: data.email || '',
                etatPassager: data.etatPassager || '',
                compagnieAdverse: data.compagnieAdverse || '',
                itt: data.itt ?? null,
                ipp: data.ipp ?? null,
                dateDeces: fmtDate(data.dateDeces),
                revenuAnnuel: data.revenuAnnuel ?? null,
                conducteur: data.conducteur === true,
                vehiculeId: data.vehiculeId || '',
            };

            console.log('📋 Formulaire chargé:', this.form);
            this._updateVilleOptions();

        } catch (e) {
            console.error('❌ Erreur complète:', e);
            console.error('Message:', e.message);
            console.error('Body:', e.body);
            this._toast('Erreur', `Impossible de charger les données du passager: ${e.body?.message || e.message}`, 'error');
            this.showFormModal = false;
        } finally {
            this.isFormLoading = false;
        }
    }

    _openDeleteModal(participantId) {
        this.selectedParticipantId = participantId;
        const rec = this.records.find(r => r.Id === participantId);
        this.selectedParticipantName = rec?.accountName || rec?.ParticipantAccount__r?.Name || participantId;
        this.showDeleteModal = true;
    }

    /* ══════════════════════════════════════
       HANDLERS CHAMPS FORMULAIRE
    ══════════════════════════════════════ */
    handleFieldChange(e) {
        const name = e.target.name;
        const value = e.target.value;
        this.form = { ...this.form, [name]: value };

        // Civility → auto sexe
        if (name === 'civility' && CIVILITY_SEX_MAP[value]) {
            this.form = { ...this.form, sexe: CIVILITY_SEX_MAP[value] };
        }
        // Pays → reset ville + filtrer villes
        if (name === 'pays') {
            this.form = { ...this.form, ville: '' };
            this._updateVilleOptions();
        }
        // Rôle changé vers Passager adverse → charger les véhicules
        if (name === 'roles' && (value || '').toLowerCase().includes('adverse')) {
            if (this.vehiculesOptions.length === 0) {
                this.loadVehicles();
            }
            // Reset vehiculeId si on passe à un autre rôle
            this.form = { ...this.form, vehiculeId: '' };
        }
        // Réinitialiser erreur du champ
        if (this.errors[name] !== undefined) {
            this.errors = { ...this.errors, [name]: '' };
        }
    }

    handleCheckbox(e) {
        this.form = { ...this.form, conducteur: e.target.checked };
    }

    handleFormSubmit(e) { e.preventDefault(); }

    /**
     * Mise à jour des options de ville selon le pays sélectionné.
     * La dépendance Pays → Ville est configurée dans Salesforce :
     * le champ Ville__c a Pays__c comme controlling field.
     * La propriété "validFor" de chaque valeur contient les indices
     * des valeurs de Pays qui l'activent.
     */
    _updateVilleOptions() {
        if (!this.form.pays || !this.allVilleOptions.length) {
            this.filteredVilleOptions = [];
            return;
        }
        // Trouver l'index de la valeur pays sélectionnée dans paysOptions
        const paysIdx = this.paysOptions.findIndex(p => p.value === this.form.pays);
        if (paysIdx === -1) {
            this.filteredVilleOptions = this.allVilleOptions;
            return;
        }
        // Filtrer les villes valides pour cet index pays
        this.filteredVilleOptions = this.allVilleOptions.filter(v => {
            if (!v.validFor || v.validFor.length === 0) return true;
            return v.validFor.includes(paysIdx);
        });
    }

    /* ══════════════════════════════════════
       VALIDATION
    ══════════════════════════════════════ */
    _validate() {
        const e = EMPTY_ERRORS();
        let ok = true;

        if (!this.form.roles) { e.roles = 'Obligatoire'; ok = false; }
        if (!this.form.civility) { e.civility = 'Obligatoire'; ok = false; }
        if (!this.form.nom?.trim()) { e.nom = 'Obligatoire'; ok = false; }
        if (!this.form.prenom?.trim()) { e.prenom = 'Obligatoire'; ok = false; }
        if (!this.form.pays) { e.pays = 'Obligatoire'; ok = false; }
        if (this.form.pays && !this.form.ville) { e.ville = 'Obligatoire'; ok = false; }
        if (!this.form.cni?.trim()) { e.cni = 'Le CNI est obligatoire'; ok = false; }
        if (!this.form.etatPassager) { e.etatPassager = 'Obligatoire'; ok = false; }

        // Validation du véhicule pour passager adverse
        if (this.isAdverse && !this.form.vehiculeId) {
            this._toast('Validation', 'Le véhicule est obligatoire pour les passagers adverses', 'warning');
            ok = false;
        }

        if ((this.form.nom?.trim().length || 0) + (this.form.prenom?.trim().length || 0) > 35) {
            this._toast('Validation', 'Le nom complet dépasse 35 caractères', 'warning');
            ok = false;
        }

        if (this.isPhoneRequired && !this.form.telephone) {
            e.telephone = 'Obligatoire (notification par téléphone)'; ok = false;
        }
        if (this.isEmailRequired && !this.form.email) {
            e.email = 'Obligatoire (notification par mail)'; ok = false;
        }
        if (this.form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.form.email)) {
            e.email = 'Format email invalide'; ok = false;
        }

        this.errors = e;
        return ok;
    }

    /* ══════════════════════════════════════
       SAUVEGARDER
    ══════════════════════════════════════ */
    async handleSave() {
        if (!this._validate()) return;
        this.isSaving = true;
        try {
            if (!this.isUpdateMode) {
                const isDup = await checkDuplicate({
                    nom: this.form.nom,
                    prenom: this.form.prenom,
                    claimId: this.recordId,
                    excludeId: null,
                });
                if (isDup) {
                    this._toast('Doublon détecté', `Un passager "${this.form.nom} ${this.form.prenom}" existe déjà sur ce sinistre.`, 'warning', 'sticky');
                    this.isSaving = false;
                    return;
                }
            }

            const cin = this.form.cni?.trim();
            const fullName = `${this.form.nom || ''} ${this.form.prenom || ''}`.trim();
            let accountId;
            try {
                accountId = await resolveAccountByCIN({ cin, nom: fullName });
            } catch (err) {
                this._toast('Erreur', err.body?.message || 'Erreur lors de la résolution du compte.', 'error');
                this.isSaving = false;
                return;
            }

            const result = await upsertPassager({
                formData: this.form,
                claimId: this.recordId,
                vehiculeId: this.form.vehiculeId || null,
                isUpdateMode: this.isUpdateMode,
                accountId,
            });

            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeModal();
                await this.loadParticipants();
                this.dispatchEvent(new CustomEvent('refresh'));
            } else {
                this._toast('Erreur', result.message, 'error', 'sticky');
            }
        } catch (e) {
            this._toast('Erreur', e.body?.message || e.message || 'Erreur inconnue', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /* ══════════════════════════════════════
       SUPPRIMER
    ══════════════════════════════════════ */
    async confirmDelete() {
        this.isSaving = true;
        try {
            const result = await deletePassager({ participantId: this.selectedParticipantId });
            if (result.success) {
                this._toast('Succès', result.message, 'success');
                this.closeDeleteModal();
                await this.loadParticipants();
                this.dispatchEvent(new CustomEvent('refresh'));
            } else {
                this._toast('Erreur', result.message, 'error');
            }
        } catch (e) {
            this._toast('Erreur', e.body?.message || e.message || 'Erreur inconnue', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /* ══════════════════════════════════════
       FERMETURE MODALES
    ══════════════════════════════════════ */
    closeModal() { this.showFormModal = false; }
    closeDeleteModal() { this.showDeleteModal = false; }

    handleOverlayClick(e) {
        if (e.target === e.currentTarget) this.closeModal();
    }
    stopPropagation(e) { e.stopPropagation(); }

    /* ══════════════════════════════════════
       TOAST HELPER
    ══════════════════════════════════════ */
    _toast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}