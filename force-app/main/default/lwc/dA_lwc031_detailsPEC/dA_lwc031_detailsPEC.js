import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDetailsPEC from '@salesforce/apex/DA_lwc031_DetailsPECController.getDetailsPEC';
import getGaragistes from '@salesforce/apex/DA_lwc031_DetailsPECController.getGaragistes';
import saveDevisInitial from '@salesforce/apex/DA_lwc031_DetailsPECController.saveDevisInitial';
import saveExpertise from '@salesforce/apex/DA_lwc031_DetailsPECController.saveExpertise';
import saveCorrection from '@salesforce/apex/DA_lwc031_DetailsPECController.saveCorrection';
import savePriseEnCharge from '@salesforce/apex/DA_lwc031_DetailsPECController.savePriseEnCharge';
import creerRequetePrestataire from '@salesforce/apex/DA_lwc031_DetailsPECController.creerRequetePrestataire';
import passerEtapeSuivante from '@salesforce/apex/DA_lwc031_DetailsPECController.passerEtapeSuivante';
import marquerEtapeTerminee from '@salesforce/apex/DA_lwc031_DetailsPECController.marquerEtapeTerminee';
import annulerInstruction from '@salesforce/apex/DA_lwc031_DetailsPECController.annulerInstruction';

const ETAPES = [
    'Étude de documents',
    'Expertise',
    'Correction du devis',
    "Établissement d'une PEC",
    'Réparation'
];

const ORIGINE_DEVIS_OPTIONS = [
    'Garage conventionné',
    'Garage non conventionné'
];

const ORIGINE_CORRECTION_OPTIONS = [
    { label: 'Revue en interne',                          value: 'Revue en interne' },
    { label: "Revue d'expert sur document",               value: "Revue d'expert sur document" },
    { label: "Revue d'expert suite à expertise véhicule", value: "Revue d'expert suite à expertise véhicule" },
    { label: 'Contre-proposition garagiste',              value: 'Contre-proposition garagiste' }
];

const STATUT_CORRECTION_OPTIONS = [
    { label: 'Soumise',    value: 'Soumise' },
    { label: 'Confirmée',  value: 'Confirmée' },
    { label: 'Refusée',    value: 'Refusée' },
    { label: 'Abandonnée', value: 'Abandonnée' }
];

const OUI_NON = ['Oui', 'Non'];

// Motifs d'annulation : la valeur envoyée au serveur reste stable (valeur de
// picklist), seul le libellé affiché est précisé selon l'étape du parcours.
const MOTIF_PASSAGE     = 'Passage à un autre type d\'instruction';
const MOTIF_DESISTEMENT = 'Désistement de l\'assuré';
const STATUT_ANNULEE  = 'Instruction annulée';
const STATUTS_TERMINEE = [
    'Instruction terminée'
];

// ── helpers ──────────────────────────────────────────────────────────────────
function formatDate(isoDate) {
    if (!isoDate) return '-';
    try {
        return new Date(isoDate).toLocaleDateString('fr-FR', {
            day: '2-digit', month: '2-digit', year: 'numeric'
        });
    } catch (e) { return isoDate; }
}

function formatMontant(value) {
    if (value === null || value === undefined || value === '') return '-';
    try {
        return Number(value).toLocaleString('fr-FR', {
            minimumFractionDigits: 2, maximumFractionDigits: 2
        });
    } catch (e) { return value; }
}

function getStatutCorrectionClass(statut) {
    if (statut === 'Confirmée')  return 'pm-state pm-state--indemne';
    if (statut === 'Refusée')    return 'pm-state pm-state--deces';
    if (statut === 'Soumise')    return 'pm-state pm-state--blesse';
    return 'pm-state pm-state--default';
}

export default class DA_lwc031_detailsPEC extends LightningElement {

    @api recordId;

