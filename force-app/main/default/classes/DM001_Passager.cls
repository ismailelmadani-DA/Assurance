public with sharing class DM001_Passager {

    private static final String CLASS_NAME = DM001_Passager.class.getName();
    private static final String SOBJECT_NAME = 'Passager__c';

    private static final String LIST_FIELDS =
        'Id, Name, Name__c, Civilite__c, CIN__c, Pays__c, Ville__c, TypeContact__c, StateOfPerson__c';

    private static final String DETAIL_FIELDS =
        'Id, Name, Name__c, Civilite__c, CIN__c, BirthDay__c, ' +
        'Pays__c, Ville__c, Adresse__c, StateOfPerson__c, MaritalStatus__c, ' +
        'Roles__c, MoyenNotification__c, Telephone__c, Email__c, ' +
        'Account__c, Compte__c, Case__c, Claim__c';

    // ===== QUERY =====

    public static List<Passager__c> getPassagersByCaseAndRole(Id caseId, String role) {
        System.debug(CLASS_NAME + ' - Start method getPassagersByCaseAndRole');
        String conditions = 'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\''
            + ' AND Roles__c = \'' + String.escapeSingleQuotes(role) + '\'';
        List<Passager__c> result = (List<Passager__c>) DA_Utility.query(LIST_FIELDS, SOBJECT_NAME, conditions, 'Name__c ASC', null);
        System.debug(CLASS_NAME + ' - End method getPassagersByCaseAndRole');
        return result;
    }

    public static List<Passager__c> getPassagersByCaseId(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersByCaseId');
        String conditions = 'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'';
        List<Passager__c> result = (List<Passager__c>) DA_Utility.query(DETAIL_FIELDS, SOBJECT_NAME, conditions, 'CreatedDate DESC', null);
        System.debug(CLASS_NAME + ' - End method getPassagersByCaseId');
        return result;
    }

    public static Passager__c getPassagerById(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method getPassagerById');
        String conditions = 'Id = \'' + String.escapeSingleQuotes(String.valueOf(passagerId)) + '\'';
        List<Passager__c> results = (List<Passager__c>) DA_Utility.query(DETAIL_FIELDS, SOBJECT_NAME, conditions, null, 1);
        System.debug(CLASS_NAME + ' - End method getPassagerById');
        return results.isEmpty() ? null : results[0];
    }

    public static List<Passager__c> getPassagersByCIN(String cin, Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassagersByCIN');
        String conditions = 'CIN__c = \'' + String.escapeSingleQuotes(cin) + '\''
            + ' AND Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'';
        List<Passager__c> result = (List<Passager__c>) DA_Utility.query('Id, CIN__c, Name__c', SOBJECT_NAME, conditions, null, null);
        System.debug(CLASS_NAME + ' - End method getPassagersByCIN');
        return result;
    }

    // ===== DML =====

    public static void insertPassagers(List<Passager__c> passagers) {
        System.debug(CLASS_NAME + ' - Start method insertPassagers');
        insert passagers;
        System.debug(CLASS_NAME + ' - End method insertPassagers');
    }

    public static void updatePassagers(List<Passager__c> passagers) {
        System.debug(CLASS_NAME + ' - Start method updatePassagers');
        update passagers;
        System.debug(CLASS_NAME + ' - End method updatePassagers');
    }

    public static void deletePassagerById(Id passagerId) {
        System.debug(CLASS_NAME + ' - Start method deletePassagerById');
        delete new Passager__c(Id = passagerId);
        System.debug(CLASS_NAME + ' - End method deletePassagerById');
    }

    public static void deletePassagers(List<Passager__c> passagers) {
        System.debug(CLASS_NAME + ' - Start method deletePassagers');
        delete passagers;
        System.debug(CLASS_NAME + ' - End method deletePassagers');
    }
}