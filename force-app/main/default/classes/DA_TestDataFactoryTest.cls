@isTest
private class DA_TestDataFactoryTest {

    @isTest
    static void allFactoryMethods_insertSuccessfully() {
        User u = DA_TestDataFactory.createTestUser('smk', 'Smoke', null);
        insert u;

        Account acc = DA_TestDataFactory.createTestAccount(null);
        insert acc;

        InsurancePolicy__c pol = DA_TestDataFactory.createTestPolicy(acc.Id, null);
        insert pol;

        Vehicule__c veh = DA_TestDataFactory.createTestVehicle(pol.Id, null);
        insert veh;

        Case c = DA_TestDataFactory.createTestCase(acc.Id, pol.Id, veh.Id, 'Smoke', null);
        insert c;

        Claim__c cl = DA_TestDataFactory.createTestClaim(c.Id, veh.Id, null);
        insert cl;

        Passager__c p = DA_TestDataFactory.createTestPassenger(c.Id, acc.Id, veh.Id, null);
        insert p;

        RequestApproval__c ra = DA_TestDataFactory.createTestRequestApproval(cl.Id, u.Id, u.Id, null);
        insert ra;

        InsurancePolicyCoverage__c ipc = DA_TestDataFactory.createTestInsurancePolicyCoverage(pol.Id, null);
        insert ipc;

        ClaimCoverage__c cc = DA_TestDataFactory.createTestClaimCoverage(cl.Id, ipc.Id, null);
        insert cc;

        CaseCoverage__c caco = DA_TestDataFactory.createTestCaseCoverage(c.Id, ipc.Id, null);
        insert caco;

        ClaimParticipant__c cp = DA_TestDataFactory.createTestClaimParticipant(cl.Id, acc.Id, null);
        insert cp;

        System.assertNotEquals(null, u.Id, 'User');
        System.assertNotEquals(null, acc.Id, 'Account');
        System.assertNotEquals(null, pol.Id, 'Policy');
        System.assertNotEquals(null, veh.Id, 'Vehicle');
        System.assertNotEquals(null, c.Id, 'Case');
        System.assertNotEquals(null, cl.Id, 'Claim');
        System.assertNotEquals(null, p.Id, 'Passager');
        System.assertNotEquals(null, ra.Id, 'RequestApproval');
        System.assertNotEquals(null, ipc.Id, 'InsurancePolicyCoverage');
        System.assertNotEquals(null, cc.Id, 'ClaimCoverage');
        System.assertNotEquals(null, caco.Id, 'CaseCoverage');
        System.assertNotEquals(null, cp.Id, 'ClaimParticipant');
    }
}
