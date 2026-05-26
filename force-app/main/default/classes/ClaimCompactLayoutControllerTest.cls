@isTest
private class ClaimCompactLayoutControllerTest {

    @TestSetup
    static void setupData() {
        Account acc  = DA_TestDataFactory.createAccount();
        Case c       = DA_TestDataFactory.createCase(acc.Id);
        DA_TestDataFactory.createClaim(c.Id);
    }

    private static Claim__c getClaim() {
        return [SELECT Id FROM Claim__c LIMIT 1];
    }

    private static Boolean fieldSetHasMembers() {
        return !DM006_Claim.getCompactFieldSetMembers().isEmpty();
    }

    @isTest
    static void getClaimData_validId_returnsClaimData() {
        Claim__c clm = getClaim();

        Test.startTest();
        try {
            ClaimCompactLayoutController.ClaimData result =
                ClaimCompactLayoutController.getClaimData(clm.Id);

            System.assertNotEquals(null, result,
                'Expected a non-null ClaimData when the field set has members');
            System.assertNotEquals(null, result.fields,
                'Fields list should be initialised');
            System.assert(fieldSetHasMembers(),
                'Field set was empty but no exception was thrown');
            System.assertEquals([SELECT Name FROM Claim__c WHERE Id = :clm.Id].Name,
                result.claimName, 'claimName should match the queried record');
        } catch (AuraHandledException e) {
            System.assert(!fieldSetHasMembers(),
                'AuraHandledException only expected when field set is missing/empty: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void getClaimData_nullRecordId_throws() {
        Test.startTest();
        try {
            ClaimCompactLayoutController.getClaimData(null);
            System.assert(false, 'Should have thrown AuraHandledException for null recordId');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void getClaimData_nonExistentId_throws() {
        Claim__c clm = getClaim();
        Id fakeId    = clm.Id;
        delete clm;

        Test.startTest();
        try {
            ClaimCompactLayoutController.getClaimData(fakeId);
            System.assert(false, 'Should have thrown AuraHandledException for deleted recordId');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}