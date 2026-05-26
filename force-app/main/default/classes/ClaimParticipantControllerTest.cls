/**
 * @description       : Tests unitaires du controller des passagers assurés d'un sinistre : récupération de la liste, du détail, vérification du doublon CIN, création, mise à jour, suppression d'un passager et lecture des valeurs de picklist.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-21
 */
@isTest
private class ClaimParticipantControllerTest {

    private static final String ROLE_ASSURE = 'Passager assuré';
    private static final String CIN_EXISTING = 'CIN_DUP_001';

    /**
    * @description      :   Configure les données de test : un compte propriétaire, une police, un case, un sinistre, et 2 passagers assurés (un avec CIN renseigné pour les scénarios de doublon).
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
        builder.withAccount();
        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);
        builder.withCases(1, builder.getAccounts()[0].Id, builder.getPolicies()[0].Id, 'CP_TEST', null);
        builder.withClaims(1, builder.getCases()[0].Id, null);

        builder.withCustomAccounts(1, new Map<String, Object>{
            'CIN__c' => CIN_EXISTING
        });
        builder.withCustomAccounts(1, null);

        Id claimId           = builder.getClaims()[0].Id;
        Id accountWithCin    = builder.getAccounts()[1].Id;
        Id accountWithoutCin = builder.getAccounts()[2].Id;

        builder.withClaimParticipants(1, claimId, accountWithCin, new Map<String, Object>{
            'Name' => 'Passager Existant'
        });
        builder.withClaimParticipants(1, claimId, accountWithoutCin, new Map<String, Object>{
            'Name' => 'Passager Sans CIN'
        });
    }

    /**
    * @description      :   Vérifie que getClaimParticipants retourne tous les passagers assurés rattachés au sinistre.
    * @method Name      :   test_getClaimParticipants_returnsAllAssures
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getClaimParticipants_returnsAllAssures() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        Test.startTest();
        List<SObject> result = ClaimParticipantController.getClaimParticipants(claim.Id);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Expected 2 participants for the claim');
    }

    /**
    * @description      :   Vérifie que getClaimParticipants lève une AuraHandledException quand l'Id du sinistre est null.
    * @method Name      :   test_getClaimParticipants_nullClaimId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getClaimParticipants_nullClaimId_throws() {
        try {
            Test.startTest();
            ClaimParticipantController.getClaimParticipants(null);
            Test.stopTest();
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    /**
    * @description      :   Vérifie que getParticipantById retourne la map de détails du participant pour un Id valide.
    * @method Name      :   test_getParticipantById_returnsDetails
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipantById_returnsDetails() {
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE ParticipantCNI__c = :CIN_EXISTING LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.getParticipantById(p.Id);
        Test.stopTest();

        System.assertEquals(p.Id, result.get('participantId'));
        System.assertNotEquals(null, result.get('accountId'));
        System.assert(result.containsKey('cni'));
        System.assert(result.containsKey('isDriver'));
    }

    /**
    * @description      :   Vérifie que getParticipantById lève une AuraHandledException quand l'Id du participant est null.
    * @method Name      :   test_getParticipantById_nullId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipantById_nullId_throws() {
        try {
            Test.startTest();
            ClaimParticipantController.getParticipantById(null);
            Test.stopTest();
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    /**
    * @description      :   Vérifie que isCinAlreadyUsed retourne true quand un autre passager du même sinistre utilise déjà le CIN.
    * @method Name      :   test_isCinAlreadyUsed_duplicate_returnsTrue
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_isCinAlreadyUsed_duplicate_returnsTrue() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        Test.startTest();
        Boolean result = ClaimParticipantController.isCinAlreadyUsed(CIN_EXISTING, claim.Id, null);
        Test.stopTest();

        System.assertEquals(true, result, 'Existing CIN on the same claim should be flagged as duplicate');
    }

    /**
    * @description      :   Vérifie que isCinAlreadyUsed retourne false quand le CIN n'est pas utilisé sur le sinistre.
    * @method Name      :   test_isCinAlreadyUsed_noDuplicate_returnsFalse
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_isCinAlreadyUsed_noDuplicate_returnsFalse() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        Test.startTest();
        Boolean result = ClaimParticipantController.isCinAlreadyUsed('CIN_UNIQUE_999', claim.Id, null);
        Test.stopTest();

        System.assertEquals(false, result, 'Unused CIN should not be flagged');
    }

    /**
    * @description      :   Vérifie que isCinAlreadyUsed retourne false quand on exclut le participant qui porte le CIN.
    * @method Name      :   test_isCinAlreadyUsed_excludingSelf_returnsFalse
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_isCinAlreadyUsed_excludingSelf_returnsFalse() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE ParticipantCNI__c = :CIN_EXISTING LIMIT 1
        ];

        Test.startTest();
        Boolean result = ClaimParticipantController.isCinAlreadyUsed(CIN_EXISTING, claim.Id, p.Id);
        Test.stopTest();

        System.assertEquals(false, result, 'Excluding the current participant should remove the duplicate');
    }

    /**
    * @description      :   Vérifie que createPassager retourne un échec quand l'Id du sinistre est null.
    * @method Name      :   test_createPassager_nullClaimId_returnsFailure
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createPassager_nullClaimId_returnsFailure() {
        Map<String, Object> formData = new Map<String, Object>{
            'participantName' => 'Nouveau Passager'
        };

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.createPassager(formData, null);
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(((String) result.get('message')).contains('sinistre'));
    }

    /**
    * @description      :   Vérifie que createPassager rejette la création quand le CIN est déjà utilisé sur le même sinistre.
    * @method Name      :   test_createPassager_duplicateCin_returnsFailure
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createPassager_duplicateCin_returnsFailure() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Map<String, Object> formData = new Map<String, Object>{
            'participantName' => 'Doublon Passager',
            'cni'             => CIN_EXISTING
        };

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.createPassager(formData, claim.Id);
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'Creating a passager with a CIN already present on the claim must fail');
        Integer count = [SELECT COUNT() FROM ClaimParticipant__c WHERE Claim__c = :claim.Id];
        System.assertEquals(2, count,
            'No new participant should be inserted when the CIN is a duplicate');
    }

    /**
    * @description      :   Vérifie que createPassager crée un nouveau passager assuré rattaché au sinistre et retourne son Id.
    * @method Name      :   test_createPassager_happyPath_succeeds
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createPassager_happyPath_succeeds() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Map<String, Object> formData = new Map<String, Object>{
            'participantName' => 'Passager Nouveau',
            'cni'             => 'CIN_NEW_777',
            'email'           => 'nouveau@test.example.com',
            'stateOfPerson'   => 'Indemne',
            'isDriver'        => false
        };

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.createPassager(formData, claim.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertNotEquals(null, result.get('participantId'));
    }

    /**
    * @description      :   Vérifie que createPassager retourne un échec quand le nom du participant est manquant.
    * @method Name      :   test_createPassager_missingName_returnsFailure
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createPassager_missingName_returnsFailure() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Map<String, Object> formData = new Map<String, Object>{
            'cni' => 'CIN_NEW_888'
        };

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.createPassager(formData, claim.Id);
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    /**
    * @description      :   Vérifie que updatePassager retourne un échec quand l'Id du participant est null.
    * @method Name      :   test_updatePassager_nullParticipantId_returnsFailure
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_updatePassager_nullParticipantId_returnsFailure() {
        Map<String, Object> formData = new Map<String, Object>{
            'participantName' => 'Update Sans Id'
        };

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.updatePassager(formData, null, null);
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(((String) result.get('message')).contains('participant'));
    }

    /**
    * @description      :   Vérifie que updatePassager modifie un passager assuré existant et retourne son Id.
    * @method Name      :   test_updatePassager_happyPath_succeeds
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_updatePassager_happyPath_succeeds() {
        ClaimParticipant__c p = [
            SELECT Id, ParticipantAccount__c
            FROM ClaimParticipant__c
            WHERE ParticipantCNI__c = :CIN_EXISTING
            LIMIT 1
        ];
        Map<String, Object> formData = new Map<String, Object>{
            'participantName' => 'Passager Modifié',
            'stateOfPerson'   => 'Blessé',
            'isDriver'        => true
        };

        Test.startTest();
        Map<String, Object> result =
            ClaimParticipantController.updatePassager(formData, p.Id, p.ParticipantAccount__c);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertEquals(p.Id, result.get('participantId'));
    }

    /**
    * @description      :   Vérifie que deletePassager retourne un échec quand l'Id du participant est null.
    * @method Name      :   test_deletePassager_nullId_returnsFailure
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_deletePassager_nullId_returnsFailure() {
        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.deletePassager(null);
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(((String) result.get('message')).contains('participant'));
    }

    /**
    * @description      :   Vérifie que deletePassager supprime le passager assuré et retourne un succès.
    * @method Name      :   test_deletePassager_happyPath_succeeds
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_deletePassager_happyPath_succeeds() {
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE ParticipantCNI__c = :CIN_EXISTING LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> result = ClaimParticipantController.deletePassager(p.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        Integer remaining = [SELECT COUNT() FROM ClaimParticipant__c WHERE Id = :p.Id];
        System.assertEquals(0, remaining, 'Participant should have been deleted');
    }

    /**
    * @description      :   Vérifie que getPicklistValues retourne les valeurs actives des champs picklist demandés.
    * @method Name      :   test_getPicklistValues_validObject_returnsOptions
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getPicklistValues_validObject_returnsOptions() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            ClaimParticipantController.getPicklistValues(
                'ClaimParticipant__c', new List<String>{ 'StateOfPerson__c' }
            );
        Test.stopTest();

        System.assert(result.containsKey('StateOfPerson__c'));
    }

    /**
    * @description      :   Vérifie que getPicklistValues lève une AuraHandledException pour un objet API name invalide.
    * @method Name      :   test_getPicklistValues_invalidObject_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getPicklistValues_invalidObject_throws() {
        try {
            Test.startTest();
            ClaimParticipantController.getPicklistValues(
                'NotARealObject__c', new List<String>{ 'AnyField__c' }
            );
            Test.stopTest();
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    /**
    * @description      :   Vérifie que upsertPassager en mode création (isUpdateMode = false) délègue à createPassager.
    * @method Name      :   test_upsertPassager_createMode_delegatesToCreate
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPassager_createMode_delegatesToCreate() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Map<String, Object> formData = new Map<String, Object>{
            'participantName' => 'Upsert Créé',
            'cni'             => 'CIN_UPSERT_111',
            'stateOfPerson'   => 'Indemne',
            'isDriver'        => false
        };

        Test.startTest();
        Map<String, Object> result =
            ClaimParticipantController.upsertPassager(formData, claim.Id, false, null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertNotEquals(null, result.get('participantId'));
    }

    /**
    * @description      :   Vérifie que upsertPassager en mode édition (isUpdateMode = true) délègue à updatePassager.
    * @method Name      :   test_upsertPassager_updateMode_delegatesToUpdate
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPassager_updateMode_delegatesToUpdate() {
        ClaimParticipant__c p = [
            SELECT Id, ParticipantAccount__c
            FROM ClaimParticipant__c
            WHERE ParticipantCNI__c = :CIN_EXISTING
            LIMIT 1
        ];
        Map<String, Object> formData = new Map<String, Object>{
            'participantId'   => p.Id,
            'participantName' => 'Upsert Modifié',
            'stateOfPerson'   => 'Indemne',
            'isDriver'        => false
        };

        Test.startTest();
        Map<String, Object> result =
            ClaimParticipantController.upsertPassager(formData, null, true, p.ParticipantAccount__c);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertEquals(p.Id, result.get('participantId'));
    }
}