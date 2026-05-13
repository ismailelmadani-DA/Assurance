import { LightningElement, api, track } from 'lwc';
import { NavigationMixin }              from 'lightning/navigation';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';

// — Flag imports —
import getClaimFlagData from '@salesforce/apex/DA_FlagSinistreController.getClaimFlagData';
import saveFlags        from '@salesforce/apex/DA_FlagSinistreController.saveFlags';

// — Événement imports (controller séparé) —
import getMatchingEvenements from '@salesforce/apex/DA_lwc021_ClaimEvenementController.getMatchingEvenements';
import getEvenementAssocie   from '@salesforce/apex/DA_lwc021_ClaimEvenementController.getEvenementAssocie';
import associerEvenement     from '@salesforce/apex/DA_lwc021_ClaimEvenementController.associerEvenement';
import isPopupEvenementVu    from '@salesforce/apex/DA_lwc021_ClaimEvenementController.isPopupEvenementVu';
import marquerPopupVu        from '@salesforce/apex/DA_lwc021_ClaimEvenementController.marquerPopupVu';

const FLAG_LIST = ['Sensible', 'Majeur', 'Grave', 'Frauduleux', 'Douteux'];

export default class DA_lwc019_FlagSinistre extends NavigationMixin(LightningElement) {

    @api recordId;

    // ── État Flag ──────────────────────────────────────────────────
    @track isModalOpen      = false;
    @track currentFlags     = [];
    @track selectedFlags    = [];
    @track commentaire      = '';
    @track isSaving         = false;
    @track isPrivileged     = false;
    @track pendingRequests  = [];
    @track claimName        = '';

    // ── État Événement ─────────────────────────────────────────────
    @track showEvenementPopup   = false;
    @track isEvenementLoading   = false;
    @track isEvenementSaving    = false;
    @track matchingEvenements   = [];
    @track selectedEventId      = null;
    @track evenementAssocie     = null;
    @track hasAnyMatchingEvents = false;
    @track isModifierMode       = false; // ✅ AJOUT : distingue "Associer" vs "Modifier"

    // ── Lifecycle ──────────────────────────────────────────────────
    connectedCallback() {
        this.loadData();
        this._loadEvenementAssocie();
    }

    // ════════════════════════════════════════
    // FLAG — logique existante inchangée
    // ════════════════════════════════════════

    async loadData() {
        try {
            const data = await getClaimFlagData({ claimId: this.recordId });
            this.currentFlags    = data.currentFlags    || [];
            this.pendingRequests = data.pendingRequests || [];
            this.isPrivileged    = data.isPrivileged;
            this.claimName       = data.claimName;
        } catch (error) {
            this.showToast('Erreur', this.extractError(error), 'error');
        }
    }

    get hasPendingRequests() {
        return this.pendingRequests && this.pendingRequests.length > 0;
    }

    get flagOptions() {
        const RESTRICTED   = ['Frauduleux', 'Douteux'];
        const pendingFlags = this.pendingRequests.map(r => r.flag);
        const hasFrauduleux = this.selectedFlags.includes('Frauduleux');
        const hasDouteux    = this.selectedFlags.includes('Douteux');

        return FLAG_LIST.map(flag => {
            let disabled      = false;
            let pendingLabel  = '';
            const isRestricted = RESTRICTED.includes(flag);
            let disabledReason = '';

            if (isRestricted && !this.isPrivileged) {
                const otherFlag = flag === 'Frauduleux' ? 'Douteux' : 'Frauduleux';
                if (pendingFlags.includes(flag)) {
                    disabled = true;
                    disabledReason = 'Une demande est déjà en attente de validation pour le flag "' + flag + '".';
                } else if (pendingFlags.includes(otherFlag)) {
                    disabled = true;
                    disabledReason = 'Vous ne pouvez pas sélectionner ce flag tant que le flag "' + otherFlag + '" est en attente de validation.';
                } else if (flag === 'Frauduleux' && hasDouteux) {
                    disabled = true;
                    disabledReason = 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.';
                } else if (flag === 'Douteux' && hasFrauduleux) {
                    disabled = true;
                    disabledReason = 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.';
                }
            }
            if (pendingFlags.includes(flag)) pendingLabel = 'En attente';

            return { value: flag, label: flag, checked: this.selectedFlags.includes(flag), disabled, disabledReason, pendingLabel };
        });
    }

