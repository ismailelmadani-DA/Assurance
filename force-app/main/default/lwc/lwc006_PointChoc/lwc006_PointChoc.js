import { LightningElement, track, api } from 'lwc';

export default class Lwc006_PointChoc extends LightningElement {
    @track parts = []; // Liste des objets {id, val} sélectionnés
    @track motifVal = ''; // Texte saisi dans le textarea
    @track messageObligatoire = false;

    @api errorMessage = 'Veuillez sélectionner au moins un point de choc.';

    /**
     * Gère le clic sur une partie du SVG ou sur la croix d'un badge
     */
    onclickPart(event) {
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
        this.messageObligatoire = (this.parts.length === 0);
        return !this.messageObligatoire;
    }
}