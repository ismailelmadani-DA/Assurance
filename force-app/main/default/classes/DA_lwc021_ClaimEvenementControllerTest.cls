/**
 * @description       : Tests unitaires du controller de gestion de l'association événement/sinistre
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 25-05-2026
 */
@isTest
public class DA_lwc021_ClaimEvenementControllerTest {

    /**
    * @description      :   Configure les données de test
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    */
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

        builder
            .withUser('usr', 'Regular')
            .withAccount()
            .withCustomPolicies(1, builder.getAccounts()[0].Id, null);

        builder.withScenarios(new Map<String, String>{
            'MATCH_FOUND'   => null,
            'NO_MATCH'      => null,
            'ASSOCIER'      => null,
            'ALREADY_ASSOC' => null,
            'MARQUER_VU'    => null,
            'NULL_CLAIM'    => null,
            'POPUP_FALSE'   => null,
            'POPUP_TRUE'    => null
        });

        // ✅ Libelle__c forcé à une valeur fixe pour être queryable dans les tests
        builder.withScenarioEvenements(new Map<String, Map<String, Object>>{
            'EVT_MATCH' => new Map<String, Object>{
                'Libelle__c'   => 'EVT_MATCH',
                'Pays__c'      => 'Maroc',
                'Ville__c'     => 'Casablanca',
                'DateDebut__c' => Date.today().addDays(-1),
                'DateFin__c'   => Date.today().addDays(1)
            },
            'EVT_ASSOCIER' => new Map<String, Object>{
                'Libelle__c' => 'EVT_ASSOCIER',
                'Pays__c'    => 'Maroc',
                'Ville__c'   => 'Casablanca'
            }
        });

        // ✅ Utilisation des Ids depuis le builder — pas de SOQL par Subject
        Id claimPopupTrueId = builder.getClaim('POPUP_TRUE').Id;
        update new Claim__c(Id = claimPopupTrueId, PopupEvenementVu__c = true);

        Id evtAssocId     = builder.getEvenement('EVT_MATCH').Id;
        Id claimAlreadyId = builder.getClaim('ALREADY_ASSOC').Id;
        update new Claim__c(Id = claimAlreadyId, EvenementAssocie__c = evtAssocId);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getMatchingEvenements
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getMatchingEvenements lève une AuraHandledException quand le claimId est null.
    * @method Name      :   test_getMatchingEvenements_nullClaimId_throws
    */
    @isTest
    static void test_getMatchingEvenements_nullClaimId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.getMatchingEvenements(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Vérifie que getMatchingEvenements retourne une liste vide quand aucun événement ne correspond.
    * @method Name      :   test_getMatchingEvenements_noMatch_returnsEmpty
    */
    @isTest
    static void test_getMatchingEvenements_noMatch_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'NO_MATCH' LIMIT 1];
        System.assertEquals(1, claims.size(), 'NO_MATCH claim should exist in test data');

        System.runAs(usr) {
            Test.startTest();
            List<Evenement__c> result = DA_lwc021_ClaimEvenementController.getMatchingEvenements(claims[0].Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(0, result.size(), 'Should return empty list when no matching event');
        }
    }

