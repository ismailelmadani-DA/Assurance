public with sharing class DM007_InsurancePolicy {

    private static final String OBJECT_NAME = 'Claim__c';
    private static final String FIELDS =
        'Id, Name, DateOfOccurrence__c, Status__c, ' +
        'RegistrationNumber__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Case__c, Case__r.CountryOfOccurrence__c, Case__r.CityOfOccurrence__c, ' +
        'CreatedById, CreatedBy.Name';

    /**
     * @description  : Récupère la liste des sinistres (Claim__c) liés à une police d'assurance
     * @param        : policyId => Id de la police (InsurancePolicy)
     * @return       : List<Claim__c>
     */
    public static List<Claim__c> getClaimsByPolicyId(Id policyId) {
        if (policyId == null) return new List<Claim__c>();

        String safeId = String.escapeSingleQuotes(String.valueOf(policyId));
        String conditions = 'PolicyNumber__c = \'' + safeId + '\'';
        String orderBy    = 'CreatedDate DESC';

        return (List<Claim__c>) DA_Utility.query(FIELDS, OBJECT_NAME, conditions, orderBy, null);
    }
}