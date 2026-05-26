public with sharing class DA_ClaimCoverageController {

    private static final String RC_CODE = '001';

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getClaimCoveragesCatalog(Id claimId) {
        try {
            if (claimId == null) return new List<Map<String, Object>>();

            Claim__c claim = DM006_Claim.getById('Id, PolicyNumber__c', claimId);
            Id policyId = claim == null ? null : claim.PolicyNumber__c;

            List<InsurancePolicyCoverage__c> policyCoverages = new List<InsurancePolicyCoverage__c>();
            if (policyId != null) {
                policyCoverages = DM008_InsurancePolicyCoverage.getByPolicyId(
                    'Id, CodeGarantie__c, NomDeLaGarantie__c, TypeGarantie__c, GarantieUsed__c',
                    policyId
                );
            }

            Map<String, ClaimCoverage__c> existingByCode = new Map<String, ClaimCoverage__c>();
            for (ClaimCoverage__c c : DM011_ClaimCoverage.getByClaimId(
                'Id, Name, CodeGarantie__c, Insurance_Policy_Coverage__c', claimId
            )) {
                if (c.CodeGarantie__c != null) existingByCode.put(c.CodeGarantie__c, c);
            }

            Map<String, Object> rcEntry = null;
            List<Map<String, Object>> selected = new List<Map<String, Object>>();
            List<Map<String, Object>> unselected = new List<Map<String, Object>>();
            for (InsurancePolicyCoverage__c pc : policyCoverages) {
                if (pc.GarantieUsed__c != true) continue;
                ClaimCoverage__c match = existingByCode.get(pc.CodeGarantie__c);
                Boolean isUsed = match != null || pc.CodeGarantie__c == RC_CODE;
                Map<String, Object> entry = new Map<String, Object>{
                    'Id'                 => match != null ? (Object) match.Id : (Object) pc.CodeGarantie__c,
                    'CodeGarantie__c'    => pc.CodeGarantie__c,
                    'NomDeLaGarantie__c' => pc.NomDeLaGarantie__c,
                    'TypeGarantie__c'    => pc.TypeGarantie__c,
                    'GarantieUsed__c'    => isUsed
                };
                if (pc.CodeGarantie__c == RC_CODE) {
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
    public static void saveClaimCoverages(Id claimId, List<String> selectedCodes) {
        try {
            if (claimId == null) return;

            Claim__c claim = DM006_Claim.getById('Id, PolicyNumber__c', claimId);
            Id policyId = claim == null ? null : claim.PolicyNumber__c;

            Map<String, InsurancePolicyCoverage__c> policyByCode = new Map<String, InsurancePolicyCoverage__c>();
            if (policyId != null) {
                for (InsurancePolicyCoverage__c pc : DM008_InsurancePolicyCoverage.getByPolicyId(
                    'Id, CodeGarantie__c, NomDeLaGarantie__c, GarantieUsed__c', policyId
                )) {
                    if (pc.GarantieUsed__c == true && pc.CodeGarantie__c != null) {
                        policyByCode.put(pc.CodeGarantie__c, pc);
                    }
                }
            }

            Map<String, ClaimCoverage__c> existingByCode = new Map<String, ClaimCoverage__c>();
            for (ClaimCoverage__c c : DM011_ClaimCoverage.getByClaimId('Id, CodeGarantie__c', claimId)) {
                if (c.CodeGarantie__c != null) existingByCode.put(c.CodeGarantie__c, c);
            }

            Set<String> selectedSet = new Set<String>(selectedCodes == null ? new List<String>() : selectedCodes);
            if (policyByCode.containsKey(RC_CODE)) selectedSet.add(RC_CODE);

            List<ClaimCoverage__c> toInsert = new List<ClaimCoverage__c>();
            List<ClaimCoverage__c> toDelete = new List<ClaimCoverage__c>();

            for (String code : policyByCode.keySet()) {
                Boolean shouldBeChecked = selectedSet.contains(code);
                ClaimCoverage__c rec = existingByCode.get(code);
                if (rec == null && shouldBeChecked) {
                    InsurancePolicyCoverage__c pc = policyByCode.get(code);
                    toInsert.add(new ClaimCoverage__c(
                        Claim__c                     = claimId,
                        Name                         = pc.NomDeLaGarantie__c,
                        CodeGarantie__c              = code,
                        Insurance_Policy_Coverage__c = pc.Id
                    ));
                } else if (rec != null && !shouldBeChecked) {
                    toDelete.add(rec);
                }
            }

            EM010_ClaimCoverage.deleteCoverages(toDelete);
            EM010_ClaimCoverage.insertCoverages(toInsert);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Erreur lors de la sauvegarde des garanties : ' + e.getMessage()
            );
        }
    }
}