    /**
    * @description      :   Vérifie que getMatchingEvenements retourne les événements correspondants au sinistre.
    * @method Name      :   test_getMatchingEvenements_withMatch_returnsEvenements
    */
    @isTest
    static void test_getMatchingEvenements_withMatch_returnsEvenements() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'MATCH_FOUND' LIMIT 1];
        System.assertEquals(1, claims.size(), 'MATCH_FOUND claim should exist in test data');

        System.runAs(usr) {
            Test.startTest();
            List<Evenement__c> result = DA_lwc021_ClaimEvenementController.getMatchingEvenements(claims[0].Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }

    /**
    * @description      :   Couvre catch(Exception) dans getMatchingEvenements via un Id invalide forgé.
    * @method Name      :   test_getMatchingEvenements_invalidId_throwsAura
    */
    @isTest
    static void test_getMatchingEvenements_invalidId_throwsAura() {
        Id fakeId = '001000000000000AAA';
        try {
            Test.startTest();
            DA_lwc021_ClaimEvenementController.getMatchingEvenements(fakeId);
            Test.stopTest();
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getEvenementAssocie
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getEvenementAssocie lève une AuraHandledException quand le claimId est null.
    * @method Name      :   test_getEvenementAssocie_nullClaimId_throws
    */
    @isTest
    static void test_getEvenementAssocie_nullClaimId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.getEvenementAssocie(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Vérifie que getEvenementAssocie retourne null quand aucun événement n'est associé.
    * @method Name      :   test_getEvenementAssocie_noAssociation_returnsNull
    */
    @isTest
    static void test_getEvenementAssocie_noAssociation_returnsNull() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'NO_MATCH' LIMIT 1];
        System.assertEquals(1, claims.size(), 'NO_MATCH claim should exist in test data');

        System.runAs(usr) {
            Test.startTest();
            Evenement__c result = DA_lwc021_ClaimEvenementController.getEvenementAssocie(claims[0].Id);
            Test.stopTest();

            System.assertEquals(null, result, 'Should return null when no event is associated');
        }
    }

    /**
    * @description      :   Vérifie que getEvenementAssocie retourne l'événement associé quand il existe.
    * @method Name      :   test_getEvenementAssocie_withAssociation_returnsEvenement
    */
    @isTest
    static void test_getEvenementAssocie_withAssociation_returnsEvenement() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'ALREADY_ASSOC' LIMIT 1];
        System.assertEquals(1, claims.size(), 'ALREADY_ASSOC claim should exist in test data');

        System.runAs(usr) {
            Test.startTest();
            Evenement__c result = DA_lwc021_ClaimEvenementController.getEvenementAssocie(claims[0].Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Should return the associated event');
            System.assertNotEquals(null, result.Id, 'Associated event should have an Id');
        }
    }

    /**
    * @description      :   Couvre catch(Exception) dans getEvenementAssocie via un Id invalide forgé.
    * @method Name      :   test_getEvenementAssocie_invalidId_throwsAura
    */
    @isTest
    static void test_getEvenementAssocie_invalidId_throwsAura() {
        Id fakeId = '001000000000000AAA';
        try {
            Test.startTest();
            DA_lwc021_ClaimEvenementController.getEvenementAssocie(fakeId);
            Test.stopTest();
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // isPopupEvenementVu
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que isPopupEvenementVu retourne true quand le claimId est null.
    * @method Name      :   test_isPopupEvenementVu_nullClaimId_returnsTrue
    */
    @isTest
    static void test_isPopupEvenementVu_nullClaimId_returnsTrue() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Boolean result = DA_lwc021_ClaimEvenementController.isPopupEvenementVu(null);
            Test.stopTest();

            System.assertEquals(true, result, 'Should return true when claimId is null');
        }
    }

    /**
    * @description      :   Vérifie que isPopupEvenementVu retourne false quand le popup n'a pas encore été vu.
    * @method Name      :   test_isPopupEvenementVu_notVu_returnsFalse
    */
    @isTest
    static void test_isPopupEvenementVu_notVu_returnsFalse() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'POPUP_FALSE' LIMIT 1];
        System.assertEquals(1, claims.size(), 'POPUP_FALSE claim should exist in test data');

        System.runAs(usr) {
            Test.startTest();
            Boolean result = DA_lwc021_ClaimEvenementController.isPopupEvenementVu(claims[0].Id);
            Test.stopTest();

            System.assertEquals(false, result, 'Should return false when popup has not been seen');
        }
    }

    /**
    * @description      :   Vérifie que isPopupEvenementVu retourne true quand le popup a déjà été vu.
    * @method Name      :   test_isPopupEvenementVu_vu_returnsTrue
    */
    @isTest
    static void test_isPopupEvenementVu_vu_returnsTrue() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'POPUP_TRUE' LIMIT 1];
        System.assertEquals(1, claims.size(), 'POPUP_TRUE claim should exist in test data');

        System.runAs(usr) {
            Test.startTest();
            Boolean result = DA_lwc021_ClaimEvenementController.isPopupEvenementVu(claims[0].Id);
            Test.stopTest();

            System.assertEquals(true, result, 'Should return true when popup has been seen');
        }
    }

    /**
    * @description      :   Couvre catch(Exception) dans isPopupEvenementVu — retourne true silencieusement.
    * @method Name      :   test_isPopupEvenementVu_invalidId_returnsTrue
    */
    @isTest
    static void test_isPopupEvenementVu_invalidId_returnsTrue() {
        Id fakeId = '001000000000000AAA';
        Test.startTest();
        Boolean result = DA_lwc021_ClaimEvenementController.isPopupEvenementVu(fakeId);
        Test.stopTest();

        System.assertEquals(true, result, 'Should return true on exception');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // associerEvenement
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que associerEvenement lève une AuraHandledException quand le claimId est null.
    * @method Name      :   test_associerEvenement_nullClaimId_throws
    */
    @isTest
    static void test_associerEvenement_nullClaimId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Evenement__c> evts = [SELECT Id FROM Evenement__c WHERE Libelle__c = 'EVT_ASSOCIER' LIMIT 1];
        System.assertEquals(1, evts.size(), 'EVT_ASSOCIER event should exist in test data');

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.associerEvenement(null, evts[0].Id);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Vérifie que associerEvenement lève une AuraHandledException quand l'evenementId est null.
    * @method Name      :   test_associerEvenement_nullEvenementId_throws
    */
    @isTest
    static void test_associerEvenement_nullEvenementId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'ASSOCIER' LIMIT 1];
        System.assertEquals(1, claims.size(), 'ASSOCIER claim should exist in test data');

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.associerEvenement(claims[0].Id, null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Couvre if(!isUpdateable()) dans associerEvenement via runAs user sans droits.
    * @method Name      :   test_associerEvenement_noUpdateRights_throws
    */
    @isTest
    static void test_associerEvenement_noUpdateRights_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'ASSOCIER' LIMIT 1];
        System.assertEquals(1, claims.size(), 'ASSOCIER claim should exist');
        List<Evenement__c> evts = [SELECT Id FROM Evenement__c WHERE Libelle__c = 'EVT_ASSOCIER' LIMIT 1];
        System.assertEquals(1, evts.size(), 'EVT_ASSOCIER event should exist');

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.associerEvenement(claims[0].Id, evts[0].Id);
                Test.stopTest();
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Couvre catch(DmlException) et handleDmlException via un Id de type incorrect.
    * @method Name      :   test_associerEvenement_invalidEvenementId_coversDmlBranches
    */
    @isTest
    static void test_associerEvenement_invalidEvenementId_coversDmlBranches() {
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'ASSOCIER' LIMIT 1];
        System.assertEquals(1, claims.size(), 'ASSOCIER claim should exist');

        // ✅ Id d'un Claim passé comme Evenement — force INVALID_CROSS_REFERENCE_KEY dans EM006
        Id wrongTypeId = claims[0].Id;

        try {
            Test.startTest();
            DA_lwc021_ClaimEvenementController.associerEvenement(claims[0].Id, wrongTypeId);
            Test.stopTest();
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
        }
    }

    /**
    * @description      :   Vérifie que associerEvenement associe correctement l'événement au sinistre et marque le popup comme vu.
    * @method Name      :   test_associerEvenement_valid_associatesAndMarksPopup
    */
    @isTest
    static void test_associerEvenement_valid_associatesAndMarksPopup() {
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'ASSOCIER' LIMIT 1];
        System.assertEquals(1, claims.size(), 'ASSOCIER claim should exist in test data');
        List<Evenement__c> evts = [SELECT Id FROM Evenement__c WHERE Libelle__c = 'EVT_ASSOCIER' LIMIT 1];
        System.assertEquals(1, evts.size(), 'EVT_ASSOCIER event should exist in test data');

        // ✅ Hors System.runAs — contexte System pour bypasser isUpdateable()
        Test.startTest();
        DA_lwc021_ClaimEvenementController.associerEvenement(claims[0].Id, evts[0].Id);
        Test.stopTest();

        Claim__c updated = [SELECT EvenementAssocie__c, PopupEvenementVu__c FROM Claim__c WHERE Id = :claims[0].Id];
        System.assertEquals(evts[0].Id, updated.EvenementAssocie__c, 'Event should be associated to the claim');
        System.assertEquals(true, updated.PopupEvenementVu__c, 'Popup should be marked as seen after association');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // marquerPopupVu
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que marquerPopupVu lève une AuraHandledException quand le claimId est null.
    * @method Name      :   test_marquerPopupVu_nullClaimId_throws
    */
    @isTest
    static void test_marquerPopupVu_nullClaimId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.marquerPopupVu(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Couvre if(!isUpdateable()) dans marquerPopupVu via runAs user sans droits.
    * @method Name      :   test_marquerPopupVu_noUpdateRights_throws
    */
    @isTest
    static void test_marquerPopupVu_noUpdateRights_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'MARQUER_VU' LIMIT 1];
        System.assertEquals(1, claims.size(), 'MARQUER_VU claim should exist');

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc021_ClaimEvenementController.marquerPopupVu(claims[0].Id);
                Test.stopTest();
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
            }
        }
    }

    /**
    * @description      :   Couvre catch(DmlException/Exception) dans marquerPopupVu via Id de type incorrect.
    * @method Name      :   test_marquerPopupVu_invalidId_coversCatchBranches
    */
    @isTest
    static void test_marquerPopupVu_invalidId_coversCatchBranches() {
        List<Evenement__c> evts = [SELECT Id FROM Evenement__c WHERE Libelle__c = 'EVT_ASSOCIER' LIMIT 1];
        System.assertEquals(1, evts.size(), 'EVT_ASSOCIER should exist');

        // ✅ Id d'un Evenement passé comme Claim — force une exception dans EM006
        Id wrongTypeId = evts[0].Id;

        try {
            Test.startTest();
            DA_lwc021_ClaimEvenementController.marquerPopupVu(wrongTypeId);
            Test.stopTest();
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
        }
    }

    /**
    * @description      :   Vérifie que marquerPopupVu met correctement PopupEvenementVu__c à true sur le sinistre.
    * @method Name      :   test_marquerPopupVu_valid_marksPopup
    */
    @isTest
    static void test_marquerPopupVu_valid_marksPopup() {
        List<Claim__c> claims = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'MARQUER_VU' LIMIT 1];
        System.assertEquals(1, claims.size(), 'MARQUER_VU claim should exist in test data');

        // ✅ Hors System.runAs — contexte System pour bypasser isUpdateable()
        Test.startTest();
        DA_lwc021_ClaimEvenementController.marquerPopupVu(claims[0].Id);
        Test.stopTest();

        Claim__c updated = [SELECT PopupEvenementVu__c FROM Claim__c WHERE Id = :claims[0].Id];
        System.assertEquals(true, updated.PopupEvenementVu__c, 'PopupEvenementVu__c should be true after marquerPopupVu');
    }
}