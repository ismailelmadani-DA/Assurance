import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { NavigationMixin } from 'lightning/navigation';

// Import des objets et champs pour Picklists dynamiques
import CASE_OBJECT from '@salesforce/schema/Case';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import COUNTRY_FIELD from '@salesforce/schema/Case.CountryOfOccurrence__c';
import CITY_FIELD from '@salesforce/schema/Case.CityOfOccurrence__c';
import CLAIMANT_FIELD from '@salesforce/schema/Case.Claimant__c';
import PV_FIELD from '@salesforce/schema/Case.IncidentReport__c';
import NOTIF_FIELD from '@salesforce/schema/Account.MoyenNotification__c';

// Apex
import searchPolicies from '@salesforce/apex/ClaimSearchController.searchPolicies';
import createCase from '@salesforce/apex/ClaimSearchController.createCase';
import getPicklistOptions from '@salesforce/apex/ClaimSearchController.getTypeDocumentsByReportoire';
import saveDocumentLocally from '@salesforce/apex/ClaimSearchController.saveDocumentLocally';
import updateCaseRecord from '@salesforce/apex/ClaimSearchController.updateCaseRecord';
import savePassengers from '@salesforce/apex/ClaimSearchController.savePassengers';
import saveAdverseVehicle from '@salesforce/apex/ClaimSearchController.saveAdverseVehicle';
import saveOtherParties from '@salesforce/apex/ClaimSearchController.saveOtherParties';
import finalizeClaimProcess from '@salesforce/apex/ClaimSearchController.finalizeClaimProcess';

export default class ClaimCreationWizard extends NavigationMixin(LightningElement) {

    // =========================================================
    // ÉTATS ET FLAGS
    // =========================================================
    @track currentStep = 1;
    @track isLoading = false;
    @track searchResults = [];
    @track isPoliceConnu;
    @track searchType;
    @track isFileUploaded = false;
    messageObligatoire = false;
    @api errorMessage = 'Prière d\'indexer le(s) document(s).';

    // =========================================================
    // ✅ CORRECTION 1 : Variables trackées pour l'étape 1
    // Sans ça, les champs perdent leur valeur quand on revient
    // =========================================================
    @track step1Data = {
        police: '',
        immat: '',
        dateSurvenance: '',
        heureSurvenance: '',
        critere: ''
    };

    // =========================================================
    // ✅ CORRECTION 4 : Flag pour éviter de recréer un Case 
    // si on revient à l'étape 4 après l'avoir déjà créé
    // =========================================================
    @track caseAlreadyCreated = false;

    // Date du jour dynamique
    @track todayDate = new Date().toISOString().split('T')[0];

    // --- Données Police & Véhicule ---
    @track selectedPolicyId;
    @track dateSurvenance;
    @track selectedPolicyRecord;
    @track IdPolice;
    @track PoliceValue;
    @track adverseVehicleData = [];
    @track otherPartiesData = [];

    // --- Variables pour l'objet Case (Étape 4) ---
    @track createdCaseId;
    @track createdCaseNumber;
    @track caseData = {
        country: '', city: '', address: '', dateDepot: '', declarant: '',
        pvConstat: '', commentaire: '', nomContact: '', telContact: '',
        mailContact: '', moyenNotification: ''
    };
    @track isSameAsInsured = false;

    // --- Variables pour l'étape 5 (Documents) ---
    @track files = [];
    @track uploadedDocumentIds = [];
    @track allPicklistData = {};
    @track optionsDirectory = [];
    @track optionsDocType = [];
    @track selectedDirectory = '';
    @track selectedDocType = '';
    @track firstPicklistValue = '';
    @track secondPicklistValue = '';
    @track document = {};
    MAX_FILE_SIZE = 3145728; // 3 MB

    // --- Variables pour les étapes 6, 7 et 8 ---
    @track claimId;
    @track circumstancesData = {};
    @track driverData = {};
    @track passengersData = [];

    // --- Options Picklists ---
    @track optionsPays = [];
    @track optionsVille = [];
    @track optionsDeclarant = [];
    @track optionsPV = [];
    @track optionsNotif = [];

