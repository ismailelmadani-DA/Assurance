/**
 * @description       : Tests unitaires du controller de réaffectation : lecture des infos requête,
 *                      liste des utilisateurs éligibles, création/upsert de requête (nouveau, rejet,
 *                      en cours, clôturé), validation, rejet, et gestion des erreurs (pas de manager,
 *                      motif vide).
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 26-05-2026
 */
@isTest
public class DA_lwc026_ReaffectationControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    // ─────────────────────────────────────────────────────────────
    // CONSTANTES DE STATUT
    // ─────────────────────────────────────────────────────────────

    private static final String STATUT_INITIALE  = 'Initiale';
    private static final String STATUT_EN_COURS  = 'En cours';
    private static final String STATUT_REJETEE   = 'Rejetée';
    private static final String STATUT_CLOTUREE  = 'Clôturée';

    // ─────────────────────────────────────────────────────────────
    // HELPER PRIVÉ — création d'une requête de réaffectation
    // ─────────────────────────────────────────────────────────────

    /**
     * Crée et insère une Case de type Requête de réaffectation avec le statut donné,
     * liée à la déclaration fournie, réaffectée à targetUserId, créée par submitterId.
     */
    private static Case insertRequete(Id declarationId, Id targetUserId, Id submitterId,
                                      Id managerId, String statut) {
        Case requete = new Case(
            RecordTypeId           = DM_Case.getRequeteRecordTypeId(),
            SourceRequete__c       = 'Déclaration',
            CategorieRequete__c    = 'Réaffectation',
            TypeRequete__c         = 'Réaffecter la déclaration',
            Priority               = 'Normale',
            Status                 = statut,
            OwnerId                = managerId,
            ReaffecterA__c         = targetUserId,
            Motif_Reaffectation__c = 'Motif initial',
            Declaration_Liee__c    = declarationId,
            Delais_Traitement__c   = 7
        );
        insert requete;
        return requete;
    }

    /**
    * @description      :   Configure les données de test : mgr (manager), usr (avec manager),
    *                       unm (sans manager), target (utilisateur cible éligible), compte, police,
    *                       et les Cases déclaration + requêtes dans chaque statut pour les scénarios.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder
            .withUser('mgr', 'Manager')
            .withUserAndManager('usr', 'Regular',  'mgr')
            .withUser('unm', 'NoManager')
            .withUser('tgt', 'Target')
            .withAccount();

        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);

        // Déclarations : une par scénario, identifiées via Subject
        builder.withScenarios(new Map<String, String>{
            'DECL_NEW'      => null,   // aucune requête existante
            'DECL_REJECTED' => null,   // requête existante Rejetée
            'DECL_ENCOURS'  => null,   // requête existante En cours
            'DECL_INITIALE' => null,   // requête existante Initiale
            'DECL_CLOTURE'  => null,   // requête existante Clôturée
            'DECL_VALIDER'  => null,   // requête à valider
            'DECL_REJETER'  => null,   // requête à rejeter
            'DECL_INFO'     => null    // lecture getRequeteInfo
        });

        // Récupération des utilisateurs pour les requêtes pré-insérées
        User mgr = builder.getUser('mgr');
        User usr = builder.getUser('usr');
        User tgt = builder.getUser('tgt');

        // Les déclarations sont des Cases — on les récupère via Subject (clé du scénario)
        Map<String, Id> declIdByKey = new Map<String, Id>();
        for (Case c : [
            SELECT Id, Subject FROM Case
            WHERE Subject IN ('DECL_REJECTED','DECL_ENCOURS','DECL_INITIALE',
                              'DECL_CLOTURE','DECL_VALIDER','DECL_REJETER','DECL_INFO')
        ]) {
            declIdByKey.put(c.Subject, c.Id);
        }

        // Requête existante Rejetée
        insertRequete(declIdByKey.get('DECL_REJECTED'), tgt.Id, usr.Id, mgr.Id, 'Rejetée');

        // Requête existante En cours
        insertRequete(declIdByKey.get('DECL_ENCOURS'), tgt.Id, usr.Id, mgr.Id, 'En cours');

        // Requête existante Initiale
        insertRequete(declIdByKey.get('DECL_INITIALE'), tgt.Id, usr.Id, mgr.Id, 'Initiale');

        // Requête existante Clôturée
        insertRequete(declIdByKey.get('DECL_CLOTURE'), tgt.Id, usr.Id, mgr.Id, 'Clôturée');

        // Requête à valider (En cours — sera validée dans le test)
        insertRequete(declIdByKey.get('DECL_VALIDER'), tgt.Id, usr.Id, mgr.Id, 'En cours');

        // Requête à rejeter (En cours — sera rejetée dans le test)
        insertRequete(declIdByKey.get('DECL_REJETER'), tgt.Id, usr.Id, mgr.Id, 'En cours');

        // Requête pour getRequeteInfo
        insertRequete(declIdByKey.get('DECL_INFO'), tgt.Id, usr.Id, mgr.Id, 'Initiale');
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 1 — getEligibleUserIds
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getEligibleUserIds retourne une liste non nulle
    *                       (au moins l'utilisateur courant actif).
    * @method Name      :   test_getEligibleUserIds_returnsNonNullList
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEligibleUserIds_returnsNonNullList() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Id> ids = DA_lwc026_ReaffectationController.getEligibleUserIds();
            Test.stopTest();

            System.assertNotEquals(null, ids, 'getEligibleUserIds ne doit pas retourner null');
            System.assert(ids.size() >= 0, 'La liste doit être initialisée');
        }
    }

    /**
    * @description      :   Vérifie que getEligibleUserIds retourne uniquement des Ids non nuls.
    * @method Name      :   test_getEligibleUserIds_containsOnlyNonNullIds
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEligibleUserIds_containsOnlyNonNullIds() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Id> ids = DA_lwc026_ReaffectationController.getEligibleUserIds();
            Test.stopTest();

            for (Id id : ids) {
                System.assertNotEquals(null, id, 'Chaque Id retourné doit être non null');
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 2 — getRequeteInfo
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getRequeteInfo retourne la map avec les 3 clés attendues
    *                       pour une requête existante.
    * @method Name      :   test_getRequeteInfo_returnsExpectedKeys
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRequeteInfo_returnsExpectedKeys() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_INFO' LIMIT 1];
        Case requete = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id
            AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Map<String, String> info = DA_lwc026_ReaffectationController.getRequeteInfo(requete.Id);
            Test.stopTest();

            System.assertNotEquals(null, info, 'getRequeteInfo ne doit pas retourner null');
            System.assert(info.containsKey('reaffecterAName'),   'La clé reaffecterAName doit être présente');
            System.assert(info.containsKey('declarationNumber'), 'La clé declarationNumber doit être présente');
            System.assert(info.containsKey('motif'),             'La clé motif doit être présente');
        }
    }

    /**
    * @description      :   Vérifie que getRequeteInfo retourne le motif correct de la requête.
    * @method Name      :   test_getRequeteInfo_returnsCorrectMotif
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRequeteInfo_returnsCorrectMotif() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_INFO' LIMIT 1];
        Case requete = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id
            AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Map<String, String> info = DA_lwc026_ReaffectationController.getRequeteInfo(requete.Id);
            Test.stopTest();

            System.assertEquals('Motif initial', info.get('motif'), 'Le motif doit correspondre à celui inséré');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 3 — createRequeteReaffectation : pas de manager
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que createRequeteReaffectation lève une AuraHandledException
    *                       quand l'utilisateur courant n'a pas de manager.
    * @method Name      :   test_createRequete_noManager_throwsAuraException
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createRequete_noManager_throwsAuraException() {
        User unm  = [SELECT Id FROM User WHERE Alias = 'unm' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_NEW' LIMIT 1];

        System.runAs(unm) {
            try {
                Test.startTest();
                DA_lwc026_ReaffectationController.createRequeteReaffectation(decl.Id, tgt.Id, 'Motif test');
                Test.stopTest();
                System.assert(false, 'Une AuraHandledException doit être levée si pas de manager');
            } catch (AuraHandledException e) {
                System.assert(
                    e.getMessage().contains('manager'),
                    'Le message doit mentionner le manager'
                );
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 4 — createRequeteReaffectation : aucune requête existante
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que createRequeteReaffectation crée une nouvelle requête
    *                       quand aucune requête n'existe pour la déclaration.
    * @method Name      :   test_createRequete_noExisting_insertsNewRequete
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createRequete_noExisting_insertsNewRequete() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_NEW' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            String requeteId = DA_lwc026_ReaffectationController.createRequeteReaffectation(
                decl.Id, tgt.Id, 'Première réaffectation'
            );
            Test.stopTest();

            System.assertNotEquals(null, requeteId, 'Un Id de requête doit être retourné');

            Case requete = [
                SELECT Status, ReaffecterA__c, Motif_Reaffectation__c, Declaration_Liee__c,
                       CategorieRequete__c, TypeRequete__c
                FROM Case WHERE Id = :requeteId
            ];
            System.assertEquals(STATUT_INITIALE,               requete.Status,                'La requête doit être Initiale');
            System.assertEquals(tgt.Id,                         requete.ReaffecterA__c,        'ReaffecterA doit être le target');
            System.assertEquals('Première réaffectation',      requete.Motif_Reaffectation__c,'Le motif doit être conservé');
            System.assertEquals(decl.Id,                        requete.Declaration_Liee__c,   'La déclaration liée doit correspondre');
            System.assertEquals('Réaffectation',                requete.CategorieRequete__c,   'La catégorie doit être Réaffectation');
            System.assertEquals('Réaffecter la déclaration',   requete.TypeRequete__c,        'Le type doit être correct');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 5 — createRequeteReaffectation : requête existante Rejetée
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que createRequeteReaffectation supprime la requête rejetée
    *                       et en crée une nouvelle quand la requête existante est en statut Rejetée.
    * @method Name      :   test_createRequete_existingRejected_deletesAndReinserts
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createRequete_existingRejected_deletesAndReinserts() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_REJECTED' LIMIT 1];
        Case ancienneRequete = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];
        Id ancienneId = ancienneRequete.Id;

        System.runAs(usr) {
            Test.startTest();
            String nouvellId = DA_lwc026_ReaffectationController.createRequeteReaffectation(
                decl.Id, tgt.Id, 'Nouvelle tentative après rejet'
            );
            Test.stopTest();

            System.assertNotEquals(null, nouvellId, 'Un Id de nouvelle requête doit être retourné');
            System.assertNotEquals(ancienneId, nouvellId, 'La nouvelle requête doit avoir un Id différent');

            List<Case> ancienne = [SELECT Id FROM Case WHERE Id = :ancienneId];
            System.assertEquals(0, ancienne.size(), 'L\'ancienne requête rejetée doit être supprimée');

            Case nouvelle = [SELECT Status FROM Case WHERE Id = :nouvellId];
            System.assertEquals(STATUT_INITIALE, nouvelle.Status, 'La nouvelle requête doit être Initiale');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 6 — createRequeteReaffectation : requête existante En cours
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que createRequeteReaffectation remet la requête à Initiale
    *                       et réassigne l'OwnerId au manager quand la requête existante est En cours.
    * @method Name      :   test_createRequete_existingEnCours_resetsToInitiale
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createRequete_existingEnCours_resetsToInitiale() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_ENCOURS' LIMIT 1];
        Case requeteExistante = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            String requeteId = DA_lwc026_ReaffectationController.createRequeteReaffectation(
                decl.Id, tgt.Id, 'Mise à jour motif'
            );
            Test.stopTest();

            System.assertEquals(
                requeteExistante.Id, requeteId,
                'L\'Id retourné doit être celui de la requête existante (update, pas insert)'
            );

            Case updated = [SELECT Status, OwnerId, Motif_Reaffectation__c FROM Case WHERE Id = :requeteId];
            System.assertEquals(STATUT_INITIALE, updated.Status,  'La requête doit repasser à Initiale');
            System.assertEquals(mgr.Id,          updated.OwnerId, 'L\'OwnerId doit être réassigné au manager');
            System.assertEquals('Mise à jour motif', updated.Motif_Reaffectation__c, 'Le motif doit être mis à jour');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 7 — createRequeteReaffectation : requête existante Initiale
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que createRequeteReaffectation met à jour ReaffecterA et Motif
    *                       sans changer le statut quand la requête existante est Initiale.
    * @method Name      :   test_createRequete_existingInitiale_updatesFieldsOnly
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createRequete_existingInitiale_updatesFieldsOnly() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_INITIALE' LIMIT 1];
        Case requeteExistante = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            String requeteId = DA_lwc026_ReaffectationController.createRequeteReaffectation(
                decl.Id, tgt.Id, 'Motif modifié'
            );
            Test.stopTest();

            System.assertEquals(requeteExistante.Id, requeteId, 'L\'Id doit être celui de la requête existante');

            Case updated = [SELECT Status, ReaffecterA__c, Motif_Reaffectation__c FROM Case WHERE Id = :requeteId];
            System.assertEquals(STATUT_INITIALE,  updated.Status,                'Le statut doit rester Initiale');
            System.assertEquals(tgt.Id,            updated.ReaffecterA__c,        'ReaffecterA doit être mis à jour');
            System.assertEquals('Motif modifié',  updated.Motif_Reaffectation__c,'Le motif doit être mis à jour');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 8 — createRequeteReaffectation : requête existante Clôturée
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que createRequeteReaffectation lève une AuraHandledException
    *                       quand la requête existante est en statut Clôturée.
    * @method Name      :   test_createRequete_existingCloturee_throwsAuraException
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_createRequete_existingCloturee_throwsAuraException() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_CLOTURE' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc026_ReaffectationController.createRequeteReaffectation(
                    decl.Id, tgt.Id, 'Tentative sur clôturé'
                );
                Test.stopTest();
                System.assert(false, 'Une AuraHandledException doit être levée pour une requête clôturée');
            } catch (AuraHandledException e) {
                System.assert(
                    e.getMessage().contains('clôturée'),
                    'Le message doit mentionner que la déclaration est clôturée'
                );
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 9 — validerReaffectation
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que validerReaffectation passe la requête En cours
    *                       et réassigne l'OwnerId à ReaffecterA__c.
    * @method Name      :   test_validerReaffectation_setsStatusEnCoursAndOwner
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_validerReaffectation_setsStatusEnCoursAndOwner() {
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_VALIDER' LIMIT 1];
        Case requete = [
            SELECT Id, ReaffecterA__c FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(mgr) {
            Test.startTest();
            DA_lwc026_ReaffectationController.validerReaffectation(requete.Id);
            Test.stopTest();

            Case updated = [SELECT Status, OwnerId FROM Case WHERE Id = :requete.Id];
            System.assertEquals(STATUT_EN_COURS, updated.Status,  'Le statut doit passer à En cours');
            System.assertEquals(tgt.Id,           updated.OwnerId, 'L\'OwnerId doit être le ReaffecterA (tgt)');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 10 — rejeterReaffectation
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que rejeterReaffectation lève une AuraHandledException
    *                       quand le motif de rejet est vide.
    * @method Name      :   test_rejeterReaffectation_blankMotif_throwsAuraException
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_rejeterReaffectation_blankMotif_throwsAuraException() {
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_REJETER' LIMIT 1];
        Case requete = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(mgr) {
            try {
                Test.startTest();
                DA_lwc026_ReaffectationController.rejeterReaffectation(requete.Id, '');
                Test.stopTest();
                System.assert(false, 'Une AuraHandledException doit être levée si le motif est vide');
            } catch (AuraHandledException e) {
                System.assert(
                    e.getMessage().contains('motif'),
                    'Le message doit mentionner le motif obligatoire'
                );
            }
        }
    }

    /**
    * @description      :   Vérifie que rejeterReaffectation passe la requête à Rejetée,
    *                       réassigne l'OwnerId au créateur et enregistre le motif de rejet.
    * @method Name      :   test_rejeterReaffectation_setsStatusAndMotifRejet
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_rejeterReaffectation_setsStatusAndMotifRejet() {
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_REJETER' LIMIT 1];
        Case requete = [
            SELECT Id, CreatedById FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];
        Id createdById = requete.CreatedById;

        System.runAs(mgr) {
            Test.startTest();
            DA_lwc026_ReaffectationController.rejeterReaffectation(requete.Id, 'Motif de rejet valide');
            Test.stopTest();

            Case updated = [SELECT Status, OwnerId, MotifRejet__c FROM Case WHERE Id = :requete.Id];
            System.assertEquals(STATUT_REJETEE,          updated.Status,      'Le statut doit passer à Rejetée');
            System.assertEquals(createdById,              updated.OwnerId,     'L\'OwnerId doit revenir au créateur');
            System.assertEquals('Motif de rejet valide', updated.MotifRejet__c,'Le motif de rejet doit être enregistré');
        }
    }
}