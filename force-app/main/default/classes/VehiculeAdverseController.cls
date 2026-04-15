public with sharing class VehiculeAdverseController {

    @AuraEnabled(cacheable=true)
    public static List<VehicleCaseAssignment__c> getVehicules(Id caseId) {
        try {
            return [
                SELECT Id,
                       EtatVehicule__c,
                       NbDePassagerBlesses__c,
                       isOpposingCar__c
                FROM VehicleCaseAssignment__c
                WHERE Claim__c = :caseId
                  AND isOpposingCar__c = true
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

   @AuraEnabled
public static Id saveVehicule(VehicleCaseAssignment__c vehicule) {
    try {
        System.debug('saveVehicule reçu : ' + JSON.serialize(vehicule));
        System.debug('Claim__c value : ' + vehicule.Claim__c);

        if (vehicule.Id != null) {
            update vehicule;
        } else {
            insert vehicule;
        }
        return vehicule.Id;

    } catch (DmlException e) {
        throw new AuraHandledException('DML Error: ' + e.getDmlMessage(0));
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}

    @AuraEnabled
    public static void deleteVehicule(Id vehiculeId) {
        try {
            delete [
                SELECT Id
                FROM VehicleCaseAssignment__c
                WHERE Id = :vehiculeId
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}