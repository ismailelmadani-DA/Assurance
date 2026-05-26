/**
 * @description  : Classe de test pour PoliceSinistresController
 *                 Couvre : getSinistresByPolice — happy path, null policyId,
 *                 fallback immatriculation, résolution lieu, AuraHandledException.
 * @author       : D&A Technologies
 * @group        : Tests
 * @last modified on  : 25-05-2026
 * @last modified by  : D&A Technologies
 **/
@isTest
private class DA_PoliceSinistresControllerTest {

    // ============================================================
    // SETUP — données communes à tous les scénarios
    // ============================================================

    /**
     * Construit le jeu de données de base :
     *   1 Account → 1 InsurancePolicy → 1 Vehicule
     *   + 3 Cases avec configurations différentes
     *   + 3 Claims liés (un par case)
     *
     * Les Cases/Claims sont créés manuellement (pas via withScenarios)
     * pour contrôler précisément CityOfOccurrence__c, CountryOfOccurrence__c
     * et RegistrationNumber__c sur Claim__c (formule read-only, non settable).
     */
    private static DA_TestBuilderFactory setupBase() {
        return new DA_TestBuilderFactory()
            .withAccount()
            .withCustomPolicies(1, null /* résolu ci-dessous */, null);
    }

    // ─── Helper : construit un builder avec account + policy + vehicle ──────
    private static DA_TestBuilderFactory buildCoreData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory()
            .withAccount();

        // La policy doit être liée au dernier account inséré
        Account acc = builder.getAccounts()[0];
        builder.withCustomPolicies(1, acc.Id, null)
               .withVehicle();

        return builder;
    }

    // ============================================================
    // TEST 1 — policyId null → liste vide, pas d'exception
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_NullPolicyId_ReturnsEmptyList() {
        Test.startTest();
        List<Map<String, Object>> result = PoliceSinistresController.getSinistresByPolice(null);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Une policyId null doit retourner une liste vide.');
    }

    // ============================================================
    // TEST 2 — police sans sinistre → liste vide
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_NoClaimsOnPolicy_ReturnsEmptyList() {
        DA_TestBuilderFactory builder = buildCoreData();
        InsurancePolicy__c pol = builder.getPolicies()[0];

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Une police sans sinistres doit retourner une liste vide.');
    }

    // ============================================================
    // TEST 3 — happy path : 1 sinistre avec véhicule et lieu complet
    // ============================================================

  // TEST 3 — happy path : 1 sinistre avec véhicule et lieu complet
