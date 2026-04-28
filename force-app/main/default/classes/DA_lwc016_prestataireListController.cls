public with sharing class DA_lwc016_prestataireListController {

    public class PrestataireWrapper {
        @AuraEnabled public String id {get;set;}
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public String code {get;set;}
        @AuraEnabled public String type {get;set;}
        @AuraEnabled public String phone {get;set;}
        @AuraEnabled public String email {get;set;}
        @AuraEnabled public String ville {get;set;}
        @AuraEnabled public String adresse {get;set;}
        @AuraEnabled public String pays {get;set;}
        @AuraEnabled public String ribId {get;set;}
        @AuraEnabled public String banque {get;set;}
        @AuraEnabled public String rib {get;set;}
        @AuraEnabled public String codeBanque {get;set;}
        @AuraEnabled public String statutRib  {get;set;}
        @AuraEnabled public Boolean actif     {get;set;}
    }

    public class SaveRequest {
        @AuraEnabled public String id {get;set;}
        @AuraEnabled public String type {get;set;}
        @AuraEnabled public String oldType {get;set;}  // ← AJOUTÉ
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public String phone {get;set;}
        @AuraEnabled public String email {get;set;}
        @AuraEnabled public String ville {get;set;}
        @AuraEnabled public String adresse {get;set;}
        @AuraEnabled public String pays {get;set;}
        @AuraEnabled public String banque {get;set;}
        @AuraEnabled public String rib {get;set;}
        @AuraEnabled public String ribId {get;set;}
        @AuraEnabled public String  codeBanque {get;set;}
        @AuraEnabled public String  statutRib  {get;set;}
        @AuraEnabled public Boolean actif      {get;set;}
    }

    @AuraEnabled(cacheable=true)
    public static List<PrestataireWrapper> getPrestataires(String typeFilter, String searchTerm) {
        try {
            List<Account> accounts = DM003_Prestataire.getPrestataires(typeFilter, searchTerm);
            Set<Id> accIds = new Map<Id, Account>(accounts).keySet();
            List<RIB__c> ribs = DM003_Prestataire.getRibsByAccountIds(accIds);
            Map<Id, RIB__c> ribMap = new Map<Id, RIB__c>();
            for(RIB__c r : ribs) ribMap.put(r.ParticipantAccount__c, r);

            List<PrestataireWrapper> results = new List<PrestataireWrapper>();
            for (Account acc : accounts) {
                PrestataireWrapper w = new PrestataireWrapper();
                w.id = acc.Id;
                w.name = acc.Name;
                w.code = acc.codeTier__c;
                w.type = acc.TypeDePrestataire__c;
                w.phone = acc.Phone;
                w.email = acc.Email__c;
                w.ville = acc.Ville__c;
                w.adresse = acc.Adresse__c;
                w.pays = acc.Pays__c;

                RIB__c r = ribMap.get(acc.Id);
                if (r != null) {
                    w.ribId     = r.Id;
                    w.banque    = r.CodeBanque__c;
                    w.rib       = r.RIB__c;
                    w.codeBanque = r.CodeBanque__c;
                    w.statutRib = r.Statut__c;
                    w.actif     = r.Actif__c;
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
            EM003_Prestataire.validatePrestataire(req);
            Account acc = EM003_Prestataire.mapRequestToAccount(req);
            RIB__c rib = EM003_Prestataire.mapRequestToRib(req, acc.Id);
            EM003_Prestataire.upsertPrestataire(acc, rib);
            return acc.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String generateCode(String type) {
        return EM003_Prestataire.generateUniqueCode(type);
    }

    @AuraEnabled(cacheable=true)
public static List<Map<String, String>> getBanqueOptions() {
    List<Map<String, String>> opts = new List<Map<String, String>>();
    for (Schema.PicklistEntry entry : RIB__c.CodeBanque__c.getDescribe().getPicklistValues()) {
        if (entry.isActive()) {
            opts.add(new Map<String, String>{
                'label' => entry.getLabel(),
                'value' => entry.getValue(),
                'code'  => entry.getValue()   // ← l'API Name EST le code banque (007, 011…)
            });
        }
    }
    return opts;
}

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaysOptions() {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : Account.Pays__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) opts.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        Map<String, List<Map<String, String>>> dependentOptions = new Map<String, List<Map<String, String>>>();
        List<Map<String, String>> allVilles = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : Account.Ville__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                allVilles.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
            }
        }
        dependentOptions.put('Maroc', allVilles);
        return dependentOptions;
    }
}