public with sharing class DM_Garantie {

    private static final String OBJECT_NAME = 'GarantieAssurance__mdt';

    private static final String FIELDS =
        'Id, Label, DeveloperName, CodeGarantie__c, TypeGarantie__c, IsActive__c';

    public static List<Map<String, Object>> getGaranties() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        List<SObject> rows = DA_Utility.query(
            FIELDS,
            OBJECT_NAME,
            null,
            'CodeGarantie__c ASC',
            null
        );

        for (SObject row : rows) {
            GarantieAssurance__mdt g = (GarantieAssurance__mdt) row;

            result.add(new Map<String, Object>{
                'id'            => g.Id,
                'label'         => g.Label,
                'developerName' => g.DeveloperName,
                'code'          => g.CodeGarantie__c,
                'type'          => g.TypeGarantie__c,
                'isActive'      => g.IsActive__c
            });
        }

        return result;
    }

    public static List<GarantieAssurance__mdt> getGarantiesByCode(String code) {
        if (String.isBlank(code)) {
            return new List<GarantieAssurance__mdt>();
        }

        List<GarantieAssurance__mdt> result = new List<GarantieAssurance__mdt>();

        List<SObject> rows = DA_Utility.query(
            'DeveloperName, CodeGarantie__c',
            OBJECT_NAME,
            'CodeGarantie__c = \'' + String.escapeSingleQuotes(code) + '\'',
            null,
            null
        );

        for (SObject row : rows) {
            result.add((GarantieAssurance__mdt) row);
        }

        return result;
    }
    
    public static List<GarantieAssurance__mdt> getAllGarantiesForCodeGeneration() {
    List<GarantieAssurance__mdt> result = new List<GarantieAssurance__mdt>();

    List<SObject> rows = DA_Utility.query(
        'CodeGarantie__c',
        'GarantieAssurance__mdt',
        null,
        null,
        null
    );

    for (SObject row : rows) {
        result.add((GarantieAssurance__mdt) row);
    }

    return result;
}
}