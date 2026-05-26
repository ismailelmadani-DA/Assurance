import { LightningElement, api, track } from 'lwc';
import { NavigationMixin }              from 'lightning/navigation';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import getMatchingEvenements            from '@salesforce/apex/DA_lwc021_ClaimEvenementController.getMatchingEvenements';
import getEvenementAssocie              from '@salesforce/apex/DA_lwc021_ClaimEvenementController.getEvenementAssocie';
import associerEvenement                from '@salesforce/apex/DA_lwc021_ClaimEvenementController.associerEvenement';
import isPopupEvenementVu               from '@salesforce/apex/DA_lwc021_ClaimEvenementController.isPopupEvenementVu';
import marquerPopupVu                   from '@salesforce/apex/DA_lwc021_ClaimEvenementController.marquerPopupVu';

export default class DA_lwc021_claimEvenement extends NavigationMixin(LightningElement) {

    // ─── Propriété reçue depuis la page Lightning ────────────────
    @api recordId;

    // ─── État interne ─────────────────────────────────────────────
    @track showPopup            = false;
    @track isLoading            = false;
    @track isSaving             = false;
    @track matchingEvenements   = [];
    @track selectedEventId      = null;
    @track evenementAssocie     = null;
    @track hasAnyMatchingEvents = false;

    // ─── Lifecycle ────────────────────────────────────────────────
    connectedCallback() {
        this._loadEvenementAssocie();
    }

    // ─── Chargement initial ───────────────────────────────────────
    async _loadEvenementAssocie() {
        try {
            const result = await getEvenementAssocie({ claimId: this.recordId });
            this.evenementAssocie = result || null;

            if (!this.evenementAssocie) {
                const dejaVu = await isPopupEvenementVu({ claimId: this.recordId });
                const raw    = await getMatchingEvenements({ claimId: this.recordId });
                this.hasAnyMatchingEvents = raw && raw.length > 0;

                // Ouvrir auto uniquement si jamais vu ET événements trouvés
                if (this.hasAnyMatchingEvents && !dejaVu) {
                    this.matchingEvenements = raw.map(ev => this._decorate(ev));
                    this._openWithDelay();
                }
            } else {
                this.hasAnyMatchingEvents = true;
            }
        } catch (e) {
            console.error('Erreur chargement événement associé', e);
        }
    }

    _openWithDelay() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showPopup = true; }, 600);
    }

    // ─── Ouvrir manuellement (bouton Ajouter / Modifier) ─────────
    openPopup() {
        this.showPopup       = true;
        this.selectedEventId = null;
        if (this.matchingEvenements.length === 0) {
            this._fetchMatchingEvents();
        }
    }

    // ─── Fermer (Annuler / ✕ / overlay) → persiste PopupEvenementVu__c ──
    closePopup() {
        this.showPopup          = false;
        this.selectedEventId    = null;
        this.matchingEvenements = [];
        marquerPopupVu({ claimId: this.recordId }).catch(e => {
            console.error('Erreur marquerPopupVu', e);
        });
    }

    // ─── Fermer après confirmation (PopupEvenementVu déjà mis à true par associerEvenement) ──
    _fermerPopupSansMarquer() {
        this.showPopup          = false;
        this.selectedEventId    = null;
        this.matchingEvenements = [];
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
        await associerEvenement({
            claimId     : this.recordId,
            evenementId : this.selectedEventId
        });

        const ev = this.matchingEvenements.find(e => e.Id === this.selectedEventId);
        this.evenementAssocie = ev || null;

        this._fermerPopupSansMarquer();

        this.dispatchEvent(new ShowToastEvent({
            title   : 'Succès',
            message : `L'événement "${ev ? ev.Libelle__c : ''}" a été associé au sinistre.`,
            variant : 'success'
        }));
    } catch (e) {
        this.dispatchEvent(new ShowToastEvent({
            title   : 'Erreur',
            message : e?.body?.message || 'Impossible d\'associer l\'événement. Veuillez réessayer.',
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
    get isVisible() {
        return this.evenementAssocie !== null || this.hasAnyMatchingEvents;
    }

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