public with sharing class EM006_Evenement {

    /* ══════════════════════════════════════════════════════════════════════
       VALIDATE — Règles métier obligatoires
    ══════════════════════════════════════════════════════════════════════ */
    public static void validateEvenement(DA_lwc020_EvenementListController.SaveRequest req) {
        if (String.isBlank(req.libelle)) {
            throw new AuraHandledException('Le libellé de l\'événement est obligatoire.');
        }
        if (String.isBlank(req.categorie)) {
            throw new AuraHandledException('La catégorie est obligatoire.');
        }
        if (String.isBlank(req.type)) {
            throw new AuraHandledException('Le type est obligatoire.');
        }
        if (req.dateDebut == null) {
            throw new AuraHandledException('La date de début est obligatoire.');
        }
        if (String.isBlank(req.pays)) {
            throw new AuraHandledException('Le pays est obligatoire.');
        }
        if (String.isBlank(req.ville)) {
            throw new AuraHandledException('La ville est obligatoire.');
        }
        if (req.dateFin != null && req.dateFin < req.dateDebut) {
            throw new AuraHandledException('La date de fin doit être postérieure à la date de début.');
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       MAP — SaveRequest → Evenement__c
    ══════════════════════════════════════════════════════════════════════ */
    public static Evenement__c mapRequestToEvenement(DA_lwc020_EvenementListController.SaveRequest req) {
        Evenement__c evt = new Evenement__c();
        if (String.isNotBlank(req.id)) evt.Id = req.id;
        evt.Libelle__c   = req.libelle;
        evt.Categorie__c = req.categorie;
        evt.Type__c      = req.type;
        evt.DateDebut__c = req.dateDebut;
        evt.DateFin__c   = req.dateFin;
        evt.Ville__c     = req.ville;
        evt.Pays__c      = req.pays;
        return evt;
    }

    /* ══════════════════════════════════════════════════════════════════════
       UPSERT — Création ou mise à jour d'un événement
    ══════════════════════════════════════════════════════════════════════ */
    public static void upsertEvenement(Evenement__c evt) {
        upsert evt;
    }

    /* ══════════════════════════════════════════════════════════════════════
       DELETE — Suppression d'un événement par Id
    ══════════════════════════════════════════════════════════════════════ */
    public static void deleteEvenement(Id recordId) {
        DA_Utility.deleteById('Evenement__c', recordId);
    }

    /* ══════════════════════════════════════════════════════════════════════
       UPDATE — Associer un événement à un sinistre
    ══════════════════════════════════════════════════════════════════════ */
    public static void associerEvenement(Id claimId, Id evenementId) {
        if (!Schema.sObjectType.Claim__c.isUpdateable()) {
            throw new AuraHandledException('Vous n\'avez pas les droits pour modifier ce sinistre.');
        }
        try {
            update new Claim__c(
                Id                  = claimId,
                EvenementAssocie__c = evenementId,
                PopupEvenementVu__c = true
            );
        } catch (DmlException e) {
            throw new AuraHandledException(handleException(e));
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       UPDATE — Marquer le popup comme vu (Annuler / ✕)
    ══════════════════════════════════════════════════════════════════════ */
    public static void marquerPopupVu(Id claimId) {
        if (!Schema.sObjectType.Claim__c.isUpdateable()) {
            throw new AuraHandledException('Droits insuffisants pour modifier le sinistre.');
        }
        try {
            update new Claim__c(
                Id                  = claimId,
                PopupEvenementVu__c = true
            );
        } catch (DmlException e) {
            throw new AuraHandledException(handleException(e));
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PRIVATE — Gestion des exceptions DML
    ══════════════════════════════════════════════════════════════════════ */
    private static String handleException(Exception e) {
        String msg = e.getMessage();
        if (msg == null)                                 return 'Une erreur inattendue s\'est produite.';
        if (msg.contains('INSUFFICIENT_ACCESS'))         return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
        if (msg.contains('INVALID_CROSS_REFERENCE_KEY')
         || msg.contains('id value of incorrect type'))  return 'Référence invalide : vérifiez que le sinistre et l\'événement sont correctement configurés.';
        if (msg.contains('ENTITY_IS_DELETED'))           return 'L\'enregistrement a déjà été supprimé.';
        if (msg.contains('REQUIRED_FIELD_MISSING'))      return 'Un ou plusieurs champs obligatoires ne sont pas renseignés.';
        return 'Une erreur est survenue lors du traitement. Veuillez réessayer. ' + msg;
    }
}