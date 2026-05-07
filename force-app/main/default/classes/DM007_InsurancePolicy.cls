// ═══════════════════════════════════════════════════════════════
// DM007_InsurancePolicy — Data Manager (lecture uniquement)
// ═══════════════════════════════════════════════════════════════
public with sharing class DM007_InsurancePolicy {

    private static final String OBJECT_NAME        = 'InsurancePolicy__c';
    private static final String OBJECT_NAME_CLAIM  = 'Claim__c';

    private static final String FIELDS_CLAIM =
        'Id, Name, DateOfOccurrence__c, Status__c, ' +
        'RegistrationNumber__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Case__c, Case__r.CountryOfOccurrence__c, Case__r.CityOfOccurrence__c, ' +
        'CreatedById, CreatedBy.Name';

    // ─────────────────────────────────────────────────────────────
    // Méthode existante (corrigée : OBJECT_NAME_CLAIM)
    // ─────────────────────────────────────────────────────────────

    /**
     * @description  : Récupère les sinistres liés à une police
     * @param        : policyId => Id de la police
     * @return       : List<Claim__c>
     */
    public static List<Claim__c> getClaimsByPolicyId(Id policyId) {
        if (policyId == null) return new List<Claim__c>();
        String safeId    = String.escapeSingleQuotes(String.valueOf(policyId));
        String conditions = 'PolicyNumber__c = \'' + safeId + '\'';
        String orderBy    = 'CreatedDate DESC';
        return (List<Claim__c>) DA_Utility.query(FIELDS_CLAIM, OBJECT_NAME_CLAIM, conditions, orderBy, null);
    }

    // ─────────────────────────────────────────────────────────────
    // Nouvelles méthodes pour DA_lwc022_PoliceCreationController
    // ─────────────────────────────────────────────────────────────

    /**
     * @description  : Vérifie si un Account existe par CIN
     * @param        : cin => numéro CIN de l'assuré
     * @return       : List<Account>
     */
    public static List<Account> getByCin(String cin) {
        if (String.isBlank(cin)) return new List<Account>();
        String safeCin    = String.escapeSingleQuotes(cin.trim());
        String conditions = 'CIN__c = \'' + safeCin + '\'';
        return (List<Account>) DA_Utility.query('Id', 'Account', conditions, null, 1);
    }

    /**
     * @description  : Récupère un véhicule avec sa police liée par immatriculation
     * @param        : immatriculation => numéro d'immatriculation
     * @return       : List<Vehicule__c>
     */
    public static List<Vehicule__c> getByImmatriculation(String immatriculation) {
        if (String.isBlank(immatriculation)) return new List<Vehicule__c>();
        String safeImmat  = String.escapeSingleQuotes(immatriculation.trim());
        String fields     =
            'Id, InsurancePolicy__c, ' +
            'InsurancePolicy__r.PolicyNumber__c, ' +
            'InsurancePolicy__r.SituationPolice__c, ' +
            'InsurancePolicy__r.SituationPrime__c, ' +
            'InsurancePolicy__r.Status__c';
        String conditions =
            'RegistrationNumber__c = \'' + safeImmat + '\'' +
            ' AND InsurancePolicy__c != null';
        String orderBy    = 'CreatedDate DESC';
        return (List<Vehicule__c>) DA_Utility.query(fields, 'Vehicule__c', conditions, orderBy, 1);
    }
}