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
        if (String.isBlank(req.ville)) {
            throw new AuraHandledException('La ville est obligatoire.');
        }
        if (req.dateFin != null && req.dateFin < req.dateDebut) {
            throw new AuraHandledException('La date de fin doit être postérieure à la date de début.');
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       MAP — SaveRequest → Evenement__c
       Le champ Name (Code) est un AutoNumber géré par Salesforce
    ══════════════════════════════════════════════════════════════════════ */
    public static Evenement__c mapRequestToEvenement(DA_lwc020_EvenementListController.SaveRequest req) {
        Evenement__c evt = new Evenement__c();

        // En modification on positionne l'Id pour l'upsert
        if (String.isNotBlank(req.id)) {
            evt.Id = req.id;
        }

        evt.Libelle__c    = req.libelle;
        evt.Categorie__c  = req.categorie;
        evt.Type__c       = req.type;
        evt.DateDebut__c  = req.dateDebut;
        evt.DateFin__c    = req.dateFin;
        evt.Ville__c      = req.ville;
        evt.Pays__c       = String.isNotBlank(req.pays) ? req.pays : 'Maroc';

        return evt;
    }

    /* ══════════════════════════════════════════════════════════════════════
       UPSERT — Création ou mise à jour
    ══════════════════════════════════════════════════════════════════════ */
    public static void upsertEvenement(Evenement__c evt) {
        upsert evt;
    }

    /* ══════════════════════════════════════════════════════════════════════
       DELETE — Suppression par Id
    ══════════════════════════════════════════════════════════════════════ */
    public static void deleteEvenement(Id recordId) {
        DA_Utility.deleteById('Evenement__c', recordId);
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLISTS — Récupère les valeurs d'une picklist simple
       Utilisé pour Categorie__c et Pays__c
    ══════════════════════════════════════════════════════════════════════ */
    public static List<Map<String, String>> getPicklistValues(
            String objectApiName,
            String fieldApiName) {

        List<Map<String, String>> opts = new List<Map<String, String>>();
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjType == null) return opts;

        Schema.DescribeFieldResult fieldDesc =
            sObjType.getDescribe().fields.getMap().get(fieldApiName)?.getDescribe();
        if (fieldDesc == null) return opts;

        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                opts.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return opts;
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLISTS DÉPENDANTES — Récupère les valeurs d'un champ dépendant
       groupées par valeur du champ contrôleur.
       Ex : Type__c dépend de Categorie__c
            Ville__c dépend de Pays__c
       Algorithme : décodage des validFor (bitmask Base64) fourni par SF
    ══════════════════════════════════════════════════════════════════════ */
   public static Map<String, List<Map<String, String>>> getDependentPicklistValues(
    String objectApiName,
    String controllingFieldApiName,
    String dependentFieldApiName) {

    Map<String, List<Map<String, String>>> result =
        new Map<String, List<Map<String, String>>>();

    Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
    if (sObjType == null) return result;

    Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();

    Schema.DescribeFieldResult controlDesc =
        fieldMap.get(controllingFieldApiName)?.getDescribe();
    if (controlDesc == null) return result;

    List<Schema.PicklistEntry> controlEntries = controlDesc.getPicklistValues();
    List<Schema.PicklistEntry> depEntries =
        fieldMap.get(dependentFieldApiName)?.getDescribe().getPicklistValues();
    if (depEntries == null) return result;

    // Initialiser le résultat avec les valeurs actives du contrôleur
    for (Schema.PicklistEntry ctrl : controlEntries) {
        if (ctrl.isActive()) {
            result.put(ctrl.getValue(), new List<Map<String, String>>());
        }
    }

    // Pour chaque valeur dépendante, décoder le bitmask validFor
    for (Schema.PicklistEntry dep : depEntries) {
        if (!dep.isActive()) continue;

        Map<String, Object> depMap =
            (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(dep));
        String validFor = (String) depMap.get('validFor');
        if (String.isBlank(validFor)) continue;

        String hexString = EncodingUtil.convertToHex(
            EncodingUtil.base64Decode(validFor));

        for (Integer i = 0; i < controlEntries.size(); i++) {
            Schema.PicklistEntry ctrl = controlEntries[i];
            if (!ctrl.isActive()) continue;

            Integer byteIndex = i / 8;
            Integer bitIndex  = 7 - Math.mod(i, 8);
            if (byteIndex * 2 + 2 > hexString.length()) continue;

            Integer byteVal = hexToInt(
                hexString.substring(byteIndex * 2, byteIndex * 2 + 2));

            if ((byteVal & (1 << bitIndex)) != 0
                    && result.containsKey(ctrl.getValue())) {
                result.get(ctrl.getValue()).add(new Map<String, String>{
                    'label' => dep.getLabel(),
                    'value' => dep.getValue()
                });
            }
        }
    }
    return result;
}

private static Integer hexToInt(String hex) {
    Integer result = 0;
    for (Integer i = 0; i < hex.length(); i++) {
        Integer c     = hex.charAt(i);
        Integer digit = (c >= 48 && c <= 57)  ? c - 48
                      : (c >= 97 && c <= 102) ? c - 87
                      : (c >= 65 && c <= 70)  ? c - 55 : 0;
        result = result * 16 + digit;
    }
    return result;
}

/* ══════════════════════════════════════════════════════════════════════
   ASSOCIATE — Associer un événement à un sinistre (pour DA_lwc021)
══════════════════════════════════════════════════════════════════════ */
public static Map<String, Object> associerEvenement(Id claimId, Id evenementId) {
    Map<String, Object> response = new Map<String, Object>();
    try {
        if (!Schema.sObjectType.Claim__c.isUpdateable()) {
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Vous n\'avez pas les droits pour modifier ce sinistre.'
            };
        }

        update new Claim__c(
            Id                  = claimId,
            EvenementAssocie__c = evenementId
        );

        response.put('success', true);
        response.put('message', 'L\'événement a été associé au sinistre avec succès.');

    } catch (Exception e) {
        response.put('success', false);
        response.put('message', handleException(e));
    }
    return response;
}

/* ══════════════════════════════════════════════════════════════════════
   PRIVATE — Gestion des erreurs (pour DA_lwc021)
══════════════════════════════════════════════════════════════════════ */
private static String handleException(Exception e) {
    String msg = e.getMessage();
    if (msg == null)                                    return 'Une erreur inattendue s\'est produite.';
    if (msg.contains('INSUFFICIENT_ACCESS'))            return 'Vous n\'avez pas les droits nécessaires pour effectuer cette action.';
    if (msg.contains('INVALID_CROSS_REFERENCE_KEY')
     || msg.contains('id value of incorrect type'))     return 'Référence invalide : vérifiez que le sinistre et l\'événement sont correctement configurés.';
    if (msg.contains('ENTITY_IS_DELETED'))              return 'L\'enregistrement a déjà été supprimé.';
    if (msg.contains('REQUIRED_FIELD_MISSING'))         return 'Un ou plusieurs champs obligatoires ne sont pas renseignés.';
    return 'Une erreur est survenue lors du traitement. Veuillez réessayer. ' + msg;
}
}