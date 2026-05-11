public with sharing class DA_CaseCoverageController {

    @AuraEnabled
    public static void saveCaseCoverages(Id caseId, Id policyId, List<Id> selectedCoverageIds) {
        try {
            List<InsurancePolicyCoverage__c> coverages = DM008_InsurancePolicyCoverage.getByPolicyId(
                'Id, CodeGarantie__c, NomDeLaGarantie__c', policyId
            );

            Set<Id> selectedSet = new Set<Id>(selectedCoverageIds);
            List<CaseCoverage__c> toInsert = new List<CaseCoverage__c>();

            for (InsurancePolicyCoverage__c cov : coverages) {
                if (selectedSet.contains(cov.Id)) {
                    toInsert.add(new CaseCoverage__c(
                        Case__c = caseId,
                        Name = cov.NomDeLaGarantie__c,
                        CodeGarantie__c = cov.CodeGarantie__c
                    ));
                }
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la sauvegarde des garanties : ' + e.getMessage()
            );
        }
    }
}
