@isTest
private class DA_FlagSinistreControllerTest {

    private static final String PENDING = 'En attente d\'approbation';

    // ============================================================
    // HELPERS DE SETUP
    // ============================================================

    private static DA_TestBuilderFactory baseSetupWithManager() {
        DA_TestBuilderFactory b = new DA_TestBuilderFactory()
            .withUser('mgr', 'Manager')
            .withUserAndManager('usr', 'Regular', 'mgr')
            .withAccount();
        b.withCustomPolicies(1, b.getAccounts()[0].Id, null);
        b.withCustomVehicles(1, b.getPolicies()[0].Id, null);
        return b;
    }

    private static DA_TestBuilderFactory baseSetupWithoutManager() {
        DA_TestBuilderFactory b = new DA_TestBuilderFactory()
            .withUser('unm', 'NoManager')
            .withAccount();
        b.withCustomPolicies(1, b.getAccounts()[0].Id, null);
        b.withCustomVehicles(1, b.getPolicies()[0].Id, null);
        return b;
    }

    private static Claim__c addClaim(DA_TestBuilderFactory b, String subject, String flags) {
        Account acc = b.getAccounts()[0];
        InsurancePolicy__c pol = b.getPolicies()[0];
        Vehicule__c veh = b.getVehicles()[0];

        b.withCases(1, acc.Id, pol.Id, veh.Id, subject, null);
        Case c = b.getCases()[b.getCases().size() - 1];

        Map<String, Object> claimParams = (flags == null) ? null : new Map<String, Object>{ 'Flags__c' => flags };
        b.withClaims(1, c.Id, veh.Id, claimParams);
        return b.getClaims()[b.getClaims().size() - 1];
    }

    private static RequestApproval__c addPendingApproval(DA_TestBuilderFactory b, Id claimId, String flag) {
        b.withRequestApprovals(
            1,
            claimId,
            b.getUser('usr').Id,
            b.getUser('mgr').Id,
            new Map<String, Object>{ 'Flag__c' => flag }
        );
        return b.getRequestApprovals()[b.getRequestApprovals().size() - 1];
    }

    // ============================================================
    // HELPERS — INVOCATION CONTROLLER SOUS RUNAS
    // ============================================================

    private static Map<String, Object> getFlagDataAs(DA_TestBuilderFactory b, String alias, Id claimId) {
        Map<String, Object> result;
        System.runAs(b.getUser(alias)) {
            result = DA_FlagSinistreController.getClaimFlagData(claimId);
        }
        return result;
    }

    private static Map<String, Object> saveFlagsAs(DA_TestBuilderFactory b, String alias, Id claimId, List<String> flags, String commentaire) {
        Map<String, Object> result;
        System.runAs(b.getUser(alias)) {
            result = DA_FlagSinistreController.saveFlags(claimId, flags, commentaire);
        }
        return result;
    }

    // ============================================================
    // TESTS — getClaimFlagData
    // ============================================================

