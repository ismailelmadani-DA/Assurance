import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import checkCin             from '@salesforce/apex/DA_lwc022_PoliceCreationController.checkCin';
import checkImmatriculation from '@salesforce/apex/DA_lwc022_PoliceCreationController.checkImmatriculation';
import creerPolice          from '@salesforce/apex/DA_lwc022_PoliceCreationController.creerPolice';

export default class DA_lwc022_PoliceCreation extends NavigationMixin(LightningElement) {

    // ─── Popups ───────────────────────────────────────────────
    @track showCinPopup          = false;
    @track showVehiculeBlockPopup = false;
    @track showVehiculeWarnPopup  = false;
    @track vehiculeWarnMessage    = '';
    @track cinConfirmed           = false;
    @track vehiculeConfirmed      = false;

    // ─── Garanties sélectionnées ──────────────────────────────
    @track selectedGaranties = [];

    // ─── Formulaire — tous les champs de la spec ──────────────
    @track formData = {
        // Bloc 1 — Police
        numeroPolice:    '',
        categorie:       'Individuelle',
        dateEffet:       '',
        dateExpiration:  '',
        canal:           'Courtier',
        situationPolice: 'En cours',
        situationPrime:  'Non Payée',

        // Bloc 2 — Assuré
        nomComplet: '',
        cin:        '',
        telephone:  '',
        email:      '',
        pays:       'Maroc',
        ville:      '',
        adresse:    '',

        // Bloc 3 — Véhicule
        immatriculation:         '',
        typeVehicule:            'Tourisme',
        marque:                  '',
        modele:                  '',
        numeroChassis:           '',
        numeroAttestation:       '',
        dateMiseEnCirculation:   ''
    };

    // ─── Sections / Stepper ───────────────────────────────────
    @track sections = [
        { index: 0, num: 1, label: 'Informations de la police',  isOpen: true,  isDone: false, isLast: false },
        { index: 1, num: 2, label: "Informations de l'assuré",   isOpen: false, isDone: false, isLast: false },
        { index: 2, num: 3, label: 'Informations du véhicule',   isOpen: false, isDone: false, isLast: false },
        { index: 3, num: 4, label: 'Choix des garanties',        isOpen: false, isDone: false, isLast: true  }
    ];

    // ═══════════════════════════════════════════════════════════
    // PROGRESSION
    // ═══════════════════════════════════════════════════════════

    get progressPercentage() {
        const done = this.sections.filter(s => s.isDone).length;
        return Math.round((done / this.sections.length) * 100);
    }

    get progressStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    get motivationMessage() {
        const pct = this.progressPercentage;
        if (pct === 0)   return "C'est parti !";
        if (pct < 50)    return "Bon début, continuez !";
        if (pct < 100)   return "Presque terminé !";
        return "Parfait, prêt à valider !";
    }

    // ═══════════════════════════════════════════════════════════
    // STEPPER — getters pour le template
    // ═══════════════════════════════════════════════════════════

    get steps() {
        return this.sections.map(s => {
            const isActive = s.isOpen && !s.isDone;
            return {
                ...s,
                id:       `step-${s.index}`,
                isActive,
                cssClass: `sb-step${s.isOpen ? ' active' : ''}${s.isDone ? ' done' : ''}`,
                dotClass: `sb-dot${s.isDone ? ' done' : ''}${isActive ? ' active' : ''}`,
                lineClass: `step-line${s.isDone ? ' done' : ''}`
            };
        });
    }

    // ─── Classes des accordéons ──────────────────────────────
    get section0Class() { return this._sectionClass(0); }
    get section1Class() { return this._sectionClass(1); }
    get section2Class() { return this._sectionClass(2); }
    get section3Class() { return this._sectionClass(3); }

    _sectionClass(idx) {
        let cls = 'acc-item';
        if (this.sections[idx].isOpen) cls += ' active';
        if (this.sections[idx].isDone) cls += ' done';
        return cls;
    }

    // ─── Numéros dans l'accordéon ────────────────────────────
    get accNum0() { return this._accNumClass(0); }
    get accNum1() { return this._accNumClass(1); }
    get accNum2() { return this._accNumClass(2); }
    get accNum3() { return this._accNumClass(3); }

    _accNumClass(idx) {
        let cls = 'acc-num';
        if (this.sections[idx].isOpen) cls += ' active';
        if (this.sections[idx].isDone) cls += ' done';
        return cls;
    }

