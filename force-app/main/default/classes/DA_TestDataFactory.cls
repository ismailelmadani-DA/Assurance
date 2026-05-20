@isTest
public class DA_TestDataFactory {

    private static Integer counter = 0;

    private static String uniqueSuffix() {
        counter++;
        return String.valueOf(System.currentTimeMillis()) + '_' + counter;
    }

    public static Id getStandardUserProfileId() {
        return [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
    }

    public static User createTestUser(String alias, String lastName, Map<String, Object> params) {
        String suffix = uniqueSuffix();
        User u = new User(
            Alias             = alias.left(8),
            Email             = 'u' + suffix + '@test.example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles',
            Username          = 'u' + suffix + '@test.assurance.factory',
            ProfileId         = getStandardUserProfileId()
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                u.put(fieldName, params.get(fieldName));
            }
        }
        return u;
    }

    public static Account createTestAccount(Map<String, Object> params) {
        Account acc = new Account(
            Name = 'TestAccount_' + uniqueSuffix()
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                acc.put(fieldName, params.get(fieldName));
            }
        }
        return acc;
    }

    public static InsurancePolicy__c createTestPolicy(Id accountId, Map<String, Object> params) {
        String suffix = uniqueSuffix();
        InsurancePolicy__c pol = new InsurancePolicy__c(
            Name               = 'POL_' + suffix,
            PolicyNumber__c    = 'POL_' + suffix,
            PolicyCategory__c  = 'Individuelle',
            DateEffet__c       = Date.today(),
            DateExpiration__c  = Date.today().addYears(1),
            Canal__c           = 'Agent',
            Status__c          = 'Initiale',
            SituationPolice__c = 'En cours',
            AccountName__c     = accountId
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                pol.put(fieldName, params.get(fieldName));
            }
        }
        return pol;
    }

    public static Vehicule__c createTestVehicle(Id policyId, Map<String, Object> params) {
        String suffix = uniqueSuffix();
        Vehicule__c veh = new Vehicule__c(
            RegistrationNumber__c      = 'AA' + suffix.right(6),
            ChassisNumber__c           = 'CH' + suffix,
            AttestationNumber__c       = 'AT' + suffix,
            DateOfFirstRegistration__c = Date.today().addYears(-2),
            InsurancePolicy__c         = policyId
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                veh.put(fieldName, params.get(fieldName));
            }
        }
        return veh;
    }

    public static Case createTestCase(Id accountId, Id policyId, String subject, Map<String, Object> params) {
        Case c = new Case(
            Subject     = subject,
            Origin      = 'Web',
            AccountId   = accountId,
            Police__c   = policyId
           
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                c.put(fieldName, params.get(fieldName));
            }
        }
        return c;
    }

    public static Claim__c createTestClaim(Id caseId, Map<String, Object> params) {
        Claim__c claim = new Claim__c(
            Case__c     = caseId
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                claim.put(fieldName, params.get(fieldName));
            }
        }
        return claim;
    }

    public static Passager__c createTestPassenger(Id caseId, Id accountId, Id vehiculeId, Map<String, Object> params) {
        Passager__c p = new Passager__c(
            Case__c     = caseId,
            Compte__c   = accountId,
            Vehicule__c = vehiculeId,
            Roles__c    = 'Passager assuré',
            CIN__c      = 'CIN' + uniqueSuffix()
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                p.put(fieldName, params.get(fieldName));
            }
        }
        return p;
    }

    public static RequestApproval__c createTestRequestApproval(Id claimId, Id submitterId, Id approverId, Map<String, Object> params) {
        RequestApproval__c r = new RequestApproval__c(
            Status__c          = 'En attente d\'approbation',
            TypeApprobation__c = 'Flag du sinistre',
            Commentaire__c     = 'Test',
            Sinistre__c        = claimId,
            Submitter__c       = submitterId,
            NextApprover__c    = approverId
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                r.put(fieldName, params.get(fieldName));
            }
        }
        return r;
    }

    public static InsurancePolicyCoverage__c createTestInsurancePolicyCoverage(Id policyId, Map<String, Object> params) {
        String suffix = uniqueSuffix();
        InsurancePolicyCoverage__c cov = new InsurancePolicyCoverage__c(
            InsurancePolicy__c = policyId,
            CodeGarantie__c    = 'GAR_' + suffix,
            NomDeLaGarantie__c = 'Test Garantie ' + suffix,
            TypeGarantie__c    = 'Matérielle',
            GarantieUsed__c    = false
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                cov.put(fieldName, params.get(fieldName));
            }
        }
        return cov;
    }

    public static ClaimCoverage__c createTestClaimCoverage(Id claimId, Id policyCoverageId, Map<String, Object> params) {
        ClaimCoverage__c cov = new ClaimCoverage__c(
            Claim__c                     = claimId,
            Insurance_Policy_Coverage__c = policyCoverageId,
            CodeGarantie__c              = 'GAR_TEST',
            NatureEvaluation__c          = 'Indemnité principale',
            EvaluationActuelle__c        = 1000,
            TypeEvaluation__c            = 'Evaluation Matérielle'
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                cov.put(fieldName, params.get(fieldName));
            }
        }
        return cov;
    }

    public static CaseCoverage__c createTestCaseCoverage(Id caseId, Id policyCoverageId, Map<String, Object> params) {
        CaseCoverage__c cov = new CaseCoverage__c(
            Case__c                      = caseId,
            Insurance_Policy_Coverage__c = policyCoverageId,
            CodeGarantie__c              = 'GAR_TEST',
            NatureEvaluation__c          = 'Matériel',
            EvaluationActuelle__c        = 1000,
            TypeEvaluation__c            = 'Provision'
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                cov.put(fieldName, params.get(fieldName));
            }
        }
        return cov;
    }

    public static ClaimParticipant__c createTestClaimParticipant(Id claimId, Id accountId, Map<String, Object> params) {
        ClaimParticipant__c p = new ClaimParticipant__c(
            Claim__c              = claimId,
            ParticipantAccount__c = accountId,
            Roles__c              = 'Passager assuré',
            Civilite__c           = 'Mr',
            StateOfPerson__c      = 'Indemne',
            isDriver__c           = false
        );
        if (params != null) {
            for (String fieldName : params.keySet()) {
                p.put(fieldName, params.get(fieldName));
            }
        }
        return p;
    }
}