    @track devis = {
        montantDevisInitial: '',
        dateReceptionDevisInitial: '',
        origineDevis: '',
        reparateurId: '',
        nouveauReparateur: false,
        nomReparateur: '',
        identifiantFiscal: '',
        montantApprecie: '',
        necessiteExpertise: '',
        commentaire: ''
    };

    @track pec = {
        montantAccordePEC: '',
        franchisePourcentage: '',
        franchiseMin: '',
        franchiseMax: '',
        paiementFranchise: '',
        obligationRapportExpertise: '',
        commentaire: '',
        dateEnvoiPEC: ''
    };

    @track correctionForm = null;   // null = formulaire fermé
    @track corrections        = [];
    @track garagistes          = [];
    @track isLoading           = false;
    @track isLoadingGaragistes = false;
    @track isSaving            = false;
    @track showEtapeModal      = false;
    @track expertiseIgnoree    = false;   // étape Expertise non activée (grisée)
    @track isClotureInstruction = false;  // modal de clôture (étape 5) vs passage d'étape
    @track showAnnulationModal = false;   // modal « Annuler instruction »
    @track motifAnnulation     = '';      // motif sélectionné dans le modal d'annulation

    etape           = ETAPES[0];
    statut          = '';
    reparateurName  = '';
    dateSinistre    = null;
    dateDeclaration = null;
    wiredDetailsResult;

    statutCorrectionOptions = STATUT_CORRECTION_OPTIONS;

    // ── Wire ─────────────────────────────────────────────────────────────────
    @wire(getDetailsPEC, { instructionId: '$recordId' })
    wiredDetails(result) {
        this.wiredDetailsResult = result;
        if (result.data) {
            const instr = result.data.instruction;
            this.etape  = instr.Etape__c || ETAPES[0];
            this.statut = instr.Statut__c || '';

            this.devis = {
                montantDevisInitial       : instr.MontantDevisInitial__c ?? '',
                dateReceptionDevisInitial : instr.DateReceptionDevisInitial__c || '',
                origineDevis              : instr.OrigineDevis__c || '',
                reparateurId              : instr.Reparateur__c || '',
                nouveauReparateur         : instr.NouveauReparateurNonConventionne__c === true,
                nomReparateur             : instr.NomReparateur__c || '',
                identifiantFiscal         : instr.IdentifiantFiscal__c || '',
                montantApprecie           : instr.MontantApprecie__c ?? '',
                necessiteExpertise        : instr.NecessiteExpertise__c || '',
                remiseFondsDocumentaire   : instr.RemiseFondsDocumentaire__c === true,
                commentaire               : instr.CommentaireDevisInitial__c || ''
            };

            // L'étape Expertise est grisée si elle a été sautée (expertise = Non)
            this.expertiseIgnoree = instr.NecessiteExpertise__c === 'Non'
                && ETAPES.indexOf(this.etape) > ETAPES.indexOf('Expertise');

            this.pec = {
                montantAccordePEC          : instr.MontantAccordePEC__c ?? '',
                franchisePourcentage       : instr.FranchisePourcentage__c ?? '',
                franchiseMin               : instr.FranchiseMin__c ?? '',
                franchiseMax               : instr.FranchiseMax__c ?? '',
                paiementFranchise          : instr.PaiementFranchise__c || '',
                paiementFranchiseRecu      : instr.PaiementFranchiseRecu__c === true,
                obligationRapportExpertise : instr.ObligationRapportExpertise__c || '',
                commentaire                : instr.CommentairePEC__c || '',
                dateEnvoiPEC               : instr.DateEnvoiPEC__c || ''
            };

            // RG1 (PEC) : dernière ligne « confirmée » par défaut
            this.corrections = result.data.corrections || [];
            if (this.isEtape4 && (this.pec.montantAccordePEC === '' || this.pec.montantAccordePEC === null)) {
                const confirmees = this.corrections.filter(c => c.StatutCorrection__c === 'Confirmée');
                if (confirmees.length > 0) {
                    this.pec.montantAccordePEC = confirmees[confirmees.length - 1].MontantDevisCorrige__c;
                }
            }

            this.reparateurName  = (instr.Reparateur__r && instr.Reparateur__r.Name) || '';
            this.dateSinistre    = result.data.dateSinistre || null;
            this.dateDeclaration = result.data.dateDeclaration || null;

            if (this.devis.origineDevis) {
                this.loadGaragistes(this.devis.origineDevis);
            }
        } else if (result.error) {
            this.fireToast('Erreur', this.extractError(result.error), 'error');
        }
    }

