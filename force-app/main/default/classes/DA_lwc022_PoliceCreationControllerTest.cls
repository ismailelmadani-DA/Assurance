/**
 * @description       : Tests unitaires du controller de création de police : vérification CIN/immatriculation,
 *                      prévisualisation du numéro de police, création avec nouveau compte/véhicule,
 *                      réaffectation d'un véhicule existant, résiliation de l'ancienne police,
 *                      insertion des garanties, et gestion des erreurs.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 26-05-2026
 */
@isTest
public class DA_lwc022_PoliceCreationControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    // ─────────────────────────────────────────────────────────────
    // HELPERS PRIVÉS
    // ─────────────────────────────────────────────────────────────

    private static String buildFormData(Map<String, String> overrides) {
        Map<String, String> base = new Map<String, String>{
            'cin'                 => 'CINTEST001',
            'nomComplet'          => 'Test Assuré',
            'telephone'           => '0600000001',
            'email'               => 'test@example.com',
            'adresse'             => '1 Rue Test',
            'pays'                => 'Maroc',
            'ville'               => 'Casablanca',
            'categorie'           => 'Individuelle',
            'dateEffet'           => String.valueOf(Date.today()),
            'dateExpiration'      => String.valueOf(Date.today().addYears(1)),
            'canal'               => 'Agent',
            'situationPolice'     => 'En cours',
            'situationPrime'      => 'Non payée',
            'immatriculation'     => 'AA-TEST-01',
            'numeroChassis'       => 'CH-TEST-001',
            'numeroAttestation'   => 'AT-TEST-001',
            'typeVehicule'        => 'Voiture',
            'marque'              => 'Renault',
            'modele'              => 'Clio',
            'dateMiseEnCirculation' => String.valueOf(Date.today().addYears(-2)),
            'numeroPolice'        => 'P-00099'
        };
        if (overrides != null) {
            base.putAll(overrides);
        }
        return JSON.serialize(base);
    }

    private static String buildGarantieJson(String nom, String code, String type) {
        return JSON.serialize(new Map<String, String>{
            'nom'  => nom,
            'code' => code,
            'type' => type
        });
    }

    /**
    * @description      :   Configure les données de test : utilisateurs, compte, police, véhicules bloqués/libres
    *                       et comptes avec CIN existant pour les scénarios checkCin et checkImmatriculation.
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
            .withUser('usr', 'Regular')
            .withAccount();

        // Compte avec CIN existant (pour checkCin et creerPolice avec upsert)
        Account accWithCin = DA_TestDataFactory.createTestAccount(new Map<String, Object>{
            'CIN__c' => 'CIN_EXISTANT_001'
        });
        insert accWithCin;

        // Police existante + véhicule libre (non bloqué : Status Initiale / SituationPrime Non payée)
        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, new Map<String, Object>{
            'Status__c'         => 'Initiale',
            'SituationPrime__c' => 'Non payée',
            'SituationPolice__c'=> 'En cours'
        });

        // Véhicule rattaché à cette police (libre — prime non payée)
        InsurancePolicy__c polLibre = builder.getPolicies()[0];
        Vehicule__c vehLibre = DA_TestDataFactory.createTestVehicle(polLibre.Id, new Map<String, Object>{
            'RegistrationNumber__c' => 'IMMAT-LIBRE-01'
        });
        insert vehLibre;

        // Police bloquée (Status Active + SituationPrime Payée)
        InsurancePolicy__c polBloquee = DA_TestDataFactory.createTestPolicy(
            builder.getAccounts()[0].Id,
            new Map<String, Object>{
                'Status__c'         => 'Active',
                'SituationPrime__c' => 'Payée',
                'SituationPolice__c'=> 'En cours'
            }
        );
        insert polBloquee;

        // Véhicule rattaché à la police bloquée
        Vehicule__c vehBloque = DA_TestDataFactory.createTestVehicle(polBloquee.Id, new Map<String, Object>{
            'RegistrationNumber__c' => 'IMMAT-BLOQUE-01'
        });
        insert vehBloque;
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 1 — checkCin
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que checkCin retourne exists=true quand un compte avec ce CIN existe.
    * @method Name      :   test_checkCin_existingCin_returnsTrue
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkCin_existingCin_returnsTrue() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc022_PoliceCreationController.CinResult result =
                DA_lwc022_PoliceCreationController.checkCin('CIN_EXISTANT_001');
            Test.stopTest();

            System.assertEquals(true, result.exists, 'CIN existant doit retourner exists=true');
        }
    }

    /**
    * @description      :   Vérifie que checkCin retourne exists=false quand aucun compte ne possède ce CIN.
    * @method Name      :   test_checkCin_unknownCin_returnsFalse
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkCin_unknownCin_returnsFalse() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc022_PoliceCreationController.CinResult result =
                DA_lwc022_PoliceCreationController.checkCin('CIN_INCONNU_XYZ');
            Test.stopTest();

            System.assertEquals(false, result.exists, 'CIN inconnu doit retourner exists=false');
        }
    }

    /**
    * @description      :   Vérifie que checkCin retourne exists=false quand le CIN passé est vide.
    * @method Name      :   test_checkCin_blankCin_returnsFalse
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkCin_blankCin_returnsFalse() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc022_PoliceCreationController.CinResult result =
                DA_lwc022_PoliceCreationController.checkCin('');
            Test.stopTest();

            System.assertEquals(false, result.exists, 'CIN vide doit retourner exists=false');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 2 — checkImmatriculation
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que checkImmatriculation retourne exists=false pour une immatriculation inconnue.
    * @method Name      :   test_checkImmatriculation_unknown_returnsFalse
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkImmatriculation_unknown_returnsFalse() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc022_PoliceCreationController.ImmatriculationResult result =
                DA_lwc022_PoliceCreationController.checkImmatriculation('IMMAT-INCONNUE-99');
            Test.stopTest();

            System.assertEquals(false, result.exists,    'Immatriculation inconnue : exists doit être false');
            System.assertEquals(false, result.isBlocked, 'Immatriculation inconnue : isBlocked doit être false');
        }
    }

    /**
    * @description      :   Vérifie que checkImmatriculation retourne exists=true et isBlocked=false
    *                       pour un véhicule dont la police est active mais la prime non payée.
    * @method Name      :   test_checkImmatriculation_existsNotBlocked_returnsCorrectFlags
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkImmatriculation_existsNotBlocked_returnsCorrectFlags() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc022_PoliceCreationController.ImmatriculationResult result =
                DA_lwc022_PoliceCreationController.checkImmatriculation('IMMAT-LIBRE-01');
            Test.stopTest();

            System.assertEquals(true,  result.exists,    'Véhicule existant : exists doit être true');
            System.assertEquals(false, result.isBlocked, 'Prime non payée : isBlocked doit être false');
            System.assertNotEquals(null, result.vehiculeId,       'vehiculeId ne doit pas être null');
            System.assertNotEquals(null, result.anciennePoliceId, 'anciennePoliceId ne doit pas être null');
        }
    }

    /**
    * @description      :   Vérifie que checkImmatriculation retourne isBlocked=true quand la police est Active
    *                       et la prime Payée.
    * @method Name      :   test_checkImmatriculation_existsBlocked_returnsBlocked
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_checkImmatriculation_existsBlocked_returnsBlocked() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc022_PoliceCreationController.ImmatriculationResult result =
                DA_lwc022_PoliceCreationController.checkImmatriculation('IMMAT-BLOQUE-01');
            Test.stopTest();

            System.assertEquals(true, result.exists,    'Véhicule bloqué : exists doit être true');
            System.assertEquals(true, result.isBlocked, 'Prime payée + police active : isBlocked doit être true');
            System.assertNotEquals(null, result.numeroPolice, 'numeroPolice ne doit pas être null');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 3 — getNextNumeroPolice
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getNextNumeroPolice retourne un numéro au format P-XXXXX non nul.
    * @method Name      :   test_getNextNumeroPolice_returnsFormattedNumber
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getNextNumeroPolice_returnsFormattedNumber() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            String numero = DA_lwc022_PoliceCreationController.getNextNumeroPolice();
            Test.stopTest();

            System.assertNotEquals(null, numero, 'Le numéro de police ne doit pas être null');
            System.assert(numero.startsWith('P-'), 'Le numéro doit commencer par P-');
            System.assertEquals(7, numero.length(), 'Le numéro doit avoir 7 caractères (P-XXXXX)');
        }
    }

    /**
    * @description      :   Vérifie que getNextNumeroPolice incrémente correctement le dernier numéro existant.
    * @method Name      :   test_getNextNumeroPolice_incrementsLastNumber
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getNextNumeroPolice_incrementsLastNumber() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        InsurancePolicy__c polRef = DA_TestDataFactory.createTestPolicy(acc.Id, new Map<String, Object>{
            'PolicyNumber__c' => 'P-00042'
        });
        insert polRef;

        System.runAs(usr) {
            Test.startTest();
            String numero = DA_lwc022_PoliceCreationController.getNextNumeroPolice();
            Test.stopTest();

            System.assertEquals('P-00043', numero, 'Le numéro doit être incrémenté à P-00043');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 4 — creerPolice : nouveau compte + nouveau véhicule
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que creerPolice crée un nouveau compte, une police et un nouveau véhicule
    *                       quand aucun compte ni véhicule n'existe pour les données fournies.
    * @method Name      :   test_creerPolice_newAccountNewVehicle_createsAllRecords
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_newAccountNewVehicle_createsAllRecords() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_NEW_USR_001',
            'immatriculation'=> 'IMMAT-NEW-001',
            'numeroPolice'   => 'P-00090'
        });

        System.runAs(usr) {
            Test.startTest();
            String policeId = DA_lwc022_PoliceCreationController.creerPolice(
                formData, new List<String>(), false, false, null, null
            );
            Test.stopTest();

            System.assertNotEquals(null, policeId, 'creerPolice doit retourner un Id de police');

            InsurancePolicy__c police = [
                SELECT Id, Status__c, SituationPolice__c, PolicyNumber__c, AccountName__c, Vehicule__c
                FROM InsurancePolicy__c WHERE Id = :policeId
            ];
            System.assertEquals('Initiale',  police.Status__c,          'Status doit être Initiale');
            System.assertEquals('En cours',  police.SituationPolice__c, 'SituationPolice doit être En cours');
            System.assertEquals('P-00090',   police.PolicyNumber__c,    'PolicyNumber doit correspondre');
            System.assertNotEquals(null, police.AccountName__c, 'La police doit être liée à un compte');
            System.assertNotEquals(null, police.Vehicule__c,    'La police doit être liée à un véhicule');

            List<Account> accounts = [SELECT Id, CIN__c FROM Account WHERE CIN__c = 'CIN_NEW_USR_001'];
            System.assertEquals(1, accounts.size(), 'Un nouveau compte doit être créé');

            List<Vehicule__c> vehicules = [
                SELECT Id, InsurancePolicy__c FROM Vehicule__c WHERE RegistrationNumber__c = 'IMMAT-NEW-001'
            ];
            System.assertEquals(1, vehicules.size(), 'Un nouveau véhicule doit être créé');
            System.assertEquals(policeId, vehicules[0].InsurancePolicy__c, 'Le véhicule doit être lié à la nouvelle police');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 5 — creerPolice : compte existant (upsert)
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que creerPolice met à jour le compte existant (upsert) quand le CIN est déjà connu,
    *                       sans créer de doublon.
    * @method Name      :   test_creerPolice_existingAccount_updatesAccountNoNewInsert
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_existingAccount_updatesAccountNoNewInsert() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Integer countBefore = [SELECT COUNT() FROM Account WHERE CIN__c = 'CIN_EXISTANT_001'];

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_EXISTANT_001',
            'nomComplet'     => 'Nom Mis À Jour',
            'telephone'      => '0611111111',
            'immatriculation'=> 'IMMAT-EXISTING-ACC-01',
            'numeroPolice'   => 'P-00091'
        });

        System.runAs(usr) {
            Test.startTest();
            String policeId = DA_lwc022_PoliceCreationController.creerPolice(
                formData, new List<String>(), true, false, null, null
            );
            Test.stopTest();

            System.assertNotEquals(null, policeId, 'creerPolice doit retourner un Id de police');

            Integer countAfter = [SELECT COUNT() FROM Account WHERE CIN__c = 'CIN_EXISTANT_001'];
            System.assertEquals(countBefore, countAfter, 'Pas de nouveau compte doit être créé pour un CIN existant');

            Account updated = [SELECT Name, Phone FROM Account WHERE CIN__c = 'CIN_EXISTANT_001' LIMIT 1];
            System.assertEquals('Nom Mis À Jour', updated.Name,    'Le nom du compte doit être mis à jour');
            System.assertEquals('0611111111',     updated.Phone,   'Le téléphone du compte doit être mis à jour');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 6 — creerPolice : véhicule existant libre (réaffectation)
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que creerPolice réaffecte un véhicule existant libre à la nouvelle police
    *                       sans créer de nouveau véhicule.
    * @method Name      :   test_creerPolice_existingFreeVehicle_reassignsVehicle
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_existingFreeVehicle_reassignsVehicle() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Vehicule__c veh = [SELECT Id, InsurancePolicy__c FROM Vehicule__c WHERE RegistrationNumber__c = 'IMMAT-LIBRE-01' LIMIT 1];
        Id anciennePoliceId = veh.InsurancePolicy__c;

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_REASSIGN_001',
            'immatriculation'=> 'IMMAT-LIBRE-01',
            'numeroPolice'   => 'P-00092'
        });

        System.runAs(usr) {
            Test.startTest();
            String policeId = DA_lwc022_PoliceCreationController.creerPolice(
                formData, new List<String>(), false, true, veh.Id, anciennePoliceId
            );
            Test.stopTest();

            System.assertNotEquals(null, policeId, 'creerPolice doit retourner un Id de police');

            Vehicule__c vehAfter = [SELECT InsurancePolicy__c FROM Vehicule__c WHERE Id = :veh.Id];
            System.assertEquals(policeId, vehAfter.InsurancePolicy__c, 'Le véhicule doit être rattaché à la nouvelle police');

            InsurancePolicy__c policeAfter = [SELECT Vehicule__c FROM InsurancePolicy__c WHERE Id = :policeId];
            System.assertEquals(veh.Id, policeAfter.Vehicule__c, 'La nouvelle police doit pointer vers le véhicule');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 7 — creerPolice : véhicule existant bloqué (résiliation ancienne police)
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que creerPolice résilie l'ancienne police quand le véhicule appartient à une
    *                       police bloquée (Active + prime Payée).
    * @method Name      :   test_creerPolice_blockedVehicle_resiliatesOldPolicy
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_blockedVehicle_resiliatesOldPolicy() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Vehicule__c veh = [SELECT Id, InsurancePolicy__c FROM Vehicule__c WHERE RegistrationNumber__c = 'IMMAT-BLOQUE-01' LIMIT 1];
        Id anciennePoliceId = veh.InsurancePolicy__c;

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_BLOCKED_001',
            'immatriculation'=> 'IMMAT-BLOQUE-01',
            'numeroPolice'   => 'P-00093'
        });

        System.runAs(usr) {
            Test.startTest();
            String policeId = DA_lwc022_PoliceCreationController.creerPolice(
                formData, new List<String>(), false, true, veh.Id, anciennePoliceId
            );
            Test.stopTest();

            System.assertNotEquals(null, policeId, 'creerPolice doit retourner un Id de police');

            InsurancePolicy__c anciennePolice = [SELECT Status__c FROM InsurancePolicy__c WHERE Id = :anciennePoliceId];
            System.assertEquals('Résiliée', anciennePolice.Status__c, 'L\'ancienne police doit être résiliée');

            Vehicule__c vehAfter = [SELECT InsurancePolicy__c FROM Vehicule__c WHERE Id = :veh.Id];
            System.assertEquals(policeId, vehAfter.InsurancePolicy__c, 'Le véhicule doit être rattaché à la nouvelle police');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 8 — creerPolice : avec garanties
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que creerPolice insère le bon nombre de garanties (InsurancePolicyCoverage__c)
    *                       quand la liste garanties est non vide.
    * @method Name      :   test_creerPolice_withGaranties_insertsAllCoverages
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_withGaranties_insertsAllCoverages() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_GARANTIES_001',
            'immatriculation'=> 'IMMAT-GAR-001',
            'numeroPolice'   => 'P-00094'
        });

        List<String> garanties = new List<String>{
            buildGarantieJson('Responsabilité Civile', 'RC',  'Obligatoire'),
            buildGarantieJson('Vol',                   'VOL', 'Optionnelle'),
            buildGarantieJson('Incendie',              'INC', 'Optionnelle')
        };

        System.runAs(usr) {
            Test.startTest();
            String policeId = DA_lwc022_PoliceCreationController.creerPolice(
                formData, garanties, false, false, null, null
            );
            Test.stopTest();

            System.assertNotEquals(null, policeId, 'creerPolice doit retourner un Id de police');

            List<InsurancePolicyCoverage__c> coverages = [
                SELECT Id, NomDeLaGarantie__c, CodeGarantie__c, TypeGarantie__c, GarantieUsed__c
                FROM InsurancePolicyCoverage__c WHERE InsurancePolicy__c = :policeId
            ];
            System.assertEquals(3, coverages.size(), '3 garanties doivent être insérées');

            Boolean hasRC  = false;
            Boolean hasVol = false;
            Boolean hasInc = false;
            for (InsurancePolicyCoverage__c cov : coverages) {
                System.assertEquals(true, cov.GarantieUsed__c, 'GarantieUsed__c doit être true');
                if (cov.CodeGarantie__c == 'RC')  hasRC  = true;
                if (cov.CodeGarantie__c == 'VOL') hasVol = true;
                if (cov.CodeGarantie__c == 'INC') hasInc = true;
            }
            System.assert(hasRC,  'La garantie RC doit être insérée');
            System.assert(hasVol, 'La garantie VOL doit être insérée');
            System.assert(hasInc, 'La garantie INC doit être insérée');
        }
    }

    /**
    * @description      :   Vérifie que creerPolice ne crée aucune garantie quand la liste passée est vide.
    * @method Name      :   test_creerPolice_noGaranties_createsNoCoverages
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_noGaranties_createsNoCoverages() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_NOGAR_001',
            'immatriculation'=> 'IMMAT-NOGAR-001',
            'numeroPolice'   => 'P-00095'
        });

        System.runAs(usr) {
            Test.startTest();
            String policeId = DA_lwc022_PoliceCreationController.creerPolice(
                formData, new List<String>(), false, false, null, null
            );
            Test.stopTest();

            System.assertNotEquals(null, policeId, 'creerPolice doit retourner un Id de police');

            Integer coverageCount = [
                SELECT COUNT() FROM InsurancePolicyCoverage__c WHERE InsurancePolicy__c = :policeId
            ];
            System.assertEquals(0, coverageCount, 'Aucune garantie ne doit être insérée si la liste est vide');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 9 — creerPolice : cas d'erreur
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que creerPolice lève une AuraHandledException quand le JSON formData est invalide.
    * @method Name      :   test_creerPolice_invalidJson_throwsAuraException
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_invalidJson_throwsAuraException() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc022_PoliceCreationController.creerPolice(
                    'NOT_VALID_JSON{{{', new List<String>(), false, false, null, null
                );
                Test.stopTest();
                System.assert(false, 'Une AuraHandledException doit être levée pour un JSON invalide');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    /**
    * @description      :   Vérifie que creerPolice lève une AuraHandledException quand la date est dans un format invalide.
    * @method Name      :   test_creerPolice_invalidDate_throwsAuraException
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_creerPolice_invalidDate_throwsAuraException() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        String formData = buildFormData(new Map<String, String>{
            'cin'            => 'CIN_BADDATE_001',
            'immatriculation'=> 'IMMAT-BADDATE-01',
            'numeroPolice'   => 'P-00096',
            'dateEffet'      => 'NOT-A-DATE'
        });

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc022_PoliceCreationController.creerPolice(
                    formData, new List<String>(), false, false, null, null
                );
                Test.stopTest();
                System.assert(false, 'Une AuraHandledException doit être levée pour une date invalide');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 10 — picklists & métadonnées (cacheable=true)
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getCategorieOptions retourne une liste non nulle de valeurs de picklist.
    * @method Name      :   test_getCategorieOptions_returnsNonEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCategorieOptions_returnsNonEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> options = DA_lwc022_PoliceCreationController.getCategorieOptions();
            Test.stopTest();

            System.assertNotEquals(null, options, 'getCategorieOptions ne doit pas retourner null');
        }
    }

    /**
    * @description      :   Vérifie que getCanalOptions retourne une liste non nulle de valeurs de picklist.
    * @method Name      :   test_getCanalOptions_returnsNonEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCanalOptions_returnsNonEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> options = DA_lwc022_PoliceCreationController.getCanalOptions();
            Test.stopTest();

            System.assertNotEquals(null, options, 'getCanalOptions ne doit pas retourner null');
        }
    }

    /**
    * @description      :   Vérifie que getGarantiesMetadata retourne une liste non nulle de métadonnées de garanties.
    * @method Name      :   test_getGarantiesMetadata_returnsNonNull
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getGarantiesMetadata_returnsNonNull() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, String>> meta = DA_lwc022_PoliceCreationController.getGarantiesMetadata();
            Test.stopTest();

            System.assertNotEquals(null, meta, 'getGarantiesMetadata ne doit pas retourner null');
        }
    }

    /**
    * @description      :   Vérifie que getDependentVilleOptions retourne une map non nulle avec au moins une entrée.
    * @method Name      :   test_getDependentVilleOptions_returnsMap
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getDependentVilleOptions_returnsMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> villeOptions =
                DA_lwc022_PoliceCreationController.getDependentVilleOptions();
            Test.stopTest();

            System.assertNotEquals(null, villeOptions, 'getDependentVilleOptions ne doit pas retourner null');
            System.assert(villeOptions.containsKey('Maroc'), 'La clé Maroc doit être présente');
        }
    }
}