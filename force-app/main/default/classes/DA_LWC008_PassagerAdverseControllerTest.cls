/**
 * @description       : Tests unitaires du controller de liste des passagers adverses :
 *                      retour des passagers adverses, liste vide si aucun adverse, comportement avec caseId null.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 20-05-2026
 * @last modified by  : D&A Technologies
 **/
@isTest
public class DA_LWC008_PassagerAdverseControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    /**
     * @description      : Configure les données de test : 1 user, 1 compte, 1 police,
     *                     2 cases (WITH_ADVERSE et NO_ADVERSE),
     *                     2 passagers adverses sur WITH_ADVERSE,
     *                     1 passager non-adverse sur NO_ADVERSE.
     * @method Name      : setupTestData
     * @Author           : D&A Technologies
     * @date             : 2026-05-22
     * @param            : None
     * @return           : None
     */
    @TestSetup
    static void setupTestData() {
        builder
            .withUser('usr', 'Regular')
            .withAccount();

        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);

        // Case 1 : contiendra 2 passagers adverses
        // Case 2 : contiendra 1 passager non-adverse (Passager assuré)
        builder.withCases(1, builder.getAccounts()[0].Id, builder.getPolicies()[0].Id, 'WITH_ADVERSE', null);
        builder.withCases(1, builder.getAccounts()[0].Id, builder.getPolicies()[0].Id, 'NO_ADVERSE', null);

        Id caseWithAdverse = builder.getCases()[0].Id;
        Id caseNoAdverse   = builder.getCases()[1].Id;
        Id accountId       = builder.getAccounts()[0].Id;

        // 2 passagers adverses liés au case WITH_ADVERSE
        // on surcharge le Roles__c par défaut ('Passager assuré') avec 'Passager adverse'
        builder.withPassengers(1, caseWithAdverse, accountId, new Map<String, Object>{
            'Roles__c' => 'Passager adverse'
        });
        builder.withPassengers(1, caseWithAdverse, accountId, new Map<String, Object>{
            'Roles__c' => 'Passager adverse'
        });

        // 1 passager non-adverse lié au case NO_ADVERSE
        // on laisse le Roles__c par défaut ('Passager assuré')
        builder.withPassengers(1, caseNoAdverse, accountId, null);
    }

    /**
     * @description      : Vérifie que getPassagersAdverses retourne exactement les passagers
     *                     adverses du case, avec le bon rôle sur chacun.
     * @method Name      : test_getPassagersAdverses_returnsAdversePassengers
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getPassagersAdverses_returnsAdversePassengers() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case c   = [SELECT Id FROM Case WHERE Subject = 'WITH_ADVERSE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<SObject> result = DA_LWC008_ListPassagerAdverseController.getPassagersAdverses(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'La liste ne doit pas être null');
            System.assertEquals(2, result.size(), 'Doit retourner 2 passagers adverses');

            for (SObject s : result) {
                Passager__c p = (Passager__c) s;
                System.assertEquals(
                    'Passager adverse',
                    p.Roles__c,
                    'Chaque passager retourné doit avoir le rôle Passager adverse'
                );
            }
        }
    }

    /**
     * @description      : Vérifie que getPassagersAdverses retourne une liste vide
     *                     quand le case ne contient aucun passager avec le rôle Passager adverse.
     * @method Name      : test_getPassagersAdverses_noAdverse_returnsEmpty
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getPassagersAdverses_noAdverse_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Case c   = [SELECT Id FROM Case WHERE Subject = 'NO_ADVERSE' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<SObject> result = DA_LWC008_ListPassagerAdverseController.getPassagersAdverses(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'La liste ne doit pas être null');
            System.assertEquals(0, result.size(), 'Doit retourner une liste vide car aucun passager adverse');
        }
    }

    /**
     * @description      : Vérifie que getPassagersAdverses retourne une liste vide
     *                     sans lever d'exception quand le caseId est null.
     * @method Name      : test_getPassagersAdverses_nullCaseId_returnsEmpty
     * @Author           : D&A Technologies
     * @date             : 2026-05-20
     * @param            : None
     * @return           : None
     */
    @isTest
    static void test_getPassagersAdverses_nullCaseId_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<SObject> result = DA_LWC008_ListPassagerAdverseController.getPassagersAdverses(null);
            Test.stopTest();

            System.assertNotEquals(null, result, 'La liste ne doit pas être null');
            System.assertEquals(0, result.size(), 'Doit retourner une liste vide pour un caseId null');
        }
    }
}