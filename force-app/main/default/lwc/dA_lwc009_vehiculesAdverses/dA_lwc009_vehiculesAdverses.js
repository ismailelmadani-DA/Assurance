import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent }                     from 'lightning/platformShowToastEvent';
import { refreshApex }                        from '@salesforce/apex';
import getVehiculesAdverses                   from '@salesforce/apex/DA_VehiculeAdverseController.getVehiculesAdverses';
import saveVehiculeAdverse                    from '@salesforce/apex/DA_VehiculeAdverseController.saveVehiculeAdverse';
import deleteVehiculeAdverse                  from '@salesforce/apex/DA_VehiculeAdverseController.deleteVehiculeAdverse';
import getPicklistValues                      from '@salesforce/apex/DA_VehiculeAdverseController.getPicklistValues';
import getObjectPrefixes                      from '@salesforce/apex/DA_VehiculeAdverseController.getObjectPrefixes';

export default class DA_lwc009_vehiculesAdverses extends LightningElement {

    @api recordId;

    @track vehicules          = [];
    @track isLoading          = true;
    @track showModal          = false;
    @track showDeleteConfirm  = false;
    @track selectedRecordId   = null;
    @track selectedVehiculeId = null;
    @track isSaving           = false;

    // Prefixes chargés dynamiquement depuis Apex
    _claimPrefix = null;
    _casePrefix  = null;

    @track form = {
        etatVehicule          : '',
        nbPassagers           : 0,
        adversaireAssure      : false,
        pays                  : '',
        compagnieAdverse      : null,
        immatriculation       : '',
        marque                : '',
        typeVehicule          : '',
        dateMiseEnCirculation : null,
        proprietaire          : null
    };

    // ── Options picklists (chargées dynamiquement) ────────────────────────
    @track etatVehiculeOptions = [];
    @track paysOptions         = [];
    @track marqueOptions       = [];
    @track typeVehiculeOptions = [];

    _wiredResult = null;

    // ── Wire : prefixes dynamiques ────────────────────────────────────────
    @wire(getObjectPrefixes)
    wiredPrefixes({ data, error }) {
        if (data) {
            this._claimPrefix = data.claim;
            this._casePrefix  = data.case;
        } else if (error) {
            console.error('Erreur prefixes', error);
        }
    }

