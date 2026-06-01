/**
 * @description       : Tests unitaires du controller RIB : récupération des RIB d'un compte et lecture des libellés de la picklist CodeBanque__c.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-27
 */
@isTest
public class DA_RIBControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    /**
    * @description      :   Configure les données de test : utilisateur, compte HAS_RIB avec deux RIB__c, et compte EMPTY sans RIB.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder.withUser('usr', 'Regular');

        builder.withCustomAccounts(1, new Map<String, Object>{ 'Name' => 'HAS_RIB' });
        builder.withCustomAccounts(1, new Map<String, Object>{ 'Name' => 'EMPTY' });

        Id hasRibId = [SELECT Id FROM Account WHERE Name = 'HAS_RIB' LIMIT 1].Id;

        builder.withRibs(1, hasRibId, new Map<String, Object>{
            'RIB__c'   => '007111111111111111111111',
            'Actif__c' => true
        });
        builder.withRibs(1, hasRibId, new Map<String, Object>{
            'RIB__c'   => '007222222222222222222222',
            'Actif__c' => false
        });
    }

    /**
    * @description      :   Vérifie que getRIBsByAccountId retourne tous les RIB__c liés au compte (actifs et inactifs).
    * @method Name      :   test_getRIBsByAccountId_returnsAllRibsForAccount
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRIBsByAccountId_returnsAllRibsForAccount() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'HAS_RIB' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<RIB__c> result = DA_RIBController.getRIBsByAccountId(acc.Id);
            Test.stopTest();

            System.assertEquals(2, result.size(), 'Both RIBs of the account should be returned');
            for (RIB__c r : result) {
                System.assertNotEquals(null, r.RIB__c);
                System.assertNotEquals(null, r.Statut__c);
            }
        }
    }

    /**
    * @description      :   Vérifie que getRIBsByAccountId retourne une liste vide pour un compte sans aucun RIB__c.
    * @method Name      :   test_getRIBsByAccountId_emptyAccount_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRIBsByAccountId_emptyAccount_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'EMPTY' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<RIB__c> result = DA_RIBController.getRIBsByAccountId(acc.Id);
            Test.stopTest();

            System.assertEquals(0, result.size(), 'An account without RIB should yield an empty list');
        }
    }

    /**
    * @description      :   Vérifie que getRIBsByAccountId propage une exception quand l'Id du compte est null (la DM ne valide pas l'Id null).
    * @method Name      :   test_getRIBsByAccountId_nullId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getRIBsByAccountId_nullId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_RIBController.getRIBsByAccountId(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown for null accountId');
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }

    /**
    * @description      :   Vérifie que getBanqueLabels retourne une Map associant chaque valeur de la picklist CodeBanque__c à son label.
    * @method Name      :   test_getBanqueLabels_returnsMap
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getBanqueLabels_returnsMap() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            Map<String, String> labels = DA_RIBController.getBanqueLabels();
            Test.stopTest();

            System.assertNotEquals(null, labels, 'Returned map must not be null');
            for (String value : labels.keySet()) {
                System.assertNotEquals(null, labels.get(value),
                    'Each picklist value must map to a non-null label');
            }
        }
    }
}
