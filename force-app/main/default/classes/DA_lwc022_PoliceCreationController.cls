public with sharing class DA_lwc022_PoliceCreationController {

    // ─── Résultat CIN ────────────────────────────────────────────
    public class CinResult {
        @AuraEnabled public Boolean exists { get; set; }
    }

    // ─── Résultat Immatriculation ─────────────────────────────────
    public class ImmatriculationResult {
        @AuraEnabled public Boolean exists           { get; set; }
        @AuraEnabled public Boolean isBlocked        { get; set; }
        @AuraEnabled public String  numeroPolice     { get; set; }
        @AuraEnabled public String  situationPolice  { get; set; }
        @AuraEnabled public String  vehiculeId       { get; set; }
        @AuraEnabled public String  anciennePoliceId { get; set; }
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Vérifier si le CIN existe déjà
    // ─────────────────────────────────────────────────────────────
    @AuraEnabled
    public static CinResult checkCin(String cin) {
        CinResult result = new CinResult();
        result.exists = false;

        // CORRECTION : L'objet s'appelle Passager__c (Participant de l'accident)
        // Le champ CIN s'appelle CIN__c
        List<Passager__c> passagers = [
            SELECT Id
            FROM Passager__c
            WHERE CIN__c = :cin
            LIMIT 1
        ];
        result.exists = !passagers.isEmpty();
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // 2. Vérifier si l'immatriculation est déjà assignée
    // ─────────────────────────────────────────────────────────────
    @AuraEnabled
    public static ImmatriculationResult checkImmatriculation(String immatriculation) {
        ImmatriculationResult result = new ImmatriculationResult();
        result.exists    = false;
        result.isBlocked = false;

        // CORRECTION : Chercher le véhicule et sa police liée
        // RegistrationNumber__c est bien le champ numéro d'immatriculation sur Véhicule__c
        List<Vehicule__c> vehicules = [
            SELECT Id,
                   InsurancePolicy__c,
                   InsurancePolicy__r.PolicyNumber__c,
                   InsurancePolicy__r.SituationPolice__c,
                   InsurancePolicy__r.SituationPrime__c
            FROM Vehicule__c
            WHERE RegistrationNumber__c = :immatriculation
              AND InsurancePolicy__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!vehicules.isEmpty()) {
            Vehicule__c v = vehicules[0];
            result.exists           = true;
            result.vehiculeId       = v.Id;
            result.anciennePoliceId = v.InsurancePolicy__c;
            result.numeroPolice     = v.InsurancePolicy__r.PolicyNumber__c;
            result.situationPolice  = v.InsurancePolicy__r.SituationPolice__c;

            String sit   = v.InsurancePolicy__r.SituationPolice__c;
            String prime = v.InsurancePolicy__r.SituationPrime__c;

            // CORRECTION selon specs :
            // BLOQUANT = police "Initiale" ou "Active" ET prime "Payée"
            // (véhicule considéré comme actif/en cours)
            result.isBlocked = (
                (sit == 'Initiale' || sit == 'Active') &&
                prime == 'Payée'
            );
        }

        return result;
    }

    // NOUVEAU : Récupérer les garanties depuis les Custom Metadata
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGarantiesMetadata() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (GarantieAssurance__mdt g : [SELECT MasterLabel, CodeGarantie__c FROM GarantieAssurance__mdt WHERE IsActive__c = true ORDER BY MasterLabel ASC]) {
            Map<String, String> item = new Map<String, String>();
            item.put('id', g.Id); 
            item.put('nom', g.MasterLabel);
            item.put('code', g.CodeGarantie__c);
            results.add(item);
        }
        return results;
    }

    // ─────────────────────────────────────────────────────────────
    // 3. Créer la police
    // ─────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String  creerPolice(
        String       formData,
        List<String> garanties,
        Boolean      cinConfirmed,
        Boolean      vehiculeConfirmed,
        String       vehiculeExistantId,
        String       anciennePoliceId
    ) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(formData);

        // ── 1. Créer ou retrouver le Passager (Assuré) ──────────
        String cin        = (String) data.get('cin');
        String nomComplet = (String) data.get('nomComplet');

        Passager__c passager;
        List<Passager__c> existants = [
            SELECT Id
            FROM Passager__c
            WHERE CIN__c = :cin
            LIMIT 1
        ];

        if (!existants.isEmpty()) {
            passager = existants[0];
        } else {
            // CORRECTION : Utiliser les bons noms de champs de Passager__c
            // Name = "Nom et Prenom" (champ Name standard)
            // CIN__c, Telephone__c, Email__c, Adresse__c existent bien
            passager = new Passager__c(
                Name         = nomComplet,
                CIN__c       = cin,
                Telephone__c = (String) data.get('telephone'),
                Email__c     = (String) data.get('email'),
                Adresse__c   = (String) data.get('adresse')
            );
            insert passager;
        }

        // ── 2. Préparer les garanties ────────────────────────────
        String garantiesStr = '';
        if (garanties != null && !garanties.isEmpty()) {
            garantiesStr = String.join(garanties, ', ');
        }

        // ── 3. Créer la police avec statut "Initiale" par défaut ─
        String dateEffetStr      = (String) data.get('dateEffet');
        String dateExpirationStr = (String) data.get('dateExpiration');

        // CORRECTION : Les champs InsurancePolicy__c corrects :
        // PolicyNumber__c, PolicyCategory__c, DateEffet__c, DateExpiration__c
        // Canal__c, SituationPolice__c, SituationPrime__c
        // Immatriculation__c, Passager__c (Lookup vers Passager__c), Garanties__c
        InsurancePolicy__c police = new InsurancePolicy__c(
            PolicyNumber__c    = (String) data.get('numeroPolice'),
            PolicyCategory__c  = (String) data.get('categorie'),
            DateEffet__c       = (dateEffetStr != null && dateEffetStr != '')
                                     ? Date.valueOf(dateEffetStr) : null,
            DateExpiration__c  = (dateExpirationStr != null && dateExpirationStr != '')
                                     ? Date.valueOf(dateExpirationStr) : null,
            Canal__c           = (String) data.get('canal'),
            UniteGestion__c    = (String) data.get('uniteGestion'),
            SituationPolice__c = 'Initiale',
            SituationPrime__c  = (String) data.get('situationPrime'),
            Immatriculation__c = (String) data.get('immatriculation'),
            Passager__c        = passager.Id,
            Garanties__c       = garantiesStr
        );
        insert police;

        // ── 4. Gérer le véhicule ─────────────────────────────────
        if (String.isNotBlank(vehiculeExistantId)) {
            // Relier le véhicule existant à la nouvelle police
            Vehicule__c vExistant = new Vehicule__c(
                Id                 = vehiculeExistantId,
                InsurancePolicy__c = police.Id
            );
            update vExistant;

            // Résilier l'ancienne police
            if (String.isNotBlank(anciennePoliceId)) {
                InsurancePolicy__c ancienne = new InsurancePolicy__c(
                    Id                 = anciennePoliceId,
                    SituationPolice__c = 'Résiliée'
                );
                update ancienne;
            }

        } else {
            // Nouveau véhicule
            String dateMECStr = (String) data.get('dateMiseEnCirculation');

            // CORRECTION : Brand__c est une Picklist sur Véhicule__c
            // On utilise Modele__c (Text) pour le modèle libre
            // TypeVehicule__c est une Picklist — les valeurs doivent correspondre à l'org
            // ATTENTION : Brand__c étant Picklist, si la valeur ne correspond pas
            // à une valeur de picklist existante, l'insert échouera.
            // Voir note ci-dessous.
            Vehicule__c vehicule = new Vehicule__c(
                RegistrationNumber__c      = (String) data.get('immatriculation'),
                Brand__c                   = (String) data.get('marque'),         // ⚠️ Picklist - voir note
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
        return police.Id;
    }
}