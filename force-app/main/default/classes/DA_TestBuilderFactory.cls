/**
 * @description       : Builder de données de test utilisant le pattern Builder/Fluent pour chaîner la création de jeux de données complexes (utilisateurs, comptes, polices, véhicules, cases, sinistres, passagers, demandes d'approbation) via DA_TestDataFactory. Chaque méthode withXxx loop, construit une liste locale, fait un bulk insert, puis l'ajoute à la collection interne accessible via getXxx().
 * @author            : D&A Technologies
 * @group             : Utilities
 * @last modified on  : 20-05-2026
 * @last modified by  : D&A Technologies
 **/
@isTest
public class DA_TestBuilderFactory {

    // ============================================================
    // COLLECTIONS PAR TYPE D'OBJET
    // ============================================================

    private List<User> users = new List<User>();
    private List<Account> accounts = new List<Account>();
    private List<InsurancePolicy__c> policies = new List<InsurancePolicy__c>();
    private List<Vehicule__c> vehicles = new List<Vehicule__c>();
    private List<Case> cases = new List<Case>();
    private List<Claim__c> claims = new List<Claim__c>();
    private List<Passager__c> passengers = new List<Passager__c>();
    private List<RequestApproval__c> requestApprovals = new List<RequestApproval__c>();
    private List<InsurancePolicyCoverage__c> insurancePolicyCoverages = new List<InsurancePolicyCoverage__c>();
    private List<ClaimCoverage__c> claimCoverages = new List<ClaimCoverage__c>();
    private List<CaseCoverage__c> caseCoverages = new List<CaseCoverage__c>();
    private List<ClaimParticipant__c> claimParticipants = new List<ClaimParticipant__c>();

    private Map<String, User> usersByAlias = new Map<String, User>();
    private Map<String, Claim__c> claimsByKey = new Map<String, Claim__c>();

    // ============================================================
    // CONSTRUCTEUR
    // ============================================================

    public DA_TestBuilderFactory() {
    }

    // ============================================================
    // HELPER STATIQUE — INSERTION BULK
    // ============================================================

    public static void insertAll(List<SObject> records) {
        insert records;
    }

    // ============================================================
    // BUILDER METHODS — USERS
    // ============================================================

    public DA_TestBuilderFactory withCustomUsers(Integer count, String alias, String lastName, Map<String, Object> params) {
        List<User> newUsers = new List<User>();
        for (Integer i = 0; i < count; i++) {
            String a = count == 1 ? alias : alias + (i + 1);
            newUsers.add(DA_TestDataFactory.createTestUser(a, lastName, params));
        }
        insert newUsers;
        users.addAll(newUsers);
        for (User u : newUsers) {
            usersByAlias.put(u.Alias, u);
        }
        return this;
    }

    public DA_TestBuilderFactory withUser(String alias, String lastName) {
        return withCustomUsers(1, alias, lastName, null);
    }

    public DA_TestBuilderFactory withUserAndManager(String alias, String lastName, String managerAlias) {
        User mgr = usersByAlias.get(managerAlias);
        return withCustomUsers(1, alias, lastName, new Map<String, Object>{
            'ManagerId' => mgr.Id
        });
    }

    // ============================================================
    // BUILDER METHODS — ACCOUNTS
    // ============================================================

