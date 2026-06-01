/**
 * @description       : Tests unitaires du controller des garanties de police : lecture des garanties utilisées, catalogue ordonné (RC en tête puis sélectionnées puis non-sélectionnées) et sauvegarde insert/update avec RC toujours conservée.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-26
 */
@isTest
public class DA_InsurancePolicyCoverageControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
    private static final String RC_CODE = '001';

    /**
    * @description      :   Configure les données de test : utilisateur, compte et 3 polices distinctes (READ / CATALOG / SAVE) avec leurs garanties initiales.
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

        Id accId = builder.getAccounts()[0].Id;

        builder.withCustomPolicies(1, accId, new Map<String, Object>{ 'Name' => 'POL_READ' });
        Id policyRead = builder.getPolicies()[builder.getPolicies().size() - 1].Id;
        builder.withInsurancePolicyCoverages(1, policyRead, new Map<String, Object>{
            'CodeGarantie__c'    => 'READ_USED',
            'NomDeLaGarantie__c' => 'Lecture utilisée',
            'GarantieUsed__c'    => true
        });
        builder.withInsurancePolicyCoverages(1, policyRead, new Map<String, Object>{
            'CodeGarantie__c'    => 'READ_UNUSED',
            'NomDeLaGarantie__c' => 'Lecture non utilisée',
            'GarantieUsed__c'    => false
        });

        builder.withCustomPolicies(1, accId, new Map<String, Object>{ 'Name' => 'POL_CATALOG' });
        builder.withCustomPolicies(1, accId, new Map<String, Object>{ 'Name' => 'POL_SAVE' });
    }

    /**
    * @description      :   Vérifie que getCoverages ne retourne que les garanties marquées GarantieUsed__c = true.
    * @method Name      :   test_getCoverages_returnsOnlyUsed
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCoverages_returnsOnlyUsed() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        InsurancePolicy__c policy = [SELECT Id FROM InsurancePolicy__c WHERE Name = 'POL_READ' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<InsurancePolicyCoverage__c> result =
                DA_InsurancePolicyCoverageController.getCoverages(policy.Id);
            Test.stopTest();

            System.assertEquals(1, result.size(), 'Only the used coverage should be returned');
            System.assertEquals('READ_USED', result[0].CodeGarantie__c);
            System.assertEquals(true, result[0].GarantieUsed__c);
        }
    }

    /**
    * @description      :   Vérifie que getCoverages retourne une liste vide quand l'Id de la police est null.
    * @method Name      :   test_getCoverages_nullPolicyId_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCoverages_nullPolicyId_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<InsurancePolicyCoverage__c> result =
                DA_InsurancePolicyCoverageController.getCoverages(null);
            Test.stopTest();

            System.assertEquals(0, result.size(), 'Null policy id should yield an empty list');
        }
    }

    /**
    * @description      :   Vérifie que getCoveragesCatalog place la garantie RC ('001') en première position quand elle est présente dans le custom metadata.
    * @method Name      :   test_getCoveragesCatalog_rcFirstWhenPresent
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCoveragesCatalog_rcFirstWhenPresent() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        InsurancePolicy__c policy = [SELECT Id FROM InsurancePolicy__c WHERE Name = 'POL_CATALOG' LIMIT 1];

        Boolean hasRc = false;
        for (GarantieAssurance__mdt g : DM010_GarantieAssurance.getActive()) {
            if (g.CodeGarantie__c == RC_CODE) { hasRc = true; break; }
        }

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, Object>> catalog =
                DA_InsurancePolicyCoverageController.getCoveragesCatalog(policy.Id);
            Test.stopTest();

            if (hasRc) {
                System.assert(!catalog.isEmpty(), 'Catalog should not be empty when RC mdt exists');
                System.assertEquals(RC_CODE, (String) catalog[0].get('CodeGarantie__c'),
                    'RC entry must be first');
                System.assertEquals(true, (Boolean) catalog[0].get('GarantieUsed__c'),
                    'RC entry must be marked used');
            }
        }
    }

    /**
    * @description      :   Vérifie que getCoveragesCatalog accepte un Id de police null et retourne un catalogue construit à partir du seul custom metadata.
    * @method Name      :   test_getCoveragesCatalog_nullPolicyId_returnsCatalog
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCoveragesCatalog_nullPolicyId_returnsCatalog() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Integer mdtCount = DM010_GarantieAssurance.getActive().size();

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, Object>> catalog =
                DA_InsurancePolicyCoverageController.getCoveragesCatalog(null);
            Test.stopTest();

            System.assertEquals(mdtCount, catalog.size(),
                'Catalog size must match the number of active GarantieAssurance__mdt records');
        }
    }

    /**
    * @description      :   Vérifie que getCoveragesCatalog marque comme sélectionnée une garantie existante en GarantieUsed__c = true, et qu'elle apparaît avant les garanties non sélectionnées.
    * @method Name      :   test_getCoveragesCatalog_selectedBeforeUnselected
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getCoveragesCatalog_selectedBeforeUnselected() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        InsurancePolicy__c policy = [SELECT Id FROM InsurancePolicy__c WHERE Name = 'POL_CATALOG' LIMIT 1];

        String someCode;
        for (GarantieAssurance__mdt g : DM010_GarantieAssurance.getActive()) {
            if (g.CodeGarantie__c != null && g.CodeGarantie__c != RC_CODE) {
                someCode = g.CodeGarantie__c;
                break;
            }
        }
        if (someCode == null) return;

        insert new InsurancePolicyCoverage__c(
            InsurancePolicy__c = policy.Id,
            CodeGarantie__c    = someCode,
            NomDeLaGarantie__c = 'Sélectionnée test',
            TypeGarantie__c    = 'Matérielle',
            GarantieUsed__c    = true
        );

        System.runAs(usr) {
            Test.startTest();
            List<Map<String, Object>> catalog =
                DA_InsurancePolicyCoverageController.getCoveragesCatalog(policy.Id);
            Test.stopTest();

            Integer selectedIdx = -1;
            Integer firstUnselectedIdx = -1;
            for (Integer i = 0; i < catalog.size(); i++) {
                String code = (String) catalog[i].get('CodeGarantie__c');
                Boolean used = (Boolean) catalog[i].get('GarantieUsed__c');
                if (code == someCode) selectedIdx = i;
                else if (code != RC_CODE && used == false && firstUnselectedIdx == -1) firstUnselectedIdx = i;
            }

            System.assertNotEquals(-1, selectedIdx, 'Selected coverage must appear in the catalog');
            if (firstUnselectedIdx != -1) {
                System.assert(selectedIdx < firstUnselectedIdx,
                    'Selected coverages must appear before unselected ones');
            }
        }
    }

    /**
    * @description      :   Vérifie que saveCoverages ne lève pas d'exception quand l'Id de la police est null et n'écrit rien en base.
    * @method Name      :   test_saveCoverages_nullPolicyId_noOp
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveCoverages_nullPolicyId_noOp() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Integer before = [SELECT COUNT() FROM InsurancePolicyCoverage__c];

        System.runAs(usr) {
            Test.startTest();
            DA_InsurancePolicyCoverageController.saveCoverages(null, new List<String>{ 'X' });
            Test.stopTest();
        }

        Integer afterC = [SELECT COUNT() FROM InsurancePolicyCoverage__c];
        System.assertEquals(before, afterC, 'No coverage should be created when policy id is null');
    }

    /**
    * @description      :   Vérifie que saveCoverages insère une nouvelle ligne pour un code mdt sélectionné qui n'existe pas encore sur la police.
    * @method Name      :   test_saveCoverages_insertsNewSelectedCoverage
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveCoverages_insertsNewSelectedCoverage() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        InsurancePolicy__c policy = [SELECT Id FROM InsurancePolicy__c WHERE Name = 'POL_SAVE' LIMIT 1];

        String someCode;
        for (GarantieAssurance__mdt g : DM010_GarantieAssurance.getActive()) {
            if (g.CodeGarantie__c != null && g.CodeGarantie__c != RC_CODE) {
                someCode = g.CodeGarantie__c;
                break;
            }
        }
        if (someCode == null) return;

        System.runAs(usr) {
            Test.startTest();
            DA_InsurancePolicyCoverageController.saveCoverages(policy.Id, new List<String>{ someCode });
            Test.stopTest();

            List<InsurancePolicyCoverage__c> rows = [
                SELECT CodeGarantie__c, GarantieUsed__c
                FROM InsurancePolicyCoverage__c
                WHERE InsurancePolicy__c = :policy.Id AND CodeGarantie__c = :someCode
            ];
            System.assertEquals(1, rows.size(), 'A new coverage must be inserted');
            System.assertEquals(true, rows[0].GarantieUsed__c);
        }
    }

    /**
    * @description      :   Vérifie que saveCoverages bascule à false GarantieUsed__c sur une garantie existante quand elle n'est plus dans la liste sélectionnée.
    * @method Name      :   test_saveCoverages_unchecksExistingCoverage
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveCoverages_unchecksExistingCoverage() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        InsurancePolicy__c policy = [SELECT Id FROM InsurancePolicy__c WHERE Name = 'POL_SAVE' LIMIT 1];

        String someCode;
        for (GarantieAssurance__mdt g : DM010_GarantieAssurance.getActive()) {
            if (g.CodeGarantie__c != null && g.CodeGarantie__c != RC_CODE) {
                someCode = g.CodeGarantie__c;
                break;
            }
        }
        if (someCode == null) return;

        InsurancePolicyCoverage__c existing = new InsurancePolicyCoverage__c(
            InsurancePolicy__c = policy.Id,
            CodeGarantie__c    = someCode,
            NomDeLaGarantie__c = 'A décocher',
            TypeGarantie__c    = 'Matérielle',
            GarantieUsed__c    = true
        );
        insert existing;

        System.runAs(usr) {
            Test.startTest();
            DA_InsurancePolicyCoverageController.saveCoverages(policy.Id, new List<String>());
            Test.stopTest();

            InsurancePolicyCoverage__c reloaded = [
                SELECT GarantieUsed__c FROM InsurancePolicyCoverage__c WHERE Id = :existing.Id
            ];
            System.assertEquals(false, reloaded.GarantieUsed__c,
                'Coverage must be unchecked when not in selected list');
        }
    }

    /**
    * @description      :   Vérifie que saveCoverages conserve toujours la garantie RC ('001') même lorsqu'elle n'est pas dans la liste sélectionnée.
    * @method Name      :   test_saveCoverages_alwaysKeepsRC
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_saveCoverages_alwaysKeepsRC() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        InsurancePolicy__c policy = [SELECT Id FROM InsurancePolicy__c WHERE Name = 'POL_SAVE' LIMIT 1];

        Boolean hasRc = false;
        for (GarantieAssurance__mdt g : DM010_GarantieAssurance.getActive()) {
            if (g.CodeGarantie__c == RC_CODE) { hasRc = true; break; }
        }
        if (!hasRc) return;

        System.runAs(usr) {
            Test.startTest();
            DA_InsurancePolicyCoverageController.saveCoverages(policy.Id, new List<String>());
            Test.stopTest();

            List<InsurancePolicyCoverage__c> rcRows = [
                SELECT GarantieUsed__c FROM InsurancePolicyCoverage__c
                WHERE InsurancePolicy__c = :policy.Id AND CodeGarantie__c = :RC_CODE
            ];
            System.assertEquals(1, rcRows.size(), 'RC coverage must be created when missing');
            System.assertEquals(true, rcRows[0].GarantieUsed__c, 'RC must remain checked');
        }
    }
}