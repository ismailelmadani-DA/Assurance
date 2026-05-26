public with sharing class DA_lwc020_EvenementListController {

    /* ══════════════════════════════════════════════════════════════════════
       WRAPPER — Données renvoyées au LWC
    ══════════════════════════════════════════════════════════════════════ */
    public class EvenementWrapper {
        @AuraEnabled public String  id            {get;set;}
        @AuraEnabled public String  code          {get;set;}
        @AuraEnabled public String  libelle       {get;set;}
        @AuraEnabled public String  categorie     {get;set;}
        @AuraEnabled public String  type          {get;set;}
        @AuraEnabled public String  dateDebut     {get;set;}
        @AuraEnabled public String  dateFin       {get;set;}
        @AuraEnabled public String  pays          {get;set;}
        @AuraEnabled public String  ville         {get;set;}
        @AuraEnabled public String  dateCreation  {get;set;}
        @AuraEnabled public String  createdById   {get;set;}
        @AuraEnabled public String  createdByName {get;set;}
    }

    /* ══════════════════════════════════════════════════════════════════════
       WRAPPER — Données reçues depuis le LWC (formulaire)
    ══════════════════════════════════════════════════════════════════════ */
    public class SaveRequest {
        @AuraEnabled public String  id        {get;set;}
        @AuraEnabled public String  libelle   {get;set;}
        @AuraEnabled public String  categorie {get;set;}
        @AuraEnabled public String  type      {get;set;}
        @AuraEnabled public Date    dateDebut {get;set;}
        @AuraEnabled public Date    dateFin   {get;set;}
        @AuraEnabled public String  pays      {get;set;}
        @AuraEnabled public String  ville     {get;set;}
    }

    /* ══════════════════════════════════════════════════════════════════════
       GET — Liste des événements
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<EvenementWrapper> getEvenements(
            String catFilter,
            String periodFilter,
            String searchTerm) {
        try {
            List<Evenement__c> records =
                DM006_Evenement.getEvenements(catFilter, periodFilter, searchTerm);
            List<EvenementWrapper> result = new List<EvenementWrapper>();
            for (Evenement__c evt : records) {
                result.add(mapToWrapper(evt));
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       SAVE — Création ou modification d'un événement
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled
    public static String saveEvenement(SaveRequest req) {
        try {
            validateEvenement(req);
            Evenement__c evt = mapRequestToEvenement(req);
            EM006_Evenement.upsertEvenement(evt);
            return evt.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLIST — Valeurs de Categorie__c
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategorieOptions() {
        try {
            return DM006_Evenement.getCategorieOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLIST — Valeurs de Pays__c
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaysOptions() {
        try {
            return DM006_Evenement.getPaysOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLIST DÉPENDANTE — Type__c groupé par Categorie__c
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentTypeOptions() {
        try {
            return DM006_Evenement.getDependentTypeOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLIST DÉPENDANTE — Ville__c groupée par Pays__c
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        try {
            return DM006_Evenement.getDependentVilleOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PRIVATE — Validation des règles métier
    ══════════════════════════════════════════════════════════════════════ */
    private static void validateEvenement(SaveRequest req) {
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
       PRIVATE — Mapping SaveRequest → Evenement__c
    ══════════════════════════════════════════════════════════════════════ */
    private static Evenement__c mapRequestToEvenement(SaveRequest req) {
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
       PRIVATE — Mapping Evenement__c → EvenementWrapper
    ══════════════════════════════════════════════════════════════════════ */
    private static EvenementWrapper mapToWrapper(Evenement__c evt) {
        EvenementWrapper w = new EvenementWrapper();
        w.id            = evt.Id;
        w.code          = evt.Name;
        w.libelle       = evt.Libelle__c;
        w.categorie     = evt.Categorie__c;
        w.type          = evt.Type__c;
        w.dateDebut     = evt.DateDebut__c != null ? String.valueOf(evt.DateDebut__c)       : null;
        w.dateFin       = evt.DateFin__c   != null ? String.valueOf(evt.DateFin__c)         : null;
        w.pays          = evt.Pays__c;
        w.ville         = evt.Ville__c;
        w.dateCreation  = evt.CreatedDate  != null ? String.valueOf(evt.CreatedDate.date()) : null;
        w.createdById   = evt.CreatedById;
        w.createdByName = evt.CreatedBy?.Name;
        return w;
    }
}