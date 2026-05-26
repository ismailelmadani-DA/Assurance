public with sharing class DA_LWC015_VehiculeAdverseClaimController {

    // ── Picklists ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static String getCompagnieAdverseRecordTypeId() {
        return DM002_VehicleCaseAssignment.getCompagnieAdverseRecordTypeId();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        return DM002_VehicleCaseAssignment.getPicklistValues();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentModeleOptions() {
        return DM002_VehicleCaseAssignment.getDependentModeleOptions();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentVilleOptions() {
        return DM002_VehicleCaseAssignment.getDependentVilleOptions();
    }

    // ── Lecture ───────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
public static List<SObject> getVehiclesAdverses(Id claimId) {
    if (claimId == null) return new List<SObject>();
    return DM002_VehicleCaseAssignment.getVehiclesAdverses(claimId);
}

    @AuraEnabled
    public static Map<String, Object> getVehicleAdverseById(Id assignmentId) {
        return DM002_VehicleCaseAssignment.getVehicleAdverseById(assignmentId);
    }

    // ── Écriture ──────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> upsertVehiculeAdverse(
            Map<String, Object> formData, Id claimId, Boolean isUpdateMode) {
        if (claimId == null) return errorResponse('L\'identifiant du sinistre est requis.');
        return isUpdateMode
            ? EM002_VehicleCaseAssignment.updateVehiculeAdverse(formData)
            : EM002_VehicleCaseAssignment.insertVehiculeAdverse(formData, claimId);
    }

    @AuraEnabled
    public static Map<String, Object> deleteVehiculeAdverse(Id assignmentId) {
        if (assignmentId == null) return errorResponse('L\'identifiant de l\'affectation est requis.');
        return EM002_VehicleCaseAssignment.deleteVehiculeAdverse(assignmentId);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Map<String, Object> errorResponse(String message) {
        return new Map<String, Object>{ 'success' => false, 'message' => message };
    }
}