public with sharing class PassagerController {
    private static final String INSURED_PASSENGER_ROLE = 'Passager assuré';
    // ─────────────────────────────────────────────────────────
    // Récupérer la liste des passagers assurés d'un dossier
    // ─────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Passager__c> getPassengers(Id caseId) {
        return DM001_Passager.getPassengersByCase(caseId, INSURED_PASSENGER_ROLE);
    }
}