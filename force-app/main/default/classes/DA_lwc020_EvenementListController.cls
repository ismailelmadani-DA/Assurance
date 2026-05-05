public with sharing class DA_lwc020_EvenementListController {

    /* ══════════════════════════════════════════════════════════════════════
       WRAPPER — Données renvoyées au LWC
    ══════════════════════════════════════════════════════════════════════ */
    public class EvenementWrapper {
        @AuraEnabled public String  id             {get;set;}
        @AuraEnabled public String  code           {get;set;} // AutoNumber = Name
        @AuraEnabled public String  libelle        {get;set;}
        @AuraEnabled public String  categorie      {get;set;}
        @AuraEnabled public String  type           {get;set;}
        @AuraEnabled public String  dateDebut      {get;set;}
        @AuraEnabled public String  dateFin        {get;set;}
        @AuraEnabled public String  pays           {get;set;}
        @AuraEnabled public String  ville          {get;set;}
        @AuraEnabled public String  dateCreation   {get;set;}
        @AuraEnabled public String  createdById    {get;set;}
        @AuraEnabled public String  createdByName  {get;set;}
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
       @param catFilter    : filtre catégorie ('' = tous)
       @param periodFilter : 'day' | 'week' | 'month' | 'year' | ''
       @param searchTerm   : terme de recherche libre
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
            EM006_Evenement.validateEvenement(req);
            Evenement__c evt = EM006_Evenement.mapRequestToEvenement(req);
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
            return EM006_Evenement.getPicklistValues('Evenement__c', 'Categorie__c');
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
            return EM006_Evenement.getPicklistValues('Evenement__c', 'Pays__c');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLIST DÉPENDANTE — Type__c groupé par Categorie__c
       Retourne : { 'Catastrophe Naturelle': [{label,value},...], ... }
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentTypeOptions() {
        try {
            return EM006_Evenement.getDependentPicklistValues(
                'Evenement__c',
                'Categorie__c',
                'Type__c'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PICKLIST DÉPENDANTE — Ville__c groupée par Pays__c
       Retourne : { 'Maroc': [{label,value},...], ... }
    ══════════════════════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        try {
            return EM006_Evenement.getDependentPicklistValues(
                'Evenement__c',
                'Pays__c',
                'Ville__c'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PRIVATE — Mapping Evenement__c → EvenementWrapper
    ══════════════════════════════════════════════════════════════════════ */
    private static EvenementWrapper mapToWrapper(Evenement__c evt) {
        EvenementWrapper w   = new EvenementWrapper();
        w.id                 = evt.Id;
        w.code               = evt.Name;                      // AutoNumber
        w.libelle            = evt.Libelle__c;
        w.categorie          = evt.Categorie__c;
        w.type               = evt.Type__c;
        w.dateDebut          = evt.DateDebut__c  != null ? String.valueOf(evt.DateDebut__c)  : null;
        w.dateFin            = evt.DateFin__c    != null ? String.valueOf(evt.DateFin__c)    : null;
        w.pays               = evt.Pays__c;
        w.ville              = evt.Ville__c;
        w.dateCreation       = evt.CreatedDate   != null ? String.valueOf(evt.CreatedDate.date()) : null;
        w.createdById        = evt.CreatedById;
        w.createdByName      = evt.CreatedBy?.Name;
        return w;
    }
}