    // ─── Ouverture / fermeture ───────────────────────────────
    get sec0Open() { return this.sections[0].isOpen; }
    get sec1Open() { return this.sections[1].isOpen; }
    get sec2Open() { return this.sections[2].isOpen; }
    get sec3Open() { return this.sections[3].isOpen; }

    // ─── Done flags ──────────────────────────────────────────
    get sec0Done() { return this.sections[0].isDone; }
    get sec1Done() { return this.sections[1].isDone; }
    get sec2Done() { return this.sections[2].isDone; }
    get sec3Done() { return this.sections[3].isDone; }

    // ─── Flèches accordéon ───────────────────────────────────
    get sec0Arrow() { return this.sections[0].isOpen ? '▲' : '▼'; }
    get sec1Arrow() { return this.sections[1].isOpen ? '▲' : '▼'; }
    get sec2Arrow() { return this.sections[2].isOpen ? '▲' : '▼'; }
    get sec3Arrow() { return this.sections[3].isOpen ? '▲' : '▼'; }

    // ═══════════════════════════════════════════════════════════
    // NAVIGATION — handlers
    // ═══════════════════════════════════════════════════════════

    /**
     * Clic sur "Valider cette section" (data-index sur le bouton)
     * → marque la section comme done + ouvre la suivante
     */
    markDone(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);

        // Validation minimale avant de cocher
        if (!this._validateSection(idx)) return;