    handleOpenModal() {
        this.selectedFlags = [...this.currentFlags];
        this.commentaire   = '';
        this.isModalOpen   = true;
    }

    handleCloseModal() { this.isModalOpen = false; }

    handleDisabledClick(event) {
        const flag = event.currentTarget.dataset.flag;
        const opt  = this.flagOptions.find(o => o.value === flag);
        if (opt && opt.disabled && opt.disabledReason) {
            this.showToast('Action non disponible', opt.disabledReason, 'warning');
        }
    }

    handleFlagChange(event) {
        const flag        = event.target.dataset.flag;
        const isChecked   = event.target.checked;
        const RESTRICTED  = ['Frauduleux', 'Douteux'];
        const isRestricted = RESTRICTED.includes(flag);
        const pendingFlags = this.pendingRequests.map(r => r.flag);

        if (isRestricted && !this.isPrivileged && isChecked) {
            const otherFlag = flag === 'Frauduleux' ? 'Douteux' : 'Frauduleux';
            if (pendingFlags.includes(flag) || pendingFlags.includes(otherFlag) || this.selectedFlags.includes(otherFlag)) {
                event.target.checked = false;
                return;
            }
        }

        let flags = [...this.selectedFlags];
        if (isChecked) { if (!flags.includes(flag)) flags.push(flag); }
        else           { flags = flags.filter(f => f !== flag); }
        this.selectedFlags = flags;
    }

    handleCommentChange(event) { this.commentaire = event.target.value; }

