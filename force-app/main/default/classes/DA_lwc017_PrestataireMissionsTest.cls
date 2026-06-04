/**
 * @description  : Classe de test — DA_lwc017_PrestataireMissionsController
 * @author       : D&A Technologies
 * @date         : 2026-05-26
 * @coverage     : getMissionsByPrestataire — cas succès, cas null, cas aucun résultat
 */
@isTest
public class DA_lwc017_PrestataireMissionsTest {

    // ============================================================
    // SETUP — DONNÉES PARTAGÉES AVEC BUILDER
    // ============================================================

    /**
     * @description Construit le jeu de données minimal via DA_TestBuilderFactory :
     *   - 2 prestataires avec Name = 'Prestataire' (requis par lookup filter)
     *   - RecordType Prestataire appliqué automatiquement
     *   - 3 missions (2 pour le 1er prestataire, 1 pour le 2ème)
     * 
     * Note: Le lookup filter sur Case.Prestataire__c exige Account.Name = 'Prestataire'
     */
    @TestSetup
    static void makeData() {
        // Récupérer les RecordTypeId nécessaires
        Id missionRtId = DA_Utility.getRecordTypeId('Case', 'Mission');
        
        // 1. CRÉER LES PRESTATAIRES avec le builder
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
        
        // Override du Name pour respecter le lookup filter
        Map<String, Object> prestaParams1 = new Map<String, Object>{
            'Name' => 'Prestataire'  // ← CRITICAL: requis par le lookup filter
        };
        Map<String, Object> prestaParams2 = new Map<String, Object>{
            'Name' => 'Prestataire'  // ← CRITICAL: requis par le lookup filter
        };
        
        builder.withPrestataire('Garagiste')  // Premier prestataire
               .withPrestataire('Médecin');   // Deuxième prestataire
        
        // Récupérer les prestataires après insertion
        List<Account> prestataires = builder.getPrestataires();
        Id targetId = prestataires[0].Id;  // Garagiste
        Id otherId  = prestataires[1].Id;  // Médecin
        
        // Mettre à jour les noms pour respecter le lookup filter
        // Note: DA_TestDataFactory.createTestPrestataire génère 'Prestataire_' + suffix
        // Nous devons donc forcer le nom après insertion
        for (Account presta : prestataires) {
            presta.Name = 'Prestataire';
        }
        update prestataires;
        
        // 2. CRÉER LES MISSIONS
        List<Case> missions = new List<Case>{
            new Case(
                RecordTypeId = missionRtId,
                Subject = 'Mission Alpha',
                Prestataire__c = targetId,
                NatureMission__c = 'Expertise classique',
                Status = 'En cours'
            ),
            new Case(
                RecordTypeId = missionRtId,
                Subject = 'Mission Beta',
                Prestataire__c = targetId,
                NatureMission__c = 'Expertise contradictoire',
                Status = 'Terminé'
            ),
            new Case(
                RecordTypeId = missionRtId,
                Subject = 'Mission Autre',
                Prestataire__c = otherId,
                NatureMission__c = 'Expertise classique',
                Status = 'En cours'
            )
        };
        insert missions;
        
        // DEBUG: Vérification
        System.debug('=== DATA SETUP COMPLETED ===');
        System.debug('Prestataires: ' + prestataires.size());
        System.debug('Target ID: ' + targetId + ' - Name: ' + [SELECT Name FROM Account WHERE Id = :targetId].Name);
        System.debug('Missions: ' + missions.size());
    }

    // ============================================================
    // HELPER — RÉCUPÈRE L'ID DU PRESTATAIRE CIBLE (Garagiste)
    // ============================================================
    
    private static Id getTargetPrestaId() {
        return [
            SELECT Id 
            FROM Account 
            WHERE Name = 'Prestataire'           // ← Filtrer par le nom exact
              AND TypeDePrestataire__c = 'Garagiste'
            LIMIT 1
        ].Id;
    }

    // ============================================================
    // HELPER — RÉCUPÈRE L'ID DE L'AUTRE PRESTATAIRE (Médecin)
    // ============================================================
    
    private static Id getOtherPrestaId() {
        return [
            SELECT Id 
            FROM Account 
            WHERE Name = 'Prestataire'           // ← Filtrer par le nom exact
              AND TypeDePrestataire__c = 'Médecin'
            LIMIT 1
        ].Id;
    }

