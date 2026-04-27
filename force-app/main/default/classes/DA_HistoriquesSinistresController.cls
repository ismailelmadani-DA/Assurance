public with sharing class DA_HistoriquesSinistresController {

    private static final String FIELDS =
        'Id, Claim__c, Claim__r.Name, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Roles__c, StateOfPerson__c';

    @AuraEnabled(cacheable=true)
    public static List<ClaimParticipant__c> getHistoriques(Id accountId) {
        return DM005_ClaimParticipant.getByAccountId(FIELDS, accountId);
    }
}
