/**
 * @description       : Tests unitaires du controller des véhicules adverses : récupération des véhicules adverses par Id de sinistre (Claim__c), par Id de case (Case__c), et gestion des cas limites (Id null, préfixe d'objet non supporté).
 * @author            : D&A Technologies
 * @group             : Test
 * @last modified on  : 2026-05-21
 */
@isTest
private class DA_VehiculeAdverseControllerTest {

    /**
    * @description      :   Configure les données de test : un compte, une police, un case, un sinistre, puis 3 affectations véhicule (2 véhicules adverses et 1 non adverse) liées au sinistre et au case.
    * @method Name      :   setupTestData
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @TestSetup
    static void setupTestData() {
        DA_TestBuilderFactory builder = new DA_TestBuilderFactory();
        builder.withAccount();
        builder.withCustomPolicies(1, builder.getAccounts()[0].Id, null);
        builder.withCases(1, builder.getAccounts()[0].Id, builder.getPolicies()[0].Id, 'VA_TEST', null);
        builder.withClaims(1, builder.getCases()[0].Id, null);

        Id claimId = builder.getClaims()[0].Id;
        Id caseId  = builder.getCases()[0].Id;

        builder.withVehicleCaseAssignments(2, claimId, caseId, true, null);
        builder.withVehicleCaseAssignments(1, claimId, caseId, false, null);
    }

    /**
    * @description      :   Vérifie que getVehiculesAdverses retourne une liste vide quand l'Id passé en paramètre est null.
    * @method Name      :   test_getVehiculesAdverses_nullRecordId_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getVehiculesAdverses_nullRecordId_returnsEmpty() {
        Test.startTest();
        List<VehicleCaseAssignment__c> result =
            DA_VehiculeAdverseController.getVehiculesAdverses(null);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Expected empty list when recordId is null');
    }

    /**
    * @description      :   Vérifie que getVehiculesAdverses, appelé avec un Id de sinistre (Claim__c), retourne uniquement les affectations marquées isOpposingCar__c = true et appartenant à ce sinistre.
    * @method Name      :   test_getVehiculesAdverses_byClaimId_returnsOpposingOnly
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getVehiculesAdverses_byClaimId_returnsOpposingOnly() {
        Claim__c clm = [SELECT Id FROM Claim__c LIMIT 1];

        Test.startTest();
        List<VehicleCaseAssignment__c> result =
            DA_VehiculeAdverseController.getVehiculesAdverses(clm.Id);
        Test.stopTest();

        System.assertEquals(2, result.size(),
            'Expected only opposing vehicles for the claim');
        for (VehicleCaseAssignment__c v : result) {
            System.assertEquals(true, v.isOpposingCar__c,
                'Non-opposing vehicle leaked through');
            System.assertEquals(clm.Id, v.Claim__c,
                'Vehicle does not belong to the queried claim');
        }
    }

    /**
    * @description      :   Vérifie que getVehiculesAdverses, appelé avec un Id de case (Case), retourne uniquement les affectations marquées isOpposingCar__c = true rattachées à ce case.
    * @method Name      :   test_getVehiculesAdverses_byCaseId_returnsOpposingOnly
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getVehiculesAdverses_byCaseId_returnsOpposingOnly() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<VehicleCaseAssignment__c> result =
            DA_VehiculeAdverseController.getVehiculesAdverses(c.Id);
        Test.stopTest();

        System.assertEquals(2, result.size(),
            'Expected only opposing vehicles for the case');
        for (VehicleCaseAssignment__c v : result) {
            System.assertEquals(true, v.isOpposingCar__c,
                'Non-opposing vehicle leaked through');
        }
    }

    /**
    * @description      :   Vérifie que getVehiculesAdverses retourne une liste vide quand l'Id passé correspond à un objet dont le préfixe n'est pas supporté (ex. Account).
    * @method Name      :   test_getVehiculesAdverses_unsupportedPrefix_returnsEmpty
    * @Author           :   D&A Technologies
    * @date             :   2026-05-21
    * @param            :   None
    * @return           :   None
    * -------------------------------------------------------------------------------------------------
    */
    @isTest
    static void test_getVehiculesAdverses_unsupportedPrefix_returnsEmpty() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<VehicleCaseAssignment__c> result =
            DA_VehiculeAdverseController.getVehiculesAdverses(acc.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Expected empty list for unsupported object prefix');
    }
}