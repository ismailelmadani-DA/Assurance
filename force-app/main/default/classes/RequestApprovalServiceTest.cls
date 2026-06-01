/**
 * @description       : Tests unitaires du service RequestApprovalService.applyDecision : early returns sur RA invalide, gestion des flags du sinistre (ajout, toggle off, exclusions mutuelles Frauduleux/Douteux, mise à null quand vide) et claim introuvable.
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-27
 */
@isTest
public class RequestApprovalServiceTest {

    private static DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
    private static final String APPROVED = 'Approuvée';
    private static final String PENDING  = 'En attente d\'approbation';

    /**
    * @description      :   Configure les données de test : utilisateur, compte, police, et 7 scénarios de sinistres avec différents états initiaux du champ Flags__c.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        builder
            .withUser('usr', 'Regular')
            .withAccount();
        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);

        builder.withScenarios(new Map<String, String>{
            'EMPTY_ADD'        => null,
            'APPEND'           => 'Majeur',
            'TOGGLE_OFF'       => 'Sensible',
            'FRAUD_REMOVES_DT' => 'Douteux',
            'DT_REMOVES_FRAUD' => 'Frauduleux',
            'LAST_FLAG'        => 'Sensible',
            'NOT_APPROVED'     => 'Sensible',
            'GONE'             => null
        });
    }

    /**
    * @description      :   Vérifie qu'un RA dont Sinistre__c est null ne déclenche aucune mise à jour du sinistre.
    * @method Name      :   test_applyDecision_nullSinistre_noOp
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_nullSinistre_noOp() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = null, Flag__c = 'Sensible', Status__c = APPROVED
            ));
            Test.stopTest();
        }
    }

    /**
    * @description      :   Vérifie qu'un RA dont Flag__c est null ne déclenche aucune mise à jour du sinistre.
    * @method Name      :   test_applyDecision_nullFlag_noOp
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_nullFlag_noOp() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id, Flags__c FROM Claim__c WHERE Case__r.Subject = 'EMPTY_ADD' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = null, Status__c = APPROVED
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assertEquals(claim.Flags__c, reloaded.Flags__c, 'Claim should not be modified');
        }
    }

    /**
    * @description      :   Vérifie qu'un RA dont le statut n'est pas 'Approuvée' n'applique aucune modification.
    * @method Name      :   test_applyDecision_notApproved_noOp
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_notApproved_noOp() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id, Flags__c FROM Claim__c WHERE Case__r.Subject = 'NOT_APPROVED' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = 'Majeur', Status__c = PENDING
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assertEquals('Sensible', reloaded.Flags__c, 'Claim flags must stay unchanged');
        }
    }

    /**
    * @description      :   Vérifie que applyDecision ne lève pas d'exception quand le sinistre référencé n'existe plus.
    * @method Name      :   test_applyDecision_claimNotFound_noOp
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_claimNotFound_noOp() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'GONE' LIMIT 1];
        Id missingId = claim.Id;
        delete claim;

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = missingId, Flag__c = 'Sensible', Status__c = APPROVED
            ));
            Test.stopTest();
        }
    }

    /**
    * @description      :   Vérifie qu'un flag est ajouté quand le sinistre n'avait aucun flag initialement.
    * @method Name      :   test_applyDecision_emptyFlags_addsFlag
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_emptyFlags_addsFlag() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'EMPTY_ADD' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = 'Sensible', Status__c = APPROVED
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assert(reloaded.Flags__c.contains('Sensible'));
        }
    }

    /**
    * @description      :   Vérifie qu'un nouveau flag est concaténé au champ Flags__c en conservant les flags existants.
    * @method Name      :   test_applyDecision_appendsToExistingFlags
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_appendsToExistingFlags() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'APPEND' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = 'Sensible', Status__c = APPROVED
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assert(reloaded.Flags__c.contains('Majeur'), 'Existing Majeur should remain');
            System.assert(reloaded.Flags__c.contains('Sensible'), 'New Sensible should be added');
        }
    }

    /**
    * @description      :   Vérifie qu'un flag déjà présent est retiré (toggle off) quand l'approbation porte sur ce même flag.
    * @method Name      :   test_applyDecision_existingFlag_togglesOff
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_existingFlag_togglesOff() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'TOGGLE_OFF' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = 'Sensible', Status__c = APPROVED
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assertEquals(null, reloaded.Flags__c, 'Toggling off the only flag must set Flags__c to null');
        }
    }

    /**
    * @description      :   Vérifie que l'ajout de Frauduleux retire automatiquement le flag Douteux préexistant (exclusion mutuelle).
    * @method Name      :   test_applyDecision_addingFrauduleux_removesDouteux
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_addingFrauduleux_removesDouteux() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'FRAUD_REMOVES_DT' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = 'Frauduleux', Status__c = APPROVED
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assert(reloaded.Flags__c.contains('Frauduleux'));
            System.assert(!reloaded.Flags__c.contains('Douteux'), 'Douteux must be removed when Frauduleux is added');
        }
    }

    /**
    * @description      :   Vérifie que l'ajout de Douteux retire automatiquement le flag Frauduleux préexistant (exclusion mutuelle).
    * @method Name      :   test_applyDecision_addingDouteux_removesFrauduleux
    * @Author           :   D&A Technologies
    * @date             :   2026-05-27
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_applyDecision_addingDouteux_removesFrauduleux() {
        User usr = [SELECT Id FROM User WHERE Alias = 'usr' LIMIT 1];
        Claim__c claim = [SELECT Id FROM Claim__c WHERE Case__r.Subject = 'DT_REMOVES_FRAUD' LIMIT 1];

        System.runAs(usr) {
            Test.startTest();
            RequestApprovalService.applyDecision(new RequestApproval__c(
                Sinistre__c = claim.Id, Flag__c = 'Douteux', Status__c = APPROVED
            ));
            Test.stopTest();

            Claim__c reloaded = [SELECT Flags__c FROM Claim__c WHERE Id = :claim.Id];
            System.assert(reloaded.Flags__c.contains('Douteux'));
            System.assert(!reloaded.Flags__c.contains('Frauduleux'), 'Frauduleux must be removed when Douteux is added');
        }
    }
}