    async handleConfirm() {
        if (!this.commentaire || this.commentaire.trim() === '') {
            this.showToast('Erreur', 'Le commentaire est obligatoire.', 'error');
            return;
        }
        if (this.selectedFlags.includes('Frauduleux') && this.selectedFlags.includes('Douteux')) {
            this.showToast('Erreur', 'Les flags "Frauduleux" et "Douteux" ne peuvent pas être sélectionnés en même temps.', 'error');
            return;
        }
        this.isSaving = true;
        try {
            const result = await saveFlags({
                claimId      : this.recordId,
                selectedFlags: this.selectedFlags,
                commentaire  : this.commentaire.trim()
            });
            if (result.success) {
                this.showToast('Succès', result.message, 'success');
                this.isModalOpen = false;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { window.location.reload(); }, 500);
            } else {
                this.showToast('Erreur', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Erreur', this.extractError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ════════════════════════════════════════
    // ÉVÉNEMENT — logique migrée
    // ════════════════════════════════════════

    async _loadEvenementAssocie() {
        try {
            const result = await getEvenementAssocie({ claimId: this.recordId });
            this.evenementAssocie = result || null;

            if (!this.evenementAssocie) {
                const dejaVu = await isPopupEvenementVu({ claimId: this.recordId });
                const raw    = await getMatchingEvenements({ claimId: this.recordId });
                this.hasAnyMatchingEvents = raw && raw.length > 0;

                if (this.hasAnyMatchingEvents && !dejaVu) {
                    this.isModifierMode  = false;   // ✅ popup auto = mode associer
                    this.selectedEventId = null;
                    this.matchingEvenements = raw.map(ev => this._decorate(ev));
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => { this.showEvenementPopup = true; }, 600);
                }
            } else {
                this.hasAnyMatchingEvents = true;
            }
        } catch (e) {
            console.error('Erreur chargement événement associé', e);
        }
    }

    openEvenementPopup() {
        // ✅ Déterminer le mode selon qu'un événement est déjà associé
        this.isModifierMode  = !!this.evenementAssocie;
        // ✅ Pré-sélectionner l'événement associé en mode modifier, sinon rien
        this.selectedEventId = this.isModifierMode ? this.evenementAssocie.Id : null;

        this.showEvenementPopup = true;

        if (this.matchingEvenements.length === 0) {
            this._fetchMatchingEvents();
        } else {
            // ✅ Re-décorer la liste pour refléter la pré-sélection
            this.matchingEvenements = this.matchingEvenements.map(ev => this._decorate(ev));
        }
    }

    closeEvenementPopup() {
        this.showEvenementPopup = false;
        this.selectedEventId    = null;
        this.matchingEvenements = [];
        this.isModifierMode     = false;
        marquerPopupVu({ claimId: this.recordId }).catch(e => {
            console.error('Erreur marquerPopupVu', e);
        });
    }

    _fermerEvenementSansMarquer() {
        this.showEvenementPopup = false;
        this.selectedEventId    = null;
        this.matchingEvenements = [];
        this.isModifierMode     = false;
    }

    async _fetchMatchingEvents() {
        this.isEvenementLoading = true;
        try {
            const raw = await getMatchingEvenements({ claimId: this.recordId });
            // ✅ En mode modifier, s'assurer que la pré-sélection est active avant de décorer
            if (this.isModifierMode && this.evenementAssocie) {
                this.selectedEventId = this.evenementAssocie.Id;
            }
            this.matchingEvenements = raw.map(ev => this._decorate(ev));
        } catch (e) {
            console.error('Erreur récupération événements', e);
            this.showToast('Erreur', 'Impossible de charger les événements correspondants.', 'error');
        } finally {
            this.isEvenementLoading = false;
        }
    }

    _decorate(ev) {
        const isSelected = ev.Id === this.selectedEventId;
        return {
            ...ev,
            isSelected,
            rowClass  : `sep-event-row${isSelected ? ' sep-event-row--selected' : ''}`,
            radioClass: `sep-radio${isSelected ? ' sep-radio--checked' : ''}`
        };
    }

    handleSelectEvent(evt) {
        this.selectedEventId    = evt.currentTarget.dataset.id;
        this.matchingEvenements = this.matchingEvenements.map(ev => this._decorate(ev));
    }

    async handleEvenementConfirm() {
        if (!this.selectedEventId) return;
        this.isEvenementSaving = true;
        try {
            await associerEvenement({ claimId: this.recordId, evenementId: this.selectedEventId });
            const ev = this.matchingEvenements.find(e => e.Id === this.selectedEventId);
            this.evenementAssocie = ev || null;
            this._fermerEvenementSansMarquer();
            this.showToast('Succès', `L'événement "${ev ? ev.Libelle__c : ''}" a été associé au sinistre.`, 'success');

            // Notifier le compact layout de se rafraîchir
            window.dispatchEvent(new CustomEvent('evenementassocie'));

        } catch (e) {
            this.showToast('Erreur', e?.body?.message || 'Impossible d\'associer l\'événement.', 'error');
        } finally {
            this.isEvenementSaving = false;
        }
    }

    handleEvenementOverlayClick() { this.closeEvenementPopup(); }
    stopPropagation(evt)          { evt.stopPropagation(); }

    // ── Getters Événement ──────────────────────────────────────────

    get isEvenementVisible() {
        return this.evenementAssocie !== null || this.hasAnyMatchingEvents;
    }

    get hasMatchingEvents() {
        return this.matchingEvenements && this.matchingEvenements.length > 0;
    }

    get matchingEvenementsCount() {
        return this.matchingEvenements ? this.matchingEvenements.length : 0;
    }

    get isEvenementConfirmDisabled() {
        return !this.selectedEventId || this.isEvenementSaving;
    }

    // ✅ AJOUT : titre dynamique selon le mode
    get popupTitre() {
        return this.isModifierMode ? "Modifier l'événement associé" : 'Associer un événement';
    }

    // ✅ AJOUT : sous-titre dynamique selon le mode
    get popupSousTitre() {
        return this.isModifierMode
            ? `Événement actuel : ${this.evenementAssocie?.Libelle__c || ''}`
            : 'Événements correspondant à ce sinistre';
    }

    // ── Helpers communs ────────────────────────────────────────────
    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message)       return error.message;
        return 'Une erreur inattendue est survenue.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'sticky' }));
    }
}