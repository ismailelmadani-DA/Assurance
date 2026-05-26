/**
 * @description       : Tests unitaires du controller de gestion des véhicules adverses :
 *                      picklists, lecture des véhicules adverses, détail par Id,
 *                      insert/update/delete d'un véhicule adverse.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 20-05-2026
 * @last modified by  : D&A Technologies
 **/
@isTest
public class DA_LWC015_VehiculeAdverseControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    // ─────────────────────────────────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description      : Configure les données de test : 1 user, 1 compte, 1 police,
     *                     1 case (CLAIM_CASE), 1 claim, 1 véhicule,
     *                     1 assignment adverse (isOpposingCar__c=true),
     *                     1 assignment non-adverse (isOpposingCar__c=false).
     * @method Name      : setupTestData
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @TestSetup
    static void setupTestData() {
        builder.withUser('usr', 'Regular');

        builder
            .withAccount()
            .withCustomPolicies(1, builder.getAccounts()[0].Id, null)
            .withCases(
                1,
                builder.getAccounts()[0].Id,
                builder.getPolicies()[0].Id,
                'CLAIM_CASE',
                null
            )
            .withClaims(1, builder.getCases()[0].Id, null)
            .withVehicle();

        Id claimId   = builder.getClaims()[0].Id;
        Id caseId    = builder.getCases()[0].Id;
        Id vehicleId = builder.getVehicles()[0].Id;

        // Assignment adverse : isOpposingCar__c = true → doit apparaître dans getVehiclesAdverses
        builder.withVehicleCaseAssignments(1, claimId, caseId, true, new Map<String, Object>{
            'Vehicule__c' => vehicleId
        });

        // Assignment non-adverse : isOpposingCar__c = false → ne doit PAS apparaître
        builder.withVehicleCaseAssignments(1, claimId, caseId, false, new Map<String, Object>{
            'Vehicule__c' => vehicleId
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER PRIVÉ — formData minimal pour les tests d'écriture
    // ─────────────────────────────────────────────────────────────────────────

    private static Map<String, Object> buildFormData(String immat, String cin) {
        return new Map<String, Object>{
            'immatriculation'       => immat,
            'marque'                => 'Toyota',
            'etatVehicule'          => 'Endommagé',
            'adversaireAssure'      => 'false',
            'nomCompletTiers'       => 'Test Tiers',
            'cniTiers'              => cin,
            'typePersonne'          => 'Physique',
            'dateMiseEnCirculation' => '2020-01-01'
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PICKLISTS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description      : Vérifie que getPicklistValues retourne une Map non vide
     *                     avec toutes les clés attendues.
     * @method Name      : test_getPicklistValues_returnsNonEmptyMap
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getPicklistValues_returnsNonEmptyMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> result =
                DA_LWC015_VehiculeAdverseClaimController.getPicklistValues();
            Test.stopTest();

            System.assertNotEquals(null, result, 'La map de picklists ne doit pas être null');
            System.assert(result.containsKey('etatVehicule'),      'Doit contenir etatVehicule');
            System.assert(result.containsKey('typeVehicule'),      'Doit contenir typeVehicule');
            System.assert(result.containsKey('marque'),            'Doit contenir marque');
            System.assert(result.containsKey('moyenNotification'), 'Doit contenir moyenNotification');
            System.assert(result.containsKey('pays'),              'Doit contenir pays');
        }
    }

    /**
     * @description      : Vérifie que getDependentModeleOptions retourne une Map non null.
     * @method Name      : test_getDependentModeleOptions_returnsMap
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getDependentModeleOptions_returnsMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> result =
                DA_LWC015_VehiculeAdverseClaimController.getDependentModeleOptions();
            Test.stopTest();

            System.assertNotEquals(null, result, 'La map des modèles ne doit pas être null');
        }
    }

    /**
     * @description      : Vérifie que getDependentVilleOptions retourne une Map non null.
     * @method Name      : test_getDependentVilleOptions_returnsMap
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getDependentVilleOptions_returnsMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, List<Map<String, String>>> result =
                DA_LWC015_VehiculeAdverseClaimController.getDependentVilleOptions();
            Test.stopTest();

            System.assertNotEquals(null, result, 'La map des villes ne doit pas être null');
        }
    }

    /**
     * @description      : Vérifie que getCompagnieAdverseRecordTypeId retourne un Id valide.
     * @method Name      : test_getCompagnieAdverseRecordTypeId_returnsId
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getCompagnieAdverseRecordTypeId_returnsId() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            String rtId = DA_LWC015_VehiculeAdverseClaimController.getCompagnieAdverseRecordTypeId();
            Test.stopTest();

            System.assertNotEquals(null, rtId, 'Le Record Type Id ne doit pas être null');
            System.assert(rtId.startsWith('012'), 'Doit être un Id de Record Type valide');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LECTURE — getVehiclesAdverses
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description      : Vérifie que getVehiclesAdverses retourne uniquement
     *                     les véhicules avec isOpposingCar__c = true.
     * @method Name      : test_getVehiclesAdverses_returnsOnlyOpposingCars
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getVehiclesAdverses_returnsOnlyOpposingCars() {
        User usr       = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'CLAIM_CASE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<SObject> result =
                DA_LWC015_VehiculeAdverseClaimController.getVehiclesAdverses(claim.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'La liste ne doit pas être null');
            System.assertEquals(1, result.size(), 'Doit retourner 1 seul véhicule adverse');

            VehicleCaseAssignment__c vca = (VehicleCaseAssignment__c) result[0];
            System.assertEquals(true, vca.isOpposingCar__c, 'Le véhicule retourné doit être adverse');
        }
    }

    /**
     * @description      : Vérifie que getVehiclesAdverses retourne une liste vide
     *                     quand le claimId est null.
     * @method Name      : test_getVehiclesAdverses_nullClaimId_returnsEmpty
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getVehiclesAdverses_nullClaimId_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<SObject> result =
                DA_LWC015_VehiculeAdverseClaimController.getVehiclesAdverses(null);
            Test.stopTest();

            System.assertNotEquals(null, result, 'La liste ne doit pas être null');
            System.assertEquals(0, result.size(), 'Doit retourner une liste vide pour un claimId null');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LECTURE — getVehicleAdverseById
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description      : Vérifie que getVehicleAdverseById retourne la Map de détails
     *                     avec les clés attendues pour un Id valide.
     * @method Name      : test_getVehicleAdverseById_returnsDetails
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getVehicleAdverseById_returnsDetails() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        VehicleCaseAssignment__c vca = [
            SELECT Id FROM VehicleCaseAssignment__c
            WHERE isOpposingCar__c = true
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result =
                DA_LWC015_VehiculeAdverseClaimController.getVehicleAdverseById(vca.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Le résultat ne doit pas être null');
            System.assert(result.containsKey('assignmentId'),   'Doit contenir assignmentId');
            System.assert(result.containsKey('etatVehicule'),   'Doit contenir etatVehicule');
            System.assert(result.containsKey('adversaireAssure'), 'Doit contenir adversaireAssure');
            System.assertEquals(vca.Id, result.get('assignmentId'), 'L\'Id doit correspondre');
        }
    }

    /**
     * @description      : Vérifie que getVehicleAdverseById retourne null
     *                     quand l'assignment a été supprimé.
     * @method Name      : test_getVehicleAdverseById_notFound_returnsNull
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getVehicleAdverseById_notFound_returnsNull() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        VehicleCaseAssignment__c vca = [
            SELECT Id FROM VehicleCaseAssignment__c
            WHERE isOpposingCar__c = true
            LIMIT 1
        ];
        Id missingId = vca.Id;
        delete vca;

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result =
                DA_LWC015_VehiculeAdverseClaimController.getVehicleAdverseById(missingId);
            Test.stopTest();

            System.assertEquals(null, result, 'Doit retourner null pour un Id inexistant');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ÉCRITURE — upsertVehiculeAdverse
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description      : Vérifie que upsertVehiculeAdverse en mode insert
     *                     crée un nouvel assignment et retourne success=true.
     * @method Name      : test_upsertVehiculeAdverse_insert_createsAssignment
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_upsertVehiculeAdverse_insert_createsAssignment() {
        User usr       = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'CLAIM_CASE' LIMIT 1];

        Map<String, Object> formData = buildFormData('BB999999', 'CIN_INSERT_TEST');

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_LWC015_VehiculeAdverseClaimController.upsertVehiculeAdverse(
                formData, claim.Id, false
            );
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'L\'insert doit réussir');
            System.assertNotEquals(null, result.get('assignmentId'), 'Doit retourner l\'Id du nouvel assignment');

            Id newId = (Id) result.get('assignmentId');
            VehicleCaseAssignment__c created = [
                SELECT Id, isOpposingCar__c FROM VehicleCaseAssignment__c WHERE Id = :newId
            ];
            System.assertEquals(true, created.isOpposingCar__c, 'Le nouvel assignment doit être adverse');
        }
    }

    /**
     * @description      : Vérifie que upsertVehiculeAdverse en mode update
     *                     met à jour l'assignment existant et retourne success=true.
     * @method Name      : test_upsertVehiculeAdverse_update_updatesAssignment
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_upsertVehiculeAdverse_update_updatesAssignment() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        VehicleCaseAssignment__c vca = [
            SELECT Id, Vehicule__c FROM VehicleCaseAssignment__c
            WHERE isOpposingCar__c = true
            LIMIT 1
        ];

        Map<String, Object> formData = buildFormData('CC111111', 'CIN_UPDATE_TEST');
        formData.put('assignmentId', vca.Id);
        formData.put('vehiculeId',   vca.Vehicule__c);

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_LWC015_VehiculeAdverseClaimController.upsertVehiculeAdverse(
                formData, null, true
            );
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'L\'update doit réussir');
            System.assertEquals(vca.Id, result.get('assignmentId'), 'Doit retourner le même Id');
        }
    }

    /**
     * @description      : Vérifie que upsertVehiculeAdverse retourne une erreur
     *                     quand le claimId est null en mode insert.
     * @method Name      : test_upsertVehiculeAdverse_nullClaimId_returnsError
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_upsertVehiculeAdverse_nullClaimId_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result = DA_LWC015_VehiculeAdverseClaimController.upsertVehiculeAdverse(
                buildFormData('DD222222', 'CIN_NULL_TEST'), null, false
            );
            Test.stopTest();

            System.assertEquals(false, result.get('success'), 'Doit retourner success=false');
            System.assert(
                ((String) result.get('message')).contains('identifiant'),
                'Le message doit mentionner l\'identifiant'
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ÉCRITURE — deleteVehiculeAdverse
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description      : Vérifie que deleteVehiculeAdverse supprime l'assignment
     *                     et retourne success=true.
     * @method Name      : test_deleteVehiculeAdverse_deletesAssignment
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_deleteVehiculeAdverse_deletesAssignment() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        VehicleCaseAssignment__c vca = [
            SELECT Id FROM VehicleCaseAssignment__c
            WHERE isOpposingCar__c = true
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result =
                DA_LWC015_VehiculeAdverseClaimController.deleteVehiculeAdverse(vca.Id);
            Test.stopTest();

            System.assertEquals(true, result.get('success'), 'La suppression doit réussir');

            Integer count = [
                SELECT COUNT() FROM VehicleCaseAssignment__c WHERE Id = :vca.Id
            ];
            System.assertEquals(0, count, 'L\'assignment doit avoir été supprimé de la base');
        }
    }

    /**
     * @description      : Vérifie que deleteVehiculeAdverse retourne une erreur
     *                     quand l'assignmentId est null.
     * @method Name      : test_deleteVehiculeAdverse_nullId_returnsError
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_deleteVehiculeAdverse_nullId_returnsError() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, Object> result =
                DA_LWC015_VehiculeAdverseClaimController.deleteVehiculeAdverse(null);
            Test.stopTest();

            System.assertEquals(false, result.get('success'), 'Doit retourner success=false');
            System.assert(
                ((String) result.get('message')).contains('identifiant'),
                'Le message doit mentionner l\'identifiant'
            );
        }
    }
}