import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import saveDocumentWithGED from '@salesforce/apex/DocumentGEDController.saveDocumentWithGED';
import getCaseDetails from '@salesforce/apex/DocumentGEDController.getCaseDetails';
import getCaseBySinistre from '@salesforce/apex/DocumentGEDController.getCaseBySinistre';
import getDocumentById from '@salesforce/apex/DocumentGEDController.getDocumentById';
import GED_OBJECT from '@salesforce/schema/Document__c';
import DIRECTORY_FIELD from '@salesforce/schema/Document__c.Directory__c';
import TYPE_DOC_FIELD from '@salesforce/schema/Document__c.Type_de_document__c';
import NATURE_FIELD from '@salesforce/schema/Document__c.Nature__c';
import ISSUER_FIELD from '@salesforce/schema/Document__c.Issuer__c';
import updateDocumentDetails from '@salesforce/apex/DocumentGEDController.updateDocumentDetails';

export default class DA_documentsGED extends LightningElement {
    @api recordId;
    @api documentId;
    @track currentDate = new Date().toISOString().split('T')[0];
    
    @track repertoireOptions = [];
    @track typeDocOptions = [];
    @track natureOptions = [];
    @track emetteurOptions = [];

    @track caseValue;
    @track sinistreValue;
    @track policeValue;
    @track immatriculationValue;
    @track occurrenceDate;
    @track valDeclaration;
    @track valSinistre;
    @track valPolice;
    @track valImmatriculation;
    @track valRepertoire;
    @track valTypeDoc;
    @track valNature;
    @track valSurvenance;
    @track valReception;
    @track valEmetteur;
    @track previewUrl;
    @track isLoading = false;

    @track selectedFile = null;
    @track fileName = '';
    @track isUploading = false;
    MAX_FILE_SIZE = 4194304; 

    @wire(getObjectInfo, { objectApiName: GED_OBJECT })
    objectInfo;

    get recordTypeId() {
        return this.objectInfo.data ? this.objectInfo.data.defaultRecordTypeId : null;
    }
    get isEditMode() {
        return !!this.documentId;
    }

    get buttonLabel() {
        return this.isEditMode ? 'Sauvegarder' : 'Envoyer';
    }

