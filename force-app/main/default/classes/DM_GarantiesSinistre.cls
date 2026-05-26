public with sharing class DM_GarantiesSinistre {

    private static final String CLAIM_COVERAGE_FIELDS =
        'Id, Name, CodeGarantie__c, Claim__c';

    /**
     * @description : Récupère toutes les garanties actives du MDT
     *                indexées par CodeGarantie__c
     */
    public static List<GarantieAssurance__mdt> getAllGarantiesMetadata() {
        return [
            SELECT MasterLabel, CodeGarantie__c, TypeGarantie__c
            FROM GarantieAssurance__mdt
            WHERE IsActive__c = true
            ORDER BY MasterLabel ASC
        ];
    }

    /**
     * @description : Récupère les garanties touchées depuis ClaimCoverage__c
     *                indexées par CodeGarantie__c
     */
    public static Map<String, ClaimCoverage__c> getClaimCoveragesBySinistre(Id sinistreId) {
        Map<String, ClaimCoverage__c> result = new Map<String, ClaimCoverage__c>();
        List<SObject> records = DA_Utility.query(
            CLAIM_COVERAGE_FIELDS,
            'ClaimCoverage__c',
            'Claim__c = \'' + String.escapeSingleQuotes(String.valueOf(sinistreId)) + '\'',
            null,
            null
        );
        for (SObject s : records) {
            ClaimCoverage__c cc = (ClaimCoverage__c) s;
            if (cc.CodeGarantie__c != null) {
                result.put(cc.CodeGarantie__c, cc);
            }
        }
        return result;
    }
}