    // ── Etapes ───────────────────────────────────────────────────────────────
    get etapeIndex() {
        const idx = ETAPES.indexOf(this.etape);
        return idx < 0 ? 0 : idx;
    }

    get isEtape1() { return this.etapeIndex === 0; }
    get isEtape2() { return this.etapeIndex === 1; }
    get isEtape3() { return this.etapeIndex === 2; }
    get isEtape4() { return this.etapeIndex === 3; }
    get isEtape5() { return this.etapeIndex === 4; }

    get steps() {
        return ETAPES.map((label, i) => {
            let cls = 'pec-step';
            if (this.expertiseIgnoree && label === 'Expertise') {
                // Étape non activée (expertise = Non) : grisée en gris foncé
                cls += ' pec-step--skipped';
            } else if (i < this.etapeIndex) {
                cls += ' pec-step--done';
            } else if (i === this.etapeIndex) {
                cls += ' pec-step--current';
            }
            return { label, num: i + 1, key: label, cls };
        });
    }

    get hasNextStep() { return this.etapeIndex < ETAPES.length - 1; }
    get nextStepLabel() { return ETAPES[this.etapeIndex + 1]; }

    // ── Annulation d'instruction ─────────────────────────────────────────────
    get isInstructionAnnulee() { return this.statut === STATUT_ANNULEE; }
    get isInstructionTerminee() { return STATUTS_TERMINEE.includes(this.statut); }

    // Bouton « Annuler instruction » : actif à toutes les étapes, sauf si
    // l'instruction est déjà annulée ou terminée.
    get annulationDisabled() {
        return this.isSaving || this.isLoading
            || this.isInstructionAnnulee || this.isInstructionTerminee;
    }

    // Liste de motifs affichée selon l'étape (le libellé est précisé par étape,
    // la valeur envoyée au serveur reste stable).
    get motifOptions() {
        let passageLabel;
        if (this.isEtape1 || this.isEtape2) {
            passageLabel = MOTIF_PASSAGE + ' (non-confirmation du mode d\'indemnisation)';
        } else if (this.isEtape3 || this.isEtape4) {
            passageLabel = MOTIF_PASSAGE + ' (Retard d\'établissement de prise en charge)';
        } else {
            passageLabel = MOTIF_PASSAGE + ' (Retard dans le démarrage des travaux)';
        }
        return [
            { label: passageLabel,        value: MOTIF_PASSAGE },
            { label: MOTIF_DESISTEMENT,   value: MOTIF_DESISTEMENT }
        ];
    }

    // ── Visibilité des blocs : uniquement le bloc de l'étape en cours ────────
    // Étape 5 (Réparation) : consultation de tous les blocs déjà saisis (US5)
    get showBlocDevisInitial() { return this.isEtape1 || this.isEtape5; }
    get showBlocExpertise()    { return this.isEtape1 || this.isEtape2 || this.isEtape5; }
    get showBlocCorrige()      { return this.isEtape3 || this.isEtape5; }
    get showBlocPEC()          { return this.isEtape4 || this.isEtape5; }

    // RG7 (US1) / RG5 (US4) : modifiable tant qu'on n'est pas à l'étape suivante
    get devisLocked()      { return !this.isEtape1; }
    get expertiseLocked()  { return !(this.isEtape1 || this.isEtape2); }   // US2
    get correctionAllowed(){ return this.isEtape3; }
    get pecLocked()        { return !this.isEtape4; }

