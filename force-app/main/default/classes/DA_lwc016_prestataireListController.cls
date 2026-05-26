public with sharing class DA_lwc016_prestataireListController {

    // ─── Wrappers ────────────────────────────────────────────────────────────

    public class PrestataireWrapper {
        @AuraEnabled public String  id          {get;set;}
        @AuraEnabled public String  name        {get;set;}
        @AuraEnabled public String  code        {get;set;}
        @AuraEnabled public String  type        {get;set;}
        @AuraEnabled public String  phone       {get;set;}
        @AuraEnabled public String  email       {get;set;}
        @AuraEnabled public String  ville       {get;set;}
        @AuraEnabled public String  adresse     {get;set;}
        @AuraEnabled public String  pays        {get;set;}
        @AuraEnabled public String  ribId       {get;set;}
        @AuraEnabled public String  banque      {get;set;}
        @AuraEnabled public String  rib         {get;set;}
        @AuraEnabled public String  codeBanque  {get;set;}
        @AuraEnabled public String  statutRib   {get;set;}
        @AuraEnabled public Boolean actif       {get;set;}
    }

    public class SaveRequest {
        @AuraEnabled public String  id          {get;set;}
        @AuraEnabled public String  type        {get;set;}
        @AuraEnabled public String  oldType     {get;set;}
        @AuraEnabled public String  name        {get;set;}
        @AuraEnabled public String  phone       {get;set;}
        @AuraEnabled public String  email       {get;set;}
        @AuraEnabled public String  ville       {get;set;}
        @AuraEnabled public String  adresse     {get;set;}
        @AuraEnabled public String  pays        {get;set;}
        @AuraEnabled public String  banque      {get;set;}
        @AuraEnabled public String  rib         {get;set;}
        @AuraEnabled public String  ribId       {get;set;}
        @AuraEnabled public String  codeBanque  {get;set;}
        @AuraEnabled public String  statutRib   {get;set;}
        @AuraEnabled public Boolean actif       {get;set;}
    }

    // ─── Constantes métier ───────────────────────────────────────────────────

    private static final Map<String, String> TYPE_PREFIX = new Map<String, String>{
        'Expert Automobile'   => 'EXP',
        'Garagiste'           => 'GAR',
        'Avocat'              => 'AVO',
        'Médecin'             => 'MED',
        'Clinique'            => 'CLI',
        'Centre radiologique' => 'RAD',
        'Pharmacie'           => 'PHA',
        'Hôpital'             => 'HOP',
        'Enquêteur'           => 'ENQ'
    };

    // ─── Méthodes AuraEnabled ────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<PrestataireWrapper> getPrestataires(String typeFilter, String searchTerm) {
        try {
            List<Account> accounts = DM003_Prestataire.getPrestataires(typeFilter, searchTerm);
            Set<Id> accIds = new Map<Id, Account>(accounts).keySet();
            List<RIB__c> ribs = DM003_Prestataire.getRibsByAccountIds(accIds);

            Map<Id, RIB__c> ribMap = new Map<Id, RIB__c>();
            for (RIB__c r : ribs) ribMap.put(r.ParticipantAccount__c, r);

            List<PrestataireWrapper> results = new List<PrestataireWrapper>();
            for (Account acc : accounts) {
                PrestataireWrapper w = new PrestataireWrapper();
                w.id      = acc.Id;
                w.name    = acc.Name;
                w.code    = acc.codeTier__c;
                w.type    = acc.TypeDePrestataire__c;
                w.phone   = acc.Phone;
                w.email   = acc.Email__c;
                w.ville   = acc.Ville__c;
                w.adresse = acc.Adresse__c;
                w.pays    = acc.Pays__c;

                RIB__c r = ribMap.get(acc.Id);
                if (r != null) {
                    w.ribId      = r.Id;
                    w.banque     = r.CodeBanque__c;
                    w.rib        = r.RIB__c;
                    w.codeBanque = r.CodeBanque__c;
                    w.statutRib  = r.Statut__c;
                    w.actif      = r.Actif__c;
                }
                results.add(w);
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String savePrestataire(SaveRequest req) {
        try {
            validatePrestataire(req);
            Account acc = mapRequestToAccount(req);
            RIB__c  rib = mapRequestToRib(req, acc.Id);
            EM003_Prestataire.upsertPrestataire(acc, rib);
            return acc.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String generateCode(String type) {
        return generateUniqueCode(type);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBanqueOptions() {
        try {
            return DM003_Prestataire.getBanqueOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaysOptions() {
        try {
            return DM003_Prestataire.getPaysOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        try {
            return DM003_Prestataire.getDependentVilleOptions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── Logique métier privée ───────────────────────────────────────────────

    private static void validatePrestataire(SaveRequest req) {
        if (String.isBlank(req.name)) throw new AuraHandledException('Le nom est obligatoire.');
        if (String.isBlank(req.type)) throw new AuraHandledException('Le type est obligatoire.');
    }

    private static String generateUniqueCode(String type) {
        String prefix = TYPE_PREFIX.containsKey(type) ? TYPE_PREFIX.get(type) : 'PRE';
        Integer count = DM003_Prestataire.countPrestatairesByType(type);
        return prefix + '-' + String.valueOf(count + 1).leftPad(4, '0');
    }

    private static Account mapRequestToAccount(SaveRequest req) {
        Account acc = new Account();
        if (String.isNotBlank(req.id)) acc.Id = req.id;

        acc.RecordTypeId         = DM003_Prestataire.getPrestataireRTId();
        acc.Name                 = req.name;
        acc.TypeDePrestataire__c = req.type;
        acc.Phone                = req.phone;
        acc.Email__c             = req.email;
        acc.Ville__c             = req.ville;
        acc.Adresse__c           = req.adresse;
        acc.Pays__c              = String.isNotBlank(req.pays) ? req.pays : 'Maroc';

        Boolean isNew       = String.isBlank(req.id);
        Boolean typeChanged = !isNew
                              && String.isNotBlank(req.oldType)
                              && req.oldType != req.type;

        if (isNew || typeChanged) {
            acc.codeTier__c = generateUniqueCode(req.type);
        }

        return acc;
    }

    private static RIB__c mapRequestToRib(SaveRequest req, Id accId) {
        if (String.isBlank(req.rib) && String.isBlank(req.banque)) return null;

        RIB__c rib = new RIB__c();
        if (String.isNotBlank(req.ribId)) rib.Id = req.ribId;
        rib.ParticipantAccount__c = accId;
        rib.CodeBanque__c         = req.banque;
        rib.RIB__c                = req.rib;
        rib.Actif__c              = true;
        rib.Statut__c             = 'RIB Validé';
        return rib;
    }
}