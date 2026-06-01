/**
 * @description       : Tests unitaires du controller des autres parties adverses : lecture filtrée sur le rôle 'Autres partie', détail d'un participant, recherche de compagnies, détection de doublon CIN, upsert avec validations (transitions d'état, dates) et suppression.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-26
 */
@isTest
public class DA_AutrePartieAdverseControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
    private static final String ROLE_AUTRE_PARTIE = 'Autres partie';

    /**
    * @description      :   Configure les données de test : utilisateur, comptes (CLAIMANT, PARTIE_ACC), police, case, sinistre et deux participants — un 'Autres partie' avec CIN renseigné et un autre rôle pour vérifier le filtrage.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder.withUser('usr', 'Regular');

        builder.withCustomAccounts(1, new Map<String, Object>{ 'Name' => 'CLAIMANT' });
        builder.withCustomAccounts(1, new Map<String, Object>{
            'Name'   => 'PARTIE_ACC',
            'CIN__c' => 'CIN-AP-001'
        });

        Id claimantId = [SELECT Id FROM Account WHERE Name = 'CLAIMANT' LIMIT 1].Id;
        Id partieAccId = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1].Id;

        builder.withCustomPolicies(1, claimantId, null);
        Id policyId = builder.getPolicies()[0].Id;

        builder.withCases(1, claimantId, policyId, 'AUTRE_PARTIE_CASE', null);
        Id caseId = builder.getCases()[0].Id;

        builder.withClaims(1, caseId, null);
        Id claimId = builder.getClaims()[0].Id;

        builder.withClaimParticipants(1, claimId, partieAccId, new Map<String, Object>{
            'Roles__c'         => ROLE_AUTRE_PARTIE,
            'StateOfPerson__c' => 'Indemne'
        });
        builder.withClaimParticipants(1, claimId, partieAccId, new Map<String, Object>{
            'Roles__c' => 'Passager adverse'
        });
    }

    /**
    * @description      :   Vérifie que getParticipants ne retourne que les participants dont le rôle est 'Autres partie' pour le sinistre fourni.
    * @method Name      :   test_getParticipants_returnsOnlyAutrePartie
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipants_returnsOnlyAutrePartie() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<SObject> result = DA_AutrePartieAdverseController.getParticipants(claim.Id);
            Test.stopTest();

            System.assertEquals(1, result.size(), 'Only the Autres partie participant should be returned');
            ClaimParticipant__c p = (ClaimParticipant__c) result[0];
            System.assertEquals(ROLE_AUTRE_PARTIE, p.Roles__c);
        }
    }

    /**
    * @description      :   Vérifie que getParticipants lève une AuraHandledException quand l'Id du sinistre est null.
    * @method Name      :   test_getParticipants_nullClaimId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipants_nullClaimId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_AutrePartieAdverseController.getParticipants(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    /**
    * @description      :   Vérifie que getParticipantById retourne une map de détail hydratée pour un participant existant.
    * @method Name      :   test_getParticipantById_returnsHydratedMap
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipantById_returnsHydratedMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_AutrePartieAdverseController.getParticipantById(p.Id);
            Test.stopTest();

            System.assertEquals(p.Id, result.get('participantId'));
            System.assertEquals('CIN-AP-001', (String) result.get('cin'));
            System.assertNotEquals(null, result.get('accountId'));
        }
    }

    /**
    * @description      :   Vérifie que getParticipantById lève une AuraHandledException quand l'Id du participant est null.
    * @method Name      :   test_getParticipantById_nullId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipantById_nullId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_AutrePartieAdverseController.getParticipantById(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    /**
    * @description      :   Vérifie que searchCompagnies retourne une liste vide quand le terme de recherche est vide ou trop court (moins de 2 caractères).
    * @method Name      :   test_searchCompagnies_blankOrShortTerm_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_searchCompagnies_blankOrShortTerm_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> empty1 = DA_AutrePartieAdverseController.searchCompagnies(null);
            List<Map<String, String>> empty2 = DA_AutrePartieAdverseController.searchCompagnies('');
            List<Map<String, String>> empty3 = DA_AutrePartieAdverseController.searchCompagnies('A');
            Test.stopTest();

            System.assertEquals(0, empty1.size());
            System.assertEquals(0, empty2.size());
            System.assertEquals(0, empty3.size());
        }
    }

    /**
    * @description      :   Vérifie que checkDuplicate retourne true quand un CIN existe déjà pour le rôle 'Autres partie' sur le même sinistre.
    * @method Name      :   test_checkDuplicate_existing_returnsTrue
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkDuplicate_existing_returnsTrue() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Boolean isDuplicate = DA_AutrePartieAdverseController.checkDuplicate(
                'CIN-AP-001', claim.Id, null
            );
            Test.stopTest();

            System.assertEquals(true, isDuplicate, 'CIN-AP-001 already exists for Autres partie role');
        }
    }

    /**
    * @description      :   Vérifie que checkDuplicate retourne false pour un CIN vide ou un Id de sinistre null sans interroger la base.
    * @method Name      :   test_checkDuplicate_blankInputs_returnsFalse
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkDuplicate_blankInputs_returnsFalse() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Boolean a = DA_AutrePartieAdverseController.checkDuplicate('', claim.Id, null);
            Boolean b = DA_AutrePartieAdverseController.checkDuplicate('CIN-X', null, null);
            Test.stopTest();

            System.assertEquals(false, a);
            System.assertEquals(false, b);
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie en mode insertion crée un nouveau ClaimParticipant__c avec le rôle 'Autres partie'.
    * @method Name      :   test_upsertPartie_insertMode_createsParticipant
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_insertMode_createsParticipant() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        Map<String, Object> form = new Map<String, Object>{
            'typePartieAdverse' => 'Pieton',
            'sexe'              => 'Masculin',
            'pays'              => 'Maroc',
            'ville'             => 'Casablanca',
            'etatPassager'      => 'Indemne',
            'cin'               => 'CIN-NEW-1'
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, false, acc.Id
            );
            Test.stopTest();

            System.assertEquals(true, r.get('success'), (String) r.get('message'));
            Id newId = (Id) r.get('participantId');
            System.assertNotEquals(null, newId);
            ClaimParticipant__c created = [
                SELECT Roles__c, TypePartieAdverse__c FROM ClaimParticipant__c WHERE Id = :newId
            ];
            System.assertEquals(ROLE_AUTRE_PARTIE, created.Roles__c);
            System.assertEquals('Pieton', created.TypePartieAdverse__c);
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie retourne success=false quand l'Id du sinistre est null.
    * @method Name      :   test_upsertPartie_nullClaim_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_nullClaim_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                new Map<String, Object>(), null, false, acc.Id
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('sinistre'));
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie retourne success=false quand l'Id du compte du participant est null.
    * @method Name      :   test_upsertPartie_nullAccount_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_nullAccount_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                new Map<String, Object>(), claim.Id, false, null
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('compte'));
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie rejette une transition d'état invalide (Décédé → autre que Décédé) en mode mise à jour.
    * @method Name      :   test_upsertPartie_invalidStateTransition_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_invalidStateTransition_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        ClaimParticipant__c existing = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];
        existing.StateOfPerson__c = 'Décédé';
        update existing;

        Map<String, Object> form = new Map<String, Object>{
            'participantId' => existing.Id,
            'etatPassager'  => 'Indemne'
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, true, acc.Id
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('Transition'));
        }
    }

    /**
    * @description      :   Vérifie que deletePartie supprime le participant et retourne success=true.
    * @method Name      :   test_deletePartie_success
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_deletePartie_success() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];
        Id targetId = p.Id;

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.deletePartie(targetId);
            Test.stopTest();

            System.assertEquals(true, r.get('success'));
            Integer remaining = [SELECT COUNT() FROM ClaimParticipant__c WHERE Id = :targetId];
            System.assertEquals(0, remaining, 'Participant should be deleted');
        }
    }

    /**
    * @description      :   Vérifie que getParticipantById lève une AuraHandledException 'Participant introuvable' quand l'Id pointe sur un enregistrement supprimé.
    * @method Name      :   test_getParticipantById_notFound_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getParticipantById_notFound_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];
        Id missingId = p.Id;
        delete p;

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_AutrePartieAdverseController.getParticipantById(missingId);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    /**
    * @description      :   Vérifie que searchCompagnies exécute la requête et retourne une liste (potentiellement vide) quand le terme contient au moins deux caractères.
    * @method Name      :   test_searchCompagnies_withValidTerm_executesQuery
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_searchCompagnies_withValidTerm_executesQuery() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        insert new Account(Name = 'AXA-COMPAGNIE-TEST');

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> result =
                DA_AutrePartieAdverseController.searchCompagnies('AXA');
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.size() >= 1, 'Should return at least the AXA-COMPAGNIE-TEST account');
            System.assertEquals('AXA-COMPAGNIE-TEST', result[0].get('label'));
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie en mode mise à jour applique tous les champs optionnels (dates, ITT, IPP, revenu, compagnie adverse, description) et retourne success=true.
    * @method Name      :   test_upsertPartie_updateMode_updatesAllFields
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_updateMode_updatesAllFields() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];
        ClaimParticipant__c existing = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];

        Account compagnie = new Account(Name = 'COMPAGNIE_TEST');
        insert compagnie;

        Map<String, Object> form = new Map<String, Object>{
            'participantId'         => existing.Id,
            'typePartieAdverse'     => 'Cyclomoteur',
            'sexe'                  => 'Masculin',
            'pays'                  => 'Maroc',
            'ville'                 => 'Rabat',
            'adresse'               => 'Rue 1',
            'typeContact'           => 'Mail',
            'etatPassager'          => 'Indemne',
            'paysCompagnieAdverse'  => 'Maroc',
            'numeroContrat'         => 'C-001',
            'compagnieAdverseId'    => compagnie.Id,
            'dateNaissance'         => '1990-01-01',
            'dateDeces'             => '2020-01-01',
            'itt'                   => 5,
            'ipp'                   => 2,
            'revenuAnnuel'          => 50000,
            'description'           => 'Test description',
            'nomComplet'            => 'Dupont Jean',
            'email'                 => 'jd@test.com',
            'telephone'             => '0600000000',
            'cin'                   => 'CIN-UPD'
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, true, acc.Id
            );
            Test.stopTest();

            System.assertEquals(true, r.get('success'), (String) r.get('message'));
            ClaimParticipant__c updated = [
                SELECT TypePartieAdverse__c, BirthDay__c, ITT__c, IPP__c,
                       RevenuAnnuel__c, CompagnieAdverse__c, Description__c
                FROM ClaimParticipant__c WHERE Id = :existing.Id
            ];
            System.assertEquals('Cyclomoteur', updated.TypePartieAdverse__c);
            System.assertEquals(Date.newInstance(1990, 1, 1), updated.BirthDay__c);
            System.assertEquals(5, updated.ITT__c);
            System.assertEquals(2, updated.IPP__c);
            System.assertEquals(50000, updated.RevenuAnnuel__c);
            System.assertEquals(compagnie.Id, updated.CompagnieAdverse__c);
            System.assertEquals('Test description', updated.Description__c);
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie refuse une date de naissance postérieure à la date de création du sinistre.
    * @method Name      :   test_upsertPartie_birthDateAfterSinistre_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_birthDateAfterSinistre_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        Map<String, Object> form = new Map<String, Object>{
            'dateNaissance' => String.valueOf(Date.today().addYears(10))
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, false, acc.Id
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('naissance'));
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie refuse une date de décès postérieure à la date de création du sinistre.
    * @method Name      :   test_upsertPartie_deathDateAfterSinistre_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_deathDateAfterSinistre_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        Map<String, Object> form = new Map<String, Object>{
            'dateDeces' => String.valueOf(Date.today().addYears(10))
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, false, acc.Id
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('décès'));
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie rejette la transition Blessé vers un état autre que Blessé ou Décédé.
    * @method Name      :   test_upsertPartie_blesseToInvalidState_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_blesseToInvalidState_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        ClaimParticipant__c existing = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];
        existing.StateOfPerson__c = 'Blessé';
        update existing;

        Map<String, Object> form = new Map<String, Object>{
            'participantId' => existing.Id,
            'etatPassager'  => 'Indemne'
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, true, acc.Id
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('Transition'));
        }
    }

    /**
    * @description      :   Vérifie que upsertPartie attrape les exceptions runtime levées pendant la conversion des champs numériques (Decimal.valueOf sur une chaîne non numérique) et retourne success=false.
    * @method Name      :   test_upsertPartie_malformedNumeric_outerCatch
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsertPartie_malformedNumeric_outerCatch() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        Map<String, Object> form = new Map<String, Object>{
            'itt' => 'not-a-number'
        };

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.upsertPartie(
                form, claim.Id, false, acc.Id
            );
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assertNotEquals(null, r.get('message'));
        }
    }

    /**
    * @description      :   Vérifie que deletePartie sur un enregistrement déjà supprimé passe par friendlyError et retourne success=false avec un message traduit.
    * @method Name      :   test_deletePartie_alreadyDeleted_triggersFriendlyError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_deletePartie_alreadyDeleted_triggersFriendlyError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        ClaimParticipant__c p = [
            SELECT Id FROM ClaimParticipant__c WHERE Roles__c = :ROLE_AUTRE_PARTIE LIMIT 1
        ];
        Id deletedId = p.Id;
        delete p;

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.deletePartie(deletedId);
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assertNotEquals(null, r.get('message'));
        }
    }

    /**
    * @description      :   Vérifie que deletePartie passe par friendlyError lorsqu'une exception est levée (Id d'un autre type d'objet) et retourne success=false avec un message traduit.
    * @method Name      :   test_deletePartie_invalidIdType_triggersFriendlyError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_deletePartie_invalidIdType_triggersFriendlyError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'PARTIE_ACC' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.deletePartie(acc.Id);
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assertNotEquals(null, r.get('message'));
        }
    }

    /**
    * @description      :   Vérifie que deletePartie retourne success=false quand l'Id du participant est null.
    * @method Name      :   test_deletePartie_nullId_returnsError
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_deletePartie_nullId_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> r = DA_AutrePartieAdverseController.deletePartie(null);
            Test.stopTest();

            System.assertEquals(false, r.get('success'));
            System.assert(((String) r.get('message')).contains('participant'));
        }
    }
}
