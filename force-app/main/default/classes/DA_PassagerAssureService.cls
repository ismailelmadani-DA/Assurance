public with sharing class DA_PassagerAssureService {

    private static final String CLASS_NAME = DA_PassagerAssureService.class.getName();
    private static final String INSURED_PASSENGER_ROLE = 'Passager assuré';

    public static List<Passager__c> getPassengers(Id caseId) {
        System.debug(CLASS_NAME + ' - Start method getPassengers');
        if (caseId == null) {
            throw new AuraHandledException('L\'identifiant du dossier est requis.');
        }
        List<Passager__c> result = DM001_Passager.getPassagersByCaseAndRole(caseId, INSURED_PASSENGER_ROLE);
        System.debug(CLASS_NAME + ' - End method getPassengers');
        return result;
    }
}