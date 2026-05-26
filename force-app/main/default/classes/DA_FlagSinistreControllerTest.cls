/**
 * @description       : Tests unitaires du controller de gestion des flags sinistre : lecture des flags, ajout/retrait de flags non restreints et restreints, déclenchement et annulation de demandes d'approbation
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 20-05-2026
 */
@isTest
public class DA_FlagSinistreControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
    private static final String PENDING = 'En attente d\'approbation';

    /**
    * @description      :   Configure les données de test : utilisateurs (mgr / usr / unm), compte, police, et 13 scénarios de sinistres + approbations pendantes pour 'READ_PENDING' et 'CANCELS'.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder
            .withUser('mgr', 'Manager')
            .withUserAndManager('usr', 'Regular', 'mgr')
            .withUser('unm', 'NoManager')
            .withAccount();

        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);

        builder.withScenarios(new Map<String, String>{
            'READ_FLAGS'      => 'Sensible;Majeur',
            'READ_PENDING'    => null,
            'NOT_FOUND'       => 'Sensible',
            'BLANK_COMMENT'   => null,
            'CONFLICT'        => null,
            'UNRESTRICTED'    => null,
            'ADD_FRAUD'       => null,
            'REMOVE_DOUTEUX'  => 'Douteux',
            'SWAP'            => 'Douteux',
            'NO_MGR'          => null,
            'CANCELS'         => null,
            'KEEP_FRAUD'      => 'Frauduleux',
            'GONE'            => null
        });

        builder.withPendingApproval('READ_PENDING', 'Frauduleux', 'usr', 'mgr');
        builder.withPendingApproval('READ_PENDING', 'Douteux',    'usr', 'mgr');
        builder.withPendingApproval('CANCELS',      'Frauduleux', 'usr', 'mgr');
    }

    /**
    * @description      :   Vérifie que getClaimFlagData retourne les flags actuels du sinistre et une liste vide de demandes pendantes.
    * @method Name      :   test_getClaimFlagData_returnsFlagsAndEmptyPending
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getClaimFlagData_returnsFlagsAndEmptyPending() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'READ_FLAGS' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_FlagSinistreController.getClaimFlagData(claim.Id);
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
    }

    /**
    * @description      :   Vérifie que getClaimFlagData remonte les demandes d'approbation en attente sur le sinistre.
    * @method Name      :   test_getClaimFlagData_returnsPendingRequests
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getClaimFlagData_returnsPendingRequests() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'READ_PENDING' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_FlagSinistreController.getClaimFlagData(claim.Id);
            Test.stopTest();

            List<Object> pending = (List<Object>) result.get('pendingRequests');
            System.assertEquals(2, pending.size(), 'Should have 2 pending requests');
        }
    }

    /**
    * @description      :   Vérifie que getClaimFlagData lève une AuraHandledException quand l'Id du sinistre est null.
    * @method Name      :   test_getClaimFlagData_nullClaimId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getClaimFlagData_nullClaimId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_FlagSinistreController.getClaimFlagData(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    /**
    * @description      :   Vérifie que getClaimFlagData retourne un résultat vide quand le sinistre a été supprimé.
    * @method Name      :   test_getClaimFlagData_claimNotFound_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getClaimFlagData_claimNotFound_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'NOT_FOUND' LIMIT 1];
        Id missingId = claim.Id;
        delete claim;

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_FlagSinistreController.getClaimFlagData(missingId);
            Test.stopTest();

            List<String> flags = (List<String>) result.get('currentFlags');
            System.assertEquals(0, flags.size());
            System.assertEquals('', result.get('claimName'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags retourne un échec quand l'Id du sinistre est null.
    * @method Name      :   test_saveFlags_nullClaimId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_nullClaimId() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                null, new List<String>{ 'Sensible' }, 'commentaire'
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('identifiant'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags rejette un commentaire vide.
    * @method Name      :   test_saveFlags_blankCommentaire
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_blankCommentaire() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'BLANK_COMMENT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Sensible' }, ''
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('commentaire'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags rejette la combinaison Frauduleux + Douteux simultanés.
    * @method Name      :   test_saveFlags_FrauduleuxAndDouteuxConflict
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_FrauduleuxAndDouteuxConflict() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'CONFLICT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Frauduleux', 'Douteux' }, 'note'
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('ne peuvent pas être sélectionnés'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags applique directement les flags non restreints sans demande d'approbation.
    * @method Name      :   test_saveFlags_unrestrictedOnly_updatesClaim
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_unrestrictedOnly_updatesClaim() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'UNRESTRICTED' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Sensible', 'Majeur' }, 'note'
            );
            Test.stopTest();

            System.assertEquals(true, r.get('success'));

            Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assert(updated.Flags__c.contains('Sensible'));
            System.assert(updated.Flags__c.contains('Majeur'));

            Integer reqCount = [SELECT COUNT() FROM RequestApproval__c WHERE Sinistre__c = :claim.Id];
            System.assertEquals(0, reqCount, 'Unrestricted flags should not create approval requests');
        }
    }

    /**
    * @description      :   Vérifie que saveFlags crée une demande d'approbation lors de l'ajout d'un flag Frauduleux.
    * @method Name      :   test_saveFlags_addingFrauduleux_createsApprovalRequest
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_addingFrauduleux_createsApprovalRequest() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'ADD_FRAUD' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Frauduleux' }, 'fraude detectee'
            );
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
    }

    /**
    * @description      :   Vérifie que saveFlags crée une demande d'approbation lors du retrait d'un flag Douteux existant.
    * @method Name      :   test_saveFlags_removingExistingDouteux_createsApprovalRequest
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_removingExistingDouteux_createsApprovalRequest() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'REMOVE_DOUTEUX' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>(), 'remove douteux'
            );
            Test.stopTest();

            System.assertEquals(true, r.get('success'));

            Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assertNotEquals(null, updated.Flags__c, 'Douteux should remain until approval');
            System.assert(updated.Flags__c.contains('Douteux'));

            Integer reqCount = [SELECT COUNT() FROM RequestApproval__c WHERE Sinistre__c = :claim.Id];
            System.assertEquals(1, reqCount);
        }
    }

    /**
    * @description      :   Vérifie que saveFlags rejette la sélection et désélection simultanées d'un flag restreint.
    * @method Name      :   test_saveFlags_simultaneousAddRemoveRestricted_rejected
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_simultaneousAddRemoveRestricted_rejected() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'SWAP' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Frauduleux' }, 'switch'
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('désélectionner'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags bloque la création d'une demande d'approbation si l'utilisateur n'a pas de manager.
    * @method Name      :   test_saveFlags_noManager_blocks
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_noManager_blocks() {
        User unm = [SELECT Id FROM User WHERE Alias = 'unm' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'NO_MGR' LIMIT 1];

        System.runAs(unm) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Frauduleux' }, 'note'
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('supérieur'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags conserve un flag restreint déjà présent quand l'utilisateur le re-soumet, sans créer de demande.
    * @method Name      :   test_saveFlags_keepingExistingRestricted_keepsClaim
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_keepingExistingRestricted_keepsClaim() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'KEEP_FRAUD' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Frauduleux' }, 'note keep'
            );
            Test.stopTest();

            System.assertEquals(true, r.get('success'));

            Claim__c updated = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assert(updated.Flags__c.contains('Frauduleux'), 'Frauduleux should remain');

            Integer reqCount = [SELECT COUNT() FROM RequestApproval__c WHERE Sinistre__c = :claim.Id];
            System.assertEquals(0, reqCount, 'No approval needed when re-submitting existing flag');
        }
    }

    /**
    * @description      :   Vérifie que saveFlags retourne une erreur 'Sinistre introuvable' quand le sinistre a été supprimé.
    * @method Name      :   test_saveFlags_claimNotFound_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_claimNotFound_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'GONE' LIMIT 1];
        Id missingId = claim.Id;
        delete claim;

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                missingId, new List<String>{ 'Sensible' }, 'note'
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('introuvable'));
        }
    }

    /**
    * @description      :   Vérifie que saveFlags annule les demandes pendantes existantes avant d'en créer une nouvelle.
    * @method Name      :   test_saveFlags_cancelsExistingPendingRequests
    * @Author           :   D&A Technologies
    * @date             :   2026-05-20
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveFlags_cancelsExistingPendingRequests() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'CANCELS' LIMIT 1];
        RequestApproval__c oldReq = [
            SELECT Id FROM RequestApproval__c
            WHERE Sinistre__c = :claim.Id AND Status__c = :PENDING
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{ 'Douteux' }, 'switch'
            );
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
}