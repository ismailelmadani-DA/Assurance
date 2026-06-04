/**
 * @description       : Test class for VehicleHistoryController
 * @author            : D&A Technologies
 * @date              : 2026-05-29
 */
@isTest
public with sharing class VehicleHistoryControllerTest {

    private static final String ROLE_ASSURED  = 'Passager assuré';
    private static final String ROLE_ADVERSE  = 'Passager adverse';
    private static final String ROLE_OTHER    = 'Autres partie';

    private static final String VALID_BRAND        = 'FORD';
    private static final String VALID_MODEL        = 'Fiesta';
    private static final String VALID_VEHICLE_TYPE = 'Une voiture';
    private static final String VALID_CIVILITY_MR  = 'Mr';
    private static final String VALID_CIVILITY_MME = 'Mme';

    // ============================================================
    // SETUP
    // ============================================================

    @TestSetup
    static void setupTestData() {
        new DA_TestBuilderFactory()
            .withCustomAccounts(1, new Map<String, Object>{
                'Name'        => 'Test Passenger Account',
                'Civility__c' => 'Mr'
            })
            .withCustomPolicies(1, [SELECT Id FROM Account WHERE Name = 'Test Passenger Account' LIMIT 1].Id,
                new Map<String, Object>{
                    'PolicyNumber__c'    => 'POL_TEST_001',
                    'Status__c'          => 'Active',
                    'PolicyCategory__c'  => 'Individuelle',
                    'DateEffet__c'       => Date.today(),
                    'DateExpiration__c'  => Date.today().addYears(1),
                    'Canal__c'           => 'Agent',
                    'SituationPolice__c' => 'En cours'
                })
            .withCustomVehicles(1, [SELECT Id FROM InsurancePolicy__c WHERE PolicyNumber__c = 'POL_TEST_001' LIMIT 1].Id,
                new Map<String, Object>{
                    'RegistrationNumber__c'      => 'AB-123-CD',
                    'Brand__c'                   => 'FORD',
                    'ModelePicklist__c'           => 'Fiesta',
                    'ChassisNumber__c'            => 'VF1ABC123456789',
                    'DateOfFirstRegistration__c'  => Date.newInstance(2020, 1, 1),
                    'MarketValue__c'              => 15000,
                    'isOpposingCar__c'            => false,
                    'TypeVehicule__c'             => 'Une voiture'
                })
            .withCases(1,
                [SELECT Id FROM Account WHERE Name = 'Test Passenger Account' LIMIT 1].Id,
                [SELECT Id FROM InsurancePolicy__c WHERE PolicyNumber__c = 'POL_TEST_001' LIMIT 1].Id,
                'Test Sinistre Automobile',
                new Map<String, Object>{
                    'Origin' => 'Web',
                    'Status' => 'New'
                })
            .withClaims(1,
                [SELECT Id FROM Case WHERE Subject = 'Test Sinistre Automobile' LIMIT 1].Id,
                null);
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Passenger Account' LIMIT 1];
    }

    private static InsurancePolicy__c getPolicy() {
        return [SELECT Id FROM InsurancePolicy__c WHERE PolicyNumber__c = 'POL_TEST_001' LIMIT 1];
    }

    private static Vehicule__c getBaseVehicle() {
        return [SELECT Id FROM Vehicule__c WHERE RegistrationNumber__c = 'AB-123-CD' LIMIT 1];
    }

    private static Case getCase() {
        return [SELECT Id FROM Case WHERE Subject = 'Test Sinistre Automobile' LIMIT 1];
    }

    private static Claim__c getClaim() {
        Case c = getCase();
        return [SELECT Id FROM Claim__c WHERE Case__c = :c.Id LIMIT 1];
    }

    private static void updateClaimWithVehicle(Id claimId, Id vehicleId) {
        update new Claim__c(Id = claimId, Vehicule__c = vehicleId);
    }

    private static void verifyVehicleWrapper(
        VehicleHistoryController.VehicleWrapper wrapper,
        Id expectedVehicleId,
        String expectedRole,
        Boolean expectedIsDriver,
        String expectedBrand,
        String expectedModel
    ) {
        System.assertNotEquals(null, wrapper, 'Wrapper ne doit pas être null');
        System.assertEquals(expectedVehicleId, wrapper.vehicleId,  'Vehicle ID incorrect');
        System.assertEquals(expectedRole,      wrapper.role,       'Rôle incorrect');
        System.assertEquals(expectedIsDriver,  wrapper.isDriver,   'Flag isDriver incorrect');

        if (String.isNotBlank(expectedBrand)) {
            System.assertEquals(expectedBrand, wrapper.brand, 'Brand incorrect');
        }
        if (String.isNotBlank(expectedModel)) {
            System.assertEquals(expectedModel, wrapper.model, 'Model incorrect');
        }
        if (String.isNotBlank(expectedBrand) && String.isNotBlank(expectedModel)) {
            System.assertEquals(expectedBrand + ' ' + expectedModel, wrapper.brandModel, 'BrandModel incorrect');
        }

        System.assertNotEquals(null, wrapper.claimId, 'Claim ID ne doit pas être null');
    }

    // ============================================================
    // TEST 1 — Assured passenger with vehicle on claim
    // ============================================================

    @isTest
    static void testGetVehicleHistory_AssuredWithClaimVehicle() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        updateClaimWithVehicle(claim.Id, veh.Id);

        new DA_TestBuilderFactory()
            .withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
                'Roles__c'        => ROLE_ASSURED,
                'isDriver__c'     => true,
                'Civilite__c'     => VALID_CIVILITY_MR,
                'StateOfPerson__c'=> 'Indemne'
            });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Un seul véhicule doit être retourné');
        verifyVehicleWrapper(result[0], veh.Id, ROLE_ASSURED, true, VALID_BRAND, VALID_MODEL);
        System.assertEquals('AB-123-CD', result[0].registrationNumber, 'Immatriculation incorrecte');
    }

    // ============================================================
    // TEST 2 — Adverse passenger with their own vehicle
    // ============================================================

    @isTest
    static void testGetVehicleHistory_AdverseWithOwnVehicle() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        new DA_TestBuilderFactory()
            .withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
                'Roles__c'        => ROLE_ADVERSE,
                'isDriver__c'     => false,
                'Vehicule__c'     => veh.Id,
                'Civilite__c'     => VALID_CIVILITY_MME,
                'StateOfPerson__c'=> 'Blessé'
            });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Un seul véhicule doit être retourné');
        verifyVehicleWrapper(result[0], veh.Id, ROLE_ADVERSE, false, VALID_BRAND, VALID_MODEL);
    }

    // ============================================================
    // TEST 3 — Other party participant with vehicle
    // ============================================================

    @isTest
    static void testGetVehicleHistory_OtherPartyWithVehicle() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        new DA_TestBuilderFactory()
            .withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
                'Roles__c'    => ROLE_OTHER,
                'isDriver__c' => true,
                'Vehicule__c' => veh.Id
            });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        verifyVehicleWrapper(result[0], veh.Id, ROLE_OTHER, true, VALID_BRAND, VALID_MODEL);
    }

    // ============================================================
    // TEST 4 — Fallback A: participant without role but with direct vehicle
    // ============================================================

    @isTest
    static void testGetVehicleHistory_FallbackDirectVehicle() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        new DA_TestBuilderFactory()
            .withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
                'Roles__c'    => null,
                'Vehicule__c' => veh.Id,
                'isDriver__c' => false
            });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(veh.Id, result[0].vehicleId);
        System.assertEquals('—', result[0].role);
        System.assertEquals(false, result[0].isDriver);
    }

    // ============================================================
    // TEST 5 — Fallback B: participant without role, claim has vehicle
    // ============================================================

    @isTest
    static void testGetVehicleHistory_FallbackClaimVehicle() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        updateClaimWithVehicle(claim.Id, veh.Id);

        new DA_TestBuilderFactory()
            .withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
                'Roles__c'    => null,
                'Vehicule__c' => null,
                'isDriver__c' => false
            });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(veh.Id, result[0].vehicleId);
        System.assertEquals('—', result[0].role);
    }

    // ============================================================
    // TEST 6 — Multiple participants for same vehicle (deduplication)
    // ============================================================

    @isTest
    static void testGetVehicleHistory_DuplicateVehicleDeduplication() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => veh.Id,
            'isDriver__c' => false
        });
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => veh.Id,
            'isDriver__c' => true
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Duplicate vehicles should be deduplicated');
        System.assertEquals(true,   result[0].isDriver);
        System.assertEquals(veh.Id, result[0].vehicleId);
    }

    // ============================================================
    // TEST 7 — Multiple different vehicles
    // ============================================================

    @isTest
    static void testGetVehicleHistory_MultipleVehicles() {
        Account acc              = getAccount();
        InsurancePolicy__c pol   = getPolicy();
        Vehicule__c veh1         = getBaseVehicle();
        Claim__c claim           = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();

        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'RegistrationNumber__c' => 'CD-456-EF',
            'Brand__c'              => VALID_BRAND,
            'ModelePicklist__c'     => 'Focus',
            'ChassisNumber__c'      => 'CHS002',
            'DateOfFirstRegistration__c' => Date.newInstance(2021, 1, 1),
            'MarketValue__c'        => 20000,
            'TypeVehicule__c'       => VALID_VEHICLE_TYPE
        });
        Vehicule__c veh2 = factory.getVehicles()[0];

        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'RegistrationNumber__c' => 'GH-789-IJ',
            'Brand__c'              => VALID_BRAND,
            'ModelePicklist__c'     => 'Mondeo',
            'ChassisNumber__c'      => 'CHS003',
            'DateOfFirstRegistration__c' => Date.newInstance(2021, 1, 1),
            'MarketValue__c'        => 25000,
            'TypeVehicule__c'       => VALID_VEHICLE_TYPE
        });
        Vehicule__c veh3 = factory.getVehicles()[1];

        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => veh1.Id,
            'isDriver__c' => true
        });
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => veh2.Id,
            'isDriver__c' => false
        });
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_OTHER,
            'Vehicule__c' => veh3.Id,
            'isDriver__c' => true
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(3, result.size(), 'Three different vehicles should be returned');

        Set<Id> vehicleIds = new Set<Id>();
        for (VehicleHistoryController.VehicleWrapper w : result) {
            vehicleIds.add(w.vehicleId);
        }
        System.assert(vehicleIds.contains(veh1.Id));
        System.assert(vehicleIds.contains(veh2.Id));
        System.assert(vehicleIds.contains(veh3.Id));
    }

    // ============================================================
    // TEST 8 — Vehicle with null fields
    // ============================================================

    @isTest
    static void testGetVehicleHistory_VehicleWithNullFields() {
        Account acc            = getAccount();
        InsurancePolicy__c pol = getPolicy();
        Claim__c claim         = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();
        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'RegistrationNumber__c' => 'MIN-001',
            'ChassisNumber__c'      => 'CHS001',
            'Brand__c'              => null,
            'ModelePicklist__c'     => null,
            'TypeVehicule__c'       => null
        });
        Vehicule__c minimalVehicle = factory.getVehicles()[0];

        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => minimalVehicle.Id,
            'isDriver__c' => false
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(minimalVehicle.Id, result[0].vehicleId);
        System.assertEquals('—',    result[0].brandModel);
        System.assertEquals(null,   result[0].brand);
        System.assertEquals(null,   result[0].model);
        System.assertEquals('MIN-001', result[0].registrationNumber);
    }

    // ============================================================
    // TEST 9 — Participant without vehicle
    // ============================================================

    @isTest
    static void testGetVehicleHistory_ParticipantWithoutVehicle() {
        Account acc    = getAccount();
        Claim__c claim = getClaim();

        new DA_TestBuilderFactory()
            .withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
                'Roles__c'    => null,
                'Vehicule__c' => null,
                'isDriver__c' => false
            });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    // ============================================================
    // TEST 10 — Null accountId
    // ============================================================

    @isTest
    static void testGetVehicleHistory_NullAccountId() {
        Test.startTest();
        try {
            VehicleHistoryController.getVehicleHistory(null);
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception was properly thrown');
        }
        Test.stopTest();
    }

    // ============================================================
    // TEST 11 — Account with no participants
    // ============================================================

    @isTest
    static void testGetVehicleHistory_NoParticipants() {
        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();
        factory.withCustomAccounts(1, new Map<String, Object>{
            'Name'        => 'Account Without Participants',
            'Civility__c' => VALID_CIVILITY_MR
        });
        Id accountId = factory.getAccounts()[0].Id;

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(accountId);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }

    // ============================================================
    // TEST 12 — isDriver flag update
    // ============================================================

    @isTest
    static void testGetVehicleHistory_DriverFlagUpdate() {
        Account acc     = getAccount();
        Vehicule__c veh = getBaseVehicle();
        Claim__c claim  = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => veh.Id,
            'isDriver__c' => false
        });
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => veh.Id,
            'isDriver__c' => true
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].isDriver);
    }

    // ============================================================
    // TEST 13 — Complete vehicle information
    // ============================================================

    @isTest
    static void testGetVehicleHistory_CompleteVehicleInfo() {
        Account acc            = getAccount();
        InsurancePolicy__c pol = getPolicy();
        Claim__c claim         = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();
        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'RegistrationNumber__c'     => 'COMPLETE-001',
            'Brand__c'                  => VALID_BRAND,
            'ModelePicklist__c'         => 'Mondeo',
            'ChassisNumber__c'          => 'WBA123456789',
            'DateOfFirstRegistration__c'=> Date.newInstance(2020, 1, 1),
            'MarketValue__c'            => 35000,
            'NewValue__c'               => 45000,
            'GlassValue__c'             => 5000,
            'TypeVehicule__c'           => VALID_VEHICLE_TYPE,
            'Usage__c'                  => 'Privé',
            'NbDePassagerBlesses__c'    => 0,
            'isOpposingCar__c'          => false
        });
        Vehicule__c completeVehicle = factory.getVehicles()[0];

        updateClaimWithVehicle(claim.Id, completeVehicle.Id);

        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ASSURED,
            'isDriver__c' => true
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        VehicleHistoryController.VehicleWrapper wrapper = result[0];
        System.assertEquals(completeVehicle.Id,         wrapper.vehicleId);
        System.assertEquals('COMPLETE-001',              wrapper.registrationNumber);
        System.assertEquals(VALID_BRAND,                 wrapper.brand);
        System.assertEquals('Mondeo',                    wrapper.model);
        System.assertEquals(VALID_BRAND + ' Mondeo',     wrapper.brandModel);
    }

    // ============================================================
    // TEST 14 — Brand model edge cases
    // ============================================================

    @isTest
    static void testGetVehicleHistory_BrandModelEdgeCases() {
        Account acc            = getAccount();
        InsurancePolicy__c pol = getPolicy();
        Claim__c claim         = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();

        // Brand only (model null)
        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'Brand__c'              => VALID_BRAND,
            'ModelePicklist__c'     => null,
            'RegistrationNumber__c' => 'BRAND-001',
            'ChassisNumber__c'      => 'CHS001',
            'TypeVehicule__c'       => VALID_VEHICLE_TYPE
        });
        Vehicule__c brandOnly = factory.getVehicles()[0];

        // Brand + model
        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'Brand__c'              => VALID_BRAND,
            'ModelePicklist__c'     => VALID_MODEL,
            'RegistrationNumber__c' => 'MODEL-001',
            'ChassisNumber__c'      => 'CHS002',
            'TypeVehicule__c'       => VALID_VEHICLE_TYPE
        });
        Vehicule__c modelOnly = factory.getVehicles()[1];

        // Both
        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'Brand__c'              => VALID_BRAND,
            'ModelePicklist__c'     => VALID_MODEL,
            'RegistrationNumber__c' => 'BOTH-001',
            'ChassisNumber__c'      => 'CHS003',
            'TypeVehicule__c'       => VALID_VEHICLE_TYPE
        });
        Vehicule__c bothVehicle = factory.getVehicles()[2];

        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => brandOnly.Id
        });
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => modelOnly.Id
        });
        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => bothVehicle.Id
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        Map<Id, VehicleHistoryController.VehicleWrapper> wrapperMap =
            new Map<Id, VehicleHistoryController.VehicleWrapper>();
        for (VehicleHistoryController.VehicleWrapper w : result) {
            wrapperMap.put(w.vehicleId, w);
        }

        // Brand only
        System.assertEquals(VALID_BRAND, wrapperMap.get(brandOnly.Id).brandModel);
        System.assertEquals(VALID_BRAND, wrapperMap.get(brandOnly.Id).brand);
        System.assertEquals(null,        wrapperMap.get(brandOnly.Id).model);

        // Model + brand (brand required for dependent picklist)
        System.assertEquals(VALID_BRAND + ' ' + VALID_MODEL, wrapperMap.get(modelOnly.Id).brandModel);
        System.assertEquals(VALID_BRAND,  wrapperMap.get(modelOnly.Id).brand);
        System.assertEquals(VALID_MODEL,  wrapperMap.get(modelOnly.Id).model);

        // Both
        System.assertEquals(VALID_BRAND + ' ' + VALID_MODEL, wrapperMap.get(bothVehicle.Id).brandModel);
        System.assertEquals(VALID_BRAND, wrapperMap.get(bothVehicle.Id).brand);
        System.assertEquals(VALID_MODEL, wrapperMap.get(bothVehicle.Id).model);
    }

    // ============================================================
    // TEST 15 — Large data volume
    // ============================================================

    @isTest
    static void testGetVehicleHistory_LargeVolume() {
        Account acc            = getAccount();
        InsurancePolicy__c pol = getPolicy();
        Claim__c claim         = getClaim();

        List<String> fordModels = new List<String>{ 'Fiesta', 'Focus', 'Mondeo' };

        List<Vehicule__c> vehicles = new List<Vehicule__c>();
        for (Integer i = 0; i < 50; i++) {
            vehicles.add(DA_TestDataFactory.createTestVehicle(pol.Id, new Map<String, Object>{
                'RegistrationNumber__c' => 'VOL-' + i,
                'Brand__c'              => VALID_BRAND,
                'ModelePicklist__c'     => fordModels[Math.mod(i, 3)],
                'ChassisNumber__c'      => 'CHS' + i,
                'TypeVehicule__c'       => VALID_VEHICLE_TYPE
            }));
        }
        insert vehicles;

        List<ClaimParticipant__c> participants = new List<ClaimParticipant__c>();
        for (Integer i = 0; i < 50; i++) {
            participants.add(DA_TestDataFactory.createTestClaimParticipant(
                claim.Id, acc.Id, new Map<String, Object>{
                    'Roles__c'    => ROLE_ADVERSE,
                    'Vehicule__c' => vehicles[i].Id,
                    'isDriver__c' => (Math.mod(i, 2) == 0)
                }
            ));
        }
        insert participants;

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(50, result.size());

        Set<Id> uniqueVehicleIds = new Set<Id>();
        for (VehicleHistoryController.VehicleWrapper w : result) {
            uniqueVehicleIds.add(w.vehicleId);
        }
        System.assertEquals(50, uniqueVehicleIds.size());
    }

    // ============================================================
    // TEST 16 — Vehicle with opposing car flag
    // ============================================================

    @isTest
    static void testGetVehicleHistory_OpposingVehicle() {
        Account acc            = getAccount();
        InsurancePolicy__c pol = getPolicy();
        Claim__c claim         = getClaim();

        DA_TestBuilderFactory factory = new DA_TestBuilderFactory();
        factory.withCustomVehicles(1, pol.Id, new Map<String, Object>{
            'RegistrationNumber__c' => 'OPP-001',
            'Brand__c'              => VALID_BRAND,
            'ModelePicklist__c'     => 'Focus',
            'isOpposingCar__c'      => true,
            'CompagnieAdverse__c'   => acc.Id,
            'AdversaireAssur__c'    => true,
            'ChassisNumber__c'      => 'CHS_OPP_001',
            'TypeVehicule__c'       => VALID_VEHICLE_TYPE
        });
        Vehicule__c opposingVehicle = factory.getVehicles()[0];

        factory.withClaimParticipants(1, claim.Id, acc.Id, new Map<String, Object>{
            'Roles__c'    => ROLE_ADVERSE,
            'Vehicule__c' => opposingVehicle.Id,
            'isDriver__c' => true
        });

        Test.startTest();
        List<VehicleHistoryController.VehicleWrapper> result =
            VehicleHistoryController.getVehicleHistory(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(opposingVehicle.Id, result[0].vehicleId);
        System.assertEquals(VALID_BRAND,         result[0].brand);
        System.assertEquals('Focus',             result[0].model);
    }
}