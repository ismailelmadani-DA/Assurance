import { LightningElement, api, track } from 'lwc';
import { NavigationMixin }              from 'lightning/navigation';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import getMatchingEvenements            from '@salesforce/apex/DA_lwc021_ClaimEvenementController.getMatchingEvenements';
import getEvenementAssocie              from '@salesforce/apex/DA_lwc021_ClaimEvenementController.getEvenementAssocie';
import associerEvenement                from '@salesforce/apex/DA_lwc021_ClaimEvenementController.associerEvenement';

export default class DA_lwc021_claimEvenement extends NavigationMixin(LightningElement) {

    // ─── Propriété reçue depuis la page Lightning ────────────────
    @api recordId;

    // ─── État interne ─────────────────────────────────────────────
    @track showPopup          = false;
    @track isLoading          = false;
    @track isSaving           = false;
    @track matchingEvenements = [];
    @track selectedEventId    = null;
    @track evenementAssocie   = null;

    // ─── Clé localStorage unique par sinistre ────────────────────
    get _storageKey() {
        return `claimEvenement_dismissed_${this.recordId}`;
    }

    get _autoPopupDismissed() {
        try {
            return localStorage.getItem(this._storageKey) === 'true';
        } catch (e) {
            return false;
        }
    }

    _markAutoPopupDismissed() {
        try {
            localStorage.setItem(this._storageKey, 'true');
        } catch (e) {
            console.error('Erreur localStorage', e);
        }
    }

    // ─── Lifecycle ────────────────────────────────────────────────
    connectedCallback() {
        this._loadEvenementAssocie();
    }

    // ─── Charger l'événement déjà associé ────────────────────────
    async _loadEvenementAssocie() {
        try {
            const result = await getEvenementAssocie({ claimId: this.recordId });
            this.evenementAssocie = result || null;

            // Pas d'événement associé ET l'utilisateur n'a pas encore fermé le popup
            // → vérifier s'il existe des événements correspondants avant d'ouvrir
            if (!this.evenementAssocie && !this._autoPopupDismissed) {
                await this._openIfMatchingEvents();
            }
        } catch (e) {
            console.error('Erreur chargement événement associé', e);
        }
    }

    // ─── Ouvrir la popup seulement si des événements matchent ────
    async _openIfMatchingEvents() {
        try {
            const raw = await getMatchingEvenements({ claimId: this.recordId });
            if (raw && raw.length > 0) {
                // Pré-remplir la liste pour éviter un double appel Apex
                this.matchingEvenements = raw.map(ev => this._decorate(ev));
                this._openWithDelay();
            }
            // Aucun événement → on n'ouvre pas
        } catch (e) {
            console.error('Erreur vérification événements correspondants', e);
        }
    }

    _openWithDelay() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showPopup = true; }, 600);
    }

    // ─── Ouvrir la popup (clic manuel sur le bouton) ──────────────
    openPopup() {
        this.showPopup       = true;
        this.selectedEventId = null;
        // Si la liste est déjà pré-chargée, on ne refait pas l'appel Apex
        if (this.matchingEvenements.length === 0) {
            this._fetchMatchingEvents();
        }
    }

    // ─── Fermer la popup ──────────────────────────────────────────
    closePopup() {
        this.showPopup          = false;
        this.selectedEventId    = null;
        this.matchingEvenements = [];
        // Mémoriser que l'utilisateur a fermé le popup → ne plus l'ouvrir automatiquement
        this._markAutoPopupDismissed();
    }

    // ─── Récupérer les événements correspondants ──────────────────
    async _fetchMatchingEvents() {
        this.isLoading = true;
        try {
            const raw = await getMatchingEvenements({ claimId: this.recordId });
            this.matchingEvenements = raw.map(ev => this._decorate(ev));
        } catch (e) {
            console.error('Erreur récupération événements', e);
            this.dispatchEvent(new ShowToastEvent({
                title   : 'Erreur',
                message : 'Impossible de charger les événements correspondants.',
                variant : 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Décorer un événement avec les classes CSS dynamiques ─────
    _decorate(ev) {
        const isSelected = ev.Id === this.selectedEventId;
        const isNat      = ev.Categorie__c &&
                           ev.Categorie__c.toLowerCase().includes('naturelle');
        return {
            ...ev,
            isSelected,
            rowClass  : `sep-event-row${isSelected ? ' sep-event-row--selected' : ''}`,
            radioClass: `sep-radio${isSelected ? ' sep-radio--checked' : ''}`,
            catClass  : isNat
                        ? 'sep-cat-badge sep-cat-badge--nat'
                        : 'sep-cat-badge sep-cat-badge--nonnat'
        };
    }

    // ─── Sélection radio ──────────────────────────────────────────
    handleSelectEvent(evt) {
        this.selectedEventId    = evt.currentTarget.dataset.id;
        this.matchingEvenements = this.matchingEvenements.map(ev => this._decorate(ev));
    }

    // ─── Confirmer l'association ──────────────────────────────────
    async handleConfirm() {
        if (!this.selectedEventId) return;
        this.isSaving = true;
        try {
            const result = await associerEvenement({
                claimId     : this.recordId,
                evenementId : this.selectedEventId
            });

            if (result && result.success === false) {
                this.dispatchEvent(new ShowToastEvent({
                    title   : 'Erreur',
                    message : result.message || 'Impossible d\'associer l\'événement.',
                    variant : 'error'
                }));
                return;
            }

            const ev = this.matchingEvenements.find(e => e.Id === this.selectedEventId);
            this.evenementAssocie = ev || null;
            this.closePopup();
            this.dispatchEvent(new ShowToastEvent({
                title   : 'Succès',
                message : `L'événement "${ev ? ev.Libelle__c : ''}" a été associé au sinistre.`,
                variant : 'success'
            }));
        } catch (e) {
            console.error('Erreur association', e);
            this.dispatchEvent(new ShowToastEvent({
                title   : 'Erreur',
                message : 'Impossible d\'associer l\'événement. Veuillez réessayer.',
                variant : 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }

    // ─── Navigation vers l'enregistrement événement ──────────────
    handleNavigateToEvenement(evt) {
        evt.preventDefault();
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId   : this.evenementAssocie.Id,
                actionName : 'view'
            }
        });
    }

    // ─── Fermer sur clic overlay ──────────────────────────────────
    handleOverlayClick() { this.closePopup(); }
    stopPropagation(evt) { evt.stopPropagation(); }

    // ─── Getters ──────────────────────────────────────────────────
    get hasMatchingEvents() {
        return this.matchingEvenements && this.matchingEvenements.length > 0;
    }

    get matchingEvenementsCount() {
        return this.matchingEvenements ? this.matchingEvenements.length : 0;
    }

    get isConfirmDisabled() {
        return !this.selectedEventId || this.isSaving;
    }

    get evenementUrl() {
        return this.evenementAssocie
            ? `/lightning/r/Evenement__c/${this.evenementAssocie.Id}/view`
            : '#';
    }
}