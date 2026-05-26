public with sharing class DA_GarantiesSinistreController {

    private static final String RC_CODE = '001';

    /**
     * @description  : Retourne toutes les garanties du MDT
     *                 enrichies avec le flag touchée depuis ClaimCoverage__c
     * @param        : sinistreId
     * @return       : List<Map<String, Object>>
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getGaranties(Id sinistreId) {
        try {
            // 1. Toutes les garanties depuis le MDT
            List<GarantieAssurance__mdt> mdtList =
                DM_GarantiesSinistre.getAllGarantiesMetadata();

            if (mdtList.isEmpty()) {
                return new List<Map<String, Object>>();
            }

            // 2. Garanties touchées depuis ClaimCoverage__c
            Map<String, ClaimCoverage__c> touchedByCode =
                DM_GarantiesSinistre.getClaimCoveragesBySinistre(sinistreId);

            // 3. Construction et tri via EM
            return EM_GarantiesSinistre.build(
                mdtList,
                touchedByCode,
                RC_CODE
            );

        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors du chargement des garanties : ' + e.getMessage()
            );
        }
    }
}