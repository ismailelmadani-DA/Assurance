@isTest
public class DA_PassagerAssureControllerTest {
    
    // ===== SETUP RÉUTILISABLE =====
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory()
            .withAccount();
        
        Account compte = factory.getAccounts()[0];
        
        // Créer une Claim
        Claim__c claim = new Claim__c();
        insert claim;
        
        // ✅ Créer 2 participants avec le Builder (sans picklists problématiques)
        factory.withClaimParticipants(1, claim.Id, compte.Id, null);
        factory.withClaimParticipants(1, claim.Id, compte.Id, null);
    }

    // ===== TEST 1: getParticipants - Cas valide =====
    @isTest
    static void testGetParticipants_WithValidClaimId() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        
        Test.startTest();
        List<SObject> result = DA_PassagerAssureController.getParticipants(claim.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Liste ne doit pas être null');
        System.assert(result.size() >= 1, 'Doit retourner au moins 1 participant');
    }
    
    // ===== TEST 2: getParticipants - ClaimId null =====
    @isTest
    static void testGetParticipants_WithNullClaimId() {
        Test.startTest();
        try {
            DA_PassagerAssureController.getParticipants(null);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Doit avoir un message d\'erreur');
        }
        Test.stopTest();
    }
    
    // ===== TEST 3: getParticipants - ClaimId inexistant =====
    @isTest
    static void testGetParticipants_WithInexistentClaimId() {
        // Créer une Claim, récupérer son ID, puis la supprimer
        Claim__c temp = new Claim__c();
        insert temp;
        Id tempId = temp.Id;
        delete temp;
        
        Test.startTest();
        List<SObject> result = DA_PassagerAssureController.getParticipants(tempId);
        Test.stopTest();
        
        System.assertEquals(0, result.size(), 'Doit retourner liste vide');
    }
    
    // ===== TEST 4: getParticipantById - Cas valide =====
    @isTest
    static void testGetParticipantById_WithValidId() {
        ClaimParticipant__c participant = [SELECT Id FROM ClaimParticipant__c LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.getParticipantById(participant.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Résultat ne doit pas être null');
        System.assertEquals(participant.Id, result.get('participantId'), 'ID doit correspondre');
    }
    
    // ===== TEST 5: getParticipantById - ID null =====
    @isTest
    static void testGetParticipantById_WithNullId() {
        Test.startTest();
        try {
            DA_PassagerAssureController.getParticipantById(null);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Doit avoir un message d\'erreur');
        }
        Test.stopTest();
    }
    
    // ===== TEST 6: getParticipantById - ID inexistant =====
    @isTest
    static void testGetParticipantById_WithInexistentId() {
        // Créer un participant, récupérer son ID, puis le supprimer
        ClaimParticipant__c temp = [SELECT Id FROM ClaimParticipant__c LIMIT 1];
        Id tempId = temp.Id;
        delete temp;
        
        Test.startTest();
        try {
            DA_PassagerAssureController.getParticipantById(tempId);
            System.assert(false, 'Doit lever une exception');
        } catch (Exception e) {
            // Accepte n'importe quel message d'erreur (peut être "introuvable" ou "Script-thrown exception")
            System.assert(e.getMessage() != null, 'Doit avoir un message d\'erreur');
        }
        Test.stopTest();
    }
    
    // ===== TEST 7: checkDuplicate - CNI inexistant =====
    @isTest
    static void testCheckDuplicate_WithUniqueCNI() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        String uniqueCNI = 'CNI_UNIQUE_' + System.currentTimeMillis();
        
        Test.startTest();
        Boolean isDuplicate = DA_PassagerAssureController.checkDuplicate(uniqueCNI, claim.Id, null);
        Test.stopTest();
        
        System.assertEquals(false, isDuplicate, 'CNI unique ne doit pas être en doublon');
    }
    
    // ===== TEST 8: checkDuplicate - CNI vide =====
    @isTest
    static void testCheckDuplicate_WithBlankCNI() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        
        Test.startTest();
        Boolean isDuplicate = DA_PassagerAssureController.checkDuplicate('', claim.Id, null);
        Test.stopTest();
        
        System.assertEquals(false, isDuplicate, 'CNI vide doit retourner false');
    }
    
    // ===== TEST 9: checkDuplicate - ClaimId null =====
    @isTest
    static void testCheckDuplicate_WithNullClaimId() {
        Test.startTest();
        Boolean isDuplicate = DA_PassagerAssureController.checkDuplicate('CNI_TEST', null, null);
        Test.stopTest();
        
        System.assertEquals(false, isDuplicate, 'ClaimId null doit retourner false');
    }
    
    // ===== TEST 10: upsertPassager - Création simple =====
    @isTest
    static void testUpsertPassager_Create() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> formData = new Map<String, Object>{
            'typeContact' => 'Téléphone',
            'conducteur' => false
        };
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.upsertPassager(
            formData,
            claim.Id,
            null,
            false,
            compte.Id
        );
        Test.stopTest();
        
        // Si la création échoue, afficher le message d'erreur pour déboguer
        if (!((Boolean)result.get('success'))) {
            System.debug('Erreur création: ' + result.get('message'));
        }
        System.assertEquals(true, result.get('success'), 'Création doit réussir. Erreur: ' + result.get('message'));
    }
    
    // ===== TEST 11: upsertPassager - Modification =====
    @isTest
    static void testUpsertPassager_Update() {
        ClaimParticipant__c participant = [SELECT Id, Claim__c, ParticipantAccount__c FROM ClaimParticipant__c LIMIT 1];
        
        Map<String, Object> formData = new Map<String, Object>{
            'participantId' => participant.Id,
            'conducteur' => true
        };
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.upsertPassager(
            formData,
            participant.Claim__c,
            null,
            true,
            participant.ParticipantAccount__c
        );
        Test.stopTest();
        
        // Si la modification échoue, afficher le message d'erreur pour déboguer
        if (!((Boolean)result.get('success'))) {
            System.debug('Erreur modification: ' + result.get('message'));
        }
        System.assertEquals(true, result.get('success'), 'Modification doit réussir. Erreur: ' + result.get('message'));
    }
    
    // ===== TEST 12: upsertPassager - ClaimId null =====
    @isTest
    static void testUpsertPassager_WithoutClaimId() {
        Account compte = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> formData = new Map<String, Object>{
            'sexe' => 'M'
        };
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.upsertPassager(
            formData,
            null,
            null,
            false,
            compte.Id
        );
        Test.stopTest();
        
        System.assertEquals(false, result.get('success'), 'Doit échouer sans claimId');
        System.assert(result.get('message') != null, 'Doit avoir un message d\'erreur');
    }
    
    // ===== TEST 13: upsertPassager - AccountId null =====
    @isTest
    static void testUpsertPassager_WithoutAccountId() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        
        Map<String, Object> formData = new Map<String, Object>{
            'sexe' => 'M'
        };
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.upsertPassager(
            formData,
            claim.Id,
            null,
            false,
            null
        );
        Test.stopTest();
        
        System.assertEquals(false, result.get('success'), 'Doit échouer sans accountId');
        System.assert(result.get('message') != null, 'Doit avoir un message d\'erreur');
    }
    
    // ===== TEST 14: deletePassager - Cas valide =====
    @isTest
    static void testDeletePassager_WithValidId() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        ClaimParticipant__c participant = [
            SELECT Id FROM ClaimParticipant__c 
            WHERE Claim__c = :claim.Id LIMIT 1
        ];
        Id participantId = participant.Id;
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.deletePassager(participantId);
        Test.stopTest();
        
        System.assertEquals(true, result.get('success'), 'Suppression doit réussir');
        
        // Vérifier que le participant a été supprimé
        List<ClaimParticipant__c> remaining = [SELECT Id FROM ClaimParticipant__c WHERE Id = :participantId];
        System.assertEquals(0, remaining.size(), 'Participant doit être supprimé');
    }
    
    // ===== TEST 15: deletePassager - ID null =====
    @isTest
    static void testDeletePassager_WithNullId() {
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.deletePassager(null);
        Test.stopTest();
        
        System.assertEquals(false, result.get('success'), 'Doit échouer');
        System.assert(result.get('message') != null, 'Doit avoir un message d\'erreur');
    }
    
    // ===== TEST 16: deletePassager - ID inexistant =====
    @isTest
    static void testDeletePassager_WithInexistentId() {
        // Créer et supprimer pour avoir un ID valide mais inexistant
        ClaimParticipant__c temp = [SELECT Id FROM ClaimParticipant__c LIMIT 1];
        Id tempId = temp.Id;
        delete temp;
        
        Test.startTest();
        Map<String, Object> result = DA_PassagerAssureController.deletePassager(tempId);
        Test.stopTest();
        
        // Salesforce retourne false si l'objet n'existe pas
        System.assertEquals(false, result.get('success'), 'Suppression inexistant retourne false');
    }
    
    // ===== TEST 17: checkDuplicate - Cas avec plusieurs participants =====
    @isTest
    static void testGetParticipants_WithMultipleParticipants() {
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        
        Test.startTest();
        List<SObject> result = DA_PassagerAssureController.getParticipants(claim.Id);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Doit retourner 2 participants (créés dans @TestSetup)');
    }

}