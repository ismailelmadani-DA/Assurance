public with sharing class EM_Garantie {

    private static final String MDT_PREFIX = 'GarantieAssurance.';

    public static void saveGarantie(String record) {

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(record);

        String devName = (String) data.get('developerName');
        String label   = (String) data.get('label');
        String type    = (String) data.get('type');
        Boolean active = (Boolean) data.get('isActive');
        String code = (String) data.get('code');

        validateRequiredFields(label, code, type);
        validateDuplicateCode(code, devName);


        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = MDT_PREFIX + devName;
        cmd.label    = label;

        cmd.values.add(buildValue('CodeGarantie__c', code));
        cmd.values.add(buildValue('TypeGarantie__c', type));
        cmd.values.add(buildValue('IsActive__c', active));

        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(cmd);

        Metadata.Operations.enqueueDeployment(container, null);
    }

    private static void validateRequiredFields(String label, String code, String type) {
        if (String.isBlank(label) || String.isBlank(code) || String.isBlank(type)) {
            throw new AuraHandledException('Veuillez renseigner tous les champs obligatoires.');
        }

      if (!Pattern.matches('^\\d{3,}$', code)) {
    throw new AuraHandledException(
        'Le code doit contenir au moins 3 chiffres'
    );
}
    }

    private static void validateDuplicateCode(String code, String devName) {

        for (GarantieAssurance__mdt existing : DM_Garantie.getGarantiesByCode(code)) {

            if (String.isBlank(devName) || existing.DeveloperName != devName) {
                throw new AuraHandledException(
                    'Le code "' + code + '" est déjà utilisé. Choisissez un code différent.'
                );
            }
        }
    }

    private static Metadata.CustomMetadataValue buildValue(String fieldName, Object value) {
        Metadata.CustomMetadataValue fieldValue = new Metadata.CustomMetadataValue();
        fieldValue.field = fieldName;
        fieldValue.value = value;
        return fieldValue;
    }
}