/**
 * @description  : Data Mapper — Case / Mission
 * @author       : D&A Technologies
 * @date         : 2026-04-27
 */
public with sharing class DM_Case {

    private static final String OBJ    = 'Case';
    private static final Integer MAX_LIMIT = NULL;

    private static final String FIELDS_MISSIONS =
        'Id, CaseNumber, NatureMission__c, Status, CreatedDate, CreatedById, CreatedBy.Name';

    public static Case getById(String fields, Id caseId) {
        if (caseId == null) return null;
        return (Case) DA_Utility.getById(fields, OBJ, caseId);
    }

    /**
     * Retourne les missions (Cases de type Mission) liées à un compte.
     */
    public static List<Case> getMissionsByAccountId(Id accountId) {
        if (accountId == null) return new List<Case>();

        String conditions =
            'AccountId = :accountId' +
            ' AND RecordType.DeveloperName = \'Mission\'';

        return (List<Case>) DA_Utility.query(
            FIELDS_MISSIONS,
            OBJ,
            conditions,
            'CreatedDate DESC',
            MAX_LIMIT
        );
    }
}