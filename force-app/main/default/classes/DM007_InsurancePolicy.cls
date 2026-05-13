// ═══════════════════════════════════════════════════════════════
// DM007_InsurancePolicy — Data Manager (lecture uniquement)
// ═══════════════════════════════════════════════════════════════
public with sharing class DM007_InsurancePolicy {

    // ─────────────────────────────────────────────────────────────
    // Constantes
    // ─────────────────────────────────────────────────────────────

    private static final String OBJECT_POLICY   = 'InsurancePolicy__c';
    private static final String OBJECT_CLAIM    = 'Claim__c';
    private static final String OBJECT_ACCOUNT  = 'Account';
    private static final String OBJECT_VEHICULE = 'Vehicule__c';

    private static final String FIELDS_CLAIM =
        'Id, Name, DateOfOccurrence__c, Status__c, ' +
        'RegistrationNumber__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Case__c, Case__r.CountryOfOccurrence__c, Case__r.CityOfOccurrence__c, ' +
        'CreatedById, CreatedBy.Name';

    private static final String FIELDS_VEHICULE_WITH_POLICY =
        'Id, InsurancePolicy__c, ' +
        'InsurancePolicy__r.PolicyNumber__c, ' +
        'InsurancePolicy__r.SituationPolice__c, ' +
        'InsurancePolicy__r.SituationPrime__c, ' +
        'InsurancePolicy__r.Status__c';

    // ─────────────────────────────────────────────────────────────
    // Claim__c
    // ─────────────────────────────────────────────────────────────

    public static List<Claim__c> getClaimsByPolicyId(Id policyId) {
        if (policyId == null) return new List<Claim__c>();
        String conditions = 'PolicyNumber__c = \'' + String.escapeSingleQuotes(String.valueOf(policyId)) + '\'';
        return (List<Claim__c>) DA_Utility.query(FIELDS_CLAIM, OBJECT_CLAIM, conditions, 'CreatedDate DESC', null);
    }

    // ─────────────────────────────────────────────────────────────
    // Account
    // ─────────────────────────────────────────────────────────────

    public static List<Account> getByCin(String cin) {
        if (String.isBlank(cin)) return new List<Account>();
        String conditions = 'CIN__c = \'' + String.escapeSingleQuotes(cin.trim()) + '\'';
        return (List<Account>) DA_Utility.query('Id, Name', OBJECT_ACCOUNT, conditions, null, 1);
    }

    // ─────────────────────────────────────────────────────────────
    // Vehicule__c
    // ─────────────────────────────────────────────────────────────

    public static List<Vehicule__c> getByImmatriculation(String immatriculation) {
        if (String.isBlank(immatriculation)) return new List<Vehicule__c>();
        String conditions =
            'RegistrationNumber__c = \'' + String.escapeSingleQuotes(immatriculation.trim()) + '\'' +
            ' AND InsurancePolicy__c != null';
        return (List<Vehicule__c>) DA_Utility.query(
            FIELDS_VEHICULE_WITH_POLICY, OBJECT_VEHICULE, conditions, 'CreatedDate DESC', 1
        );
    }

    // ─────────────────────────────────────────────────────────────
    // Picklists — InsurancePolicy__c
    // ─────────────────────────────────────────────────────────────

    public static List<Map<String, String>> getCategorieOptions() {
        return DA_Utility.getPicklistValues(OBJECT_POLICY, 'PolicyCategory__c');
    }

    public static List<Map<String, String>> getCanalOptions() {
        return DA_Utility.getPicklistValues(OBJECT_POLICY, 'Canal__c');
    }

    public static List<Map<String, String>> getSituationPoliceOptions() {
        return DA_Utility.getPicklistValues(OBJECT_POLICY, 'SituationPolice__c');
    }

    public static List<Map<String, String>> getSituationPrimeOptions() {
        return DA_Utility.getPicklistValues(OBJECT_POLICY, 'SituationPrime__c');
    }

    // ─────────────────────────────────────────────────────────────
    // Picklists — Account
    // ─────────────────────────────────────────────────────────────

    public static List<Map<String, String>> getPaysOptions() {
        return DA_Utility.getPicklistValues(OBJECT_ACCOUNT, 'Pays__c');
    }

    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        result.put('Maroc', DA_Utility.getPicklistValues(OBJECT_ACCOUNT, 'Ville__c'));
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // Picklists — Vehicule__c
    // ─────────────────────────────────────────────────────────────

    public static List<Map<String, String>> getTypeVehiculeOptions() {
        return DA_Utility.getPicklistValues(OBJECT_VEHICULE, 'TypeVehicule__c');
    }

    public static List<Map<String, String>> getMarqueOptions() {
        return DA_Utility.getPicklistValues(OBJECT_VEHICULE, 'Brand__c');
    }

    public static Map<String, List<Map<String, String>>> getDependentModeleOptions() {
        return DA_Utility.getDependentPicklistValues(OBJECT_VEHICULE, 'Brand__c', 'ModelePicklist__c');
    }

  // ─────────────────────────────────────────────────────────────
// InsurancePolicy__c — Numéro de police
// ─────────────────────────────────────────────────────────────

public static String getNextNumeroPolice() {
    List<AggregateResult> agg = (List<AggregateResult>) DA_Utility.query(
        'MAX(PolicyNumber__c) maxNum',
        'InsurancePolicy__c',
        'PolicyNumber__c LIKE \'P-%\'',
        null,
        null
    );

    if (agg.isEmpty() || agg[0].get('maxNum') == null) return 'P-00001';

    String lastName = (String) agg[0].get('maxNum');
    String numPart  = lastName.substringAfter('P-');

    if (!numPart.isNumeric()) return 'P-00001';

    Integer num = Integer.valueOf(numPart);
    return 'P-' + String.valueOf(num + 1).leftPad(5, '0');
}

   // ─────────────────────────────────────────────────────────────
// Custom Metadata — GarantieAssurance__mdt
// ─────────────────────────────────────────────────────────────

public static List<Map<String, String>> getGarantiesMetadata() {
    List<Map<String, String>> results = new List<Map<String, String>>();

    List<GarantieAssurance__mdt> garanties = (List<GarantieAssurance__mdt>) DA_Utility.query(
        'Id, MasterLabel, CodeGarantie__c, TypeGarantie__c',
        'GarantieAssurance__mdt',
        'IsActive__c = true',
        'MasterLabel ASC',
        null
    );

    for (GarantieAssurance__mdt g : garanties) {
        results.add(new Map<String, String>{
            'id'   => g.Id,
            'nom'  => g.MasterLabel,
            'code' => g.CodeGarantie__c,
            'type' => g.TypeGarantie__c
        });
    }

    return results;
}
}