    get showDevisSave()      { return this.isEtape1 || this.isEtape2; }
    get showPECSave()        { return this.isEtape4; }
    get showCorrectionForm() { return this.correctionForm !== null; }

    // ── Données devis initial : getters ──────────────────────────────────────
    get origineDevisChips() {
        return ORIGINE_DEVIS_OPTIONS.map(v => ({
            value: v,
            label: v,
            cls: `pm-contact-btn${this.devis.origineDevis === v ? ' pm-contact-btn--active' : ''}`
        }));
    }

    get expertiseChips() {
        return OUI_NON.map(v => ({
            value: v,
            label: v,
            cls: `pm-contact-btn${this.devis.necessiteExpertise === v ? ' pm-contact-btn--active' : ''}`
        }));
    }

    get minDateReception() {
        // RG1 : pas antérieure à la date sinistre / date déclaration
        const dates = [this.dateSinistre, this.dateDeclaration].filter(Boolean).sort();
        return dates.length ? dates[dates.length - 1] : null;
    }

    get garagisteRows() {
        return this.garagistes.map(g => ({
            ...g,
            isSelected : this.devis.reparateurId === g.Id,
            rowClass   : this.devis.reparateurId === g.Id ? 'pm-table__row--selected' : ''
        }));
    }

    get hasGaragistes()      { return this.garagistes.length > 0; }

    get garagistesEmptyMessage() {
        const type = this.devis.origineDevis === 'Garage conventionné' ? 'conventionné' : 'non conventionné';
        return `Aucun garagiste « ${type} » disponible (vérifiez la case Conventionné et le pays des comptes prestataires).`;
    }
    get showGaragisteListe() { return !!this.devis.origineDevis && !this.devis.nouveauReparateur; }
    get showNouveauReparateur() {
        return this.devis.origineDevis === 'Garage non conventionné';
    }
    get showNouveauReparateurFields() { return this.devis.nouveauReparateur; }
    get reparateurRequired() { return !this.devis.nouveauReparateur; }

    get devisFieldsDisabled()     { return this.devisLocked || this.isSaving; }
    get expertiseFieldsDisabled() { return this.expertiseLocked || this.isSaving; }

    // CR4 (Etape 1) : action « Remise du fonds documentaire » visible si expertise requise
    get showRemiseFondsDoc() { return this.devis.necessiteExpertise === 'Oui'; }

    // CR4 (Etape 4) : action « Paiement franchise reçu » visible si paiement « A la compagnie »
    get showPaiementFranchiseRecu() { return this.pec.paiementFranchise === 'A la compagnie'; }

    // ── Données devis corrigé : getters ──────────────────────────────────────
    get correctionRows() {
        return this.corrections.map(c => ({
            ...c,
            montantFmt     : formatMontant(c.MontantDevisCorrige__c),
            reparateurName : (c.Reparateur__r && c.Reparateur__r.Name) || '-',
            statutClass    : getStatutCorrectionClass(c.StatutCorrection__c),
            dateStatutFmt  : formatDate(c.DateStatut__c)
        }));
    }

    get hasCorrections() { return this.corrections.length > 0; }

    get origineCorrectionChips() {
        const current = this.correctionForm ? this.correctionForm.origineCorrection : '';
        return ORIGINE_CORRECTION_OPTIONS.map(o => ({
            ...o,
            cls: `pm-contact-btn${current === o.value ? ' pm-contact-btn--active' : ''}`
        }));
    }

    get reparateurOptions() {
        return this.garagistes.map(g => ({ label: g.Name, value: g.Id }));
    }

    get isCorrectionEdit() {
        return !!(this.correctionForm && this.correctionForm.id);
    }

    get correctionFormTitle() {
        return this.isCorrectionEdit ? 'Modifier la correction' : 'Nouvelle correction de devis';
    }

