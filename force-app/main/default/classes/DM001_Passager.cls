public with sharing class DM001_Passager {

    private static final String CLASS_NAME = DM001_Passager.class.getName();

    public static List<Passager__c> getPassagersByCaseAndRole(Id caseId, String role) {
        System.debug(CLASS_NAME + ' - Start method getPassagersByCaseAndRole');
        String fields = 'Id, Name, Name__c, Civilite__c, CIN__c, Pays__c, Ville__c, TypeContact__c, StateOfPerson__c';
        String conditions = 'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\''
            + ' AND Roles__c = \'' + String.escapeSingleQuotes(role) + '\'';
        List<Passager__c> result = (List<Passager__c>) DA_Utility.query(fields, 'Passager__c', conditions, 'Name__c ASC', null);
        System.debug(CLASS_NAME + ' - End method getPassagersByCaseAndRole');
        return result;
    }

    public static void deletePassagerById(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassagerById');
        delete new Passager__c(Id = passagerId);
        System.debug(CLASS_NAME + ' - End method deletePassagerById');
    }
}