    // ── Wire : picklists dynamiques ───────────────────────────────────────
    @wire(getPicklistValues)
    wiredPicklists({ data, error }) {
        if (data) {
            this.etatVehiculeOptions = data.EtatVehicule__c.map(o => ({ label: o.label, value: o.value }));
            this.paysOptions         = data.Pays__c.map(o => ({ label: o.label, value: o.value }));
            this.marqueOptions       = data.Brand__c.map(o => ({ label: o.label, value: o.value }));
            this.typeVehiculeOptions = data.TypeVehicule__c.map(o => ({ label: o.label, value: o.value }));
        } else if (error) {
            console.error('Erreur picklists', error);
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────
    get isEmpty() {
        return !this.isLoading && (!this.vehicules || this.vehicules.length === 0);
    }

    get isAddMode() {
        return this.selectedRecordId === null;
    }

    get modalTitle() {
        return this.isAddMode ? 'Ajouter un véhicule adverse' : 'Modifier le véhicule adverse';
    }

    get isClaim() {
        return this._claimPrefix && this.recordId?.substring(0, 3) === this._claimPrefix;
    }

    // ── Wire : données ────────────────────────────────────────────────────
    @wire(getVehiculesAdverses, { recordId: '$recordId' })
    wiredVehicules(result) {
        this._wiredResult = result;
        this.isLoading    = false;

        if (result.data) {
            this.vehicules = result.data.map(v => ({
                ...v,
                nomVehicule     : v.Vehicule__r ? v.Vehicule__r.Name                   || '—' : '—',
                immatriculation : v.Vehicule__r ? v.Vehicule__r.RegistrationNumber__c  || '—' : '—',
                marqueAffichee  : v.Vehicule__r ? v.Vehicule__r.Brand__c               || '—' : '—',
                etatBadgeClass  : v.EtatVehicule__c === 'Endommagé'
                    ? 'pm-state pm-state--blesse'
                    : v.EtatVehicule__c === 'Pas de dommage'
                    ? 'pm-state pm-state--indemne'
                    : 'pm-state pm-state--default'
            }));
        } else if (result.error) {
            this.showToast('Erreur', result.error.body?.message ?? 'Erreur inconnue', 'error');
        }
    }

    // ── Ajout ─────────────────────────────────────────────────────────────
    handleAdd() {
        this.selectedRecordId   = null;
        this.selectedVehiculeId = null;
        this.form = {
            etatVehicule: '', nbPassagers: 0, adversaireAssure: false,
            pays: '', compagnieAdverse: null, immatriculation: '',
            marque: '', typeVehicule: '', dateMiseEnCirculation: null,
            proprietaire: null
        };
        this.showModal = true;
    }

    // ── Modification ──────────────────────────────────────────────────────
    handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        const v  = this.vehicules.find(x => x.Id === id);

        this.selectedRecordId   = v.Id;
        this.selectedVehiculeId = v.Vehicule__c || null;

        this.form = {
            etatVehicule          : v.EtatVehicule__c || '',
            nbPassagers           : v.NbDePassagerBlesses__c || 0,
            adversaireAssure      : v.AdversaireAssure__c || false,
            pays                  : v.Pays__c || '',
            compagnieAdverse      : v.CompagnieAdverse__c || null,
            immatriculation       : v.Vehicule__r ? v.Vehicule__r.RegistrationNumber__c  || '' : '',
            marque                : v.Vehicule__r ? v.Vehicule__r.Brand__c               || '' : '',
            typeVehicule          : v.Vehicule__r ? v.Vehicule__r.TypeVehicule__c        || '' : '',
            dateMiseEnCirculation : v.Vehicule__r ? v.Vehicule__r.DateOfFirstRegistration__c || null : null,
            proprietaire          : v.Vehicule__r ? v.Vehicule__r.ProprietaireDuVehicule__c  || null : null
        };

        this.showModal = true;
    }

    // ── Champs formulaire ─────────────────────────────────────────────────
    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.type === 'checkbox'
            ? event.target.checked
            : event.target.value;
        this.form = { ...this.form, [field]: value };
    }

    // ── Sauvegarde ────────────────────────────────────────────────────────
    handleSave() {
        this.isSaving = true;
        saveVehiculeAdverse({
            recordId             : this.recordId,
            assignmentId         : this.selectedRecordId,
            vehiculeId           : this.selectedVehiculeId,
            etatVehicule         : this.form.etatVehicule,
            nbPassagers          : this.form.nbPassagers,
            adversaireAssure     : this.form.adversaireAssure,
            pays                 : this.form.pays,
            compagnieAdverse     : this.form.compagnieAdverse,
            immatriculation      : this.form.immatriculation,
            marque               : this.form.marque,
            typeVehicule         : this.form.typeVehicule,
            dateMiseEnCirculation: this.form.dateMiseEnCirculation,
            proprietaire         : this.form.proprietaire
        })
        .then(() => {
            const msg = this.isAddMode
                ? 'Véhicule ajouté avec succès.'
                : 'Véhicule modifié avec succès.';
            this.showToast('Succès', msg, 'success');
            this.closeModal();
            return refreshApex(this._wiredResult);
        })
        .catch(error => {
            this.showToast('Erreur', error.body?.message ?? 'Erreur inconnue', 'error');
        })
        .finally(() => {
            this.isSaving = false;
        });
    }

    // ── Suppression ───────────────────────────────────────────────────────
    handleDelete(event) {
        this.selectedRecordId  = event.currentTarget.dataset.id;
        this.showDeleteConfirm = true;
    }

    cancelDelete() {
        this.showDeleteConfirm = false;
        this.selectedRecordId  = null;
    }

    confirmDelete() {
        deleteVehiculeAdverse({ recordId: this.selectedRecordId })
            .then(() => {
                this.showToast('Succès', 'Véhicule supprimé avec succès.', 'success');
                this.showDeleteConfirm = false;
                this.selectedRecordId  = null;
                return refreshApex(this._wiredResult);
            })
            .catch(error => {
                this.showToast('Erreur', error.body?.message ?? 'Erreur inconnue', 'error');
            });
    }

    // ── Modal ─────────────────────────────────────────────────────────────
    closeModal() {
        this.showModal        = false;
        this.selectedRecordId = null;
    }

    // ── Toast ─────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}