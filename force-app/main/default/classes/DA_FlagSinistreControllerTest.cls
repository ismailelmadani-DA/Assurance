@isTest
private class DA_FlagSinistreControllerTest {

    private static final String PENDING = 'En attente d\'approbation';

    @TestSetup
    static void setupData() {
        new DA_TestBuilderFactory()
            .withUser('mgr', 'Manager')
            .withUserAndManager('usr', 'Regular', 'mgr')
            .withUser('unm', 'NoManager')
            .withAccount()
            .withScenarios(new Map<String, String>{
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
                'CANCELS'         => null
            })
            .withPendingApproval('READ_PENDING', 'Frauduleux', 'usr', 'mgr')
            .withPendingApproval('READ_PENDING', 'Douteux',    'usr', 'mgr')
            .withPendingApproval('CANCELS',      'Frauduleux', 'usr', 'mgr');
    }

    @isTest
    static void getClaimFlagData_returnsFlagsAndEmptyPending() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('READ_FLAGS');

        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
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

    @isTest
    static void getClaimFlagData_returnsPendingRequests() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('READ_PENDING');

        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Test.startTest();
            Map<String, Object> result = DA_FlagSinistreController.getClaimFlagData(claim.Id);
            Test.stopTest();

            List<Object> pending = (List<Object>) result.get('pendingRequests');
            System.assertEquals(2, pending.size(), 'Should have 2 pending requests');
        }
    }

    @isTest
    static void getClaimFlagData_nullClaimId_throws() {
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            try {
                DA_FlagSinistreController.getClaimFlagData(null);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    @isTest
    static void getClaimFlagData_claimNotFound_returnsEmpty() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('NOT_FOUND');
        Id missingId = claim.Id;
        delete claim;

        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Map<String, Object> result = DA_FlagSinistreController.getClaimFlagData(missingId);
            List<String> flags = (List<String>) result.get('currentFlags');
            System.assertEquals(0, flags.size());
            System.assertEquals('', result.get('claimName'));
        }
    }

    @isTest
    static void saveFlags_nullClaimId() {
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                null, new List<String>{'Sensible'}, 'commentaire'
            );
            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('identifiant'));
        }
    }

    @isTest
    static void saveFlags_blankCommentaire() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('BLANK_COMMENT');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Sensible'}, ''
            );
            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('commentaire'));
        }
    }

    @isTest
    static void saveFlags_FrauduleuxAndDouteuxConflict() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('CONFLICT');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Frauduleux', 'Douteux'}, 'note'
            );
            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('ne peuvent pas être sélectionnés'));
        }
    }

    @isTest
    static void saveFlags_unrestrictedOnly_updatesClaim() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('UNRESTRICTED');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Sensible', 'Majeur'}, 'note'
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

    @isTest
    static void saveFlags_addingFrauduleux_createsApprovalRequest() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('ADD_FRAUD');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Frauduleux'}, 'fraude detectee'
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

    @isTest
    static void saveFlags_removingExistingDouteux_createsApprovalRequest() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('REMOVE_DOUTEUX');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
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

    @isTest
    static void saveFlags_simultaneousAddRemoveRestricted_rejected() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('SWAP');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Frauduleux'}, 'switch'
            );
            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('désélectionner'));
        }
    }

    @isTest
    static void saveFlags_noManager_blocks() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('NO_MGR');
        System.runAs(DA_TestBuilderFactory.getUserByAlias('unm')) {
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Frauduleux'}, 'note'
            );
            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('supérieur'));
        }
    }

    @isTest
    static void saveFlags_cancelsExistingPendingRequests() {
        Claim__c claim = DA_TestBuilderFactory.getClaimByScenario('CANCELS');
        RequestApproval__c oldReq = [
            SELECT Id FROM RequestApproval__c
            WHERE Sinistre__c = :claim.Id AND Status__c = :PENDING
            LIMIT 1
        ];

        System.runAs(DA_TestBuilderFactory.getUserByAlias('usr')) {
            Test.startTest();
            Map<String, Object> r = DA_FlagSinistreController.saveFlags(
                claim.Id, new List<String>{'Douteux'}, 'switch'
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