        this.sections = this.sections.map((s, i) => {
            if (i === idx)     return { ...s, isDone: true,  isOpen: false };
            if (i === idx + 1) return { ...s, isOpen: true };
            return s;
        });
    }

    /**
     * Clic sur une étape du sidebar
     */
    handleStepClick(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.sections = this.sections.map((s, i) => ({ ...s, isOpen: (i === idx) }));
    }

    /**
     * Toggle accordéon
     */
    handleSectionToggle(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.sections = this.sections.map((s, i) => ({
            ...s,
            isOpen: (i === idx) ? !s.isOpen : s.isOpen
        }));
    }

    // ═══════════════════════════════════════════════════════════
    // VALIDATION LOCALE PAR SECTION
    // ═══════════════════════════════════════════════════════════

    _validateSection(idx) {
        switch (idx) {
            case 0:
                if (!this.formData.numeroPolice || !this.formData.dateEffet || !this.formData.dateExpiration) {
                    this._showToast('Champs manquants', 'Veuillez remplir le numéro de police, la date d\'effet et la date d\'expiration.', 'warning');
                    return false;
                }
                break;
            case 1:
                if (!this.formData.nomComplet || !this.formData.cin) {
                    this._showToast('Champs manquants', 'Veuillez remplir le nom complet et le CIN.', 'warning');
                    return false;
                }
                break;
            case 2:
                if (!this.formData.immatriculation) {
                    this._showToast('Champs manquants', 'Veuillez renseigner le numéro d\'immatriculation.', 'warning');
                    return false;
                }
                break;
            case 3:
                if (this.selectedGaranties.length === 0) {
                    this._showToast('Aucune garantie', 'Veuillez sélectionner au moins une garantie.', 'warning');
                    return false;
                }
                break;
            default:
                break;
        }
        return true;
    }

    // ═══════════════════════════════════════════════════════════
    // FORMULAIRE
    // ═══════════════════════════════════════════════════════════

    handleChange(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
    }

    handleGarantieSelection(event) {
        this.selectedGaranties = event.detail.selectedRows.map(r => r.id);
    }

    // ═══════════════════════════════════════════════════════════
    // ACTIONS FINALES
    // ═══════════════════════════════════════════════════════════

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Home' }
        });
    }

    async handleConfirm() {
        // Validation globale des champs obligatoires
        if (!this._validateAll()) return;

        try {
            // 1. Vérification CIN
            if (!this.cinConfirmed) {
                const cinResult = await checkCin({ cin: this.formData.cin });
                if (cinResult.exists) {
                    this.showCinPopup = true;
                    return;
                }
            }

            // 2. Vérification immatriculation
            if (!this.vehiculeConfirmed) {
                const immaResult = await checkImmatriculation({ immatriculation: this.formData.immatriculation });

                if (immaResult.exists) {
                    if (immaResult.isActif) {
                        // Police active → BLOCAGE
                        this.showVehiculeBlockPopup = true;
                        return;
                    } else {
                        // Police résiliée/suspendue → AVERTISSEMENT
                        this.vehiculeWarnMessage =
                            `Ce véhicule est déjà assigné à la police [${immaResult.numeroPolice}]`
                            + ` - [${immaResult.situationPolice}].`
                            + ' Êtes-vous sûr de vouloir créer une nouvelle police ?';
                        this.showVehiculeWarnPopup = true;
                        return;
                    }
                }
            }

            // 3. Création
            await this._callCreerPolice();

        } catch (error) {
            console.error('Erreur handleConfirm :', error);
            this._showToast('Erreur', 'Une erreur technique est survenue. Veuillez réessayer.', 'error');
        }
    }

    async _callCreerPolice() {
        await creerPolice({
            formData:          JSON.stringify(this.formData),
            garanties:         this.selectedGaranties,
            cinConfirmed:      this.cinConfirmed,
            vehiculeConfirmed: this.vehiculeConfirmed
        });
        this._showToast('Succès !', 'La police d\'assurance a été créée avec succès.', 'success');
        this.handleCancel();
    }

    _validateAll() {
        const required = [
            { field: 'numeroPolice',   label: 'Numéro de police' },
            { field: 'dateEffet',      label: 'Date d\'effet' },
            { field: 'dateExpiration', label: 'Date d\'expiration' },
            { field: 'nomComplet',     label: 'Nom complet' },
            { field: 'cin',            label: 'CIN' },
            { field: 'immatriculation', label: 'Numéro d\'immatriculation' }
        ];
        const missing = required.filter(r => !this.formData[r.field]).map(r => r.label);
        if (missing.length > 0) {
            this._showToast(
                'Champs obligatoires manquants',
                'Veuillez remplir : ' + missing.join(', '),
                'warning'
            );
            return false;
        }
        return true;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─── Popup CIN ───────────────────────────────────────────
    closeCinPopup() { this.showCinPopup = false; }

    confirmCin() {
        this.cinConfirmed = true;
        this.showCinPopup = false;
        this.handleConfirm();
    }

    // ─── Popup Véhicule bloqué ───────────────────────────────
    closeVehiculeBlockPopup() { this.showVehiculeBlockPopup = false; }

    // ─── Popup Véhicule avertissement ────────────────────────
    closeVehiculeWarnPopup() { this.showVehiculeWarnPopup = false; }

    confirmVehicule() {
        this.vehiculeConfirmed   = true;
        this.showVehiculeWarnPopup = false;
        this.handleConfirm();
    }

    // ═══════════════════════════════════════════════════════════
    // PICKLISTS / OPTIONS
    // ═══════════════════════════════════════════════════════════

    categorieOptions = [
        { label: 'Individuelle', value: 'Individuelle' },
        { label: 'Commerciale',  value: 'Commerciale'  }
    ];

    canalOptions = [
        { label: 'Agent',    value: 'Agent'    },
        { label: 'Courtier', value: 'Courtier' },
        { label: 'Direct',   value: 'Direct'   }
    ];

    situationPoliceOptions = [
        { label: 'En cours',   value: 'En cours'   },
        { label: 'Suspendue',  value: 'Suspendue'  },
        { label: 'Résiliée',   value: 'Résiliée'   },
        { label: 'Expirée',    value: 'Expirée'    }
    ];

    situationPrimeOptions = [
        { label: 'Payée',     value: 'Payée'     },
        { label: 'Non Payée', value: 'Non Payée' },
        { label: 'Annulée',   value: 'Annulée'   }
    ];

    typeVehiculeOptions = [
        { label: 'Tourisme',     value: 'Tourisme'     },
        { label: 'Utilitaire',   value: 'Utilitaire'   },
        { label: 'Moto',         value: 'Moto'         },
        { label: 'Camion',       value: 'Camion'       },
        { label: 'Bus / Car',    value: 'Bus'          }
    ];

    // ─── Colonnes du datatable garanties ─────────────────────
    garantiesColumns = [
        { label: 'Nom de la garantie', fieldName: 'nom',  type: 'text' },
        { label: 'Code',               fieldName: 'code', type: 'text' }
    ];

    // ─── Données garanties (à remplacer par un appel Apex) ───
    garanties = [
        { id: 'RC-01',  nom: 'Responsabilité Civile',        code: 'RC-01'  },
        { id: 'DC-02',  nom: 'Dommages Collision',           code: 'DC-02'  },
        { id: 'INC-03', nom: 'Incendie / Explosion',         code: 'INC-03' },
        { id: 'VOL-04', nom: 'Vol',                          code: 'VOL-04' },
        { id: 'BR-05',  nom: 'Bris de glace',                code: 'BR-05'  },
        { id: 'AT-06',  nom: 'Assistance Dépannage',         code: 'AT-06'  }
    ];
}