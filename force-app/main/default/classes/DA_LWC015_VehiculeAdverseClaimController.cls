public with sharing class DA_LWC015_VehiculeAdverseClaimController {

    // ── Helpers ─────────────────────────────────────────────────────────────

    private static Id resolveClaimId(Id recordId) {
        if (recordId == null) return null;
        String prefix      = String.valueOf(recordId).substring(0, 3);
        String claimPrefix = Claim__c.SObjectType.getDescribe().getKeyPrefix();
        if (prefix == claimPrefix) return recordId;
        List<SObject> claims = DA_Utility.query(
            'Id', 'Claim__c',
            'Case__c = \'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'',
            'CreatedDate DESC', 1
        );
        return claims.isEmpty() ? null : (Id) claims[0].get('Id');
    }

    // ── Picklists ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
public static String getCompagnieAdverseRecordTypeId() {
    Id rtId = DA_Utility.getRecordTypeId('Account', 'CompagnieAdverse');
    if (rtId == null)
        throw new AuraHandledException('Record Type "CompagnieAdverse" introuvable sur Account.');
    return rtId;
}

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        result.put('etatVehicule',      getPicklist('VehicleCaseAssignment__c', 'EtatVehicule__c'));
        result.put('typeVehicule',      getPicklist('VehicleCaseAssignment__c', 'TypeVehicule__c'));
        result.put('marque',            getPicklist('Vehicule__c', 'Brand__c'));
        result.put('modele',            getPicklist('Vehicule__c', 'ModelePicklist__c'));
        result.put('moyenNotification', getPicklist('Account', 'MoyenNotification__c'));
        result.put('pays',              getPicklist('Account', 'Pays__c'));
        return result;
    }

    private static List<Map<String, String>> getPicklist(String objectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) return options;
            for (Schema.PicklistEntry e : objType.getDescribe().fields.getMap()
                    .get(fieldName).getDescribe().getPicklistValues()) {
                if (e.isActive()) options.add(new Map<String, String>{
                    'label' => e.getLabel(), 'value' => e.getValue()
                });
            }
        } catch (Exception e) { }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentModeleOptions() {
        return getDependentOptions('Vehicule__c', 'Brand__c', 'ModelePicklist__c');
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        return getDependentOptions('Account', 'Pays__c', 'Ville__c');
    }

    private static Map<String, List<Map<String, String>>> getDependentOptions(
            String objectName, String controllingFieldName, String dependentFieldName) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            List<Schema.PicklistEntry> ctrlEntries = objType.getDescribe()
                .fields.getMap().get(controllingFieldName).getDescribe().getPicklistValues();
            List<Schema.PicklistEntry> depEntries  = objType.getDescribe()
                .fields.getMap().get(dependentFieldName).getDescribe().getPicklistValues();

            for (Schema.PicklistEntry ctrl : ctrlEntries)
                if (ctrl.isActive()) result.put(ctrl.getValue(), new List<Map<String, String>>());

            for (Schema.PicklistEntry dep : depEntries) {
                if (!dep.isActive()) continue;
                Map<String, Object> depMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(dep));
                String validFor = (String) depMap.get('validFor');
                if (String.isBlank(validFor)) continue;
                String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(validFor));
                for (Integer i = 0; i < ctrlEntries.size(); i++) {
                    Schema.PicklistEntry ctrl = ctrlEntries[i];
                    if (!ctrl.isActive()) continue;
                    Integer byteIndex = i / 8;
                    Integer bitIndex  = 7 - Math.mod(i, 8);
                    if (byteIndex * 2 + 2 > hexString.length()) continue;
                    Integer byteVal = hexToInt(hexString.substring(byteIndex * 2, byteIndex * 2 + 2));
                    if ((byteVal & (1 << bitIndex)) != 0 && result.containsKey(ctrl.getValue())) {
                        result.get(ctrl.getValue()).add(new Map<String, String>{
                            'label' => dep.getLabel(), 'value' => dep.getValue()
                        });
                    }
                }
            }
        } catch (Exception e) { }
        return result;
    }

    private static Integer hexToInt(String hex) {
        Integer result = 0;
        for (Integer i = 0; i < hex.length(); i++) {
            Integer c = hex.charAt(i);
            Integer digit = (c >= 48 && c <= 57) ? c - 48
                          : (c >= 97 && c <= 102) ? c - 87
                          : (c >= 65 && c <= 70)  ? c - 55 : 0;
            result = result * 16 + digit;
        }
        return result;
    }

    // ── Lecture ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<SObject> getVehiclesAdverses(Id claimId) {
            return DM002_VehicleCaseAssignment.getVehiclesAdverses(claimId);
    }

    @AuraEnabled
    public static Map<String, Object> getVehicleAdverseById(Id assignmentId) {
            Map<String, Object> result = DM002_VehicleCaseAssignment.getVehicleAdverseById(assignmentId);
            return result;
    }

    // ── Écriture ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> upsertVehiculeAdverse(
            Map<String, Object> formData, Id claimId, Boolean isUpdateMode) {
        if (claimId == null) return errorResponse('L\'identifiant du sinistre est requis.');
        Id resolvedClaimId = resolveClaimId(claimId);
        if (resolvedClaimId == null) return errorResponse('Aucun sinistre trouvé pour cet enregistrement.');
        return isUpdateMode
            ? EM002_VehicleCaseAssignment.updateVehiculeAdverse(formData)
            : EM002_VehicleCaseAssignment.insertVehiculeAdverse(formData, resolvedClaimId);
    }

    @AuraEnabled
    public static Map<String, Object> deleteVehiculeAdverse(Id assignmentId) {
        if (assignmentId == null) return errorResponse('L\'identifiant de l\'affectation est requis.');
        return EM002_VehicleCaseAssignment.deleteVehiculeAdverse(assignmentId);
    }

    private static Map<String, Object> errorResponse(String message) {
        return new Map<String, Object>{ 'success' => false, 'message' => message };
    }
}