    @isTest
    static void getClaimFlagData_returnsFlagsAndEmptyPending() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'READ_FLAGS', 'Sensible;Majeur');

        Test.startTest();
        Map<String, Object> result = getFlagDataAs(b, 'usr', claim.Id);
        Test.stopTest();

        List<String> flags = (List<String>) result.get('currentFlags');
        System.assertEquals(2, flags.size(), 'Expected 2 current flags');
        System.assert(flags.contains('Sensible'), 'Should contain Sensible');
        System.assert(flags.contains('Majeur'), 'Should contain Majeur');

        List<Object> pending = (List<Object>) result.get('pendingRequests');
        System.assertEquals(0, pending.size(), 'Should have no pending requests');
        System.assertEquals(false, result.get('isPrivileged'));
        System.assertNotEquals(null, result.get('claimName'));
    }

    @isTest
    static void getClaimFlagData_returnsPendingRequests() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'READ_PENDING', null);
        addPendingApproval(b, claim.Id, 'Frauduleux');
        addPendingApproval(b, claim.Id, 'Douteux');

        Test.startTest();
        Map<String, Object> result = getFlagDataAs(b, 'usr', claim.Id);
        Test.stopTest();

        List<Object> pending = (List<Object>) result.get('pendingRequests');
        System.assertEquals(2, pending.size(), 'Should have 2 pending requests');
    }

    @isTest
    static void getClaimFlagData_nullClaimId_throws() {
        DA_TestBuilderFactory b = baseSetupWithManager();

        try {
            getFlagDataAs(b, 'usr', null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @isTest
    static void getClaimFlagData_claimNotFound_returnsEmpty() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'NOT_FOUND', 'Sensible');
        Id missingId = claim.Id;
        delete claim;

        Map<String, Object> result = getFlagDataAs(b, 'usr', missingId);
        List<String> flags = (List<String>) result.get('currentFlags');
        System.assertEquals(0, flags.size());
        System.assertEquals('', result.get('claimName'));
    }

    // ============================================================
    // TESTS — saveFlags
    // ============================================================

    @isTest
    static void saveFlags_nullClaimId() {
        DA_TestBuilderFactory b = baseSetupWithManager();

        Map<String, Object> r = saveFlagsAs(b, 'usr', null, new List<String>{ 'Sensible' }, 'commentaire');
        System.assertEquals(false, r.get('success'));
        System.assert(((String) r.get('message')).contains('identifiant'));
    }

    @isTest
    static void saveFlags_blankCommentaire() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'BLANK_COMMENT', null);

        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Sensible' }, '');
        System.assertEquals(false, r.get('success'));
        System.assert(((String) r.get('message')).contains('commentaire'));
    }

    @isTest
    static void saveFlags_FrauduleuxAndDouteuxConflict() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'CONFLICT', null);

        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Frauduleux', 'Douteux' }, 'note');
        System.assertEquals(false, r.get('success'));
        System.assert(((String) r.get('message')).contains('ne peuvent pas être sélectionnés'));
    }

    @isTest
    static void saveFlags_unrestrictedOnly_updatesClaim() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'UNRESTRICTED', null);

        Test.startTest();
        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Sensible', 'Majeur' }, 'note');
        Test.stopTest();

        System.assertEquals(true, r.get('success'));

        Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
        System.assert(updated.Flags__c.contains('Sensible'));
        System.assert(updated.Flags__c.contains('Majeur'));

        Integer reqCount = [SELECT COUNT() FROM RequestApproval__c WHERE Sinistre__c = :claim.Id];
        System.assertEquals(0, reqCount, 'Unrestricted flags should not create approval requests');
    }

    @isTest
    static void saveFlags_addingFrauduleux_createsApprovalRequest() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'ADD_FRAUD', null);

        Test.startTest();
        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Frauduleux' }, 'fraude detectee');
        Test.stopTest();

        System.assertEquals(true, r.get('success'));
        System.assert(((String) r.get('message')).contains('validation'));

        Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
        System.assert(
            updated.Flags__c == null || !updated.Flags__c.contains('Frauduleux'),
            'Frauduleux should not be on the claim until approval'
        );

        List<RequestApproval__c> reqs = [
            SELECT Flag__c, Status__c FROM RequestApproval__c WHERE Sinistre__c = :claim.Id
        ];
        System.assertEquals(1, reqs.size());
        System.assertEquals('Frauduleux', reqs[0].Flag__c);
        System.assertEquals(PENDING, reqs[0].Status__c);
    }

    @isTest
    static void saveFlags_removingExistingDouteux_createsApprovalRequest() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'REMOVE_DOUTEUX', 'Douteux');

        Test.startTest();
        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>(), 'remove douteux');
        Test.stopTest();

        System.assertEquals(true, r.get('success'));

        Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
        System.assertNotEquals(null, updated.Flags__c, 'Douteux should remain until approval');
        System.assert(updated.Flags__c.contains('Douteux'));

        Integer reqCount = [SELECT COUNT() FROM RequestApproval__c WHERE Sinistre__c = :claim.Id];
        System.assertEquals(1, reqCount);
    }

    @isTest
    static void saveFlags_simultaneousAddRemoveRestricted_rejected() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'SWAP', 'Douteux');

        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Frauduleux' }, 'switch');
        System.assertEquals(false, r.get('success'));
        System.assert(((String) r.get('message')).contains('désélectionner'));
    }

    @isTest
    static void saveFlags_noManager_blocks() {
        DA_TestBuilderFactory b = baseSetupWithoutManager();
        Claim__c claim = addClaim(b, 'NO_MGR', null);

        Map<String, Object> r = saveFlagsAs(b, 'unm', claim.Id, new List<String>{ 'Frauduleux' }, 'note');
        System.assertEquals(false, r.get('success'));
        System.assert(((String) r.get('message')).contains('supérieur'));
    }

    @isTest
    static void saveFlags_keepingExistingRestricted_keepsClaim() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'KEEP_FRAUD', 'Frauduleux');

        Test.startTest();
        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Frauduleux' }, 'note keep');
        Test.stopTest();

        System.assertEquals(true, r.get('success'));

        Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
        System.assert(updated.Flags__c.contains('Frauduleux'), 'Frauduleux should remain');

        Integer reqCount = [SELECT COUNT() FROM RequestApproval__c WHERE Sinistre__c = :claim.Id];
        System.assertEquals(0, reqCount, 'No approval needed when re-submitting existing flag');
    }

    @isTest
    static void saveFlags_claimNotFound_returnsError() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'GONE', null);
        Id missingId = claim.Id;
        delete claim;

        Map<String, Object> r = saveFlagsAs(b, 'usr', missingId, new List<String>{ 'Sensible' }, 'note');
        System.assertEquals(false, r.get('success'));
        System.assert(((String) r.get('message')).contains('introuvable'));
    }

    @isTest
    static void saveFlags_cancelsExistingPendingRequests() {
        DA_TestBuilderFactory b = baseSetupWithManager();
        Claim__c claim = addClaim(b, 'CANCELS', null);
        RequestApproval__c oldReq = addPendingApproval(b, claim.Id, 'Frauduleux');

        Test.startTest();
        Map<String, Object> r = saveFlagsAs(b, 'usr', claim.Id, new List<String>{ 'Douteux' }, 'switch');
        Test.stopTest();

        System.assertEquals(true, r.get('success'));

        RequestApproval__c oldUpdated = [SELECT Status__c FROM RequestApproval__c WHERE Id = :oldReq.Id];
        System.assertEquals('Annulée', oldUpdated.Status__c, 'Previous pending request should be cancelled');

        List<RequestApproval__c> news = [
            SELECT Flag__c, Status__c FROM RequestApproval__c
            WHERE Sinistre__c = :claim.Id AND Id != :oldReq.Id
        ];
        System.assertEquals(1, news.size());
        System.assertEquals('Douteux', news[0].Flag__c);
        System.assertEquals(PENDING, news[0].Status__c);
    }
}