    // ============================================================
    // TEST 1 — CAS NOMINAL : 2 MISSIONS RETOURNÉES
    // ============================================================

    @isTest
    static void testGetMissions_returnsCorrectRows() {
        Id prestaId = getTargetPrestaId();
        
        Test.startTest();
        List<Map<String, Object>> result = 
            DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire(prestaId);
        Test.stopTest();
        
        // Vérifications
        System.assertEquals(2, result.size(),
            'Doit retourner exactement 2 missions pour le prestataire cible');
        
        // Vérification des clés présentes dans chaque row
        if (!result.isEmpty()) {
            Map<String, Object> row = result[0];
            System.assertNotEquals(null, row.get('id'), 'id manquant');
            System.assertNotEquals(null, row.get('caseNumber'), 'caseNumber manquant');
            System.assertNotEquals(null, row.get('status'), 'status manquant');
            System.assertNotEquals(null, row.get('createdDate'), 'createdDate manquant');
            System.assertNotEquals(null, row.get('createdById'), 'createdById manquant');
            System.assertNotEquals(null, row.get('createdByName'), 'createdByName manquant');
        }
    }

    // ============================================================
    // TEST 2 — ISOLATION : LE FILTRE Prestataire__c EST RESPECTÉ
    // ============================================================

    @isTest
    static void testGetMissions_isolationByPrestataire() {
        Id otherPrestaId = getOtherPrestaId();
        
        Test.startTest();
        List<Map<String, Object>> result = 
            DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire(otherPrestaId);
        Test.stopTest();
        
        System.assertEquals(1, result.size(),
            'Le filtre Prestataire__c doit exclure les missions des autres prestataires');
    }

    // ============================================================
    // TEST 3 — PARAMÈTRE NULL : RETOURNE LISTE VIDE
    // ============================================================

    @isTest
    static void testGetMissions_nullId_returnsEmpty() {
        Test.startTest();
        List<Map<String, Object>> result = 
            DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Ne doit jamais retourner null');
        System.assertEquals(0, result.size(),
            'Un accountId null doit retourner une liste vide');
    }

    // ============================================================
    // TEST 4 — PRESTATAIRE SANS MISSION : RETOURNE LISTE VIDE
    // ============================================================

    @isTest
    static void testGetMissions_prestaWithNoMissions_returnsEmpty() {
        // Créer un nouveau prestataire sans mission via le builder
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
        
        builder.withPrestataire('Clinique');
        
        List<Account> newPrestas = builder.getPrestataires();
        Account newPresta = newPrestas[0];
        
        // Forcer le nom pour respecter le lookup filter
        newPresta.Name = 'Prestataire';
        update newPresta;
        
        Test.startTest();
        List<Map<String, Object>> result = 
            DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire(newPresta.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Ne doit jamais retourner null');
        System.assertEquals(0, result.size(), 'Aucune mission attendue pour ce prestataire');
    }

    // ============================================================
    // TEST 5 — VÉRIFICATION DU CHAMP natureMission
    // ============================================================

    @isTest
    static void testGetMissions_natureMissionFieldMapped() {
        Id prestaId = getTargetPrestaId();
        
        Test.startTest();
        List<Map<String, Object>> result = 
            DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire(prestaId);
        Test.stopTest();
        
        // Le champ natureMission doit être présent
        Boolean atLeastOneWithNature = false;
        for (Map<String, Object> row : result) {
            if (row.get('natureMission') != null) {
                atLeastOneWithNature = true;
                break;
            }
        }
        System.assert(atLeastOneWithNature,
            'Au moins une mission doit avoir natureMission renseigné');
    }

    // ============================================================
    // TEST 6 — CHAMP createdByName NON VIDE
    // ============================================================

    @isTest
    static void testGetMissions_createdByNamePopulated() {
        Id prestaId = getTargetPrestaId();
        
        Test.startTest();
        List<Map<String, Object>> result = 
            DA_lwc017_PrestataireMissionsController.getMissionsByPrestataire(prestaId);
        Test.stopTest();
        
        for (Map<String, Object> row : result) {
            String name = (String) row.get('createdByName');
            System.assertNotEquals(null, name,
                'createdByName ne doit pas être null — la relation CreatedBy doit être résolue');
            System.assertNotEquals('', name,
                'createdByName ne doit pas être une chaîne vide');
        }
    }
}