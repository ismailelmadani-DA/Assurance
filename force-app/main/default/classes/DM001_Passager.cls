public with sharing class DM001_Passager {

    private static final String CLASS_NAME = DM001_Passager.class.getName();

    public static List<Passager__c> getPassagersByCaseAndRole(Id caseId, String role) {
        System.debug(CLASS_NAME + ' - Start method getPassagersByCaseAndRole');
        List<Passager__c> result = [
            SELECT Id, Name, Name__c, Civilite__c, CIN__c,
                   Pays__c, Ville__c, TypeContact__c, StateOfPerson__c
            FROM Passager__c
            WHERE Case__c = :caseId
              AND Roles__c = :role
            ORDER BY Name__c ASC
        ];
        System.debug(CLASS_NAME + ' - End method getPassagersByCaseAndRole');
        return result;
    }

    public static void deletePassagerById(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassagerById');
        delete new Passager__c(Id = passagerId);
        System.debug(CLASS_NAME + ' - End method deletePassagerById');
    }
}