    get todayFmt() {
        return formatDate(new Date().toISOString());
    }

    // ── Données prise en charge : getters ────────────────────────────────────
    get paiementFranchiseChips() {
        return ['A la compagnie', 'Au garagiste'].map(v => ({
            value: v,
            label: v,
            cls: `pm-contact-btn${this.pec.paiementFranchise === v ? ' pm-contact-btn--active' : ''}`
        }));
    }

    get obligationChips() {
        return OUI_NON.map(v => ({
            value: v,
            label: v,
            cls: `pm-contact-btn${this.pec.obligationRapportExpertise === v ? ' pm-contact-btn--active' : ''}`
        }));
    }

    get pecFieldsDisabled() { return this.pecLocked || this.isSaving; }

    // ── Chargement garagistes (RG2 / RG3) ────────────────────────────────────
    loadGaragistes(origineDevis) {
        this.isLoadingGaragistes = true;
        getGaragistes({ conventionne: origineDevis === 'Garage conventionné' })
            .then(data  => { this.garagistes = data || []; })
            .catch(()   => { this.fireToast('Erreur', 'Impossible de charger la liste des garagistes.', 'error'); })
            .finally(() => { this.isLoadingGaragistes = false; });
    }

    // ── Handlers devis initial ───────────────────────────────────────────────
    handleDevisFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        this.devis = { ...this.devis, [field]: value };
    }

    handleOrigineDevisClick(event) {
        if (this.devisFieldsDisabled) return;
        const value = event.currentTarget.dataset.value;
        this.devis = { ...this.devis, origineDevis: value, reparateurId: '' };
        // RG3 : conventionné → liste des conventionnés, sinon non conventionnés
        if (value !== 'Garage non conventionné') {
            this.devis = { ...this.devis, nouveauReparateur: false, nomReparateur: '', identifiantFiscal: '' };
        }
        this.loadGaragistes(value);
    }

    handleExpertiseClick(event) {
        if (this.devisFieldsDisabled) return;
        this.devis = { ...this.devis, necessiteExpertise: event.currentTarget.dataset.value };
    }

    handleGaragisteSelect(event) {
        if (this.devisFieldsDisabled) return;
        this.devis = { ...this.devis, reparateurId: event.currentTarget.dataset.id };
    }

    handleNouveauReparateurChange(event) {
        const checked = event.target.checked;
        this.devis = { ...this.devis, nouveauReparateur: checked };
        if (checked) {
            this.devis = { ...this.devis, reparateurId: '' };
        }
    }

    // RG4 : requête « Création prestataire » + notification cloche
    handleAjouterReparateur() {
        if (!this.devis.nomReparateur) {
            this.fireToast('Validation', 'Veuillez renseigner le nom du réparateur.', 'warning');
            return;
        }
        this.isSaving = true;
        creerRequetePrestataire({
            instructionId     : this.recordId,
            nomReparateur     : this.devis.nomReparateur,
            identifiantFiscal : this.devis.identifiantFiscal
        })
            .then(() => {
                this.fireToast(
                    'Requête créée',
                    'Une requête « Création prestataire » a été affectée au gestionnaire Admin fonctionnel.',
                    'success'
                );
            })
            .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
            .finally(()  => { this.isSaving = false; });
    }

    // RG5 / RG6 : enregistrement avec contrôle des champs obligatoires
    handleSaveDevis() {
        if (this.isSaving) return;

        if (this.isEtape2) {
            // US2 : seuls « Montant apprécié » et « Commentaire » sont modifiables
            this.isSaving = true;
            saveExpertise({
                instructionId: this.recordId,
                payload: JSON.stringify({
                    montantApprecie : this.devis.montantApprecie,
                    commentaire     : this.devis.commentaire
                })
            })
                .then(() => this.afterSaveDevis())
                .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
                .finally(()  => { this.isSaving = false; });
            return;
        }

        if (!this.validateDevis()) return;

        this.isSaving = true;
        saveDevisInitial({ instructionId: this.recordId, payload: JSON.stringify(this.devis) })
            .then(() => this.afterSaveDevis())
            .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
            .finally(()  => { this.isSaving = false; });
    }

    afterSaveDevis() {
        this.fireToast('Succès', 'Données du devis enregistrées.', 'success');

        // RG6 : redirection selon « Nécessite une expertise ? »
        const targetTab = this.devis.necessiteExpertise === 'Oui' ? 'Missions' : 'Suivi Instruction';
        this.dispatchEvent(new CustomEvent('pecredirect', {
            detail   : { tab: targetTab },
            bubbles  : true,
            composed : true
        }));
        if (this.devis.necessiteExpertise === 'Oui') {
            this.fireToast(
                'Expertise requise',
                "Rendez-vous sur l'onglet [Missions] pour le missionnement d'un expert.",
                'info'
            );
        }
        return refreshApex(this.wiredDetailsResult);
    }

    validateDevis() {
        const d = this.devis;
        let message = null;

        if (d.montantDevisInitial === '' || d.montantDevisInitial === null) {
            message = 'Le champ « Montant devis initial » est obligatoire.';
        } else if (!d.dateReceptionDevisInitial) {
            message = 'Le champ « Date réception devis initial » est obligatoire.';
        } else if (this.minDateReception && d.dateReceptionDevisInitial < this.minDateReception) {
            // RG1
            message = 'La date de réception du devis ne peut pas être antérieure à la date sinistre / date déclaration.';
        } else if (!d.origineDevis) {
            message = 'Le champ « Origine devis » est obligatoire.';
        } else if (!d.nouveauReparateur && !d.reparateurId) {
            message = 'Veuillez sélectionner un réparateur dans la liste ou cocher « Nouveau réparateur non conventionné ».';
        } else if (d.nouveauReparateur && !d.nomReparateur) {
            message = 'Le champ « Nom réparateur » est obligatoire.';
        } else if (!d.necessiteExpertise) {
            message = 'Le champ « Nécessite une expertise ? » est obligatoire.';
        }

        if (message) {
            this.fireToast('Validation', message, 'warning');
            return false;
        }
        return true;
    }

    // ── Handlers devis corrigé ───────────────────────────────────────────────
    // RG1 / RG2 / RG3 / RG6 : nouvelle ligne pré-remplie
    handleAjouterCorrection() {
        this.correctionForm = {
            id                  : null,
            montantDevisCorrige : this.devis.montantApprecie ?? '',   // RG3
            origineCorrection   : '',
            reparateurId        : this.devis.reparateurId || '',      // RG6
            statutCorrection    : 'Soumise'
        };
        if (this.garagistes.length === 0) {
            this.loadGaragistes(this.devis.origineDevis || 'Garage conventionné');
        }
    }

    // RG7 : post enregistrement, seul le statut reste modifiable
    handleEditCorrection(event) {
        const id  = event.currentTarget.dataset.id;
        const row = this.corrections.find(c => c.Id === id);
        if (!row) return;
        this.correctionForm = {
            id                  : row.Id,
            montantDevisCorrige : row.MontantDevisCorrige__c ?? '',
            origineCorrection   : row.OrigineCorrection__c || '',
            reparateurId        : row.Reparateur__c || '',
            statutCorrection    : row.StatutCorrection__c || ''
        };
        if (this.garagistes.length === 0) {
            this.loadGaragistes(this.devis.origineDevis || 'Garage conventionné');
        }
    }

    handleCorrectionFieldChange(event) {
        const field = event.target.dataset.field;
        this.correctionForm = { ...this.correctionForm, [field]: event.detail.value };
    }

    handleOrigineCorrectionClick(event) {
        if (this.isCorrectionEdit) return;   // RG5
        this.correctionForm = {
            ...this.correctionForm,
            origineCorrection: event.currentTarget.dataset.value
        };
    }

    handleCancelCorrection() {
        this.correctionForm = null;
    }

    // RG9 : enregistrement avec contrôle des champs obligatoires
    handleSaveCorrection() {
        const f = this.correctionForm;
        if (!f) return;

        let message = null;
        if (f.montantDevisCorrige === '' || f.montantDevisCorrige === null) {
            message = 'Le champ « Montant devis corrigé » est obligatoire.';
        } else if (!f.origineCorrection) {
            message = 'Le champ « Origine correction » est obligatoire.';
        } else if (!f.reparateurId) {
            message = 'Le champ « Réparateur » est obligatoire.';
        } else if (!f.statutCorrection) {
            message = 'Le champ « Statut correction » est obligatoire.';
        }
        if (message) {
            this.fireToast('Validation', message, 'warning');
            return;
        }

        this.isSaving = true;
        saveCorrection({ instructionId: this.recordId, payload: JSON.stringify(f) })
            .then(() => {
                this.correctionForm = null;
                this.fireToast('Succès', 'Correction de devis enregistrée.', 'success');
                return refreshApex(this.wiredDetailsResult);
            })
            .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
            .finally(()  => { this.isSaving = false; });
    }

    // ── Handlers prise en charge ─────────────────────────────────────────────
    handlePECFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        this.pec = { ...this.pec, [field]: value };
    }

    handlePaiementFranchiseClick(event) {
        if (this.pecFieldsDisabled) return;
        this.pec = { ...this.pec, paiementFranchise: event.currentTarget.dataset.value };
    }

    handleObligationClick(event) {
        if (this.pecFieldsDisabled) return;
        this.pec = { ...this.pec, obligationRapportExpertise: event.currentTarget.dataset.value };
    }

    // RG3 (US4) : édition de la PEC selon modèle à partager
    handleEditionPEC() {
        this.fireToast(
            'Édition de la PEC',
            'Le modèle de prise en charge sera disponible prochainement (modèle à partager).',
            'info'
        );
    }

    // RG4 (US4) : enregistrement avec contrôle des champs obligatoires
    handleSavePEC() {
        if (this.isSaving) return;

        const p = this.pec;
        let message = null;
        if (p.montantAccordePEC === '' || p.montantAccordePEC === null) {
            message = 'Le champ « Montant accordée PEC » est obligatoire.';
        } else if (p.franchisePourcentage === '' || p.franchisePourcentage === null) {
            message = 'Le champ « Franchise (en %) » est obligatoire.';
        } else if (Number(p.franchisePourcentage) > 100) {
            message = 'La franchise ne peut pas dépasser 100 %.';   // RG2
        } else if (p.franchiseMin === '' || p.franchiseMin === null) {
            message = 'Le champ « Franchise Min » est obligatoire.';
        } else if (p.franchiseMax === '' || p.franchiseMax === null) {
            message = 'Le champ « Franchise MAX » est obligatoire.';
        } else if (!p.paiementFranchise) {
            message = 'Le champ « Paiement de la franchise » est obligatoire.';
        } else if (!p.obligationRapportExpertise) {
            message = "Le champ « Obligation Rapport d'expertise post travaux » est obligatoire.";
        } else if (!p.dateEnvoiPEC) {
            message = "Le champ « Date d'envoi de la PEC » est obligatoire.";
        }
        if (message) {
            this.fireToast('Validation', message, 'warning');
            return;
        }

        this.isSaving = true;
        savePriseEnCharge({ instructionId: this.recordId, payload: JSON.stringify(p) })
            .then(() => {
                this.fireToast('Succès', 'Données de prise en charge enregistrées.', 'success');
                return refreshApex(this.wiredDetailsResult);
            })
            .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
            .finally(()  => { this.isSaving = false; });
    }

    // ── Avancement d'étape (progression uniquement, pas de retour) ───────────
    handleEtapeSuivante() {
        this.isClotureInstruction = false;
        this.showEtapeModal = true;
    }

    // Étape 5 : clôture de l'instruction
    handleMarquerInstructionTerminee() {
        this.isClotureInstruction = true;
        this.showEtapeModal = true;
    }

    handleCancelEtape() {
        this.showEtapeModal = false;
    }

    // Texte du modal selon le contexte (passage d'étape ou clôture)
    get etapeModalTitle() {
        return this.isClotureInstruction ? "Clôturer l'instruction" : "Passer à l'étape suivante";
    }
    get etapeModalMessage() {
        return this.isClotureInstruction
            ? "Confirmer la clôture de l'instruction ?"
            : `Confirmer le passage à l'étape « ${this.nextStepLabel} » ?`;
    }

    handleConfirmEtape() {
        this.showEtapeModal = false;
        this.isLoading = true;
        marquerEtapeTerminee({ instructionId: this.recordId })
            .then(result => {
                if (!result.ok) {
                    // Un ou plusieurs contrôles KO : on bloque l'avancement
                    this.afficherControlesKO(result.erreurs);
                    return null;
                }
                this.etape = result.nouvelleEtape;
                this.expertiseIgnoree = result.expertiseIgnoree === true;
                if (result.instructionTerminee) {
                    this.fireToast(
                        'Instruction terminée',
                        "L'instruction est clôturée (statut « Instruction terminée »).",
                        'success'
                    );
                } else {
                    this.fireToast(
                        'Étape terminée',
                        `L'instruction passe à l'étape « ${result.nouvelleEtape} ».`,
                        'success'
                    );
                }
                return refreshApex(this.wiredDetailsResult);
            })
            .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
            .finally(()  => { this.isLoading = false; });
    }

    // Alerte récapitulant les contrôles non satisfaits
    afficherControlesKO(erreurs) {
        const lignes = (erreurs || []).map(e => `- ${e}`).join('\n');
        this.fireToast(
            'Contrôles non satisfaits',
            `Attention, vous ne pouvez pas clôturer cette étape sans :\n${lignes}`,
            'warning'
        );
    }

    // ── Annulation d'instruction ─────────────────────────────────────────────
    handleAnnulerInstruction() {
        this.motifAnnulation = '';
        this.showAnnulationModal = true;
    }

    handleCancelAnnulation() {
        this.showAnnulationModal = false;
    }

    handleMotifAnnulationChange(event) {
        this.motifAnnulation = event.detail.value;
    }

    handleConfirmAnnulation() {
        if (!this.motifAnnulation) {
            this.fireToast('Validation', 'Veuillez sélectionner un motif d\'annulation.', 'warning');
            return;
        }
        this.showAnnulationModal = false;
        this.isLoading = true;
        annulerInstruction({ instructionId: this.recordId, motif: this.motifAnnulation })
            .then(result => {
                if (!result.ok) {
                    // Un contrôle est KO : on affiche le message d'alerte et on arrête.
                    this.fireToast('Annulation impossible', result.message, 'warning');
                    return null;
                }
                this.statut = STATUT_ANNULEE;
                this.fireToast('Instruction annulée', "L'instruction a été annulée.", 'success');
                return refreshApex(this.wiredDetailsResult);
            })
            .catch(error => { this.fireToast('Erreur', this.extractError(error), 'error'); })
            .finally(()  => { this.isLoading = false; });
    }

    // ── Utilitaires ──────────────────────────────────────────────────────────
    fireToast(title, message, variant) {
        // Les toasts d'erreur / de validation restent affichés jusqu'à fermeture
        // manuelle (sticky) ; les autres se referment automatiquement.
        const mode = (variant === 'error' || variant === 'warning') ? 'sticky' : 'dismissable';
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }

    extractError(error) {
        return (error && error.body && error.body.message)
            ? error.body.message
            : 'Une erreur est survenue.';
    }
}