    get uploadZoneClass() {
        const baseClass = 'upload-zone slds-box slds-box_dashed slds-align_absolute-center slds-is-relative';
        return this.isEditMode ? baseClass + ' disabled-zone' : baseClass;
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: DIRECTORY_FIELD })
    wiredDirectory({ data, error }) {
        if (data) this.repertoireOptions = data.values;
        else if (error) console.error('Erreur chargement Répertoire', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: TYPE_DOC_FIELD })
    wiredTypeDoc({ data, error }) {
        if (data) this.typeDocOptions = data.values;
        else if (error) console.error('Erreur chargement Type de document', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: NATURE_FIELD })
    wiredNature({ data, error }) {
        if (data) this.natureOptions = data.values;
        else if (error) console.error('Erreur chargement Nature', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: ISSUER_FIELD })
    wiredIssuer({ data, error }) {
        if (data) this.emetteurOptions = data.values;
        else if (error) console.error('Erreur chargement Émetteur', error);
    }

    handleFileChange(event) {
        if (event.target.files.length > 0) {
            const file = event.target.files[0];
            
            if (file.size > this.MAX_FILE_SIZE) {
                this.showToast('Fichier trop lourd', 'Le fichier dépasse la limite de 4 Mo. Veuillez le compresser.', 'error');
                this.selectedFile = null;
                this.fileName = '';
                return;
            }

            this.selectedFile = file;
            this.fileName = file.name;
        }
    }

    handleEnvoyer() {
    console.log('--- DÉBUT DE L\'ENVOI (CRÉATION) ---');

        try {
            const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')];
            let allValid = true;

            inputs.forEach(inputCmp => {
                if (typeof inputCmp.reportValidity === 'function') {
                    inputCmp.reportValidity();
                    if (!inputCmp.checkValidity()) {
                        allValid = false;
                    }
                }
            });

            if (!allValid) {
                this.showToast('Erreur', 'Veuillez remplir tous les champs obligatoires.', 'error');
                return;
            }

            if (!this.selectedFile) {
                this.showToast('Attention', 'Veuillez sélectionner un document à numériser.', 'warning');
                return;
            }

            this.isLoading = true; 
            this.showToast('En cours', 'Préparation et envoi vers Google Drive...', 'info');

            const formData = {};
            inputs.forEach(input => {
                if (input.name && input.value) {
                    if (input.type === 'date') {
                        formData[input.name] = input.value.split('T')[0];
                    } else {
                        formData[input.name] = input.value;
                    }
                }
            });

            formData['Sinistre__c'] = this.recordId; 
            if (this.valDeclaration) {
                formData['NumeroDeclaration__c'] = this.valDeclaration; 
            }

            console.log('Données prêtes pour l\'envoi :', JSON.stringify(formData));

            const reader = new FileReader();
            reader.onload = () => {
                const base64Data = reader.result.split(',')[1];

                saveDocumentWithGED({
                    recordId: this.recordId,
                    base64Data: base64Data,
                    fileName: this.selectedFile.name,
                    mimeType: this.selectedFile.type,
                    formDataJSON: JSON.stringify(formData)
                })
                .then((googleFileId) => {
                    console.log('Succès ! Fichier Google Drive ID :', googleFileId);
                    this.isLoading = false;
                    
                    this.showToast('Succès', 'Document créé et synchronisé avec succès !', 'success');
                    
                    this.dispatchEvent(new CustomEvent('close'));
                })
                .catch((error) => {
                    console.error('Erreur lors de la création Apex :', error);
                    this.isLoading = false;
                    let errorMsg = error.body ? error.body.message : error.message;
                    this.showToast('Erreur d\'envoi', errorMsg, 'error');
                });
            };

            reader.readAsDataURL(this.selectedFile);

        } catch (globalError) {
            console.error('Erreur critique dans handleEnvoyer :', globalError);
            this.isLoading = false;
            this.showToast('Erreur critique', 'Une erreur inattendue est survenue lors de l\'envoi.', 'error');
        }
    }
    handlePreviewFile() {
        if (this.selectedFile) {
            const fileURL = URL.createObjectURL(this.selectedFile);
            window.open(fileURL, '_blank');
        }
    }

    handleRemoveFile() {
        this.selectedFile = null;
        this.fileName = '';
        
        const fileInput = this.template.querySelector('#file-upload-input');
        if (fileInput) {
            fileInput.value = '';
        }
    }
    get caseFilter() {
        if (!this.recordId) return undefined;
        return {
            criteria: [{
                fieldPath: 'Claim__c',
                operator: 'eq',
                value: this.recordId
            }]
        };
    }

    @wire(getCaseBySinistre, { sinistreId: '$recordId' })
    wiredDefaultCase({ data, error }) {
        this.sinistreValue = this.recordId;

        if (data) {
            this.caseValue = data.Id;
            this.policeValue = data.Police__c;
            this.immatriculationValue = data.Num_ro_d_immatriculation__c;
        }
    }

    handleDeclarationChange(event) {
        const caseId = event.detail.recordId;
        console.log('--- 1. Nouvelle Déclaration sélectionnée ---');
        console.log('ID Déclaration : ', caseId);
        
        if (caseId) {
            getCaseDetails({ caseId: caseId })
                .then(result => {
                    console.log('--- 2. Résultat reçu de la base de données ---');
                    console.log(JSON.stringify(result)); 

                    this.sinistreValue = result.Claim__c || null;
                    this.policeValue = result.Police__c || null;
                    this.immatriculationValue = result.Num_ro_d_immatriculation__c || null;
                    this.occurrenceDate = result.DateOfOccurrence__c || null;

                    const sinistreInput = this.template.querySelector('lightning-record-picker[name="Sinistre__c"]');
                    if (sinistreInput) sinistreInput.value = this.sinistreValue;

                    const policeInput = this.template.querySelector('lightning-record-picker[name="Police__c"]');
                    if (policeInput) policeInput.value = this.policeValue;

                    const immatInput = this.template.querySelector('lightning-input[name="RegistrationNumber__c"]');
                    if (immatInput) immatInput.value = this.immatriculationValue;

                    const occurrenceInput = this.template.querySelector('lightning-input[name="DateOfOccurrence__c"]');
                    if (occurrenceInput) occurrenceInput.value = this.occurrenceDate;
                    
                    console.log('--- 3. Champs mis à jour ---');
                })
                .catch(error => {
                    console.error('Erreur Apex lors de la récupération : ', error);
                });
        } else {
            this.sinistreValue = null;
            this.policeValue = null;
            this.immatriculationValue = null;
            this.occurrenceDate = null;
            
            this.template.querySelector('lightning-record-picker[name="Sinistre__c"]').value = null;
            this.template.querySelector('lightning-record-picker[name="Police__c"]').value = null;
            this.template.querySelector('lightning-input[name="RegistrationNumber__c"]').value = null;
            this.template.querySelector('lightning-input[name="DateOfOccurrence__c"]').value = null;
        }
    }

    updateFields(caseId, claimId, policeId, immat, occurrenceDate) {
        const fieldMap = {
            'NumeroDeclaration__c': caseId,
            'Sinistre__c': claimId,
            'Police__c': policeId,
            'RegistrationNumber__c': immat,
            'DateOfOccurrence__c': occurrenceDate
        };

        Object.keys(fieldMap).forEach(fieldName => {
            const input = this.template.querySelector(`[name="${fieldName}"]`);
            if (input) input.value = fieldMap[fieldName];
        });
    }
    clearFileInput(event) {
        event.target.value = null;
    }
    
    resetForm() {
        this.selectedFile = null;
        this.fileName = '';
        this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker').forEach(input => {
            input.value = null;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    connectedCallback() {
        if (this.isEditMode) {
            this.loadDocumentData();
        } else {
            this.loadSinistreData();
        }
    }
    loadDocumentData() {
        this.isLoading = true;
        
        getDocumentById({ docId: this.documentId })
            .then(result => {
                this.valRepertoire = result.Directory__c;
                this.valTypeDoc    = result.Type_de_document__c;
                this.valNature     = result.Nature__c;
                
                this.valCompagnie  = result.Compagnie_Adverse__c;
                this.valSurvenance = result.OccurrenceDate__c;
                this.valReception  = result.dateOfReceipt__c;
                this.valEmetteur   = result.Issuer__c;
                if (result.IdDocument__c) {
                    this.previewUrl = `https://drive.google.com/file/d/${result.IdDocument__c}/preview`;
                } else {
                    this.previewUrl = null;
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Erreur chargement:', error);
                this.isLoading = false;
            });
    }

    handleAction() {
        if (this.isEditMode) {
            this.handleUpdate();
        } else {
            this.handleEnvoyer(); 
        }
    }
    handleAdd() {
        this.selectedDocumentId = null;  
        this.showFormModal = true;
    }
    
    loadSinistreData() {
        this.sinistreValue = this.recordId;

        getCaseBySinistre({ sinistreId: this.recordId })
            .then(result => {
                if (result) {
                    this.policeValue = result.Police__c;
                    this.immatriculationValue = result.Num_ro_d_immatriculation__c;
                    
                   
                    this.declarationValue = result.Id;
                    
                    if (!this.valSurvenance) {
                        this.valSurvenance = result.DateOfOccurrence__c;
                    }
                }
            })
            .catch(error => {
                console.error('Erreur lors du pré-remplissage du sinistre :', error);
            });
    }

    
    handleUpdate() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')];
        let allValid = true;
        const formData = {};

        inputs.forEach(inputCmp => {
            if (typeof inputCmp.reportValidity === 'function') {
                inputCmp.reportValidity();
                if (!inputCmp.checkValidity()) allValid = false;
            }
            if (inputCmp.name && inputCmp.value) {
                formData[inputCmp.name] = inputCmp.type === 'date' ? inputCmp.value.split('T')[0] : inputCmp.value;
            }
        });

        if (!allValid) {
            this.showToast('Erreur', 'Veuillez remplir tous les champs obligatoires.', 'error');
            return;
        }

        this.isLoading = true;
        
        updateDocumentDetails({
            docId: this.documentId,
            repertoire: formData.Directory__c,
            typeDoc: formData.Type_de_document__c,
            nature: formData.Nature__c,
            dateSurvenance: formData.OccurrenceDate__c,
            dateReception: formData.dateOfReceipt__c,
            emetteur: formData.Issuer__c,
        })
        .then(() => {
            this.showToast('Succès', 'Le document a été mis à jour.', 'success');
            this.dispatchEvent(new CustomEvent('close'));
        })
        .catch(error => {
            console.error('Erreur Update:', error);
            this.showToast('Erreur', 'Échec de la mise à jour.', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
    handleRedirect() {
        if (this.previewUrl) {
            window.open(this.previewUrl, '_blank');
        } else {
            this.showToast('Information', 'Le fichier n\'est pas encore synchronisé ou est introuvable.', 'info');
        }
    }
    
}