    optionsOuiNon = [{ label: 'Oui', value: 'Oui' }, { label: 'Non', value: 'Non' }];
    optionsCriteres = [
        { label: "Numéro d'immatriculation", value: 'immatriculation' },
        { label: "Numéro d'attestation", value: 'attestation' },
        { label: "Numéro chassis", value: 'chassis' }
    ];
    optionsContact = [{ label: 'Oui', value: 'true' }, { label: 'Non', value: 'false' }];

    // =========================================================
    // WIRES : Données Case & Account
    // =========================================================
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT }) caseObjectInfo;
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: COUNTRY_FIELD })
    wiredPays({ data }) { if (data) this.optionsPays = data.values; }
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: CITY_FIELD })
    wiredVille({ data }) { if (data) this.optionsVille = data.values; }
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: CLAIMANT_FIELD })
    wiredDeclarant({ data }) { if (data) this.optionsDeclarant = data.values; }
    @wire(getPicklistValues, { recordTypeId: '$caseObjectInfo.data.defaultRecordTypeId', fieldApiName: PV_FIELD })
    wiredPV({ data }) { if (data) this.optionsPV = data.values; }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT }) accountObjectInfo;
    @wire(getPicklistValues, { recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId', fieldApiName: NOTIF_FIELD })
    wiredNotif({ data }) { if (data) this.optionsNotif = data.values; }

    // WIRE : Métadonnées Documents
    @wire(getPicklistOptions)
    wiredPicklistOptions({ error, data }) {
        if (data) {
            this.allPicklistData = data;
            this.optionsDirectory = Object.keys(data).map(key => ({ label: key, value: key }));
        } else if (error) {
            console.error('Erreur picklist documents:', error);
        }
    }

    // =========================================================
    // GETTERS DE NAVIGATION
    // =========================================================
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }
    get isStep7() { return this.currentStep === 7; }
    get isStep8() { return this.currentStep === 8; }
    get isStep9() { return this.currentStep === 9; }
    get isStep10() { return this.currentStep === 10; }
    get isStep11() { return this.currentStep === 11; }

    get showFooter() { return this.currentStep <= 11; }
    get showPrecedent() { return this.currentStep > 1; }

    get isOuiSelected() { return this.isPoliceConnu === 'Oui'; }
    get isNonSelected() { return this.isPoliceConnu === 'Non'; }
    get isSameAsInsuredString() { return this.isSameAsInsured.toString(); }
    get isUploadDisabled() { return !this.selectedDirectory || !this.selectedDocType; }

    get inputLabel() {
        const labels = {
            immatriculation: "Numéro d'immatriculation",
            attestation: "Numéro d'attestation",
            chassis: "Numéro chassis"
        };
        return labels[this.searchType] || "Valeur";
    }

    // =========================================================
    // GETTERS STEPPER (Classes CSS)
    // =========================================================
    get step1Class() { return this.currentStep === 1 ? 'step active' : 'step completed'; }
    get step1IconClass() { return this.currentStep > 1 ? 'circle-check' : 'circle-ring'; }
    get step2Class() { return this.currentStep === 2 ? 'step active' : (this.currentStep > 2 ? 'step completed' : 'step'); }
    get step2IconClass() { return this.currentStep === 2 ? 'circle-ring' : (this.currentStep > 2 ? 'circle-check' : 'square-gray'); }
    get step3Class() { return this.currentStep === 3 ? 'step active' : (this.currentStep > 3 ? 'step completed' : 'step'); }
    get step3IconClass() { return this.currentStep === 3 ? 'circle-ring' : (this.currentStep > 3 ? 'circle-check' : 'square-gray'); }
    get step4Class() { return this.currentStep === 4 ? 'step active' : (this.currentStep > 4 ? 'step completed' : 'step'); }
    get step4IconClass() { return this.currentStep === 4 ? 'circle-ring' : (this.currentStep > 4 ? 'circle-check' : 'square-gray'); }
    get step5Class() { return this.currentStep === 5 ? 'step active' : (this.currentStep > 5 ? 'step completed' : 'step'); }
    get step5IconClass() { return this.currentStep === 5 ? 'circle-ring' : (this.currentStep > 5 ? 'circle-check' : 'square-gray'); }
    get step6Class() { return this.currentStep === 6 ? 'step active' : (this.currentStep > 6 ? 'step completed' : 'step'); }
    get step6IconClass() { return this.currentStep === 6 ? 'circle-ring' : (this.currentStep > 6 ? 'circle-check' : 'square-gray'); }
    get step7Class() { return this.currentStep === 7 ? 'step active' : (this.currentStep > 7 ? 'step completed' : 'step'); }
    get step7IconClass() { return this.currentStep === 7 ? 'circle-ring' : (this.currentStep > 7 ? 'circle-check' : 'square-gray'); }
    get step8Class() { return this.currentStep === 8 ? 'step active' : (this.currentStep > 8 ? 'step completed' : 'step'); }
    get step8IconClass() { return this.currentStep === 8 ? 'circle-ring' : (this.currentStep > 8 ? 'circle-check' : 'square-gray'); }
    get step9Class() { return this.currentStep === 9 ? 'step active' : (this.currentStep > 9 ? 'step completed' : 'step'); }
    get step9IconClass() { return this.currentStep === 9 ? 'circle-ring' : (this.currentStep > 9 ? 'circle-check' : 'square-gray'); }
    get step10Class() { return this.currentStep === 10 ? 'step active' : (this.currentStep > 10 ? 'step completed' : 'step'); }
    get step10IconClass() { return this.currentStep === 10 ? 'circle-ring' : (this.currentStep > 10 ? 'circle-check' : 'square-gray'); }
    get step11Class() { return this.currentStep === 11 ? 'step active' : (this.currentStep > 11 ? 'step completed' : 'step'); }
    get step11IconClass() { return this.currentStep === 11 ? 'circle-ring' : (this.currentStep > 11 ? 'circle-check' : 'square-gray'); }

    // --- Données pour composants enfants ---
    get summaryForChild() {
        return {
            dateSurvenance: this.dateSurvenance,
            policyNumber: this.selectedPolicyRecord?.PolicyNumber,
            registrationNumber: this.selectedPolicyRecord?.RegistrationNumber,
            caseNumber: this.createdCaseNumber || 'En cours',
            nbBlesses: this.driverData?.NumberOfInjuredPassengers__c || 0,
            brand: this.selectedPolicyRecord?.Brand || '-',
            vehicleName: this.selectedPolicyRecord?.vehicleName || '-',
            driverName: this.driverData ? `${this.driverData.FirstName || ''} ${this.driverData.LastName || ''}`.trim() : 'Non renseigné'
        };
    }

    // =========================================================
    // ✅ CORRECTION 1 : Handler pour sauvegarder les champs étape 1
    // =========================================================
    handleStep1Change(event) {
        const fieldId = event.target.dataset.id;
        this.step1Data = { ...this.step1Data, [fieldId]: event.target.value };
        // Synchroniser dateSurvenance utilisée dans toute l'application
        if (fieldId === 'dateSurvenance') {
            this.dateSurvenance = event.target.value;
        }
    }

    // =========================================================
    // HANDLERS RECHERCHE & SÉLECTION
    // =========================================================
    handleDateChange(event) {
        this.dateSurvenance = event.target.value;
    }

    handlePoliceConnuChange(event) {
        this.isPoliceConnu = event.detail.value;
        this.searchType = undefined;
        this.searchResults = [];
        this.selectedPolicyId = undefined;
    }

    handleSearchTypeChange(event) {
        this.searchType = event.detail.value;
        this.selectedPolicyId = undefined;
    }

    // =========================================================
    // ✅ CORRECTION 2 : handleRowClick mémorise la sélection dans les données
    // Ainsi, quand on revient à l'étape 2, la ligne reste cochée
    // =========================================================
    handleRowClick(event) {
        const policyId = event.currentTarget.dataset.id;
        this.selectedPolicyId = policyId;

        // On enrichit chaque ligne avec isSelected et rowClass
        this.searchResults = this.searchResults.map(p => ({
            ...p,
            isSelected: p.Id === policyId,
            rowClass: p.Id === policyId ? 'clickable-row row-selected' : 'clickable-row'
        }));
    }

    // =========================================================
    // HANDLER FORMULAIRE CASE (Étape 4)
    // =========================================================
    handleCaseInputChange(event) {
        const field = event.target.dataset.field;
        this.caseData = { ...this.caseData, [field]: event.target.value };
    }

    handleContactToggle(event) {
        this.isSameAsInsured = event.detail.value === 'true';
        if (this.isSameAsInsured && this.selectedPolicyRecord) {
            this.caseData = { ...this.caseData, nomContact: this.selectedPolicyRecord.InsuredName };
        } else {
            this.caseData = { ...this.caseData, nomContact: '' };
        }
    }

    // =========================================================
    // HANDLERS DOCUMENTS (Étape 5)
    // =========================================================
    handleFolderChange(event) {
        this.selectedDirectory = event.target.value;
        const types = this.allPicklistData[this.selectedDirectory] || [];
        this.optionsDocType = types.map(t => ({ label: t, value: t }));
        this.selectedDocType = '';
    }

    handleDocTypeChange(event) {
        this.selectedDocType = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const currentFileCount = this.files.length;
        uploadedFiles.forEach((file, idx) => {
            const newFile = {
                fileName: file.name,
                size: file.size,
                contentVersionId: file.contentVersionId,
                typeDocument: this.selectedDocType,
                repertoire: this.selectedDirectory,
                index: currentFileCount + idx + 1
            };
            this.files = [...this.files, newFile];
        });
        this.isFileUploaded = true;
        this.showToast('Success', `${uploadedFiles.length} fichier(s) chargé(s)`, 'success');
    }

    async handleUploadSingle(event) {
        const fileName = event.target.dataset.id;
        const file = this.files.find(f => f.fileName === fileName);
        if (file.size > this.MAX_FILE_SIZE) {
            this.showToast('Erreur', `Le fichier dépasse 3 Mo`, 'error');
            return;
        }
        this.isLoading = true;
        try {
            const docObj = {
                RegistrationNumber__c: this.selectedPolicyRecord.RegistrationNumber,
                Police__c: this.selectedPolicyId,
                Directory__c: file.repertoire,
                Type_de_document__c: file.typeDocument
            };
            const result = await saveDocumentLocally({
                fileData: { document: docObj, caseId: this.createdCaseId, typeDocument: file.typeDocument }
            });
            if (result === 'Ok') {
                this.uploadedDocumentIds = [...this.uploadedDocumentIds, file];
                this.files = this.files.filter(f => f.fileName !== fileName);
                this.showToast('Succès', `${fileName} indexé`, 'success');
            }
        } catch (error) {
            this.showToast('Erreur', 'Indexation échouée', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRemoveFile(event) {
        const id = event.target.dataset.id;
        this.files = this.files.filter(f => f.fileName !== id);
        this.isFileUploaded = this.files.length > 0;
    }

    // =========================================================
    // HANDLERS ENFANTS (Étapes 6, 7, 8, 9, 10)
    // =========================================================
    handleCircumstancesUpdate(event) { this.circumstancesData = event.detail; }
    handleDriverUpdate(event) { this.driverData = event.detail; }
    handlePassengersUpdate(event) { this.passengersData = event.detail; }
    handleAdverseVehicleUpdate(event) { this.adverseVehicleData = event.detail; }
    handleOtherPartiesUpdate(event) { this.otherPartiesData = event.detail; }

    // =========================================================
    // NAVIGATION PRINCIPALE
    // =========================================================
    async handleNext() {
        this.isLoading = true;
        try {

            // -----------------------------------------------
            // ÉTAPE 1 : Recherche Police & Validation Date
            // -----------------------------------------------
            if (this.currentStep === 1) {
                const allValid = [...this.template.querySelectorAll('lightning-input, lightning-radio-group')]
                    .reduce((v, i) => { i.reportValidity(); return v && i.checkValidity(); }, true);
                if (!allValid) { this.isLoading = false; return; }

                // ✅ On lit depuis step1Data au lieu du DOM
                const params = {
                    policyNumber: this.step1Data.police || null,
                    registrationNumber: this.isOuiSelected
                        ? (this.step1Data.immat || null)
                        : (this.searchType === 'immatriculation' ? this.step1Data.critere : null),
                    chassisNumber: this.searchType === 'chassis' ? this.step1Data.critere : null,
                    attestationNumber: this.searchType === 'attestation' ? this.step1Data.critere : null
                };

                const data = await searchPolicies(params);
                if (data && data.length > 0) {
                    const dSurv = new Date(this.dateSurvenance).setHours(0, 0, 0, 0);
                    const validPols = data.filter(p => {
                        const dEf = new Date(p.DateEffet).setHours(0, 0, 0, 0);
                        const dEx = new Date(p.DateExpiration).setHours(0, 0, 0, 0);
                        return dSurv >= dEf && dSurv <= dEx;
                    });
                    if (validPols.length > 0) {
                        // ✅ On initialise rowClass et isSelected pour chaque résultat
                        this.searchResults = validPols.map(p => ({
                            ...p,
                            isSelected: false,
                            rowClass: 'clickable-row'
                        }));
                        this.currentStep = 2;
                    } else {
                        this.showToast('Erreur', 'Période non couverte par ce contrat.', 'error');
                    }
                } else {
                    this.showToast('Info', 'Aucune police trouvée avec ces critères.', 'info');
                }
            }

            // -----------------------------------------------
            // ÉTAPE 2 : Sélection de la Police
            // -----------------------------------------------
            else if (this.currentStep === 2) {
                if (!this.selectedPolicyId) {
                    this.showToast('Attention', 'Veuillez sélectionner une police avant de continuer.', 'warning');
                    this.isLoading = false;
                    return;
                }
                this.selectedPolicyRecord = this.searchResults.find(p => p.Id === this.selectedPolicyId);
                this.currentStep = 3;
            }

            // -----------------------------------------------
            // ÉTAPE 3 : Consultation Infos (Navigation simple)
            // -----------------------------------------------
            else if (this.currentStep === 3) {
                this.currentStep = 4;
            }

            // -----------------------------------------------
            // ÉTAPE 4 : Création de la Déclaration (Case)
            // -----------------------------------------------
            else if (this.currentStep === 4) {
                const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
                    .reduce((v, i) => { i.reportValidity(); return v && i.checkValidity(); }, true);
                if (!allValid) { this.isLoading = false; return; }

                // ✅ CORRECTION 4 : Si le Case a déjà été créé (retour arrière), on ne recrée pas
                if (this.caseAlreadyCreated) {
                    this.currentStep = 5;
                    this.isLoading = false;
                    return;
                }

                const payload = {
                    ...this.caseData,
                    policyId: this.selectedPolicyId,
                    vehicleId: this.selectedPolicyRecord.vehicleId,
                    dateSurvenance: this.dateSurvenance,
                    insuredIsContact: this.insuredIsContact
                };

                const result = await createCase({ payload: JSON.stringify(payload) });
                console.log('🔍 RETOUR APEX BRUT :', JSON.stringify(result));

                this.createdCaseId = result.id;
                this.createdCaseNumber = result.caseNumber;
                console.log('📌 NUMÉRO ENREGISTRÉ DANS JS :', this.createdCaseNumber);
                
                this.caseAlreadyCreated = true; // ✅ On marque le Case comme créé

                this.showToast('Succès', 'Déclaration initialisée', 'success');
                this.currentStep = 5;
            }

            // -----------------------------------------------
            // ÉTAPE 5 : Documents (Navigation simple)
            // -----------------------------------------------
            else if (this.currentStep === 5) {
                this.currentStep = 6;
            }

            // -----------------------------------------------
            // ÉTAPE 6 : Mise à jour des Circonstances
            // -----------------------------------------------
            else if (this.currentStep === 6) {
                const formChild = this.template.querySelector('c-d-a_lwc005_-claim-circumstances-form');
                if (formChild && formChild.validate()) {
                    await updateCaseRecord({
                        caseId: this.createdCaseId,
                        caseData: formChild.formData
                    });
                    this.showToast('Succès', 'Circonstances enregistrées', 'success');
                    this.currentStep = 7;
                }
            }

            // -----------------------------------------------
            // ÉTAPE 7 : Infos Conducteur
            // -----------------------------------------------
            else if (this.currentStep === 7) {
                const driverChild = this.template.querySelector('c-lwc007_-driver-info');
                if (driverChild && driverChild.validate()) {
                    this.currentStep = 8;
                }
            }

            // -----------------------------------------------
            // ÉTAPE 8 : Passagers Assurés
            // -----------------------------------------------
            else if (this.currentStep === 8) {
                const passengerChild = this.template.querySelector('c-lwc011_-passagers-assure');
                if (passengerChild && passengerChild.validate()) {
                    if (this.passengersData && this.passengersData.length > 0) {
                        await savePassengers({
                            caseId: this.createdCaseId,
                            passengersJson: JSON.stringify(this.passengersData)
                        });
                    }
                    this.currentStep = 9;
                }
            }

            // -----------------------------------------------
            // ÉTAPE 9 : Véhicule Adverse
            // -----------------------------------------------
            else if (this.currentStep === 9) {
                const adverseChild = this.template.querySelector('c-lwc012_-vehicule-adverse');
                if (adverseChild && adverseChild.validate()) {
                    const dataFromChild = adverseChild.adverseVehicleData;

                    if (!dataFromChild || dataFromChild.length === 0) {
                        this.currentStep = 10;
                        this.isLoading = false;
                        return;
                    }

                    try {
                        await saveAdverseVehicle({
                            caseId: this.createdCaseId,
                            adverseDataJson: JSON.stringify(dataFromChild)
                        });
                        this.showToast('Succès', 'Informations du tiers enregistrées', 'success');
                        this.currentStep = 10;
                    } catch (error) {
                        this.showToast('Erreur', error.body?.message || error.message, 'error');
                    } finally {
                        this.isLoading = false;
                    }
                } else {
                    this.isLoading = false;
                }
            }

            // -----------------------------------------------
            // ÉTAPE 10 : Dommages Autres Parties
            // -----------------------------------------------
            else if (this.currentStep === 10) {
                const partyChild = this.template.querySelector('c-lwc013_-dommages-autres-parties');

                if (partyChild && partyChild.validate()) {
                    if (!this.otherPartiesData || this.otherPartiesData.length === 0) {
                        this.currentStep = 11;
                        return;
                    }

                    this.isLoading = true;
                    try {
                        await saveOtherParties({
                            caseId: this.createdCaseId,
                            partiesJson: JSON.stringify(this.otherPartiesData)
                        });
                        this.showToast('Succès', 'Informations Tiers enregistrées', 'success');
                        this.currentStep = 11;
                    } catch (error) {
                        this.showToast('Erreur', error.body?.message || error.message, 'error');
                    } finally {
                        this.isLoading = false;
                    }
                }
            }

            // -----------------------------------------------
            // ÉTAPE 11 : Finalisation et création du Sinistre
            // -----------------------------------------------
            else if (this.currentStep === 11) {
                this.isLoading = true;
                try {
                    const finalClaimId = await finalizeClaimProcess({
                        caseId: this.createdCaseId
                    });

                    this.showToast('Succès', 'Le dossier sinistre a été finalisé et mis en traitement !', 'success');

                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: finalClaimId,
                            objectApiName: 'Claim__c',
                            actionName: 'view'
                        }
                    });
                } catch (error) {
                    this.showToast('Erreur', error.body?.message || error.message, 'error');
                } finally {
                    this.isLoading = false;
                }
            }

        } catch (error) {
            this.showToast('Erreur', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // =========================================================
    // ✅ BOUTON PRÉCÉDENT : simple, pas de logique destructive
    // Les données sont dans les @track, elles survivent au retour
    // =========================================================
    handlePrecedent() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    // =========================================================
    // TOAST
    // =========================================================
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        }));
    }
}