/**
 * @description       : Tests unitaires du controller de gestion des prestataires :
 *                      lecture, création, modification, génération de code, picklists.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 22-05-2026
 * @last modified by  : D&A Technologies
 */
@isTest
public class DA_lwc016_prestataireListControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    // ============================================================
    // SETUP
    // ============================================================

    @TestSetup
    static void setupTestData() {
        builder
            .withUser('usr', 'Standard')
            .withPrestataire('Garagiste')        // index 0 — aura un RIB
            .withPrestataire('Avocat')            // index 1 — sans RIB, pour update
            .withPrestataire('Expert Automobile') // index 2 — pour searchTerm
            .withPrestataire('Garagiste');        // index 3 — 2ème Garagiste pour countByType

        Account premierGaragiste = [
            SELECT Id FROM Account
            WHERE TypeDePrestataire__c = 'Garagiste'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        builder.withRib(premierGaragiste.Id);
    }

    // ============================================================
    // GET PRESTATAIRES — sans filtre
    // ============================================================

    @isTest
    static void test_getPrestataires_noFilter_returnsAll() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc016_prestataireListController.PrestataireWrapper> results =
                DA_lwc016_prestataireListController.getPrestataires(null, null);
            Test.stopTest();

            System.assert(results.size() >= 4, 'Should return at least 4 prestataires');
        }
    }

    // ============================================================
    // GET PRESTATAIRES — filtre par type
    // ============================================================

    @isTest
    static void test_getPrestataires_typeFilter_returnsFiltered() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc016_prestataireListController.PrestataireWrapper> results =
                DA_lwc016_prestataireListController.getPrestataires('Avocat', null);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should return only Avocat prestataires');
            System.assertEquals('Avocat', results[0].type);
        }
    }

    // ============================================================
    // GET PRESTATAIRES — filtre par searchTerm
    // ============================================================

    @isTest
    static void test_getPrestataires_searchTerm_returnsMatching() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        // FIX : ajout de Name dans le SELECT
        Account prest = [
            SELECT Id, Name FROM Account
            WHERE TypeDePrestataire__c = 'Expert Automobile'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc016_prestataireListController.PrestataireWrapper> results =
                DA_lwc016_prestataireListController.getPrestataires(null, prest.Name);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should match exactly 1 by name');
            System.assertEquals(prest.Name, results[0].name);
        }
    }

    // ============================================================
    // GET PRESTATAIRES — RIB attaché au wrapper
    // ============================================================

    @isTest
    static void test_getPrestataires_withRib_ribFieldsPopulated() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        // FIX : ajout de Name dans le SELECT pour pouvoir l'utiliser comme searchTerm
        Account prest = [
            SELECT Id, Name FROM Account
            WHERE TypeDePrestataire__c = 'Garagiste'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc016_prestataireListController.PrestataireWrapper> results =
                DA_lwc016_prestataireListController.getPrestataires(null, prest.Name);
            Test.stopTest();

            System.assertEquals(1, results.size());
            DA_lwc016_prestataireListController.PrestataireWrapper w = results[0];
            System.assertNotEquals(null, w.ribId,  'ribId should be populated');
            System.assertNotEquals(null, w.rib,    'rib should be populated');
            System.assertEquals(true,  w.actif,   'RIB should be actif');
            System.assertEquals('RIB Validé', w.statutRib, 'Statut should be RIB Validé');
        }
    }

    // ============================================================
    // GET PRESTATAIRES — sans RIB, champs RIB null
    // ============================================================

    @isTest
    static void test_getPrestataires_withoutRib_ribFieldsNull() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<DA_lwc016_prestataireListController.PrestataireWrapper> results =
                DA_lwc016_prestataireListController.getPrestataires('Avocat', null);
            Test.stopTest();

            System.assertEquals(1, results.size());
            DA_lwc016_prestataireListController.PrestataireWrapper w = results[0];
            System.assertEquals(null, w.ribId, 'ribId should be null when no RIB');
            System.assertEquals(null, w.rib,   'rib should be null when no RIB');
        }
    }

    // ============================================================
    // SAVE PRESTATAIRE — création avec RIB
    // ============================================================

    @isTest
    static void test_savePrestataire_create_insertsAccountAndRib() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        DA_lwc016_prestataireListController.SaveRequest req =
            new DA_lwc016_prestataireListController.SaveRequest();
        req.name    = 'Nouveau Prestataire Test';
        req.type    = 'Médecin';
        req.phone   = '0612345678';
        req.email   = 'med@test.com';
        req.ville   = 'Casablanca';
        req.adresse = '5 Avenue Test';
        req.pays    = 'Maroc';
        req.banque  = '007';
        req.rib     = '007123456789012345678901';

        System.runAs(usr) {
            Test.startTest();
            String newId = DA_lwc016_prestataireListController.savePrestataire(req);
            Test.stopTest();

            System.assertNotEquals(null, newId, 'Should return the new Account Id');

            Account acc = [SELECT Name, TypeDePrestataire__c, codeTier__c FROM Account WHERE Id = :newId];
            System.assertEquals('Nouveau Prestataire Test', acc.Name);
            System.assertEquals('Médecin', acc.TypeDePrestataire__c);
            System.assert(acc.codeTier__c.startsWith('MED-'), 'Code should start with MED-');

            List<RIB__c> ribs = [SELECT Id FROM RIB__c WHERE ParticipantAccount__c = :newId];
            System.assertEquals(1, ribs.size(), 'A RIB should have been created');
        }
    }

    // ============================================================
    // SAVE PRESTATAIRE — création sans RIB
    // ============================================================

    @isTest
    static void test_savePrestataire_create_withoutRib_noRibCreated() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        DA_lwc016_prestataireListController.SaveRequest req =
            new DA_lwc016_prestataireListController.SaveRequest();
        req.name = 'Prestataire Sans RIB';
        req.type = 'Pharmacie';
        req.pays = 'Maroc';

        System.runAs(usr) {
            Test.startTest();
            String newId = DA_lwc016_prestataireListController.savePrestataire(req);
            Test.stopTest();

            List<RIB__c> ribs = [SELECT Id FROM RIB__c WHERE ParticipantAccount__c = :newId];
            System.assertEquals(0, ribs.size(), 'No RIB should be created when rib and banque are blank');
        }
    }

    // ============================================================
    // SAVE PRESTATAIRE — modification sans changement de type
    // ============================================================

    @isTest
    static void test_savePrestataire_update_sameType_codeUnchanged() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account existing = [
            SELECT Id, codeTier__c FROM Account
            WHERE TypeDePrestataire__c = 'Avocat'
            LIMIT 1
        ];

        DA_lwc016_prestataireListController.SaveRequest req =
            new DA_lwc016_prestataireListController.SaveRequest();
        req.id      = existing.Id;
        req.name    = 'Avocat Modifié';
        req.type    = 'Avocat';
        req.oldType = 'Avocat';
        req.pays    = 'Maroc';

        System.runAs(usr) {
            Test.startTest();
            DA_lwc016_prestataireListController.savePrestataire(req);
            Test.stopTest();

            Account updated = [SELECT Name, codeTier__c FROM Account WHERE Id = :existing.Id];
            System.assertEquals('Avocat Modifié', updated.Name);
            System.assertEquals(existing.codeTier__c, updated.codeTier__c, 'Code should not change when type is unchanged');
        }
    }

    // ============================================================
    // SAVE PRESTATAIRE — modification avec changement de type
    // ============================================================

    @isTest
    static void test_savePrestataire_update_typeChanged_codeRegenerated() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        // FIX : ajout de Name dans le SELECT (même si on ne l'utilise pas ici,
        //       on ajoute codeTier__c qui était déjà présent — le vrai fix est
        //       que la ligne 256 faisait existing.Name sur un SELECT Id-only)
        Account existing = [
            SELECT Id, Name, codeTier__c FROM Account
            WHERE TypeDePrestataire__c = 'Avocat'
            LIMIT 1
        ];

        DA_lwc016_prestataireListController.SaveRequest req =
            new DA_lwc016_prestataireListController.SaveRequest();
        req.id      = existing.Id;
        req.name    = existing.Name;  // <-- c'était la ligne 256 qui crashait
        req.type    = 'Clinique';
        req.oldType = 'Avocat';
        req.pays    = 'Maroc';

        System.runAs(usr) {
            Test.startTest();
            DA_lwc016_prestataireListController.savePrestataire(req);
            Test.stopTest();

            Account updated = [SELECT codeTier__c FROM Account WHERE Id = :existing.Id];
            System.assertNotEquals(existing.codeTier__c, updated.codeTier__c, 'Code should be regenerated when type changes');
            System.assert(updated.codeTier__c.startsWith('CLI-'), 'New code should start with CLI-');
        }
    }

    // ============================================================
    // SAVE PRESTATAIRE — validation : nom manquant
    // ============================================================

    @isTest
    static void test_savePrestataire_missingName_throwsException() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        DA_lwc016_prestataireListController.SaveRequest req =
            new DA_lwc016_prestataireListController.SaveRequest();
        req.type = 'Garagiste';

        System.runAs(usr) {
            Boolean exceptionThrown = false;
            Test.startTest();
            try {
                DA_lwc016_prestataireListController.savePrestataire(req);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
                // FIX : AuraHandledException.getMessage() retourne 'Script-thrown exception'
                //       en contexte de test Apex — on vérifie juste que l'exception est levée
                System.assert(true, 'AuraHandledException correctly thrown for missing name');
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Should have thrown AuraHandledException when name is blank');
        }
    }

    // ============================================================
    // SAVE PRESTATAIRE — validation : type manquant
    // ============================================================

    @isTest
    static void test_savePrestataire_missingType_throwsException() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        DA_lwc016_prestataireListController.SaveRequest req =
            new DA_lwc016_prestataireListController.SaveRequest();
        req.name = 'Test Sans Type';

        System.runAs(usr) {
            Boolean exceptionThrown = false;
            Test.startTest();
            try {
                DA_lwc016_prestataireListController.savePrestataire(req);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
                // FIX : même raison — getMessage() non fiable en test Apex pour AuraHandledException
                System.assert(true, 'AuraHandledException correctly thrown for missing type');
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Should have thrown AuraHandledException when type is blank');
        }
    }

    // ============================================================
    // GENERATE CODE — préfixes connus et inconnus
    // ============================================================

    @isTest
    static void test_generateCode_returnsCorrectPrefix() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            String codeExp = DA_lwc016_prestataireListController.generateCode('Expert Automobile');
            String codeGar = DA_lwc016_prestataireListController.generateCode('Garagiste');
            String codeMed = DA_lwc016_prestataireListController.generateCode('Médecin');
            String codeUnk = DA_lwc016_prestataireListController.generateCode('TypeInconnu');
            Test.stopTest();

            System.assert(codeExp.startsWith('EXP-'), 'Expert Automobile should use EXP prefix');
            System.assert(codeGar.startsWith('GAR-'), 'Garagiste should use GAR prefix');
            System.assert(codeMed.startsWith('MED-'), 'Médecin should use MED prefix');
            System.assert(codeUnk.startsWith('PRE-'), 'Unknown type should use PRE prefix');
        }
    }

    // ============================================================
    // GENERATE CODE — format du numéro padded
    // ============================================================

    @isTest
    static void test_generateCode_format_isPaddedWithZeros() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            String code = DA_lwc016_prestataireListController.generateCode('Hôpital');
            Test.stopTest();

            System.assert(code.contains('-'), 'Code should contain a dash separator');
            List<String> parts = code.split('-');
            System.assertEquals(2, parts.size(), 'Code should have exactly 2 parts');
            System.assertEquals(4, parts[1].length(), 'Number part should be 4 digits padded');
        }
    }

    // ============================================================
    // PICKLISTS — getBanqueOptions
    // ============================================================

    @isTest
    static void test_getBanqueOptions_returnsNonEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> opts =
                DA_lwc016_prestataireListController.getBanqueOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'Should not be null');
            System.assert(!opts.isEmpty(), 'Should return at least one banque option');
            System.assertNotEquals(null, opts[0].get('label'), 'Each option should have a label');
            System.assertNotEquals(null, opts[0].get('value'), 'Each option should have a value');
        }
    }

    // ============================================================
    // PICKLISTS — getPaysOptions
    // ============================================================

    @isTest
    static void test_getPaysOptions_returnsNonEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> opts =
                DA_lwc016_prestataireListController.getPaysOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'Should not be null');
            System.assert(!opts.isEmpty(), 'Should return at least one pays option');
        }
    }

    // ============================================================
    // PICKLISTS — getDependentVilleOptions
    // ============================================================

    @isTest
    static void test_getDependentVilleOptions_containsMaroc() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> opts =
                DA_lwc016_prestataireListController.getDependentVilleOptions();
            Test.stopTest();

            System.assertNotEquals(null, opts, 'Should not be null');
            System.assert(!opts.isEmpty(), 'Should return dependent ville options');
            System.assert(opts.containsKey('Maroc'), 'Should contain Maroc as a key');
            System.assert(!opts.get('Maroc').isEmpty(), 'Maroc should have at least one ville');
        }
    }
}