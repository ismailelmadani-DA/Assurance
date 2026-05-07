public with sharing class DA_VehiculeAdverseController {

    @AuraEnabled(cacheable=true)
    public static List<VehicleCaseAssignment__c> getVehiculesAdverses(Id recordId) {
        if (recordId == null) return new List<VehicleCaseAssignment__c>();

        String prefix = String.valueOf(recordId).substring(0, 3);

        List<SObject> records;

        if (prefix == Schema.SObjectType.Claim__c.getKeyPrefix()) {
            records = DM002_VehicleCaseAssignment.getVehiclesAdverses(recordId);

        } else if (prefix == Schema.SObjectType.Case.getKeyPrefix()) {
            records = DM002_VehicleCaseAssignment.getVehiclesAdversesByCaseId(recordId);

        } else {
            return new List<VehicleCaseAssignment__c>();
        }

        return (List<VehicleCaseAssignment__c>) records;
    }
}