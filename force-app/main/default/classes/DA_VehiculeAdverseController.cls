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

    @AuraEnabled(cacheable=true)
    public static List<VehicleCaseAssignment__c> getVehiculesAdverses(Id recordId) {
        if (recordId == null) return new List<VehicleCaseAssignment__c>();

        String prefix = String.valueOf(recordId).substring(0, 3);
        String whereClause;

        if (prefix == Schema.SObjectType.Claim__c.getKeyPrefix()) {
            whereClause = 'Claim__c = \'' + recordId + '\' ORDER BY CreatedDate DESC';
        } else if (prefix == Schema.SObjectType.Case.getKeyPrefix()) {
            whereClause = 'Case__c = \'' + recordId + '\' ORDER BY CreatedDate DESC';
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
}