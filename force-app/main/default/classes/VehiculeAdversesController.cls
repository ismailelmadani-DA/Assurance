public with sharing class VehiculeAdversesController {

    // ─── Récupérer les véhicules adverses liés à une déclaration ──────────
    @AuraEnabled(cacheable=true)
    public static List<VehicleCaseAssignment__c> getAdverseVehicles(Id claimId) {
        return [
            SELECT Id,
                   EtatVehicule__c,
                   NbDePassagerBlesses__c,
                   isOpposingCar__c,
                   Claim__c
            FROM VehicleCaseAssignment__c
            WHERE Claim__c = :claimId
              AND isOpposingCar__c = true
            ORDER BY CreatedDate DESC
        ];
    }

    // ─── Créer ou modifier un véhicule adverse ────────────────────────────
    @AuraEnabled
    public static void saveAdverseVehicle(VehicleCaseAssignment__c vehicle) {
        upsert vehicle;
    }

    // ─── Supprimer un véhicule adverse ────────────────────────────────────
    @AuraEnabled
    public static void deleteAdverseVehicle(Id vehicleId) {
        delete [
            SELECT Id
            FROM VehicleCaseAssignment__c
            WHERE Id = :vehicleId
            LIMIT 1
        ];
    }

    // ─── Récupérer les valeurs de la picklist EtatVehicule__c ─────────────
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEtatPicklistValues() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult =
            VehicleCaseAssignment__c.EtatVehicule__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }
}