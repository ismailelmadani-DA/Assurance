@isTest
public class DA_TestBuilderFactory {

    public static void insertAll(List<SObject> records) {
        insert records;
    }

    public static User getUserByAlias(String alias) {
        return [SELECT Id, ManagerId FROM User WHERE Alias = :alias LIMIT 1];
    }

    public static List<User> getUsersByAliasPrefix(String prefix) {
        String pattern = prefix + '%';
        return [SELECT Id, Alias, ManagerId FROM User WHERE Alias LIKE :pattern];
    }

    public static List<User> getAllTestUsers() {
        return [SELECT Id, Alias, ManagerId FROM User WHERE Username LIKE '%@test.assurance.factory'];
    }

    public static Claim__c getClaimByScenario(String scenarioKey) {
        return [SELECT Id, Flags__c FROM Claim__c WHERE Case__r.Subject = :scenarioKey LIMIT 1];
    }

    public static List<Claim__c> getAllClaims() {
        return [SELECT Id, Flags__c, Case__c FROM Claim__c];
    }

    public static List<Case> getAllCases() {
        return [SELECT Id, Subject, AccountId FROM Case];
    }

    public static List<Account> getAllAccounts() {
        return [SELECT Id, Name FROM Account];
    }

    public static List<RequestApproval__c> getAllRequestApprovals() {
        return [
            SELECT Id, Flag__c, Status__c, Sinistre__c, Submitter__c, NextApprover__c
            FROM RequestApproval__c
        ];
    }

    public static List<RequestApproval__c> getRequestApprovalsForClaim(Id claimId) {
        return [
            SELECT Id, Flag__c, Status__c, Submitter__c, NextApprover__c
            FROM RequestApproval__c
            WHERE Sinistre__c = :claimId
        ];
    }

    private Account account;
    private Map<String, User> usersByAlias       = new Map<String, User>();
    private Map<String, Claim__c> claimsByKey    = new Map<String, Claim__c>();

    public DA_TestBuilderFactory withUser(String alias, String lastName) {
        User u = DA_TestDataFactory.createTestUser(alias, lastName);
        insert u;
        usersByAlias.put(alias, u);
        return this;
    }

    public DA_TestBuilderFactory withUser(String alias, String lastName, Integer count) {
        List<User> users = new List<User>();
        for (Integer i = 0; i < count; i++) {
            users.add(DA_TestDataFactory.createTestUser(alias + (i + 1), lastName));
        }
        insertAll(users);
        for (Integer i = 0; i < users.size(); i++) {
            usersByAlias.put(alias + (i + 1), users[i]);
        }
        return this;
    }

    public DA_TestBuilderFactory withUserAndManager(String alias, String lastName, String managerAlias) {
        User mgr = usersByAlias.get(managerAlias);
        User u = DA_TestDataFactory.createTestUserWithManager(alias, lastName, mgr.Id);
        insert u;
        usersByAlias.put(alias, u);
        return this;
    }

    public DA_TestBuilderFactory withUserAndManager(String alias, String lastName, String managerAlias, Integer count) {
        User mgr = usersByAlias.get(managerAlias);
        List<User> users = new List<User>();
        for (Integer i = 0; i < count; i++) {
            users.add(DA_TestDataFactory.createTestUserWithManager(alias + (i + 1), lastName, mgr.Id));
        }
        insertAll(users);
        for (Integer i = 0; i < users.size(); i++) {
            usersByAlias.put(alias + (i + 1), users[i]);
        }
        return this;
    }

    public DA_TestBuilderFactory withAccount() {
        account = DA_TestDataFactory.createTestAccount();
        insert account;
        return this;
    }

    public DA_TestBuilderFactory withScenarios(Map<String, String> scenarios) {
        List<String> keys = new List<String>(scenarios.keySet());

        List<Case> cases = new List<Case>();
        for (String key : keys) {
            cases.add(DA_TestDataFactory.createTestCase(account.Id, key));
        }
        insertAll(cases);

        List<Claim__c> claims = new List<Claim__c>();
        for (Integer i = 0; i < keys.size(); i++) {
            claims.add(DA_TestDataFactory.createTestClaim(cases[i].Id, scenarios.get(keys[i])));
        }
        insertAll(claims);

        for (Integer i = 0; i < keys.size(); i++) {
            claimsByKey.put(keys[i], claims[i]);
        }
        return this;
    }

    public DA_TestBuilderFactory withPendingApproval(
        String scenarioKey, String flag, String submitterAlias, String approverAlias
    ) {
        RequestApproval__c r = DA_TestDataFactory.createTestRequestApproval(
            claimsByKey.get(scenarioKey).Id,
            flag,
            usersByAlias.get(submitterAlias).Id,
            usersByAlias.get(approverAlias).Id
        );
        insert r;
        return this;
    }

    public User getUser(String alias)                       { return usersByAlias.get(alias); }
    public Account getAccount()                             { return account; }
    public Claim__c getClaim(String scenarioKey)            { return claimsByKey.get(scenarioKey); }
    public Map<String, Claim__c> getScenarioClaims()        { return claimsByKey; }
}
