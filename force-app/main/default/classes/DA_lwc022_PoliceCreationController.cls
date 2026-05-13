// ═══════════════════════════════════════════════════════════════
// DA_lwc022_PoliceCreationController — Orchestration LWC
// ═══════════════════════════════════════════════════════════════
public with sharing class DA_lwc022_PoliceCreationController {

    public class CinResult {
        @AuraEnabled public Boolean exists { get; set; }
    }

    public class ImmatriculationResult {
        @AuraEnabled public Boolean exists          { get; set; }
        @AuraEnabled public Boolean isBlocked       { get; set; }
        @AuraEnabled public String  numeroPolice    { get; set; }
        @AuraEnabled public String  situationPolice { get; set; }
        @AuraEnabled public String  vehiculeId      { get; set; }
        @AuraEnabled public String  anciennePoliceId{ get; set; }
    }

    // ═══════════════════════════════════════════════════════════════
    // PICKLISTS — délégation vers DM007
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategorieOptions() {
        return DM007_InsurancePolicy.getCategorieOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCanalOptions() {
        return DM007_InsurancePolicy.getCanalOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSituationPoliceOptions() {
        return DM007_InsurancePolicy.getSituationPoliceOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSituationPrimeOptions() {
        return DM007_InsurancePolicy.getSituationPrimeOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaysOptions() {
        return DM007_InsurancePolicy.getPaysOptions();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        return DM007_InsurancePolicy.getDependentVilleOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTypeVehiculeOptions() {
        return DM007_InsurancePolicy.getTypeVehiculeOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMarqueOptions() {
        return DM007_InsurancePolicy.getMarqueOptions();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentModeleOptions() {
        return DM007_InsurancePolicy.getDependentModeleOptions();
    }

    // ═══════════════════════════════════════════════════════════════
    // GARANTIES — délégation vers DM007
    // ═══════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGarantiesMetadata() {
        return DM007_InsurancePolicy.getGarantiesMetadata();
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
                Vehicule__c v           = vehicules[0];
                result.exists           = true;
                result.vehiculeId       = v.Id;
                result.anciennePoliceId = v.InsurancePolicy__c;
                result.numeroPolice = v.InsurancePolicy__r.PolicyNumber__c; // ← à la place de .Name
                result.situationPolice  = v.InsurancePolicy__r.SituationPolice__c;
                String status           = v.InsurancePolicy__r.Status__c;
                String prime            = v.InsurancePolicy__r.SituationPrime__c;
                result.isBlocked        = ((status == 'Initiale' || status == 'Active') && prime == 'Payée');
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur vérification immatriculation : ' + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // NUMÉRO DE POLICE — prévisualisation auto-number
    // ═══════════════════════════════════════════════════════════════

 @AuraEnabled(cacheable=false)
public static String getNextNumeroPolice() {
    return DM007_InsurancePolicy.getNextNumeroPolice();
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

            // ── 1. Upsert Account ───────────────────────────────────────────
            String  cin        = (String) data.get('cin');
            String  nomComplet = (String) data.get('nomComplet');
            Account assure;

            List<Account> existants = DM007_InsurancePolicy.getByCin(cin);

            if (!existants.isEmpty()) {
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
                assure = new Account(
                    RecordTypeId = DA_Utility.getRecordTypeId('Account', 'Passager'),
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
            // ── 2. Créer la police ──────────────────────────────────────────
String dateEffetStr      = (String) data.get('dateEffet');
String dateExpirationStr = (String) data.get('dateExpiration');
String numeroPolice      = (String) data.get('numeroPolice'); // ← récupérer depuis formData

InsurancePolicy__c police = new InsurancePolicy__c(
    Name               = numeroPolice,
    PolicyNumber__c    = numeroPolice,        // ← champ custom correct
    PolicyCategory__c  = (String) data.get('categorie'),
    DateEffet__c       = String.isNotBlank(dateEffetStr)      ? Date.valueOf(dateEffetStr)      : null,
    DateExpiration__c  = String.isNotBlank(dateExpirationStr) ? Date.valueOf(dateExpirationStr) : null,
    Canal__c           = (String) data.get('canal'),
    Status__c          = 'Initiale',
    SituationPolice__c = String.isNotBlank((String) data.get('situationPolice'))
                            ? (String) data.get('situationPolice')
                            : 'En cours',   
    SituationPrime__c  = (String) data.get('situationPrime'),
    Immatriculation__c = (String) data.get('immatriculation'),
    AccountName__c     = assure.Id
);
EM007_InsurancePolicy.insertPolice(police);

            // ── 3. Gérer le véhicule ────────────────────────────────────────
            if (String.isNotBlank(vehiculeExistantId)) {
                EM007_InsurancePolicy.updateVehicule(new Vehicule__c(
                    Id                 = vehiculeExistantId,
                    InsurancePolicy__c = police.Id
                ));
                EM007_InsurancePolicy.updatePolice(new InsurancePolicy__c(
                    Id          = police.Id,
                    Vehicule__c = vehiculeExistantId
                ));
                if (String.isNotBlank(anciennePoliceId)) {
                    EM007_InsurancePolicy.updatePolice(new InsurancePolicy__c(
                        Id        = anciennePoliceId,
                        Status__c = 'Résiliée'
                    ));
                }
            } else {
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