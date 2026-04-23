public with sharing class DM001_Passager {

    private static final String PASSENGER_OBJECT = 'Passager__c';

    private static final String PASSENGER_LIST_FIELDS =
        'Id, Civilite__c, Name, Name__c, CIN__c, Pays__c, Ville__c, ' +
        'StateOfPerson__c, isDriver__c, TypeContact__c, Compte__c, Compte__r.Name';

    // Champs étendus pour les passagers adverses (cas sinistre)
    private static final String PASSENGER_ADVERSE_FIELDS =
        'Id, Name, Civilite__c, CIN__c, Sexe__c, ' +
        'Pays__c, Ville__c, StateOfPerson__c, ' +
        'isDriver__c, Passager_mineurisMinorPassenger__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Roles__c, Case__c';

    private static final String ROLE_ADVERSE = 'Passager adverse';

    public static List<Passager__c> getPassengersByCase(Id caseId, String role) {
        String conditions =
            'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'' +
            ' AND Roles__c = \'' + String.escapeSingleQuotes(role) + '\'';

        List<SObject> records = DA_Utility.query(
            PASSENGER_LIST_FIELDS,
            PASSENGER_OBJECT,
            conditions,
            'CreatedDate DESC',
            null
        );

        List<Passager__c> passengers = new List<Passager__c>();
        for (SObject record : records) {
            passengers.add((Passager__c) record);
        }
        return passengers;
    }

    public static List<Passager__c> getPassagersByCaseAndRole(Id caseId, String role) {
        return getPassengersByCase(caseId, role);
    }

    public static List<Passager__c> getPassagersByCIN(String cin, Id caseId) {
        String conditions =
            'CIN__c = \'' + String.escapeSingleQuotes(cin) + '\'' +
            ' AND Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'';

        List<SObject> records = DA_Utility.query(
            PASSENGER_LIST_FIELDS,
            PASSENGER_OBJECT,
            conditions,
            null,
            null
        );

        List<Passager__c> passengers = new List<Passager__c>();
        for (SObject record : records) {
            passengers.add((Passager__c) record);
        }
        return passengers;
    }

    // Nouvelle méthode — champs complets pour le contexte sinistre/case
    public static List<Passager__c> getPassagersAdversesByCase(Id caseId) {
        String conditions =
            'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\'' +
            ' AND Roles__c = \'' + ROLE_ADVERSE + '\'';

        List<SObject> records = DA_Utility.query(
            PASSENGER_ADVERSE_FIELDS,
            PASSENGER_OBJECT,
            conditions,
            'CreatedDate DESC',
            null
        );

        List<Passager__c> passengers = new List<Passager__c>();
        for (SObject record : records) {
            passengers.add((Passager__c) record);
        }
        return passengers;
    }
}