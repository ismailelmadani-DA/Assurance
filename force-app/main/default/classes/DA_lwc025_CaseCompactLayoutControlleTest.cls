/**
 * @description       : Tests unitaires du controller compact layout (DA_lwc025) et d'EM_Case :
 *                      getRecordData (Declaration/Mission/Requete, null checks, objet inconnu,
 *                      enregistrement introuvable), closeCase, cancelCase, takeOverCase,
 *                      et les 5 branches d'upsertRequeteReaffectation via EM_Case directement.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 26-05-2026
 */
@isTest
public class DA_lwc025_CaseCompactLayoutControlleTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    // ─────────────────────────────────────────────────────────────
    // CONSTANTES
    // ─────────────────────────────────────────────────────────────

    private static final String RT_DECLARATION = 'Declaration';
    private static final String RT_MISSION     = 'Mission';
    private static final String RT_REQUETE     = 'Requete';
    private static final String OBJ_CASE       = 'Case';

    private static final String FIELDS_CSV_DECLARATION = 'Subject,Status,OwnerId';
    private static final String FIELDS_CSV_MISSION     = 'Subject,Status';
    private static final String FIELDS_CSV_REQUETE     = 'Subject,Status,TypeRequete__c,CategorieRequete__c';

    private static final String STATUT_INITIALE = 'Initiale';
    private static final String STATUT_EN_COURS = 'En cours';
    private static final String STATUT_REJETEE  = 'Rejetée';
    private static final String STATUT_CLOTUREE = 'Clôturée';

    // ─────────────────────────────────────────────────────────────
    // HELPER — création requête de réaffectation
    // ─────────────────────────────────────────────────────────────

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

    // ─────────────────────────────────────────────────────────────
    // HELPER — Id d'un RecordType Case
    // ─────────────────────────────────────────────────────────────

    private static Id getRecordTypeId(String devName) {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = :devName LIMIT 1].Id;
    }

    /**
    * @description      :   Configure les données de test : utilisateurs (mgr/usr/unm/tgt),
    *                       compte, police, véhicule, et Cases dans chaque RecordType
    *                       (Declaration, Mission, Requete) + requêtes pré-insérées par statut
    *                       pour les scénarios EM_Case.
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
            .withUserAndManager('usr', 'Regular', 'mgr')
            .withUser('unm', 'NoManager')
            .withUser('tgt', 'Target')
            .withAccount();

        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);
        builder.withVehicle();

        // Scénarios Cases identifiés par Subject
        // Valeur null = pas de Flags (champ non utilisé sur Case, withScenarios crée Case + Claim__c)
        builder.withScenarios(new Map<String, String>{
            'DECL_COMPACT'        => null,  // getRecordData RecordType Declaration
            'DECL_WITH_REAFFECT'  => null,  // getRecordData Declaration + requête En cours liée (reaffecterAId)
            'DECL_WITH_INITIALE'  => null,  // getRecordData Declaration + requête Initiale liée (requeteInitialeId)
            'DECL_DATE_LOOKUP'    => null,  // getRecordData Declaration avec champs date + lookup + relationship
            'MISSION_COMPACT'     => null,  // getRecordData RecordType Mission
            'REQUETE_COMPACT'     => null,  // getRecordData RecordType Requete (réaffectation)
            'REQUETE_AUTRE'       => null,  // getRecordData RecordType Requete (autre type)
            'CLOSE_CASE'          => null,  // closeCase
            'CANCEL_CASE'         => null,  // cancelCase
            'TAKEOVER_CASE'       => null,  // takeOverCase
            'EM_NEW'              => null,  // upsertRequete : aucune existante
            'EM_REJECTED'         => null,  // upsertRequete : existante Rejetée
            'EM_ENCOURS'          => null,  // upsertRequete : existante En cours
            'EM_INITIALE'         => null,  // upsertRequete : existante Initiale
            'EM_CLOTUREE'         => null,  // upsertRequete : existante Clôturée
            'EM_VALIDER'          => null,  // validerReaffectation
            'EM_REJETER'          => null   // rejeterReaffectation
        });

        // Mise à jour des RecordType sur les Cases concernés
        Id rtDecl    = getRecordTypeId(RT_DECLARATION);
        Id rtMission = getRecordTypeId(RT_MISSION);
        Id rtRequete = getRecordTypeId(RT_REQUETE);

        Map<String, Id> caseIdBySubject = new Map<String, Id>();
        for (Case c : [
            SELECT Id, Subject FROM Case
            WHERE Subject IN (
                'DECL_COMPACT','DECL_WITH_REAFFECT','DECL_WITH_INITIALE','DECL_DATE_LOOKUP',
                'MISSION_COMPACT','REQUETE_COMPACT','REQUETE_AUTRE',
                'CLOSE_CASE','CANCEL_CASE','TAKEOVER_CASE',
                'EM_NEW','EM_REJECTED','EM_ENCOURS','EM_INITIALE','EM_CLOTUREE',
                'EM_VALIDER','EM_REJETER'
            )
        ]) {
            caseIdBySubject.put(c.Subject, c.Id);
        }

        // Appliquer les RecordTypes appropriés
        List<Case> toUpdate = new List<Case>();
        toUpdate.add(new Case(Id = caseIdBySubject.get('DECL_COMPACT'),       RecordTypeId = rtDecl));
        toUpdate.add(new Case(Id = caseIdBySubject.get('DECL_WITH_REAFFECT'), RecordTypeId = rtDecl,
            DateOfOccurrence__c = Date.today()));
        toUpdate.add(new Case(Id = caseIdBySubject.get('DECL_WITH_INITIALE'), RecordTypeId = rtDecl,
            DateOfOccurrence__c = Date.today()));
        toUpdate.add(new Case(Id = caseIdBySubject.get('DECL_DATE_LOOKUP'),   RecordTypeId = rtDecl,
            DateOfOccurrence__c = Date.today()));
        toUpdate.add(new Case(Id = caseIdBySubject.get('MISSION_COMPACT'), RecordTypeId = rtMission));
        toUpdate.add(new Case(Id = caseIdBySubject.get('REQUETE_COMPACT'), RecordTypeId = rtRequete,
            TypeRequete__c = 'Réaffecter la déclaration', CategorieRequete__c = 'Réaffectation'));
        toUpdate.add(new Case(Id = caseIdBySubject.get('REQUETE_AUTRE'),   RecordTypeId = rtRequete,
            CategorieRequete__c = 'Traitement courrier'));
        for (String subj : new List<String>{
                'CLOSE_CASE','CANCEL_CASE','TAKEOVER_CASE',
                'EM_NEW','EM_REJECTED','EM_ENCOURS','EM_INITIALE','EM_CLOTUREE',
                'EM_VALIDER','EM_REJETER'}) {
            toUpdate.add(new Case(Id = caseIdBySubject.get(subj), RecordTypeId = rtDecl));
        }
        update toUpdate;

        User mgr = builder.getUser('mgr');
        User usr = builder.getUser('usr');
        User tgt = builder.getUser('tgt');

        // Requêtes pour DECL_WITH_REAFFECT : statut En cours → alimente reaffecterAId
        insertRequete(caseIdBySubject.get('DECL_WITH_REAFFECT'), tgt.Id, usr.Id, mgr.Id, 'En cours');
        // Requête pour DECL_WITH_INITIALE : statut Initiale → alimente requeteInitialeId
        insertRequete(caseIdBySubject.get('DECL_WITH_INITIALE'), tgt.Id, usr.Id, mgr.Id, 'Initiale');

        // Requêtes pré-insérées pour les scénarios EM_Case
        insertRequete(caseIdBySubject.get('EM_REJECTED'), tgt.Id, usr.Id, mgr.Id, 'Rejetée');
        insertRequete(caseIdBySubject.get('EM_ENCOURS'),  tgt.Id, usr.Id, mgr.Id, 'En cours');
        insertRequete(caseIdBySubject.get('EM_INITIALE'), tgt.Id, usr.Id, mgr.Id, 'Initiale');
        insertRequete(caseIdBySubject.get('EM_CLOTUREE'), tgt.Id, usr.Id, mgr.Id, 'Clôturée');
        insertRequete(caseIdBySubject.get('EM_VALIDER'),  tgt.Id, usr.Id, mgr.Id, 'En cours');
        insertRequete(caseIdBySubject.get('EM_REJETER'),  tgt.Id, usr.Id, mgr.Id, 'En cours');
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 1 — getRecordData : validations des paramètres
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getRecordData lève une AuraHandledException quand recordId est null.
    * @method Name      :   test_getRecordData_nullRecordId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_nullRecordId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    null, OBJ_CASE, FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour recordId null');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que getRecordData lève une AuraHandledException quand objectApiName est vide.
    * @method Name      :   test_getRecordData_blankObjectApiName_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_blankObjectApiName_throws() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, '', FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour objectApiName vide');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que getRecordData lève une AuraHandledException quand fieldsCsv est vide.
    * @method Name      :   test_getRecordData_blankFieldsCsv_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_blankFieldsCsv_throws() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE, '', RT_DECLARATION
                );
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour fieldsCsv vide');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que getRecordData lève une AuraHandledException quand recordTypeName est vide.
    * @method Name      :   test_getRecordData_blankRecordTypeName_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_blankRecordTypeName_throws() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE, FIELDS_CSV_DECLARATION, ''
                );
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour recordTypeName vide');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que getRecordData lève une AuraHandledException quand l'objet est inconnu.
    * @method Name      :   test_getRecordData_unknownObject_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_unknownObject_throws() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, 'ObjetInconnu__xyz', FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour objet inconnu');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que getRecordData lève une AuraHandledException quand l'enregistrement est introuvable.
    * @method Name      :   test_getRecordData_recordNotFound_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_recordNotFound_throws() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];
        Id missingId = decl.Id;
        delete decl;

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    missingId, OBJ_CASE, FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour enregistrement introuvable');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 2 — getRecordData : RecordType Declaration
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getRecordData retourne un CompactData correctement peuplé
    *                       pour un Case de type Declaration.
    * @method Name      :   test_getRecordData_declaration_returnsCompactData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_declaration_returnsCompactData() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE, FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
            Test.stopTest();

            System.assertNotEquals(null, data,                   'CompactData ne doit pas être null');
            System.assertEquals(String.valueOf(decl.Id), data.caseId, 'caseId doit correspondre');
            System.assertEquals(OBJ_CASE,      data.objectApiName,   'objectApiName doit être Case');
            System.assertEquals(RT_DECLARATION, data.recordTypeName,  'recordTypeName doit être Declaration');
            System.assertEquals('Déclaration',  data.headerLabel,     'headerLabel doit être Déclaration');
            System.assertEquals('standard:case', data.iconName,       'iconName doit être standard:case');
            System.assertNotEquals(null, data.caseNumber, 'caseNumber ne doit pas être null');
            System.assertNotEquals(null, data.fields,     'fields ne doit pas être null');
            System.assertNotEquals(null, data.actions,    'actions ne doit pas être null');
            System.assert(data.fields.size() > 0, 'fields doit contenir au moins un élément');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData retourne les 2 actions attendues pour une Declaration.
    * @method Name      :   test_getRecordData_declaration_returnsTwoActions
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_declaration_returnsTwoActions() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_COMPACT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE, FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
            Test.stopTest();

            System.assertEquals(2, data.actions.size(), 'Declaration doit avoir 2 actions');
            Set<String> actionNames = new Set<String>();
            for (DA_lwc025_CaseCompactLayoutController.ActionItem a : data.actions) {
                actionNames.add(a.name);
            }
            System.assert(actionNames.contains('continueDeclaration'), 'Action continueDeclaration attendue');
            System.assert(actionNames.contains('reassign'),            'Action reassign attendue');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 3 — getRecordData : RecordType Mission
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getRecordData retourne un CompactData avec headerLabel Mission
    *                       et icon standard:task pour un Case de type Mission.
    * @method Name      :   test_getRecordData_mission_returnsCorrectHeaderAndIcon
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_mission_returnsCorrectHeaderAndIcon() {
        User usr     = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case mission = [SELECT Id FROM Case WHERE Subject = 'MISSION_COMPACT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    mission.Id, OBJ_CASE, FIELDS_CSV_MISSION, RT_MISSION
                );
            Test.stopTest();

            System.assertNotEquals(null, data, 'CompactData ne doit pas être null');
            System.assertEquals('Mission',       data.headerLabel, 'headerLabel doit être Mission');
            System.assertEquals('standard:task', data.iconName,    'iconName doit être standard:task');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData retourne les 2 actions cancel/close pour une Mission.
    * @method Name      :   test_getRecordData_mission_returnsCancelAndCloseActions
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_mission_returnsCancelAndCloseActions() {
        User usr     = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case mission = [SELECT Id FROM Case WHERE Subject = 'MISSION_COMPACT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    mission.Id, OBJ_CASE, FIELDS_CSV_MISSION, RT_MISSION
                );
            Test.stopTest();

            System.assertEquals(2, data.actions.size(), 'Mission doit avoir 2 actions');
            Set<String> actionNames = new Set<String>();
            for (DA_lwc025_CaseCompactLayoutController.ActionItem a : data.actions) {
                actionNames.add(a.name);
            }
            System.assert(actionNames.contains('cancel'), 'Action cancel attendue');
            System.assert(actionNames.contains('close'),  'Action close attendue');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 4 — getRecordData : RecordType Requete (réaffectation)
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getRecordData retourne les actions valider/rejeter
    *                       pour une Requete de type réaffectation.
    * @method Name      :   test_getRecordData_requeteReaffectation_returnsValidateRejectActions
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_requeteReaffectation_returnsValidateRejectActions() {
        User usr     = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case requete = [SELECT Id FROM Case WHERE Subject = 'REQUETE_COMPACT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    requete.Id, OBJ_CASE, FIELDS_CSV_REQUETE, RT_REQUETE
                );
            Test.stopTest();

            System.assertNotEquals(null, data, 'CompactData ne doit pas être null');
            System.assertEquals('Requête',                data.headerLabel, 'headerLabel doit être Requête');
            System.assertEquals('standard:question_feed', data.iconName,    'iconName doit être standard:question_feed');
            System.assertEquals(2, data.actions.size(), 'Requete réaffectation doit avoir 2 actions');

            Set<String> actionNames = new Set<String>();
            for (DA_lwc025_CaseCompactLayoutController.ActionItem a : data.actions) {
                actionNames.add(a.name);
            }
            System.assert(actionNames.contains('validateReassign'), 'Action validateReassign attendue');
            System.assert(actionNames.contains('rejectReassign'),   'Action rejectReassign attendue');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData retourne les actions close/reassign/takeOver
    *                       pour une Requete d'un autre type (non réaffectation).
    * @method Name      :   test_getRecordData_requeteAutre_returnsGenericActions
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_requeteAutre_returnsGenericActions() {
        User usr     = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case requete = [SELECT Id FROM Case WHERE Subject = 'REQUETE_AUTRE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    requete.Id, OBJ_CASE, FIELDS_CSV_REQUETE, RT_REQUETE
                );
            Test.stopTest();

            System.assertEquals(3, data.actions.size(), 'Requete autre doit avoir 3 actions');
            Set<String> actionNames = new Set<String>();
            for (DA_lwc025_CaseCompactLayoutController.ActionItem a : data.actions) {
                actionNames.add(a.name);
            }
            System.assert(actionNames.contains('close'),    'Action close attendue');
            System.assert(actionNames.contains('reassign'), 'Action reassign attendue');
            System.assert(actionNames.contains('takeOver'), 'Action takeOver attendue');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 5 — closeCase / cancelCase / takeOverCase
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que closeCase lève une AuraHandledException quand recordId est null.
    * @method Name      :   test_closeCase_nullId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_closeCase_nullId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.closeCase(null);
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour closeCase null');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que closeCase passe le statut du Case à Clôturé.
    * @method Name      :   test_closeCase_setsStatusCloture
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_closeCase_setsStatusCloture() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case c    = [SELECT Id FROM Case WHERE Subject = 'CLOSE_CASE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.closeCase(c.Id);
            Test.stopTest();

            Case updated = [SELECT Status FROM Case WHERE Id = :c.Id];
            System.assertEquals('Clôturé', updated.Status, 'Le statut doit être Clôturé');
        }
    }

    /**
    * @description      :   Vérifie que cancelCase lève une AuraHandledException quand recordId est null.
    * @method Name      :   test_cancelCase_nullId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_cancelCase_nullId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.cancelCase(null);
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour cancelCase null');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que cancelCase passe le statut du Case à Annulé.
    * @method Name      :   test_cancelCase_setsStatusAnnule
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_cancelCase_setsStatusAnnule() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case c   = [SELECT Id FROM Case WHERE Subject = 'CANCEL_CASE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.cancelCase(c.Id);
            Test.stopTest();

            Case updated = [SELECT Status FROM Case WHERE Id = :c.Id];
            System.assertEquals('Annulé', updated.Status, 'Le statut doit être Annulé');
        }
    }

    /**
    * @description      :   Vérifie que takeOverCase lève une AuraHandledException quand recordId est null.
    * @method Name      :   test_takeOverCase_nullId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_takeOverCase_nullId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_lwc025_CaseCompactLayoutController.takeOverCase(null);
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour takeOverCase null');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    /**
    * @description      :   Vérifie que takeOverCase passe le statut à En cours
    *                       et réassigne l'OwnerId à l'utilisateur courant.
    * @method Name      :   test_takeOverCase_setsStatusAndOwner
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_takeOverCase_setsStatusAndOwner() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case c   = [SELECT Id FROM Case WHERE Subject = 'TAKEOVER_CASE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.takeOverCase(c.Id);
            Test.stopTest();

            Case updated = [SELECT Status, OwnerId FROM Case WHERE Id = :c.Id];
            System.assertEquals('En cours', updated.Status,  'Le statut doit être En cours');
            System.assertEquals(usr.Id,      updated.OwnerId, 'L\'OwnerId doit être l\'utilisateur courant');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 6 — EM_Case.upsertRequeteReaffectation : aucune existante
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que upsertRequeteReaffectation crée une nouvelle requête
    *                       quand aucune requête n'existe pour la déclaration.
    * @method Name      :   test_upsert_noExisting_insertsNewRequete
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsert_noExisting_insertsNewRequete() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'EM_NEW' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Id requeteId = EM_Case.upsertRequeteReaffectation(decl.Id, tgt.Id, 'Motif initial', mgr.Id);
            Test.stopTest();

            System.assertNotEquals(null, requeteId, 'Un Id de requête doit être retourné');

            Case requete = [
                SELECT Status, ReaffecterA__c, Motif_Reaffectation__c,
                       Declaration_Liee__c, CategorieRequete__c, TypeRequete__c
                FROM Case WHERE Id = :requeteId
            ];
            System.assertEquals(STATUT_INITIALE,              requete.Status,                'Statut doit être Initiale');
            System.assertEquals(tgt.Id,                        requete.ReaffecterA__c,        'ReaffecterA doit être tgt');
            System.assertEquals('Motif initial',              requete.Motif_Reaffectation__c,'Motif doit être conservé');
            System.assertEquals(decl.Id,                       requete.Declaration_Liee__c,   'Déclaration liée correcte');
            System.assertEquals('Réaffectation',               requete.CategorieRequete__c,   'Catégorie correcte');
            System.assertEquals('Réaffecter la déclaration',  requete.TypeRequete__c,        'Type correct');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 7 — EM_Case.upsertRequeteReaffectation : existante Rejetée
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que upsertRequeteReaffectation supprime la requête rejetée
    *                       et en crée une nouvelle.
    * @method Name      :   test_upsert_existingRejected_deletesAndReinserts
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsert_existingRejected_deletesAndReinserts() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'EM_REJECTED' LIMIT 1];
        Case ancienne = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];
        Id ancienneId = ancienne.Id;

        // mgr est OwnerId de la requête insérée en @TestSetup — il a les droits de suppression
        System.runAs(mgr) {
            Test.startTest();
            Id nouvellId = EM_Case.upsertRequeteReaffectation(decl.Id, tgt.Id, 'Nouvelle tentative', mgr.Id);
            Test.stopTest();

            System.assertNotEquals(null,       nouvellId, 'Nouvel Id doit être retourné');
            System.assertNotEquals(ancienneId, nouvellId, 'Le nouvel Id doit être différent');

            List<Case> ancienneCheck = [SELECT Id FROM Case WHERE Id = :ancienneId];
            System.assertEquals(0, ancienneCheck.size(), 'L\'ancienne requête rejetée doit être supprimée');

            Case nouvelle = [SELECT Status FROM Case WHERE Id = :nouvellId];
            System.assertEquals(STATUT_INITIALE, nouvelle.Status, 'La nouvelle requête doit être Initiale');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 8 — EM_Case.upsertRequeteReaffectation : existante En cours
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que upsertRequeteReaffectation remet la requête à Initiale
    *                       et réassigne l'OwnerId au manager quand la requête est En cours.
    * @method Name      :   test_upsert_existingEnCours_resetsToInitiale
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsert_existingEnCours_resetsToInitiale() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'EM_ENCOURS' LIMIT 1];
        Case existante = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Id requeteId = EM_Case.upsertRequeteReaffectation(decl.Id, tgt.Id, 'Nouveau motif', mgr.Id);
            Test.stopTest();

            System.assertEquals(existante.Id, requeteId, 'L\'Id doit être celui de la requête existante');

            Case updated = [SELECT Status, OwnerId, Motif_Reaffectation__c FROM Case WHERE Id = :requeteId];
            System.assertEquals(STATUT_INITIALE,   updated.Status,                'Doit repasser à Initiale');
            System.assertEquals(mgr.Id,             updated.OwnerId,               'OwnerId doit être le manager');
            System.assertEquals('Nouveau motif',   updated.Motif_Reaffectation__c,'Motif doit être mis à jour');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 9 — EM_Case.upsertRequeteReaffectation : existante Initiale
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que upsertRequeteReaffectation met à jour ReaffecterA et Motif
    *                       sans changer le statut quand la requête est Initiale.
    * @method Name      :   test_upsert_existingInitiale_updatesFieldsOnly
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsert_existingInitiale_updatesFieldsOnly() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'EM_INITIALE' LIMIT 1];
        Case existante = [
            SELECT Id FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(usr) {
            Test.startTest();
            Id requeteId = EM_Case.upsertRequeteReaffectation(decl.Id, tgt.Id, 'Motif modifié', mgr.Id);
            Test.stopTest();

            System.assertEquals(existante.Id, requeteId, 'L\'Id doit être celui de la requête existante');

            Case updated = [SELECT Status, ReaffecterA__c, Motif_Reaffectation__c FROM Case WHERE Id = :requeteId];
            System.assertEquals(STATUT_INITIALE, updated.Status,                'Statut doit rester Initiale');
            System.assertEquals(tgt.Id,           updated.ReaffecterA__c,        'ReaffecterA doit être mis à jour');
            System.assertEquals('Motif modifié', updated.Motif_Reaffectation__c,'Motif doit être mis à jour');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 10 — EM_Case.upsertRequeteReaffectation : existante Clôturée
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que upsertRequeteReaffectation lève une AuraHandledException
    *                       quand la requête existante est Clôturée.
    * @method Name      :   test_upsert_existingCloturee_throwsAuraException
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_upsert_existingCloturee_throwsAuraException() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'EM_CLOTUREE' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                EM_Case.upsertRequeteReaffectation(decl.Id, tgt.Id, 'Tentative', mgr.Id);
                Test.stopTest();
                System.assert(false, 'AuraHandledException attendue pour requête clôturée');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException correctement levée');
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 11 — EM_Case.validerReaffectation
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que validerReaffectation passe la requête En cours
    *                       et réassigne l'OwnerId à ReaffecterA__c.
    * @method Name      :   test_validerReaffectation_setsStatusAndOwner
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_validerReaffectation_setsStatusAndOwner() {
        User mgr  = [SELECT Id FROM User WHERE Alias = 'mgr' LIMIT 1];
        User tgt  = [SELECT Id FROM User WHERE Alias = 'tgt' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'EM_VALIDER' LIMIT 1];
        Case requete = [
            SELECT Id, ReaffecterA__c FROM Case
            WHERE Declaration_Liee__c = :decl.Id AND TypeRequete__c = 'Réaffecter la déclaration'
            LIMIT 1
        ];

        System.runAs(mgr) {
            Test.startTest();
            EM_Case.validerReaffectation(requete.Id);
            Test.stopTest();

            Case updated = [SELECT Status, OwnerId FROM Case WHERE Id = :requete.Id];
            System.assertEquals(STATUT_EN_COURS, updated.Status,  'Statut doit passer à En cours');
            System.assertEquals(tgt.Id,           updated.OwnerId, 'OwnerId doit être ReaffecterA (tgt)');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SECTION 12 — EM_Case.rejeterReaffectation
    // ═══════════════════════════════════════════════════════════════

    /**
    * @description      :   Vérifie que getRecordData peuple reaffecterAId quand une requête En cours
    *                       est liée à la déclaration (branche DM_Case.getReaffecterAId).
    * @method Name      :   test_getRecordData_declaration_withReaffectEnCours_populatesReaffecterAId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_declaration_withReaffectEnCours_populatesReaffecterAId() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_WITH_REAFFECT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE, FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
            Test.stopTest();

            System.assertNotEquals(null, data, 'CompactData ne doit pas être null');
            System.assertNotEquals(null, data.reaffecterAId,
                'reaffecterAId doit être peuplé quand une requête En cours existe');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData peuple requeteInitialeId quand une requête Initiale
    *                       est liée à la déclaration (branche DM_Case.getRequeteInitialeId).
    * @method Name      :   test_getRecordData_declaration_withRequeteInitiale_populatesRequeteInitialeId
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_declaration_withRequeteInitiale_populatesRequeteInitialeId() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_WITH_INITIALE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE, FIELDS_CSV_DECLARATION, RT_DECLARATION
                );
            Test.stopTest();

            System.assertNotEquals(null, data, 'CompactData ne doit pas être null');
            System.assertNotEquals(null, data.requeteInitialeId,
                'requeteInitialeId doit être peuplé quand une requête Initiale existe');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData gère les champs de type Date et Lookup
    *                       en incluant DateOfOccurrence__c (date) et OwnerId (lookup) dans fieldsCsv.
    * @method Name      :   test_getRecordData_declaration_withDateAndLookupFields_buildsItems
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_declaration_withDateAndLookupFields_buildsItems() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_DATE_LOOKUP' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE,
                    'DateOfOccurrence__c,OwnerId,CreatedDate',
                    RT_DECLARATION
                );
            Test.stopTest();

            System.assertNotEquals(null, data,   'CompactData ne doit pas être null');
            System.assertEquals(3, data.fields.size(), '3 champs doivent être retournés');

            Boolean hasDate   = false;
            Boolean hasLookup = false;
            Boolean hasDT     = false;
            for (DA_lwc025_CaseCompactLayoutController.FieldItem fi : data.fields) {
                if (fi.fieldPath == 'DateOfOccurrence__c') hasDate   = true;
                if (fi.fieldPath == 'OwnerId')             hasLookup = true;
                if (fi.fieldPath == 'CreatedDate')         hasDT     = true;
            }
            System.assert(hasDate,   'FieldItem pour DateOfOccurrence__c attendu');
            System.assert(hasLookup, 'FieldItem pour OwnerId attendu');
            System.assert(hasDT,     'FieldItem pour CreatedDate attendu');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData gère un champ relationship (dot-notation)
    *                       dans fieldsCsv en construisant un FieldItem de type lookup.
    * @method Name      :   test_getRecordData_declaration_withRelationshipField_buildsLookupItem
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_declaration_withRelationshipField_buildsLookupItem() {
        User usr  = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case decl = [SELECT Id FROM Case WHERE Subject = 'DECL_DATE_LOOKUP' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    decl.Id, OBJ_CASE,
                    'Owner.Name',
                    RT_DECLARATION
                );
            Test.stopTest();

            System.assertNotEquals(null, data, 'CompactData ne doit pas être null');
            System.assertEquals(1, data.fields.size(), '1 champ relationship doit être retourné');

            DA_lwc025_CaseCompactLayoutController.FieldItem fi = data.fields[0];
            System.assertEquals('Owner.Name', fi.fieldPath, 'fieldPath doit être Owner.Name');
            System.assertEquals(true, fi.isLookup, 'isLookup doit être true pour un champ relationship');
        }
    }

    /**
    * @description      :   Vérifie que getRecordData fonctionne sur un objet non-Case (Claim__c)
    *                       et peuple caseNumber depuis le champ Name (branche else non-Case).
    * @method Name      :   test_getRecordData_nonCaseObject_populatesCaseNumberFromName
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRecordData_nonCaseObject_populatesCaseNumberFromName() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        // Claim__c est un objet non-Case présent dans l'org — on récupère n'importe quel sinistre existant
        Claim__c claim = [SELECT Id FROM Claim__c LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            DA_lwc025_CaseCompactLayoutController.CompactData data =
                DA_lwc025_CaseCompactLayoutController.getRecordData(
                    claim.Id, 'Claim__c', 'Name', RT_DECLARATION
                );
            Test.stopTest();

            System.assertNotEquals(null, data,           'CompactData ne doit pas être null');
            System.assertNotEquals(null, data.caseNumber,'caseNumber doit être peuplé pour un objet non-Case');
            System.assertEquals('Claim__c', data.objectApiName, 'objectApiName doit être Claim__c');
        }
    }
}