    public DA_TestBuilderFactory withCustomAccounts(Integer count, Map<String, Object> params) {
        List<Account> newAccounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            newAccounts.add(DA_TestDataFactory.createTestAccount(params));
        }
        insert newAccounts;
        accounts.addAll(newAccounts);
        return this;
    }

    public DA_TestBuilderFactory withAccount() {
        return withCustomAccounts(1, null);
    }

    // ============================================================
    // BUILDER METHODS — POLICIES
    // ============================================================

    public DA_TestBuilderFactory withCustomPolicies(Integer count, Id accountId, Map<String, Object> params) {
        List<InsurancePolicy__c> newPolicies = new List<InsurancePolicy__c>();
        for (Integer i = 0; i < count; i++) {
            newPolicies.add(DA_TestDataFactory.createTestPolicy(accountId, params));
        }
        insert newPolicies;
        policies.addAll(newPolicies);
        return this;
    }

    public DA_TestBuilderFactory withPolicy() {
        return withCustomPolicies(1, accounts[accounts.size() - 1].Id, null);
    }

    // ============================================================
    // BUILDER METHODS — VEHICLES
    // ============================================================

    public DA_TestBuilderFactory withCustomVehicles(Integer count, Id policyId, Map<String, Object> params) {
        List<Vehicule__c> newVehicles = new List<Vehicule__c>();
        for (Integer i = 0; i < count; i++) {
            newVehicles.add(DA_TestDataFactory.createTestVehicle(policyId, params));
        }
        insert newVehicles;
        vehicles.addAll(newVehicles);
        return this;
    }

    public DA_TestBuilderFactory withVehicle() {
        return withCustomVehicles(1, policies[policies.size() - 1].Id, null);
    }

    // ============================================================
    // BUILDER METHODS — CASES
    // ============================================================

    public DA_TestBuilderFactory withCases(Integer count, Id accountId, Id policyId, String subject, Map<String, Object> params) {
        List<Case> newCases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            String subj = count == 1 ? subject : subject + ' ' + (i + 1);
            newCases.add(DA_TestDataFactory.createTestCase(accountId, policyId,subj, params));
        }
        insert newCases;
        cases.addAll(newCases);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — CLAIMS
    // ============================================================

    public DA_TestBuilderFactory withClaims(Integer count, Id caseId, Map<String, Object> params) {
        List<Claim__c> newClaims = new List<Claim__c>();
        for (Integer i = 0; i < count; i++) {
            newClaims.add(DA_TestDataFactory.createTestClaim(caseId, params));
        }
        insert newClaims;
        claims.addAll(newClaims);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — PASSENGERS
    // ============================================================

    public DA_TestBuilderFactory withPassengers(Integer count, Id caseId, Id accountId, Map<String, Object> params) {
        List<Passager__c> newPassengers = new List<Passager__c>();
        for (Integer i = 0; i < count; i++) {
            newPassengers.add(DA_TestDataFactory.createTestPassenger(caseId, accountId, params));
        }
        insert newPassengers;
        passengers.addAll(newPassengers);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — REQUEST APPROVALS
    // ============================================================

    public DA_TestBuilderFactory withRequestApprovals(Integer count, Id claimId, Id submitterId, Id approverId, Map<String, Object> params) {
        List<RequestApproval__c> newRequests = new List<RequestApproval__c>();
        for (Integer i = 0; i < count; i++) {
            newRequests.add(DA_TestDataFactory.createTestRequestApproval(claimId, submitterId, approverId, params));
        }
        insert newRequests;
        requestApprovals.addAll(newRequests);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — INSURANCE POLICY COVERAGES (GARANTIES)
    // ============================================================

    public DA_TestBuilderFactory withInsurancePolicyCoverages(Integer count, Id policyId, Map<String, Object> params) {
        List<InsurancePolicyCoverage__c> newCovs = new List<InsurancePolicyCoverage__c>();
        for (Integer i = 0; i < count; i++) {
            newCovs.add(DA_TestDataFactory.createTestInsurancePolicyCoverage(policyId, params));
        }
        insert newCovs;
        insurancePolicyCoverages.addAll(newCovs);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — CLAIM COVERAGES
    // ============================================================

    public DA_TestBuilderFactory withClaimCoverages(Integer count, Id claimId, Id policyCoverageId, Map<String, Object> params) {
        List<ClaimCoverage__c> newCovs = new List<ClaimCoverage__c>();
        for (Integer i = 0; i < count; i++) {
            newCovs.add(DA_TestDataFactory.createTestClaimCoverage(claimId, policyCoverageId, params));
        }
        insert newCovs;
        claimCoverages.addAll(newCovs);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — CASE COVERAGES
    // ============================================================

    public DA_TestBuilderFactory withCaseCoverages(Integer count, Id caseId, Id policyCoverageId, Map<String, Object> params) {
        List<CaseCoverage__c> newCovs = new List<CaseCoverage__c>();
        for (Integer i = 0; i < count; i++) {
            newCovs.add(DA_TestDataFactory.createTestCaseCoverage(caseId, policyCoverageId, params));
        }
        insert newCovs;
        caseCoverages.addAll(newCovs);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — CLAIM PARTICIPANTS
    // ============================================================

    public DA_TestBuilderFactory withClaimParticipants(Integer count, Id claimId, Id accountId, Map<String, Object> params) {
        List<ClaimParticipant__c> newParticipants = new List<ClaimParticipant__c>();
        for (Integer i = 0; i < count; i++) {
            newParticipants.add(DA_TestDataFactory.createTestClaimParticipant(claimId, accountId, params));
        }
        insert newParticipants;
        claimParticipants.addAll(newParticipants);
        return this;
    }

    // ============================================================
    // BUILDER METHODS — SCÉNARIOS (compat tests scénarisés)
    // ============================================================

    public DA_TestBuilderFactory withScenarios(Map<String, String> scenarios) {
        Account acc = accounts[accounts.size() - 1];
        InsurancePolicy__c pol = policies[policies.size() - 1];

        List<String> keys = new List<String>(scenarios.keySet());
        List<Case> newCases = new List<Case>();
        for (String key : keys) {
            newCases.add(DA_TestDataFactory.createTestCase(acc.Id, pol.Id, key, null));
        }
        insert newCases;
        cases.addAll(newCases);

        List<Claim__c> newClaims = new List<Claim__c>();
        for (Integer i = 0; i < keys.size(); i++) {
            newClaims.add(DA_TestDataFactory.createTestClaim(
                newCases[i].Id,
                new Map<String, Object>{ 'Flags__c' => scenarios.get(keys[i]) }
            ));
        }
        insert newClaims;
        claims.addAll(newClaims);

        for (Integer i = 0; i < keys.size(); i++) {
            claimsByKey.put(keys[i], newClaims[i]);
        }
        return this;
    }

    public DA_TestBuilderFactory withPendingApproval(String scenarioKey, String flag, String submitterAlias, String approverAlias) {
        RequestApproval__c r = DA_TestDataFactory.createTestRequestApproval(
            claimsByKey.get(scenarioKey).Id,
            usersByAlias.get(submitterAlias).Id,
            usersByAlias.get(approverAlias).Id,
            new Map<String, Object>{ 'Flag__c' => flag }
        );
        insert r;
        requestApprovals.add(r);
        return this;
    }

    // ============================================================
    // ACCESSEURS — RETOURNENT LES LISTES INTERNES
    // ============================================================

    public List<User> getUsers() {
        return users;
    }

    public List<Account> getAccounts() {
        return accounts;
    }

    public List<InsurancePolicy__c> getPolicies() {
        return policies;
    }

    public List<Vehicule__c> getVehicles() {
        return vehicles;
    }

    public List<Case> getCases() {
        return cases;
    }

    public List<Claim__c> getClaims() {
        return claims;
    }

    public List<Passager__c> getPassengers() {
        return passengers;
    }

    public List<RequestApproval__c> getRequestApprovals() {
        return requestApprovals;
    }

    public List<InsurancePolicyCoverage__c> getInsurancePolicyCoverages() {
        return insurancePolicyCoverages;
    }

    public List<ClaimCoverage__c> getClaimCoverages() {
        return claimCoverages;
    }

    public List<CaseCoverage__c> getCaseCoverages() {
        return caseCoverages;
    }

    public List<ClaimParticipant__c> getClaimParticipants() {
        return claimParticipants;
    }

    public User getUser(String alias) {
        return usersByAlias.get(alias);
    }

    public Claim__c getClaim(String scenarioKey) {
        return claimsByKey.get(scenarioKey);
    }

    public Map<String, Claim__c> getScenarioClaims() {
        return claimsByKey;
    }
}
