public with sharing class DA_lwc022_PoliceCreationController {

    // ─── Résultat CIN ────────────────────────────────────
    public class CinResult {
        @AuraEnabled public Boolean exists { get; set; }
    }

    // ─── Résultat Immatriculation ─────────────────────────
    public class ImmatriculationResult {
        @AuraEnabled public Boolean exists         { get; set; }
        @AuraEnabled public Boolean isActif        { get; set; }
        @AuraEnabled public String  numeroPolice   { get; set; }
        @AuraEnabled public String  situationPolice { get; set; }
    }

    // ─────────────────────────────────────────────────────
    // 1. Vérifier si le CIN existe déjà
    // ─────────────────────────────────────────────────────
    @AuraEnabled
    public static CinResult checkCin(String cin) {
        CinResult result = new CinResult();
        result.exists = false;

        List<Passager__c> passagers = [
            SELECT Id FROM Passager__c
            WHERE CIN__c = :cin
            LIMIT 1
        ];
        result.exists = !passagers.isEmpty();
        return result;
    }

    // ─────────────────────────────────────────────────────
    // 2. Vérifier si l'immatriculation est déjà assignée
    // ─────────────────────────────────────────────────────
    @AuraEnabled
    public static ImmatriculationResult checkImmatriculation(String immatriculation) {
        ImmatriculationResult result = new ImmatriculationResult();
        result.exists  = false;
        result.isActif = false;

        List<InsurancePolicy__c> polices = [
            SELECT Id, PolicyNumber__c, SituationPolice__c, SituationPrime__c
            FROM InsurancePolicy__c
            WHERE Immatriculation__c = :immatriculation
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!polices.isEmpty()) {
            InsurancePolicy__c p = polices[0];
            result.exists         = true;
            result.numeroPolice   = p.PolicyNumber__c;
            result.situationPolice = p.SituationPolice__c;
            // Actif = police "En cours" ET prime "Payée"
            result.isActif = (p.SituationPolice__c == 'En cours' && p.SituationPrime__c == 'Payée');
        }

        return result;
    }

    // ─────────────────────────────────────────────────────
    // 3. Créer la police
    // ─────────────────────────────────────────────────────
    @AuraEnabled
    public static void creerPolice(
        String       formData,
        List<String> garanties,
        Boolean      cinConfirmed,
        Boolean      vehiculeConfirmed
    ) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(formData);

        // ── 1. Créer ou retrouver le Passager (Assuré) ──
        String cin        = (String) data.get('cin');
        String nomComplet = (String) data.get('nomComplet');

        Passager__c passager;
        List<Passager__c> existants = [
            SELECT Id FROM Passager__c
            WHERE CIN__c = :cin
            LIMIT 1
        ];

        if (!existants.isEmpty()) {
            passager = existants[0];
        } else {
            passager = new Passager__c(
                Name          = nomComplet,
                CIN__c        = cin,
                Telephone__c  = (String) data.get('telephone'),
                Email__c      = (String) data.get('email'),
                Adresse__c    = (String) data.get('adresse')
            );
            insert passager;
        }

        // ── 2. Créer la police InsurancePolicy__c ──
        String dateEffetStr      = (String) data.get('dateEffet');
        String dateExpirationStr = (String) data.get('dateExpiration');

        // Garanties → stocker les labels séparés par virgule
        String garantiesStr = '';
        if (garanties != null && !garanties.isEmpty()) {
            List<GarantieAssurance__mdt> mdt = [
                SELECT MasterLabel, CodeGarantie__c
                FROM GarantieAssurance__mdt
                WHERE DeveloperName IN :garanties
            ];
            List<String> labels = new List<String>();
            for (GarantieAssurance__mdt g : mdt) {
                labels.add(g.MasterLabel);
            }
            garantiesStr = String.join(labels, ', ');
        }

        InsurancePolicy__c police = new InsurancePolicy__c(
            PolicyNumber__c   = (String) data.get('numeroPolice'),
            PolicyCategory__c = (String) data.get('categorie'),
            DateEffet__c      = (dateEffetStr != null && dateEffetStr != '')
                                    ? Date.valueOf(dateEffetStr) : null,
            DateExpiration__c = (dateExpirationStr != null && dateExpirationStr != '')
                                    ? Date.valueOf(dateExpirationStr) : null,
            Canal__c          = (String) data.get('canal'),
            SituationPolice__c = (String) data.get('situationPolice'),
            SituationPrime__c  = (String) data.get('situationPrime'),
            Immatriculation__c = (String) data.get('immatriculation'),
            Passager__c        = passager.Id,
            Garanties__c       = garantiesStr
        );
        insert police;

        // ── 3. Créer le Véhicule lié à la police ──
        String dateMECStr = (String) data.get('dateMiseEnCirculation');

        Vehicule__c vehicule = new Vehicule__c(
            RegistrationNumber__c      = (String) data.get('immatriculation'),
            Brand__c                   = (String) data.get('marque'),
            Modele__c                  = (String) data.get('modele'),
            ChassisNumber__c           = (String) data.get('numeroChassis'),
            AttestationNumber__c       = (String) data.get('numeroAttestation'),
            TypeVehicule__c            = (String) data.get('typeVehicule'),
            DateOfFirstRegistration__c = (dateMECStr != null && dateMECStr != '')
                                            ? Date.valueOf(dateMECStr) : null,
            InsurancePolicy__c         = police.Id
        );
        insert vehicule;
    }
}