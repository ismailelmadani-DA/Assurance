@isTest
public class DA_TestDataFactory {

    private static Integer counter = 0;

    private static String uniqueSuffix() {
        counter++;
        return String.valueOf(System.currentTimeMillis()) + '_' + counter;
    }

    public static Id standardUserProfileId() {
        return [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
    }

    public static User createTestUser(String alias, String lastName) {
        String suffix = uniqueSuffix();
        return new User(
            Alias             = alias.left(8),
            Email             = 'u' + suffix + '@test.example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles',
            Username          = 'u' + suffix + '@test.assurance.factory',
            ProfileId         = standardUserProfileId()
        );
    }

    public static User createTestUserWithManager(String alias, String lastName, Id managerId) {
        User u = createTestUser(alias, lastName);
        u.ManagerId = managerId;
        return u;
    }

    public static Account createTestAccount() {
        return new Account(Name = 'TestAccount_' + uniqueSuffix());
    }

    public static Case createTestCase(Id accountId, String subject) {
        return new Case(
            Subject   = subject,
            Origin    = 'Web',
            AccountId = accountId
        );
    }

    public static Claim__c createTestClaim(Id caseId, String flagsCsv) {
        return new Claim__c(
            Case__c  = caseId,
            Flags__c = flagsCsv
        );
    }

    public static RequestApproval__c createTestRequestApproval(
        Id claimId, String flag, Id submitterId, Id approverId
    ) {
        return new RequestApproval__c(
            Status__c          = 'En attente d\'approbation',
            TypeApprobation__c = 'Flag du sinistre',
            Flag__c            = flag,
            Commentaire__c     = 'Test',
            Sinistre__c        = claimId,
            Submitter__c       = submitterId,
            NextApprover__c    = approverId
        );
    }

    public static Case createTestDeclaration(
        Id recordTypeId,
        Id accountId,
        Id policyNumberId,
        String channel,
        Boolean createdByIntermediate
    ) {
        return new Case(
            AccountId                = accountId,
            Channel__c               = channel,
            CityOfOccurrence__c      = 'Dakar',
            Pays__c                  = 'Sénégal',
            Claimant__c              = 'Assuré',
            CountryOfOccurrence__c   = 'Sénégal',
            UniteGestion__c          = '2',
            RecordTypeId             = recordTypeId,
            CreatedByIntermediate__c = createdByIntermediate,
            Status                   = 'En cours',
            Directory__c             = 'DECLARATION',
            RegistrationNumber__c    = 'AA 049 HQ',
            IncidentReport__c        = 'Gendarmerie',
            Police__c                = policyNumberId,
            DateOfOccurrence__c      = Date.today()
        );
    }
}
