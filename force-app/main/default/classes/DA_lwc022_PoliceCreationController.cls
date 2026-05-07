public with sharing class DA_lwc022_PoliceCreationController {

    public class CinResult {
        @AuraEnabled public Boolean exists { get; set; }
    }

    public class ImmatriculationResult {
        @AuraEnabled public Boolean exists           { get; set; }
        @AuraEnabled public Boolean isBlocked        { get; set; }
        @AuraEnabled public String  numeroPolice     { get; set; }
        @AuraEnabled public String  situationPolice  { get; set; }
        @AuraEnabled public String  vehiculeId       { get; set; }
        @AuraEnabled public String  anciennePoliceId { get; set; }
    }

    // ═══════════════════════════════════════════════════════════════
    // PICKLISTS — Section 1
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategorieOptions() {
        return DA_Utility.getPicklistValues('InsurancePolicy__c', 'PolicyCategory__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCanalOptions() {
        return DA_Utility.getPicklistValues('InsurancePolicy__c', 'Canal__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSituationPoliceOptions() {
        return DA_Utility.getPicklistValues('InsurancePolicy__c', 'SituationPolice__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSituationPrimeOptions() {
        return DA_Utility.getPicklistValues('InsurancePolicy__c', 'SituationPrime__c');
    }

    // ═══════════════════════════════════════════════════════════════
    // PICKLISTS — Section 2 (Pays + Ville)
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaysOptions() {
        return DA_Utility.getPicklistValues('Account', 'Pays__c');
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        // Ville n'est pas une picklist dépendante dans Salesforce :
        // on retourne toutes les villes regroupées sous la clé 'Maroc'.
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        result.put('Maroc', DA_Utility.getPicklistValues('Account', 'Ville__c'));
        return result;
    }

    // ═══════════════════════════════════════════════════════════════
    // PICKLISTS — Section 3 (Véhicule)
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTypeVehiculeOptions() {
        return DA_Utility.getPicklistValues('Vehicule__c', 'TypeVehicule__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMarqueOptions() {
        return DA_Utility.getPicklistValues('Vehicule__c', 'Brand__c');
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentModeleOptions() {
        return DA_Utility.getDependentPicklistValues('Vehicule__c', 'Brand__c', 'ModelePicklist__c');
    }

    // ═══════════════════════════════════════════════════════════════
    // GARANTIES — Custom Metadata
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGarantiesMetadata() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (GarantieAssurance__mdt g : [
            SELECT MasterLabel, CodeGarantie__c, TypeGarantie__c
            FROM GarantieAssurance__mdt
            WHERE IsActive__c = true
            ORDER BY MasterLabel ASC
        ]) {
            results.add(new Map<String, String>{
                'id'   => g.Id,
                'nom'  => g.MasterLabel,
                'code' => g.CodeGarantie__c,
                'type' => g.TypeGarantie__c
            });
        }
        return results;
    }

    // ═══════════════════════════════════════════════════════════════
    // CHECKS — via DM007
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled
    public static CinResult checkCin(String cin) {
        try {
            CinResult result = new CinResult();
            result.exists = !DM007_InsurancePolicy.getByCin(cin).isEmpty();
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur vérification CIN : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ImmatriculationResult checkImmatriculation(String immatriculation) {
        try {
            ImmatriculationResult result = new ImmatriculationResult();
            result.exists    = false;
            result.isBlocked = false;

            List<Vehicule__c> vehicules = DM007_InsurancePolicy.getByImmatriculation(immatriculation);

            if (!vehicules.isEmpty()) {
                Vehicule__c v            = vehicules[0];
                result.exists            = true;
                result.vehiculeId        = v.Id;
                result.anciennePoliceId  = v.InsurancePolicy__c;
                result.numeroPolice      = v.InsurancePolicy__r.PolicyNumber__c;
                result.situationPolice   = v.InsurancePolicy__r.SituationPolice__c;
                String status            = v.InsurancePolicy__r.Status__c;
                String prime             = v.InsurancePolicy__r.SituationPrime__c;
                result.isBlocked         = ((status == 'Initiale' || status == 'Active') && prime == 'Payée');
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur vérification immatriculation : ' + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CRÉER LA POLICE — orchestration via EM007 + DA_Utility
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled
    public static String creerPolice(
        String       formData,
        List<String> garanties,
        Boolean      cinConfirmed,
        Boolean      vehiculeConfirmed,
        String       vehiculeExistantId,
        String       anciennePoliceId
    ) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(formData);

            // ── 1. Upsert Account (RecordType Passager via DA_Utility) ──────
            String  cin        = (String) data.get('cin');
            String  nomComplet = (String) data.get('nomComplet');
            Account assure;

            List<Account> existants = DM007_InsurancePolicy.getByCin(cin);

            if (!existants.isEmpty()) {
                // Mise à jour — on garde le RecordType existant
                assure = new Account(
                    Id         = existants[0].Id,
                    Name       = nomComplet,
                    Nom__c     = nomComplet,
                    Phone      = (String) data.get('telephone'),
                    Email__c   = (String) data.get('email'),
                    Adresse__c = (String) data.get('adresse'),
                    Pays__c    = (String) data.get('pays'),
                    Ville__c   = (String) data.get('ville')
                );
                EM007_InsurancePolicy.updateAccount(assure);
            } else {
                // Création — RecordType Passager via DA_Utility
                Id rtId = DA_Utility.getRecordTypeId('Account', 'Passager');
                assure = new Account(
                    RecordTypeId = rtId,
                    Name         = nomComplet,
                    Nom__c       = nomComplet,
                    CIN__c       = cin,
                    Phone        = (String) data.get('telephone'),
                    Email__c     = (String) data.get('email'),
                    Adresse__c   = (String) data.get('adresse'),
                    Pays__c      = (String) data.get('pays'),
                    Ville__c     = (String) data.get('ville')
                );
                EM007_InsurancePolicy.insertAccount(assure);
            }

            // ── 2. Créer la police ──────────────────────────────────────────
            String dateEffetStr      = (String) data.get('dateEffet');
            String dateExpirationStr = (String) data.get('dateExpiration');

            InsurancePolicy__c police = new InsurancePolicy__c(
                PolicyNumber__c    = (String) data.get('numeroPolice'),
                PolicyCategory__c  = (String) data.get('categorie'),
                DateEffet__c       = String.isNotBlank(dateEffetStr)      ? Date.valueOf(dateEffetStr)      : null,
                DateExpiration__c  = String.isNotBlank(dateExpirationStr) ? Date.valueOf(dateExpirationStr) : null,
                Canal__c           = (String) data.get('canal'),
                Status__c          = 'Initiale',
                SituationPolice__c = (String) data.get('situationPolice'),
                SituationPrime__c  = (String) data.get('situationPrime'),
                Immatriculation__c = (String) data.get('immatriculation'),
                AccountName__c     = assure.Id
            );
            EM007_InsurancePolicy.insertPolice(police);

            // ── 3. Gérer le véhicule ────────────────────────────────────────
            if (String.isNotBlank(vehiculeExistantId)) {
                // Réaffecter le véhicule existant à la nouvelle police
                EM007_InsurancePolicy.updateVehicule(new Vehicule__c(
                    Id                 = vehiculeExistantId,
                    InsurancePolicy__c = police.Id
                ));
                // Lier le véhicule à la nouvelle police
                EM007_InsurancePolicy.updatePolice(new InsurancePolicy__c(
                    Id          = police.Id,
                    Vehicule__c = vehiculeExistantId
                ));
                // Résilier l'ancienne police
                if (String.isNotBlank(anciennePoliceId)) {
                    EM007_InsurancePolicy.updatePolice(new InsurancePolicy__c(
                        Id        = anciennePoliceId,
                        Status__c = 'Résiliée'
                    ));
                }
            } else {
                // Créer un nouveau véhicule
                String dateMECStr = (String) data.get('dateMiseEnCirculation');
                Vehicule__c vehicule = new Vehicule__c(
                    RegistrationNumber__c      = (String) data.get('immatriculation'),
                    Brand__c                   = (String) data.get('marque'),
                    ModelePicklist__c          = (String) data.get('modele'),
                    ChassisNumber__c           = (String) data.get('numeroChassis'),
                    AttestationNumber__c       = (String) data.get('numeroAttestation'),
                    TypeVehicule__c            = (String) data.get('typeVehicule'),
                    DateOfFirstRegistration__c = String.isNotBlank(dateMECStr) ? Date.valueOf(dateMECStr) : null,
                    InsurancePolicy__c         = police.Id
                );
                EM007_InsurancePolicy.insertVehicule(vehicule);
                // Lier le nouveau véhicule à la police
                EM007_InsurancePolicy.updatePolice(new InsurancePolicy__c(
                    Id          = police.Id,
                    Vehicule__c = vehicule.Id
                ));
            }

            // ── 4. Créer les garanties ──────────────────────────────────────
            if (garanties != null && !garanties.isEmpty()) {
                List<InsurancePolicyCoverage__c> coverages = new List<InsurancePolicyCoverage__c>();
                for (String garantieJson : garanties) {
                    Map<String, Object> g = (Map<String, Object>) JSON.deserializeUntyped(garantieJson);
                    coverages.add(new InsurancePolicyCoverage__c(
                        InsurancePolicy__c = police.Id,
                        NomDeLaGarantie__c = (String) g.get('nom'),
                        CodeGarantie__c    = (String) g.get('code'),
                        TypeGarantie__c    = (String) g.get('type'),
                        GarantieUsed__c    = true
                    ));
                }
                EM007_InsurancePolicy.insertCoverages(coverages);
            }

            return police.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Erreur création police : ' + e.getMessage());
        }
    }
}