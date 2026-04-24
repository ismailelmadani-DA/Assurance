public with sharing class DA_HistoriquesSinistresController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getHistoriques(Id accountId) {
        return DM_SinistreHistory.getHistoriques(accountId);
    }
}
