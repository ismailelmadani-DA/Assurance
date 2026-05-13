public with sharing class DA_InsurancePolicyCoverageController {

    private static final String RC_CODE = '001';
    private static final String FIELDS =
        'Id, Name, CodeGarantie__c, NomDeLaGarantie__c, TypeGarantie__c, GarantieUsed__c, InsurancePolicy__c';

    @AuraEnabled(cacheable=false)
    public static List<InsurancePolicyCoverage__c> getCoverages(Id policyId) {
        try {
            List<InsurancePolicyCoverage__c> all = DM008_InsurancePolicyCoverage.getByPolicyId(FIELDS, policyId);
            List<InsurancePolicyCoverage__c> used = new List<InsurancePolicyCoverage__c>();
            for (InsurancePolicyCoverage__c c : all) {
                if (c.GarantieUsed__c == true) used.add(c);
            }
            return used;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors du chargement des garanties : ' + e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getCoveragesCatalog(Id policyId) {
        try {
            List<GarantieAssurance__mdt> mdtList = DM010_GarantieAssurance.getActive();

            Map<String, InsurancePolicyCoverage__c> existingByCode = new Map<String, InsurancePolicyCoverage__c>();
            if (policyId != null) {
                List<InsurancePolicyCoverage__c> existing = DM008_InsurancePolicyCoverage.getByPolicyId(
                    'Id, CodeGarantie__c, NomDeLaGarantie__c, TypeGarantie__c, GarantieUsed__c, InsurancePolicy__c',
                    policyId
                );
                for (InsurancePolicyCoverage__c c : existing) {
                    if (c.CodeGarantie__c != null) existingByCode.put(c.CodeGarantie__c, c);
                }
            }

            Map<String, Object> rcEntry = null;
            List<Map<String, Object>> selected = new List<Map<String, Object>>();
            List<Map<String, Object>> unselected = new List<Map<String, Object>>();
            for (GarantieAssurance__mdt g : mdtList) {
                InsurancePolicyCoverage__c match = existingByCode.get(g.CodeGarantie__c);
                Boolean isUsed = (match != null && match.GarantieUsed__c == true) || g.CodeGarantie__c == RC_CODE;
                Map<String, Object> entry = new Map<String, Object>{
                    'Id'                  => match != null ? (Object) match.Id : (Object) g.CodeGarantie__c,
                    'CodeGarantie__c'     => g.CodeGarantie__c,
                    'NomDeLaGarantie__c'  => g.MasterLabel,
                    'TypeGarantie__c'     => g.TypeGarantie__c,
                    'GarantieUsed__c'     => isUsed
                };
                if (g.CodeGarantie__c == RC_CODE) {
                    rcEntry = entry;
                } else if (isUsed) {
                    selected.add(entry);
                } else {
                    unselected.add(entry);
                }
            }

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            if (rcEntry != null) result.add(rcEntry);
            result.addAll(selected);
            result.addAll(unselected);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors du chargement des garanties : ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static void saveCoverages(Id policyId, List<String> selectedCodes) {
        try {
            if (policyId == null) return;

            Map<String, GarantieAssurance__mdt> mdtByCode = DM010_GarantieAssurance.getActiveByCode();

            Map<String, InsurancePolicyCoverage__c> existingByCode = new Map<String, InsurancePolicyCoverage__c>();
            for (InsurancePolicyCoverage__c c : DM008_InsurancePolicyCoverage.getByPolicyId(
                'Id, CodeGarantie__c, GarantieUsed__c', policyId
            )) {
                if (c.CodeGarantie__c != null) existingByCode.put(c.CodeGarantie__c, c);
            }

            Set<String> selectedSet = new Set<String>(selectedCodes == null ? new List<String>() : selectedCodes);
            selectedSet.add(RC_CODE);

            List<InsurancePolicyCoverage__c> toUpdate = new List<InsurancePolicyCoverage__c>();
            List<InsurancePolicyCoverage__c> toInsert = new List<InsurancePolicyCoverage__c>();

            for (String code : mdtByCode.keySet()) {
                Boolean shouldBeChecked = selectedSet.contains(code);
                InsurancePolicyCoverage__c rec = existingByCode.get(code);
                if (rec == null) {
                    if (shouldBeChecked) {
                        GarantieAssurance__mdt g = mdtByCode.get(code);
                        toInsert.add(new InsurancePolicyCoverage__c(
                            InsurancePolicy__c = policyId,
                            CodeGarantie__c    = code,
                            NomDeLaGarantie__c = g.MasterLabel,
                            TypeGarantie__c    = g.TypeGarantie__c,
                            GarantieUsed__c    = true
                        ));
                    }
                } else if (rec.GarantieUsed__c != shouldBeChecked) {
                    rec.GarantieUsed__c = shouldBeChecked;
                    toUpdate.add(rec);
                }
            }

            if (!toUpdate.isEmpty()) EM008_InsurancePolicyCoverage.updateCoverages(toUpdate);
            if (!toInsert.isEmpty()) insert toInsert;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la sauvegarde des garanties : ' + e.getMessage()
            );
        }
    }
}