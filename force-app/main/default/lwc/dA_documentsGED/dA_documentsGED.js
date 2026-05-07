import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import de l'Apex mis à jour vers le Contrôleur Séparé
import saveDocumentWithGED from '@salesforce/apex/DocumentGEDController.saveDocumentWithGED';

import GED_OBJECT from '@salesforce/schema/Document__c';
import DIRECTORY_FIELD from '@salesforce/schema/Document__c.Directory__c';
import TYPE_DOC_FIELD from '@salesforce/schema/Document__c.Type_de_document__c';
import NATURE_FIELD from '@salesforce/schema/Document__c.Nature__c';
import ISSUER_FIELD from '@salesforce/schema/Document__c.Issuer__c';

export default class DA_documentsGED extends LightningElement {
    @api recordId;
    @track currentDate = new Date().toISOString().split('T')[0];
    
    // Options Picklist
    @track repertoireOptions = [];
    @track typeDocOptions = [];
    @track natureOptions = [];
    @track emetteurOptions = [];

    // Gestion du Fichier
    @track selectedFile = null;
    @track fileName = '';
    @track isUploading = false;
    MAX_FILE_SIZE = 4194304; // 4 Mo max

    @wire(getObjectInfo, { objectApiName: GED_OBJECT })
    objectInfo;

    get recordTypeId() {
        return this.objectInfo.data ? this.objectInfo.data.defaultRecordTypeId : null;
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
        console.log('--- BOUTON ENVOYER CLIQUÉ ---'); // Doit s'afficher dans la console F12

        try {
            // 1. Validation de TOUS les champs (Version Ultra Sécurisée)
            const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')];
            let allValid = true;

            inputs.forEach(inputCmp => {
                // On vérifie que le composant possède bien la fonction de validation avant de l'appeler
                if (typeof inputCmp.reportValidity === 'function') {
                    inputCmp.reportValidity();
                    if (!inputCmp.checkValidity()) {
                        allValid = false;
                        console.log('Champ invalide détecté : ', inputCmp.name);
                    }
                }
            });

            if (!allValid) {
                console.log('Arrêt : Le formulaire contient des erreurs.');
                this.showToast('Erreur', 'Veuillez remplir tous les champs obligatoires.', 'error');
                return;
            }

            // 2. Validation du fichier
            if (!this.selectedFile) {
                console.log('Arrêt : Aucun fichier sélectionné.');
                this.showToast('Attention', 'Veuillez sélectionner un document à numériser.', 'warning');
                return;
            }

            // 3. Construction dynamique du payload
            console.log('Validation réussie. Préparation des données...');
            const formData = {};
            inputs.forEach(input => {
                if(input.name && input.value) {
                    formData[input.name] = input.value;
                }
            });
            console.log('Données capturées : ', JSON.parse(JSON.stringify(formData)));

            // 4. Préparation et envoi
            this.isUploading = true;
            this.showToast('En cours', 'Chiffrement et envoi vers Google Drive...', 'info');

            const reader = new FileReader();
            reader.onload = () => {
                const base64Data = reader.result.split(',')[1];
                console.log('Fichier lu, appel Apex en cours...');

                saveDocumentWithGED({
                    recordId: this.recordId,
                    base64Data: base64Data,
                    fileName: this.selectedFile.name,
                    mimeType: this.selectedFile.type,
                    formDataJSON: JSON.stringify(formData)
                })
                .then((googleFileId) => {
                    console.log('Succès Apex ! ID : ', googleFileId);
                    this.isUploading = false;
                    this.showToast('Succès', 'Document synchronisé avec succès !', 'success');
                    this.resetForm();
                })
                .catch((error) => {
                    console.error('Erreur Apex : ', error);
                    this.isUploading = false;
                    let errorMsg = error.body ? error.body.message : error.message;
                    this.showToast('Erreur d\'envoi', errorMsg, 'error');
                });
            };

            reader.readAsDataURL(this.selectedFile);

        } catch (globalError) {
            console.error('CRASH JS COMPLET : ', globalError);
            this.showToast('Erreur critique', 'Le code a planté avant l\'envoi.', 'error');
        }
    }

    // Fonction pour vider le formulaire après succès
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
}