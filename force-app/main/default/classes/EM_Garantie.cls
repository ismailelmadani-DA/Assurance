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

        if (String.isBlank(code)) {
               code = generateNextCode();
    }
       

        validateRequiredFields(label, code, type);
        validateDuplicateCode(code, devName);

        if (String.isBlank(devName)) {
            devName = generateDeveloperName(label);
        }

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

    private static String generateDeveloperName(String label) {

        String devName = label
            .trim()
            .replaceAll('[^a-zA-Z0-9]', '_')
            .replaceAll('_+', '_');

        if (devName.endsWith('_')) {
            devName = devName.left(devName.length() - 1);
        }

        return devName;
    }

    private static String generateNextCode() {
    Integer maxCode = 0;

    for (GarantieAssurance__mdt g : DM_Garantie.getAllGarantiesForCodeGeneration()) {
        if (String.isNotBlank(g.CodeGarantie__c) && Pattern.matches('^\\d+$', g.CodeGarantie__c)) {
            Integer currentCode = Integer.valueOf(g.CodeGarantie__c);

            if (currentCode > maxCode) {
                maxCode = currentCode;
            }
        }
    }

    Integer nextCode = maxCode + 1;

    if (nextCode < 10) {
        return '00' + String.valueOf(nextCode);
    }

    if (nextCode < 100) {
        return '0' + String.valueOf(nextCode);
    }

    return String.valueOf(nextCode);
}

    private static Metadata.CustomMetadataValue buildValue(String fieldName, Object value) {
        Metadata.CustomMetadataValue fieldValue = new Metadata.CustomMetadataValue();
        fieldValue.field = fieldName;
        fieldValue.value = value;
        return fieldValue;
    }
}