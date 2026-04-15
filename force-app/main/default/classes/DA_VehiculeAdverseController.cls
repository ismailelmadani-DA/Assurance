public with sharing class DA_VehiculeAdverseController {

    private static final Set<String> VEHICULE_FIELDS = new Set<String>{
        'Id',
        'EtatVehicule__c',
        'NbDePassagerBlesses__c',
        'isOpposingCar__c',
        'Claim__c',
        'Case__c',
        'Vehicule__c',
        'Vehicule__r.Name',
        'Vehicule__r.RegistrationNumber__c',
        'Vehicule__r.Brand__c',
        'AdversaireAssure__c',
        'Pays__c',
        'CompagnieAdverse__c'
    };

    // ── Picklists dynamiques ──────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();

        result.put('EtatVehicule__c',  getPicklist('VehicleCaseAssignment__c', 'EtatVehicule__c'));
        result.put('Pays__c',          getPicklist('VehicleCaseAssignment__c', 'Pays__c'));
        result.put('Brand__c',         getPicklist('Vehicule__c',              'Brand__c'));
        result.put('TypeVehicule__c',  getPicklist('Vehicule__c',              'TypeVehicule__c'));

        return result;
    }

    private static List<Map<String, String>> getPicklist(String objectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();

        // Option vide par défaut
        options.add(new Map<String, String>{ 'label' => '-- Aucun --', 'value' => '' });

        Schema.DescribeFieldResult fieldDesc = Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields
            .getMap()
            .get(fieldName)
            .getDescribe();

        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        return options;
    }

    // ── Prefixes dynamiques ───────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getObjectPrefixes() {
        return new Map<String, String>{
            'claim' => Schema.SObjectType.Claim__c.getKeyPrefix(),
            'case'  => Schema.SObjectType.Case.getKeyPrefix()
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<VehicleCaseAssignment__c> getVehiculesAdverses(Id recordId) {
        if (recordId == null) return new List<VehicleCaseAssignment__c>();

        String prefix = String.valueOf(recordId).substring(0, 3);
        String whereClause;

        if (prefix == Schema.SObjectType.Claim__c.getKeyPrefix()) {
            whereClause = 'Claim__c = \'' + recordId + '\' AND isOpposingCar__c = true ORDER BY CreatedDate DESC';
        } else if (prefix == Schema.SObjectType.Case.getKeyPrefix()) {
            whereClause = 'Case__c = \'' + recordId + '\' AND isOpposingCar__c = true ORDER BY CreatedDate DESC';
        } else {
            return new List<VehicleCaseAssignment__c>();
        }

        String query = DA_Utility.buildStandardQuery(
            'VehicleCaseAssignment__c',
            VEHICULE_FIELDS,
            whereClause
        );

        return Database.query(query);
    }

    @AuraEnabled
    public static void saveVehiculeAdverse(
        Id      recordId,
        Id      assignmentId,
        Id      vehiculeId,
        String  etatVehicule,
        Integer nbPassagers,
        Boolean adversaireAssure,
        String  pays,
        Id      compagnieAdverse,
        String  immatriculation,
        String  marque,
        String  typeVehicule,
        Date    dateMiseEnCirculation,
        Id      proprietaire
    ) {
        Vehicule__c veh = vehiculeId != null
            ? new Vehicule__c(Id = vehiculeId)
            : new Vehicule__c();

        veh.RegistrationNumber__c      = immatriculation;
        veh.Brand__c                   = marque;
        veh.TypeVehicule__c            = typeVehicule;
        veh.DateOfFirstRegistration__c = dateMiseEnCirculation;
        veh.ProprietaireDuVehicule__c  = proprietaire;
        veh.AdversaireAssur__c         = adversaireAssure;
        veh.CompagnieAdverse__c        = compagnieAdverse;

        upsert veh;

        VehicleCaseAssignment__c assignment = assignmentId != null
            ? new VehicleCaseAssignment__c(Id = assignmentId)
            : new VehicleCaseAssignment__c();

        assignment.Vehicule__c            = veh.Id;
        assignment.EtatVehicule__c        = etatVehicule;
        assignment.NbDePassagerBlesses__c = nbPassagers;
        assignment.AdversaireAssure__c    = adversaireAssure;
        assignment.Pays__c                = pays;
        assignment.CompagnieAdverse__c    = compagnieAdverse;
        assignment.isOpposingCar__c       = true;

        String prefix = String.valueOf(recordId).substring(0, 3);
        if (prefix == Schema.SObjectType.Claim__c.getKeyPrefix()) {
            assignment.Claim__c = recordId;
        } else {
            assignment.Case__c = recordId;
        }

        upsert assignment;
    }

    @AuraEnabled
    public static void deleteVehiculeAdverse(Id recordId) {
        if (recordId == null) throw new AuraHandledException('ID manquant.');

        List<VehicleCaseAssignment__c> toDelete = [
            SELECT Id, Vehicule__c
            FROM VehicleCaseAssignment__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (toDelete.isEmpty()) throw new AuraHandledException('Enregistrement introuvable.');

        Id vehiculeId = toDelete[0].Vehicule__c;
        delete toDelete;

        if (vehiculeId != null) {
            delete new Vehicule__c(Id = vehiculeId);
        }
    }
}