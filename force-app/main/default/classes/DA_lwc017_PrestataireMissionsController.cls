/**
 * @description  : Controller LWC — Missions (Cases) assignées à un Prestataire
 * @author       : D&A Technologies
 * @date         : 2026-04-27
 */
public with sharing class DA_lwc017_PrestataireMissionsController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMissionsByPrestataire(Id accountId) {
        if (accountId == null) {
            return new List<Map<String, Object>>();
        }

        try {
            List<Case> records = DM_Case.getMissionsByAccountId(accountId);

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (Case c : records) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('id',            c.Id);
                row.put('caseNumber',    c.CaseNumber);
                row.put('natureMission', c.NatureMission__c);
                row.put('status',        c.Status);
                row.put('createdDate',   c.CreatedDate);
                row.put('createdById',   c.CreatedById);
                row.put('createdByName', c.CreatedBy != null ? c.CreatedBy.Name : '');
                result.add(row);
            }

            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la récupération des missions : ' + e.getMessage());
        }
    }
}