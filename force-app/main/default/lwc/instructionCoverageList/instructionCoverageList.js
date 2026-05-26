import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getInstructionCoverages from '@salesforce/apex/DA_InstructionCoverageController.getInstructionCoverages';

/**
 * Composant LWC - InstructionCoverageList
 * Affiche la liste des Instruction Coverages avec 2 colonnes:
 * - Code de la garantie
 * - Nom de la garantie (cliquable)
 * Design Wafa Brand
 */
export default class InstructionCoverageList extends NavigationMixin(LightningElement) {
    @api recordId;
    @track data = [];
    @track error = null;
    @track isLoading = true;
    @track wiredResult = null;

    /**
     * Wire service pour charger les données des Instruction Coverages
     * @param {Object} result - Résultat de la requête Apex
     */
    @wire(getInstructionCoverages, { instructionId: '$recordId' })
    wiredData(result) {
        this.wiredResult = result;
        this.isLoading = true;

        if (result.data) {
            // Traiter les données pour afficher Code Garantie et Nom Garantie
            this.data = result.data.map((item, index) => {
                const codeGarantie = this.getNestedValue(item, 'ClaimCoverage__r.CodeGarantie__c') || '—';
                const claimCoverageName = this.getNestedValue(item, 'ClaimCoverage__r.Name') || '—';
                
                return {
                    Id: item.Id,
                    CodeGarantie: codeGarantie,
                    ClaimCoverageName: claimCoverageName
                };
            });

            this.error = null;
            this.isLoading = false;

            console.log('✅ InstructionCoverageList - Données chargées:', this.data);
            console.log('✅ Nombre d\'enregistrements:', this.data.length);
        } else if (result.error) {
            // Gérer les erreurs
            this.error = this.getErrorMessage(result.error);
            this.data = [];
            this.isLoading = false;

            console.error('❌ InstructionCoverageList - Erreur:', this.error);
            console.error('Détails de l\'erreur:', result.error);
        }
    }

    /**
     * Getter pour vérifier s'il y a des données
     * @returns {boolean} true si data contient au moins un élément
     */
    get hasData() {
        return this.data && this.data.length > 0;
    }

    /**
     * Récupérer une valeur imbriquée dans un objet
     * @param {Object} obj - Objet source
     * @param {String} path - Chemin de la propriété (ex: 'ClaimCoverage__r.Name')
     * @returns {*} Valeur de la propriété ou undefined
     */
    getNestedValue(obj, path) {
        return path.split('.').reduce((current, prop) => current?.[prop], obj);
    }

    /**
     * Extraire le message d'erreur du résultat d'erreur Apex
     * @param {Object} error - Objet d'erreur
     * @returns {string} Message d'erreur formaté
     */
    getErrorMessage(error) {
        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            }
            if (error.body.fieldErrors && Object.keys(error.body.fieldErrors).length > 0) {
                return Object.values(error.body.fieldErrors)
                    .flat()
                    .map(e => e.message)
                    .join(', ');
            }
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors
                    .map(e => e.message)
                    .join(', ');
            }
        }
        return 'Une erreur inconnue est survenue';
    }

    /**
     * Rafraîchir les données
     */
    handleRefresh() {
        console.log('🔄 Rafraîchissement des données...');
        this.isLoading = true;
        
        if (this.wiredResult) {
            return this.wiredResult.data 
                ? Promise.resolve()
                : Promise.reject();
        }
    }

    /**
     * Naviguer vers le détail de l'Instruction_Coverage__c
     * @param {Event} event - Événement de clic
     */
    handleNavigateToRecord(event) {
        event.preventDefault();
        
        const recordId = event.currentTarget.dataset.recordId;
        
        if (recordId) {
            console.log('📍 Navigation vers l\'enregistrement:', recordId);
            
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        }
    }

    /**
     * Lifecycle hook - composant inséré dans le DOM
     */
    connectedCallback() {
        console.log('🎯 InstructionCoverageList - Initialisé avec recordId:', this.recordId);
    }

    /**
     * Lifecycle hook - composant déconnecté du DOM
     */
    disconnectedCallback() {
        console.log('⛔ InstructionCoverageList - Composant détruit');
    }
}