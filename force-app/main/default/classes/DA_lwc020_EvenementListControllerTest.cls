/**
 * @description       : Tests unitaires du controller de gestion des événements : lecture de la liste avec filtres, création, modification d'un événement et validation des règles métier
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 25-05-2026
 */
@isTest
public class DA_lwc020_EvenementListControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    /**
    * @description      :   Configure les données de test : utilisateur standard et 4 scénarios d'événements (GET_LIST, GET_CAT_FILTER, GET_SEARCH, SAVE_UPDATE).
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder
            .withUser('usr', 'Regular')
            .withScenarioEvenements(new Map<String, Map<String, Object>>{
                'GET_LIST'       => null,
                'GET_CAT_FILTER' => new Map<String, Object>{
                    'Type__c'  => 'Inondation',
                    'Ville__c' => 'Rabat'
                },
                'GET_SEARCH'     => new Map<String, Object>{
                    'Libelle__c' => 'TermeRechercheUnique',
                    'Type__c'    => 'Tempête / Ouragan',
                    'Ville__c'   => 'Tanger'
                },
                'SAVE_UPDATE'    => new Map<String, Object>{
                    'Libelle__c' => 'SAVE_UPDATE',
                    'Ville__c'   => 'Fes'
                }
            });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getEvenements
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getEvenements retourne la liste des événements sans filtre avec tous les champs du wrapper mappés.
    * @method Name      :   test_getEvenements_noFilter_returnsList
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEvenements_noFilter_returnsList() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc020_EvenementListController.EvenementWrapper> result =
                DA_lwc020_EvenementListController.getEvenements(null, null, null);
            Test.stopTest();

            System.assert(result != null, 'Result should not be null');
            System.assert(result.size() >= 4, 'Should return at least the 4 test events');

            DA_lwc020_EvenementListController.EvenementWrapper w = result[0];
            System.assertNotEquals(null, w.id,        'id should be populated');
            System.assertNotEquals(null, w.libelle,   'libelle should be populated');
            System.assertNotEquals(null, w.categorie, 'categorie should be populated');
            System.assertNotEquals(null, w.type,      'type should be populated');
            System.assertNotEquals(null, w.dateDebut, 'dateDebut should be populated');
            System.assertNotEquals(null, w.pays,      'pays should be populated');
            System.assertNotEquals(null, w.ville,     'ville should be populated');
        }
    }

    /**
    * @description      :   Vérifie que getEvenements filtre correctement par catégorie.
    * @method Name      :   test_getEvenements_catFilter_returnsFilteredList
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEvenements_catFilter_returnsFilteredList() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc020_EvenementListController.EvenementWrapper> result =
                DA_lwc020_EvenementListController.getEvenements('Catastrophe Naturelle', null, null);
            Test.stopTest();

            System.assert(result.size() >= 2, 'Should return events matching the category filter');
            for (DA_lwc020_EvenementListController.EvenementWrapper w : result) {
                System.assertEquals('Catastrophe Naturelle', w.categorie, 'All results should match the category filter');
            }
        }
    }

    /**
    * @description      :   Vérifie que getEvenements retourne exactement l'événement dont le libellé correspond au terme recherché.
    * @method Name      :   test_getEvenements_searchTerm_returnsMatchingEvent
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEvenements_searchTerm_returnsMatchingEvent() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc020_EvenementListController.EvenementWrapper> result =
                DA_lwc020_EvenementListController.getEvenements(null, null, 'TermeRechercheUnique');
            Test.stopTest();

            System.assertEquals(1, result.size(), 'Should return exactly one event matching the search term');
            System.assert(result[0].libelle.contains('TermeRechercheUnique'), 'Returned event should match the search term');
        }
    }

    /**
    * @description      :   Vérifie que getEvenements filtre correctement par période prédéfinie (month).
    * @method Name      :   test_getEvenements_periodFilter_month_returnsEvents
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEvenements_periodFilter_month_returnsEvents() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc020_EvenementListController.EvenementWrapper> result =
                DA_lwc020_EvenementListController.getEvenements(null, 'month', null);
            Test.stopTest();

            System.assert(result != null, 'Result should not be null');
            System.assert(result.size() >= 4, 'All test events start this month, so all should be returned');
        }
    }

    /**
    * @description      :   Vérifie que getEvenements filtre correctement par période personnalisée (custom).
    * @method Name      :   test_getEvenements_periodFilter_custom_returnsEvents
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getEvenements_periodFilter_custom_returnsEvents() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        String customFilter = 'custom|' + String.valueOf(Date.today().addDays(-1))
                            + '|'       + String.valueOf(Date.today().addDays(1));

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc020_EvenementListController.EvenementWrapper> result =
                DA_lwc020_EvenementListController.getEvenements(null, customFilter, null);
            Test.stopTest();

            System.assert(result != null, 'Result should not be null for custom period filter');
            System.assert(result.size() >= 4, 'All test events should fall in the custom date range');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // saveEvenement — Validations métier
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand le libellé est vide.
    * @method Name      :   test_saveEvenement_blankLibelle_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_blankLibelle_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.libelle = '';

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('libellé'), 'Exception message should mention libellé');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand la catégorie est vide.
    * @method Name      :   test_saveEvenement_blankCategorie_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_blankCategorie_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.categorie = '';

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('catégorie'), 'Exception message should mention catégorie');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand le type est vide.
    * @method Name      :   test_saveEvenement_blankType_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_blankType_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.type = '';

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('type'), 'Exception message should mention type');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand la date de début est nulle.
    * @method Name      :   test_saveEvenement_nullDateDebut_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_nullDateDebut_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.dateDebut = null;

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('date de début'), 'Exception message should mention date de début');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand le pays est vide.
    * @method Name      :   test_saveEvenement_blankPays_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_blankPays_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.pays = '';

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('pays'), 'Exception message should mention pays');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand la ville est vide.
    * @method Name      :   test_saveEvenement_blankVille_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_blankVille_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.ville = '';

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('ville'), 'Exception message should mention ville');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement lève une exception quand la date de fin est antérieure à la date de début.
    * @method Name      :   test_saveEvenement_dateFinBeforeDateDebut_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_dateFinBeforeDateDebut_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.dateDebut = Date.today();
        req.dateFin   = Date.today().addDays(-1);

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc020_EvenementListController.saveEvenement(req);
                Test.stopTest();
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('date de fin'), 'Exception message should mention date de fin');
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // saveEvenement — Création et mise à jour
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que saveEvenement crée un nouvel événement et retourne son Id avec les champs correctement persistés.
    * @method Name      :   test_saveEvenement_validCreate_returnsId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_validCreate_returnsId() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();

        System.runAs(usr) {
            Test.startTest();
            String returnedId = DA_lwc020_EvenementListController.saveEvenement(req);
            Test.stopTest();

            System.assertNotEquals(null, returnedId, 'saveEvenement should return the new record Id');

            Evenement__c created = [SELECT Libelle__c, Categorie__c, Type__c, Pays__c, Ville__c FROM Evenement__c WHERE Id = :returnedId];
            System.assertEquals(req.libelle,   created.Libelle__c,   'Libelle should match');
            System.assertEquals(req.categorie, created.Categorie__c, 'Categorie should match');
            System.assertEquals(req.type,      created.Type__c,      'Type should match');
            System.assertEquals(req.pays,      created.Pays__c,      'Pays should match');
            System.assertEquals(req.ville,     created.Ville__c,     'Ville should match');
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement met à jour un événement existant quand un Id est fourni et retourne le même Id.
    * @method Name      :   test_saveEvenement_validUpdate_updatesRecord
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_validUpdate_updatesRecord() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Evenement__c existing = [SELECT Id FROM Evenement__c WHERE Libelle__c = 'SAVE_UPDATE' LIMIT 1];

        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.id      = existing.Id;
        req.libelle = 'SAVE_UPDATE_MODIFIE';

        System.runAs(usr) {
            Test.startTest();
            String returnedId = DA_lwc020_EvenementListController.saveEvenement(req);
            Test.stopTest();

            System.assertEquals(existing.Id, returnedId, 'Returned Id should match the existing record Id');

            Evenement__c updated = [SELECT Libelle__c FROM Evenement__c WHERE Id = :existing.Id];
            System.assertEquals('SAVE_UPDATE_MODIFIE', updated.Libelle__c, 'Libelle should have been updated');
        }
    }

    /**
    * @description      :   Vérifie que saveEvenement accepte un événement sans date de fin (dateFin optionnelle).
    * @method Name      :   test_saveEvenement_nullDateFin_succeeds
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveEvenement_nullDateFin_succeeds() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        DA_lwc020_EvenementListController.SaveRequest req = buildValidRequest();
        req.dateFin = null;

        System.runAs(usr) {
            Test.startTest();
            String returnedId = DA_lwc020_EvenementListController.saveEvenement(req);
            Test.stopTest();

            System.assertNotEquals(null, returnedId, 'Should succeed with null dateFin');

            Evenement__c created = [SELECT DateFin__c FROM Evenement__c WHERE Id = :returnedId];
            System.assertEquals(null, created.DateFin__c, 'DateFin should be null on the created record');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Picklists
    // ═══════════════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getCategorieOptions retourne une liste non nulle.
    * @method Name      :   test_getCategorieOptions_returnsList
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCategorieOptions_returnsList() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> opts = DA_lwc020_EvenementListController.getCategorieOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'getCategorieOptions should not return null');
        }
    }

    /**
    * @description      :   Vérifie que getPaysOptions retourne une liste non nulle.
    * @method Name      :   test_getPaysOptions_returnsList
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getPaysOptions_returnsList() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> opts = DA_lwc020_EvenementListController.getPaysOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'getPaysOptions should not return null');
        }
    }

    /**
    * @description      :   Vérifie que getDependentTypeOptions retourne une map non nulle.
    * @method Name      :   test_getDependentTypeOptions_returnsMap
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getDependentTypeOptions_returnsMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> opts = DA_lwc020_EvenementListController.getDependentTypeOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'getDependentTypeOptions should not return null');
        }
    }

    /**
    * @description      :   Vérifie que getDependentVilleOptions retourne une map non nulle.
    * @method Name      :   test_getDependentVilleOptions_returnsMap
    * @Author           :   D&A Technologies
    * @date             :   2026-05-25
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getDependentVilleOptions_returnsMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> opts = DA_lwc020_EvenementListController.getDependentVilleOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'getDependentVilleOptions should not return null');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HELPER PRIVÉ — Construction d'une SaveRequest valide
    // ═══════════════════════════════════════════════════════════════════════

    private static DA_lwc020_EvenementListController.SaveRequest buildValidRequest() {
        DA_lwc020_EvenementListController.SaveRequest req = new DA_lwc020_EvenementListController.SaveRequest();
        req.libelle   = 'Événement Test';
        req.categorie = 'Catastrophe Naturelle';
        req.type      = 'Inondation';
        req.dateDebut = Date.today();
        req.dateFin   = Date.today().addDays(3);
        req.pays      = 'Maroc';
        req.ville     = 'Casablanca';
        return req;
    }
}