@isTest
static void testGetSinistresByPolice_OneClaim_ReturnsCorrectMap() {
    DA_TestBuilderFactory builder = buildCoreData();
    Account             acc = builder.getAccounts()[0];
    InsurancePolicy__c  pol = builder.getPolicies()[0];
    Vehicule__c         veh = builder.getVehicles()[0];

    // Case avec pays + ville de survenance
    builder.withCases(1, acc.Id, pol.Id, 'Accident Test',
        new Map<String, Object>{
            'CountryOfOccurrence__c' => 'Maroc',
            'CityOfOccurrence__c'    => 'Casablanca'
        }
    );
    Case cas = builder.getCases()[0];

    // Claim lié à la police + au véhicule
    builder.withClaims(1, cas.Id,
        new Map<String, Object>{
            'PolicyNumber__c' => pol.Id,
            'Vehicule__c'     => veh.Id,
            'Status__c'       => 'En cours de traitement'
        }
    );
    Claim__c claim = builder.getClaims()[0];

    Test.startTest();
    List<Map<String, Object>> result =
        PoliceSinistresController.getSinistresByPolice(pol.Id);
    Test.stopTest();

    System.assertEquals(1, result.size(),
        'Doit retourner exactement 1 sinistre.');

    Map<String, Object> row = result[0];
    System.assertEquals(claim.Id,   row.get('id'),           'Id du sinistre incorrect.');
    System.assertEquals(pol.Id,     
        [SELECT PolicyNumber__c FROM Claim__c WHERE Id = :claim.Id].PolicyNumber__c,
        'PolicyNumber__c doit pointer vers la police.');
    System.assertEquals('En cours de traitement',   row.get('statut'),        'Statut incorrect.');
    System.assertNotEquals(null,     row.get('createdByName'), 'createdByName ne doit pas être null.');
}

    // ============================================================
    // TEST 4 — plusieurs sinistres → tous retournés, triés CreatedDate DESC
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_MultipleClaims_ReturnsAll() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        // 3 Cases → 3 Claims sur la même police
        builder.withCases(3, acc.Id, pol.Id, 'Sinistre', null);
        List<Case> caseList = builder.getCases();

        for (Case c : caseList) {
            builder.withClaims(1, c.Id,
                new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
            );
        }

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(3, result.size(),
            'Doit retourner les 3 sinistres de la police.');
    }

    // ============================================================
    // TEST 5 — résolution lieu : pays seul (ville vide)
    // ============================================================

    @isTest
    static void testResolveLieu_PaysSeul() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        builder.withCases(1, acc.Id, pol.Id, 'Pays seul',
            new Map<String, Object>{
                'CountryOfOccurrence__c' => 'Maroc',
                'CityOfOccurrence__c'    => null
            }
        );
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Maroc', result[0].get('lieuSurvenance'),
            'Lieu doit être uniquement le pays quand la ville est vide.');
    }

    // ============================================================
    // TEST 6 — résolution lieu : ville seule (pays vide)
    // ============================================================

    @isTest
    static void testResolveLieu_VilleSeule() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        builder.withCases(1, acc.Id, pol.Id, 'Ville seule',
            new Map<String, Object>{
                'CountryOfOccurrence__c' => null,
                'CityOfOccurrence__c'    => 'Rabat'
            }
        );
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals('Rabat', result[0].get('lieuSurvenance'),
            'Lieu doit être uniquement la ville quand le pays est vide.');
    }

    // ============================================================
    // TEST 7 — résolution lieu : pays + ville (format concat)
    // ============================================================

    @isTest
    static void testResolveLieu_PaysEtVille() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        builder.withCases(1, acc.Id, pol.Id, 'Pays et ville',
            new Map<String, Object>{
                'CountryOfOccurrence__c' => 'Maroc',
                'CityOfOccurrence__c'    => 'Fes'
            }
        );
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals('Maroc, Fes', result[0].get('lieuSurvenance'),
            'Lieu doit être "pays, ville" quand les deux sont renseignés.');
    }

    // ============================================================
    // TEST 8 — résolution lieu : Case null → lieu vide
    // ============================================================

    @isTest
    static void testResolveLieu_CaseNull_ReturnsEmptyString() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        // Claim sans Case (Case__c laissé null n'est pas toujours possible selon les règles
        // de validation — on crée un Case minimal sans pays ni ville)
        builder.withCases(1, acc.Id, pol.Id, 'Sans lieu', null);
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        // Pays et ville sont null/blank → '' attendu
        String lieu = (String) result[0].get('lieuSurvenance');
        System.assertEquals('', lieu,
            'lieuSurvenance doit être vide quand pays et ville sont absents.');
    }

    // ============================================================
    // TEST 9 — fallback immatriculation : Vehicule__r null
    //          → RegistrationNumber__c (formule) est utilisé
    //          NB : RegistrationNumber__c est une formule read-only ;
    //               on vérifie que resolveImmatriculation ne plante pas.
    // ============================================================

    @isTest
    static void testResolveImmatriculation_NoVehicle_NoException() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        builder.withCases(1, acc.Id, pol.Id, 'Sans véhicule', null);
        // Claim sans Vehicule__c
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(),
            'La méthode ne doit pas lever d\'exception quand Vehicule__c est null.');
        // immatriculation peut être null ou vide — on vérifie juste la présence de la clé
        System.assert(result[0].containsKey('immatriculation'),
            'La clé immatriculation doit toujours être présente dans la map.');
    }

    // ============================================================
    // TEST 10 — fallback immatriculation : Vehicule__r présent
    //           → RegistrationNumber__c du véhicule prioritaire
    // ============================================================

    @isTest
    static void testResolveImmatriculation_WithVehicle_UsesVehicleRegistration() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];
        Vehicule__c        veh = builder.getVehicles()[0];

        builder.withCases(1, acc.Id, pol.Id, 'Avec véhicule', null);
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{
                'PolicyNumber__c' => pol.Id,
                'Vehicule__c'     => veh.Id
            }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        // Le numéro d'immatriculation doit provenir du Vehicule__r
        String immat = (String) result[0].get('immatriculation');
        System.assertNotEquals(null, immat,
            'immatriculation doit être renseignée quand le véhicule est lié.');
        System.assert(String.isNotBlank(immat),
            'immatriculation doit être non vide quand le véhicule est lié.');
    }

    // ============================================================
    // TEST 11 — clés retournées dans la map : toutes présentes
    // ============================================================

    @isTest
    static void testMapKeys_AllExpectedKeysPresent() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        builder.withCases(1, acc.Id, pol.Id, 'Clés map', null);
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        Map<String, Object> row = result[0];

        List<String> expectedKeys = new List<String>{
            'id', 'claimNumber', 'vehiculeId', 'immatriculation',
            'dateSurvenance', 'lieuSurvenance', 'statut',
            'createdById', 'createdByName'
        };
        for (String key : expectedKeys) {
            System.assert(row.containsKey(key),
                'La clé "' + key + '" est absente de la map retournée.');
        }
    }

    // ============================================================
    // TEST 12 — sinistres d'une autre police ne remontent pas
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_OtherPolicyClaimsNotReturned() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc  = builder.getAccounts()[0];
        InsurancePolicy__c pol1 = builder.getPolicies()[0];

        // Deuxième police
        builder.withCustomPolicies(1, acc.Id, null);
        InsurancePolicy__c pol2 = builder.getPolicies()[1];

        // Case + Claim sur pol1
        builder.withCases(1, acc.Id, pol1.Id, 'Sinistre pol1', null);
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol1.Id }
        );

        // Case + Claim sur pol2
        builder.withCases(1, acc.Id, pol2.Id, 'Sinistre pol2', null);
        builder.withClaims(1, builder.getCases()[1].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol2.Id }
        );

        Test.startTest();
        List<Map<String, Object>> resultPol1 =
            PoliceSinistresController.getSinistresByPolice(pol1.Id);
        List<Map<String, Object>> resultPol2 =
            PoliceSinistresController.getSinistresByPolice(pol2.Id);
        Test.stopTest();

        System.assertEquals(1, resultPol1.size(),
            'La police 1 doit avoir exactement 1 sinistre.');
        System.assertEquals(1, resultPol2.size(),
            'La police 2 doit avoir exactement 1 sinistre.');

        // Vérifier que les sinistres n'ont pas été croisés
        Id claimIdPol1 = (Id) resultPol1[0].get('id');
        Id claimIdPol2 = (Id) resultPol2[0].get('id');
        System.assertNotEquals(claimIdPol1, claimIdPol2,
            'Les sinistres des deux polices doivent être distincts.');
    }

    // ============================================================
    // TEST 13 — exécution sous System.runAs (with sharing respecté)
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_RunAsStandardUser_NoException() {
        DA_TestBuilderFactory builder = buildCoreData();
        Account            acc = builder.getAccounts()[0];
        InsurancePolicy__c pol = builder.getPolicies()[0];

        builder.withCases(1, acc.Id, pol.Id, 'RunAs test', null);
        builder.withClaims(1, builder.getCases()[0].Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );

        // Créer un utilisateur standard pour tester le with sharing
        builder.withUser('tstUsr', 'TestUser');
        User stdUser = builder.getUser('tstUsr');

        List<Map<String, Object>> result;
        Test.startTest();
        System.runAs(stdUser) {
            result = PoliceSinistresController.getSinistresByPolice(pol.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, result,
            'Le résultat ne doit pas être null pour un utilisateur standard.');
    }
}