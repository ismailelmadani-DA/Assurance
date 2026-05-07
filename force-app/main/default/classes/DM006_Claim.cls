public with sharing class DM006_Claim {

            private static final String OBJ = 'Claim__c';

            private static final String FIELDS =
                'Id, Name, Flags__c, Case__c, CreatedDate';

            public static Claim__c getById(String fields, Id claimId) {
                String queryFields = String.isNotBlank(fields) ? fields : FIELDS;
                return (Claim__c) DA_Utility.getById(queryFields, OBJ, claimId);
            }

            public static Claim__c getByCase(Id caseId) {
                String safeId = String.escapeSingleQuotes(String.valueOf(caseId));
                List<SObject> results = DA_Utility.query(FIELDS, OBJ, 'Case__c = \'' + safeId + '\'', 'CreatedDate DESC', 1);
                return results.isEmpty() ? null : (Claim__c) results[0];
            }

            public static void updateClaim(Claim__c claim) {
                update claim;
            }
            private static final String FIELDS_COMPACT =
            'Id, Name, Case__c, Case__r.AccountId, Case__r.Account.Name, ' +
            'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
            'PolicyNumber__c, PolicyNumber__r.PolicyNumber__c, ' +
            'DateOfOccurrence__c';

        public static Claim__c getClaimCompact(Id claimId) {
            return (Claim__c) Database.query(
                'SELECT ' + FIELDS_COMPACT +
                ' FROM Claim__c' +
                ' WHERE Id = :claimId' +
                ' LIMIT 1'
            );
        }
        public static List<Schema.FieldSetMember> getCompactFieldSetMembers() {
            Schema.FieldSet fs = Schema.SObjectType.Claim__c
                .fieldSets.getMap()
                .get('Claim_Compact_Layout');
            return fs != null ? fs.getFields() : new List<Schema.FieldSetMember>();
        }
        private static final String FIELDS_BY_POLICY =
        'Id, Name, DateOfOccurrence__c, Status__c, ' +
        'RegistrationNumber__c, ' +
        'Vehicule__c, Vehicule__r.RegistrationNumber__c, ' +
        'Case__c, Case__r.CountryOfOccurrence__c, Case__r.CityOfOccurrence__c, ' +
        'CreatedById, CreatedBy.Name';

    public static List<Claim__c> getClaimsByPolicyId(Id policyId) {
        if (policyId == null) return new List<Claim__c>();

        String safeId    = String.escapeSingleQuotes(String.valueOf(policyId));
        String condition = 'PolicyNumber__c = \'' + safeId + '\'';
        String orderBy   = 'CreatedDate DESC';

        return (List<Claim__c>) DA_Utility.query(FIELDS_BY_POLICY, OBJ, condition, orderBy, null);
    }
        }