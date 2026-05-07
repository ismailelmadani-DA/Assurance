public with sharing class DA_InsurancePolicyCoverageController {

    private static final String FIELDS =
        'Id, Name, CodeGarantie__c, NomDeLaGarantie__c, TypeGarantie__c, GarantieUsed__c, InsurancePolicy__c';

    @AuraEnabled(cacheable=false)
    public static List<InsurancePolicyCoverage__c> getCoverages(Id policyId) {
        try {
            return DM008_InsurancePolicyCoverage.getByPolicyId(FIELDS, policyId);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors du chargement des garanties : ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static void saveCoverages(Id policyId, List<Id> selectedIds) {
        try {
            List<InsurancePolicyCoverage__c> allCoverages = DM008_InsurancePolicyCoverage.getByPolicyId(
                'Id, CodeGarantie__c, GarantieUsed__c', policyId
            );

            Set<Id> selectedSet = new Set<Id>(selectedIds);
            List<InsurancePolicyCoverage__c> toUpdate = new List<InsurancePolicyCoverage__c>();

            for (InsurancePolicyCoverage__c cov : allCoverages) {
                Boolean shouldBeChecked = selectedSet.contains(cov.Id)
                    || cov.CodeGarantie__c == '001';

                if (cov.GarantieUsed__c != shouldBeChecked) {
                    cov.GarantieUsed__c = shouldBeChecked;
                    toUpdate.add(cov);
                }
            }

            EM008_InsurancePolicyCoverage.updateCoverages(toUpdate);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la sauvegarde des garanties : ' + e.getMessage()
            );
        }
    }
}