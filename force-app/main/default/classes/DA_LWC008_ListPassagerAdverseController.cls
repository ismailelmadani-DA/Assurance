public with sharing class DA_LWC008_ListPassagerAdverseController  {

   @AuraEnabled(cacheable=true)
public static List<SObject> getPassagersAdverses(Id caseId) {
    if (caseId == null) {
        return new List<SObject>();
    }
    return DM001_Passager.getPassagersAdversesByCase(caseId);
}
}