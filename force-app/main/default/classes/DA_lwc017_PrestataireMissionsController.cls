/**
 * @description  : Controller LWC — Missions (Cases) assignées à un Prestataire
 * @author       : D&A Technologies
 * @date         : 2026-04-27
 */
public with sharing class DA_lwc017_PrestataireMissionsController {

    private static final String CASE_OBJECT = 'Case';
    private static final Integer MAX_LIMIT = 500;
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMissionsByPrestataire(Id accountId) {
        // Validation initiale
        if (accountId == null) {
            return new List<Map<String, Object>>();
        }
        
        try {
            String safeAccountId = String.escapeSingleQuotes(String.valueOf(accountId));
            
            // Condition : La mission doit être liée au compte (via Prestataire__c OU AccountId)
            String conditions = 'Prestataire__c = \'' + safeAccountId + '\' OR AccountId = \'' + safeAccountId + '\'';
            
            System.debug('Account ID: ' + accountId);
            System.debug('Conditions: ' + conditions);
            
            // Appel à DA_Utility.query()
            List<SObject> records = DA_Utility.query(
                'Id, CaseNumber, NatureMission__c, Status, CreatedDate, CreatedById, CreatedBy.Name',
                CASE_OBJECT,
                conditions,
                'CreatedDate DESC',
                MAX_LIMIT
            );
            
            System.debug('Nombre de missions trouvées: ' + records.size());
            
            // Transformation en Map pour le LWC
            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (SObject rec : records) {
                Case c = (Case) rec;
                Map<String, Object> row = new Map<String, Object>();
                
                row.put('id', c.Id);
                row.put('caseNumber', c.CaseNumber);
                row.put('natureMission', c.NatureMission__c);
                row.put('status', c.Status);
                row.put('createdDate', c.CreatedDate);
                row.put('createdById', c.CreatedById);
                row.put('createdByName', c.CreatedBy != null ? c.CreatedBy.Name : '');
                
                result.add(row);
            }
            
            return result;
            
        } catch (Exception e) {
            System.debug('Erreur: ' + e.getMessage());
            throw new AuraHandledException('Erreur lors de la récupération des missions: ' + e.getMessage());
        }
    }
}