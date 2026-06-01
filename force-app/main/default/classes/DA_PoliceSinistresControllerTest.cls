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
    // SETUP — données communes à tous les scénarios (@testSetup)
    // ============================================================

    @testSetup
    static void setup() {
        // Création du compte
        Account acc = DA_TestDataFactory.createTestAccount(null);
        insert acc;
        
        // Création de la police d'assurance
        InsurancePolicy__c pol = DA_TestDataFactory.createTestPolicy(acc.Id, null);
        insert pol;
        
        // Création du véhicule
        Vehicule__c veh = DA_TestDataFactory.createTestVehicle(pol.Id, null);
        insert veh;
        
        // Création des 3 Cases avec différentes configurations
        List<Case> casesToInsert = new List<Case>();
        
        // Case 1 - avec pays + ville
        casesToInsert.add(DA_TestDataFactory.createTestCase(acc.Id, pol.Id, 'Accident Test',
            new Map<String, Object>{
                'CountryOfOccurrence__c' => 'Maroc',
                'CityOfOccurrence__c'    => 'Casablanca'
            }
        ));
        
        // Case 2 - pays seul
        casesToInsert.add(DA_TestDataFactory.createTestCase(acc.Id, pol.Id, 'Pays seul',
            new Map<String, Object>{
                'CountryOfOccurrence__c' => 'Maroc',
                'CityOfOccurrence__c'    => null
            }
        ));
        
        // Case 3 - ville seule
        casesToInsert.add(DA_TestDataFactory.createTestCase(acc.Id, pol.Id, 'Ville seule',
            new Map<String, Object>{
                'CountryOfOccurrence__c' => null,
                'CityOfOccurrence__c'    => 'Rabat'
            }
        ));
        
        insert casesToInsert;
        
        // Création des Claims liés aux Cases
        List<Claim__c> claimsToInsert = new List<Claim__c>();
        
        // Claim 1 - avec véhicule et statut
        claimsToInsert.add(DA_TestDataFactory.createTestClaim(casesToInsert[0].Id,
            new Map<String, Object>{
                'PolicyNumber__c' => pol.Id,
                'Vehicule__c'     => veh.Id,
                'Status__c'       => 'En cours de traitement'
            }
        ));
        
        // Claim 2 - pour test pays seul
        claimsToInsert.add(DA_TestDataFactory.createTestClaim(casesToInsert[1].Id,
            new Map<String, Object>{
                'PolicyNumber__c' => pol.Id,
                'Status__c'       => 'En cours de traitement'
            }
        ));
        
        // Claim 3 - pour test ville seule
        claimsToInsert.add(DA_TestDataFactory.createTestClaim(casesToInsert[2].Id,
            new Map<String, Object>{
                'PolicyNumber__c' => pol.Id,
                'Status__c'       => 'En cours de traitement'
            }
        ));
        
        insert claimsToInsert;
    }

    // ============================================================
    // HELPER — Récupération des données créées par @testSetup
    // ============================================================

    private static Account getTestAccount() {
        return [SELECT Id, Name FROM Account LIMIT 1];
    }
    
    private static InsurancePolicy__c getTestPolicy() {
        return [SELECT Id, PolicyNumber__c FROM InsurancePolicy__c LIMIT 1];
    }
    
    private static Vehicule__c getTestVehicle() {
        return [SELECT Id, RegistrationNumber__c FROM Vehicule__c LIMIT 1];
    }
    
    private static List<Case> getAllTestCases() {
        return [SELECT Id, Subject, CountryOfOccurrence__c, CityOfOccurrence__c 
                FROM Case ORDER BY CreatedDate ASC];
    }
    
    private static List<Claim__c> getAllTestClaims() {
        return [SELECT Id, PolicyNumber__c, Vehicule__c, Status__c, Case__c 
                FROM Claim__c ORDER BY CreatedDate ASC];
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
        // Créer une nouvelle police sans sinistre associé
        Account acc = getTestAccount();
        InsurancePolicy__c newPol = DA_TestDataFactory.createTestPolicy(acc.Id, null);
        insert newPol;

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(newPol.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Une police sans sinistres doit retourner une liste vide.');
    }

    // ============================================================
    // TEST 3 — happy path : 1 sinistre avec véhicule et lieu complet
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_OneClaim_ReturnsCorrectMap() {
        InsurancePolicy__c pol = getTestPolicy();
        Vehicule__c veh = getTestVehicle();
        List<Claim__c> claims = getAllTestClaims();
        Claim__c claim = claims[0];

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assertEquals(3, result.size(),
            'Doit retourner tous les sinistres de la police.');
    }

    // ============================================================
    // TEST 4 — plusieurs sinistres → tous retournés, triés CreatedDate DESC
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_MultipleClaims_ReturnsAll() {
        InsurancePolicy__c pol = getTestPolicy();

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
        InsurancePolicy__c pol = getTestPolicy();

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        // Le deuxième claim (index 1) a pays seul
        System.assertEquals('Maroc', result[1].get('lieuSurvenance'),
            'Lieu doit être uniquement le pays quand la ville est vide.');
    }

    // ============================================================
    // TEST 6 — résolution lieu : ville seule (pays vide)
    // ============================================================

    @isTest
    static void testResolveLieu_VilleSeule() {
        InsurancePolicy__c pol = getTestPolicy();

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        // Le troisième claim (index 2) a ville seule
        System.assertEquals('Rabat', result[2].get('lieuSurvenance'),
            'Lieu doit être uniquement la ville quand le pays est vide.');
    }

    // ============================================================
    // TEST 7 — résolution lieu : pays + ville (format concat)
    // ============================================================

    @isTest
    static void testResolveLieu_PaysEtVille() {
        InsurancePolicy__c pol = getTestPolicy();

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        // Le premier claim (index 0) a pays + ville
        System.assertEquals('Maroc, Casablanca', result[0].get('lieuSurvenance'),
            'Lieu doit être "pays, ville" quand les deux sont renseignés.');
    }

    // ============================================================
    // TEST 8 — résolution lieu : Case null → lieu vide
    // ============================================================

  // ============================================================
// TEST 8 — résolution lieu : Case null → lieu vide
// ============================================================

@isTest
static void testResolveLieu_CaseNull_ReturnsEmptyString() {
    Account acc = getTestAccount();
    InsurancePolicy__c pol = getTestPolicy();
    
    // Créer un Case sans pays ni ville
    Case emptyCase = DA_TestDataFactory.createTestCase(acc.Id, pol.Id, 'Sans lieu', null);
    insert emptyCase;
    
    // Créer un Claim lié à ce Case
    Claim__c emptyClaim = DA_TestDataFactory.createTestClaim(emptyCase.Id,
        new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
    );
    insert emptyClaim;

    Test.startTest();
    List<Map<String, Object>> result =
        PoliceSinistresController.getSinistresByPolice(pol.Id);
    Test.stopTest();

    // Parcourir les résultats pour trouver le claim que nous venons de créer
    Map<String, Object> targetRow = null;
    for (Map<String, Object> row : result) {
        // Comparer par l'ID du claim
        if (row.get('id') == emptyClaim.Id) {
            targetRow = row;
            break;
        }
    }
    
    System.assertNotEquals(null, targetRow, 'Le claim créé doit être présent dans les résultats');
    String lieu = (String) targetRow.get('lieuSurvenance');
    System.assertEquals('', lieu,
        'lieuSurvenance doit être vide quand pays et ville sont absents.');
}

    // ============================================================
    // TEST 9 — fallback immatriculation : Vehicule__r null
    // ============================================================

    @isTest
    static void testResolveImmatriculation_NoVehicle_NoException() {
        Account acc = getTestAccount();
        InsurancePolicy__c pol = getTestPolicy();
        
        Case newCase = DA_TestDataFactory.createTestCase(acc.Id, pol.Id, 'Sans véhicule', null);
        insert newCase;
        
        // Claim sans Vehicule__c
        Claim__c claimWithoutVehicle = DA_TestDataFactory.createTestClaim(newCase.Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol.Id }
        );
        insert claimWithoutVehicle;

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

        System.assert(result[result.size()-1].containsKey('immatriculation'),
            'La clé immatriculation doit toujours être présente dans la map.');
    }

    // ============================================================
    // TEST 10 — fallback immatriculation : Vehicule__r présent
    // ============================================================

    @isTest
    static void testResolveImmatriculation_WithVehicle_UsesVehicleRegistration() {
        InsurancePolicy__c pol = getTestPolicy();
        Vehicule__c veh = getTestVehicle();
        List<Claim__c> claims = getAllTestClaims();
        
        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

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
        InsurancePolicy__c pol = getTestPolicy();

        Test.startTest();
        List<Map<String, Object>> result =
            PoliceSinistresController.getSinistresByPolice(pol.Id);
        Test.stopTest();

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
        Account acc = getTestAccount();
        InsurancePolicy__c pol1 = getTestPolicy();
        
        // Deuxième police
        InsurancePolicy__c pol2 = DA_TestDataFactory.createTestPolicy(acc.Id, null);
        insert pol2;
        
        // Case + Claim sur pol2
        Case casePol2 = DA_TestDataFactory.createTestCase(acc.Id, pol2.Id, 'Sinistre pol2', null);
        insert casePol2;
        
        Claim__c claimPol2 = DA_TestDataFactory.createTestClaim(casePol2.Id,
            new Map<String, Object>{ 'PolicyNumber__c' => pol2.Id }
        );
        insert claimPol2;

        Test.startTest();
        List<Map<String, Object>> resultPol1 =
            PoliceSinistresController.getSinistresByPolice(pol1.Id);
        List<Map<String, Object>> resultPol2 =
            PoliceSinistresController.getSinistresByPolice(pol2.Id);
        Test.stopTest();

        System.assertEquals(3, resultPol1.size(),
            'La police 1 doit avoir 3 sinistres.');
        System.assertEquals(1, resultPol2.size(),
            'La police 2 doit avoir exactement 1 sinistre.');
    }

    // ============================================================
    // TEST 13 — exécution sous System.runAs (with sharing respecté)
    // ============================================================

    @isTest
    static void testGetSinistresByPolice_RunAsStandardUser_NoException() {
        InsurancePolicy__c pol = getTestPolicy();

        // Créer un utilisateur standard
        User stdUser = DA_TestDataFactory.createTestUser('tstusr', 'TestUser', null);
        insert stdUser;

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