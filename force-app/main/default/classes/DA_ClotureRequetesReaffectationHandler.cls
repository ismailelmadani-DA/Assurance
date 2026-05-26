public class DA_ClotureRequetesReaffectationHandler {

    public static void handleAfterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
        System.debug('METHOD_NAME : handleAfterUpdate');

        Set<Id> declarationIds = collectDeclarationIds(newList, oldMap);
        if (declarationIds.isEmpty()) return;

        List<Case> requetes = getRequetesReaffectation(declarationIds);
        if (requetes.isEmpty()) return;

        cloturerRequetes(requetes);
    }

    private static Set<Id> collectDeclarationIds(List<Case> newList, Map<Id, Case> oldMap) {
        Set<Id> declarationIds = new Set<Id>();
        for (Case c : newList) {
            Case oldCase = oldMap.get(c.Id);
            if (c.Claim__c != null && oldCase.Claim__c == null) {
                declarationIds.add(c.Id);
            }
        }
        return declarationIds;
    }

    private static List<Case> getRequetesReaffectation(Set<Id> declarationIds) {
        return [
            SELECT Id, Status
            FROM Case
            WHERE Declaration_Liee__c IN :declarationIds
            AND CategorieRequete__c = 'Réaffectation'
            AND TypeRequete__c = 'Réaffecter la déclaration'
            AND Status != 'Clôturé'
        ];
    }

    private static void cloturerRequetes(List<Case> requetes) {
        for (Case r : requetes) {
            r.Status = 'Clôturé';
        }
        update requetes;
    }
}