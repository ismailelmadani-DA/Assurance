/**
 * @description       : Tests unitaires du controller de l'historique des sinistres : récupération des ClaimParticipant__c associés à un compte, gestion d'un compte sans historique et d'un Id null.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-26
 */
@isTest
public class DA_HistoriquesSinistresControllerTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();

    /**
    * @description      :   Configure les données de test : utilisateur, deux comptes (HISTO avec 2 participants sur un sinistre, EMPTY sans aucun participant), police, case et sinistre rattachés à HISTO.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder.withUser('usr', 'Regular');

        builder.withCustomAccounts(1, new Map<String, Object>{ 'Name' => 'HISTO' });
        builder.withCustomAccounts(1, new Map<String, Object>{ 'Name' => 'EMPTY' });

        Id histoAccId = [SELECT Id FROM Account WHERE Name = 'HISTO' LIMIT 1].Id;

        builder.withCustomPolicies(1, histoAccId, null);
        Id policyId = builder.getPolicies()[0].Id;

        builder.withCases(1, histoAccId, policyId, 'HISTO_CASE', null);
        Id caseId = builder.getCases()[0].Id;

        builder.withClaims(1, caseId, null);
        Id claimId = builder.getClaims()[0].Id;

        builder.withClaimParticipants(1, claimId, histoAccId, new Map<String, Object>{
            'Roles__c' => 'Passager adverse'
        });
        builder.withClaimParticipants(1, claimId, histoAccId, new Map<String, Object>{
            'Roles__c' => 'Passager assuré'
        });
    }

    /**
    * @description      :   Vérifie que getHistoriques retourne tous les ClaimParticipant__c liés au compte fourni, avec les champs relationnels Claim__r.Name renseignés.
    * @method Name      :   test_getHistoriques_returnsParticipantsForAccount
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getHistoriques_returnsParticipantsForAccount() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account histo = [SELECT Id FROM Account WHERE Name = 'HISTO' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<ClaimParticipant__c> result =
                DA_HistoriquesSinistresController.getHistoriques(histo.Id);
            Test.stopTest();

            System.assertEquals(2, result.size(), 'Expected both participants of the HISTO account');
            for (ClaimParticipant__c p : result) {
                System.assertNotEquals(null, p.Claim__c, 'Each participant should have a Claim');
                System.assertNotEquals(null, p.Claim__r.Name, 'Claim__r.Name should be hydrated');
            }
        }
    }

    /**
    * @description      :   Vérifie que getHistoriques retourne une liste vide pour un compte sans aucun ClaimParticipant__c associé.
    * @method Name      :   test_getHistoriques_emptyAccount_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-26
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getHistoriques_emptyAccount_returnsEmpty() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Account empty = [SELECT Id FROM Account WHERE Name = 'EMPTY' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            List<ClaimParticipant__c> result =
                DA_HistoriquesSinistresController.getHistoriques(empty.Id);
            Test.stopTest();

            System.assertEquals(0, result.size(), 'An account without history should yield an empty list');
        }
    }

    /**
    * @description      :   Vérifie que getHistoriques propage une exception quand l'Id du compte est null (la DM ne valide pas l'Id null).
    * @method Name      :   test_getHistoriques_nullAccountId_throws
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getHistoriques_nullAccountId_throws() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            try {
                Test.startTest();
                DA_HistoriquesSinistresController.getHistoriques(null);
                Test.stopTest();
                System.assert(false, 'Should have thrown for null accountId');
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
}