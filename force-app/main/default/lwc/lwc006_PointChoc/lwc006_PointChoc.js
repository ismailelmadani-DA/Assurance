import { LightningElement, track, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Importation des champs de l'objet Claim__c
import POINTS_CHOC_FIELD from '@salesforce/schema/Claim__c.PointsDeChoc__c';
import PRECISIONS_FIELD from '@salesforce/schema/Claim__c.PrecisionsDommages__c';

export default class Lwc006_PointChoc extends LightningElement {
    @api recordId; // Identifiant de l'enregistrement (rempli automatiquement sur la page de consultation)
    
    @track parts = []; // Liste des objets {id, val} sélectionnés
    @track motifVal = ''; // Texte saisi dans le textarea
    @track messageObligatoire = false;

    @api errorMessage = 'Veuillez sélectionner au moins un point de choc.';

    // --- MODE LECTURE SEULE ---
    // Si recordId est présent, cela signifie que le composant est sur une page de consultation
    get isReadOnly() {
        return !!this.recordId;
    }

    // Récupération automatique des données si on est sur la page d'un Sinistre
    @wire(getRecord, { recordId: '$recordId', fields: [POINTS_CHOC_FIELD, PRECISIONS_FIELD] })
    wiredClaim({ error, data }) {
        if (data) {
            const pointsSauvegardes = getFieldValue(data, POINTS_CHOC_FIELD);
            const precisionsSauvegardees = getFieldValue(data, PRECISIONS_FIELD);

            if (precisionsSauvegardees) {
                this.motifVal = precisionsSauvegardees;
            }

            if (pointsSauvegardes) {
                this.colorierPointsExistants(pointsSauvegardes);
            }
        } else if (error) {
            console.error('Erreur lors de la récupération des points de choc', error);
        }
    }

    /**
     * Colorie le SVG en fonction des données sauvegardées (Mode Lecture)
     */
    colorierPointsExistants(pointsStr) {
        // Dans votre méthode notifyChange, vous sépariez les valeurs par un point-virgule (;)
        const partiesEndommagees = pointsStr.split(';').map(p => p.trim()).filter(p => p !== '');

        // Un petit délai pour s'assurer que le HTML et le SVG sont bien chargés à l'écran
        setTimeout(() => {
            partiesEndommagees.forEach(partval => {
                const myPartElement = this.template.querySelector(`path[data-value='${partval}']`);
                
                if (myPartElement) {
                    // On simule visuellement le clic
                    myPartElement.style.fill = "#FF0000";
                    myPartElement.style.fillOpacity = "0.6";
                    
                    // On l'ajoute à la liste pour que les badges s'affichent aussi en bas
                    this.parts.push({ id: myPartElement.id, val: partval });
                }
            });
            
            // Forcer la réactivité pour afficher les badges
            this.parts = [...this.parts];
            this.updateLayout();

        }, 500); 
    }

    /**
     * Gère le clic sur une partie du SVG ou sur la croix d'un badge
     */
    onclickPart(event) {
        // SÉCURITÉ : Si on est en mode lecture seule, on bloque toute interaction
        if (this.isReadOnly) {
            return;
        }

        try {
            const type = event.target.getAttribute('data-type');
            const partval = event.target.getAttribute('data-value');
            let partId;

            if (type === "div") {
                // Si on clique sur le bouton fermer du badge, on retrouve l'élément SVG via son data-value
                const myPartElement = this.template.querySelector(`path[data-value='${partval}']`);
                partId = myPartElement ? myPartElement.id : null;
            } else {
                // Clic direct sur une zone de la voiture (l'id du path SVG)
                partId = event.target.id;
            }

            if (!partId) return;

            const partDom = this.template.querySelector(`#${partId}`);
            const index = this.parts.findIndex(p => p.id === partId);

            if (index > -1) {
                // --- LOGIQUE DE DÉSÉLECTION ---
                partDom.style.fill = "";
                partDom.style.fillOpacity = "0";
                this.parts.splice(index, 1);
            } else {
                // --- LOGIQUE DE SÉLECTION ---
                partDom.style.fill = "#FF0000"; 
                partDom.style.fillOpacity = "0.6";
                this.parts.push({ id: partId, val: partval });
            }

            // Forcer la réactivité
            this.parts = [...this.parts];
            
            // Mise à jour de l'interface
            this.updateLayout();
            // Notification du parent
            this.notifyChange();

        } catch (e) {
            console.error('Erreur dans onclickPart:', e.message);
        }
    }

    /**
     * Gère la saisie dans le champ de commentaire
     */
    handleMotifChange(event) {
        // SÉCURITÉ : Si on est en mode lecture seule, on ne met pas à jour (bien que le HTML doive aussi être en disabled)
        if (this.isReadOnly) {
            return;
        }

        this.motifVal = event.target.value;
        this.notifyChange();
    }

    /**
     * Alterne les classes CSS pour l'animation
     */
    updateLayout() {
        const hasParts = this.parts.length > 0;
        const car = this.template.querySelector('.my-car-container');
        const details = this.template.querySelector('.my-details-container');

        if (car && details) {
            if (hasParts) {
                car.classList.remove('car-initial');
                car.classList.add('car-with-details');
                details.classList.remove('details-empty');
                details.classList.add('details-not-empty');
            } else {
                car.classList.add('car-initial');
                car.classList.remove('car-with-details');
                details.classList.add('details-empty');
                details.classList.remove('details-not-empty');
            }
        }
    }

    /**
     * Émet l'événement vers dA_lwc005 avec la clé correcte pour PrecisionsDommages__c
     */
    notifyChange() {
        const selectedPartsString = this.parts.map(p => p.val).join(';');
        
        this.dispatchEvent(new CustomEvent('pointchocchange', {
            detail: {
                clickedParts: selectedPartsString,
                precisionDommage: this.motifVal // On envoie motifVal sous le nom attendu par le parent
            }
        }));
    }

    /**
     * Méthode de validation
     */
    @api 
    checkValidity() {
        // En mode lecture, on renvoie toujours true pour ne pas bloquer
        if (this.isReadOnly) {
            return true;
        }

        this.messageObligatoire = (this.parts.length === 0);
        return !this.messageObligatoire;
    }
}