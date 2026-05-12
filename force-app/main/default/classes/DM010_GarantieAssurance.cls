public with sharing class DM010_GarantieAssurance {

    public static List<GarantieAssurance__mdt> getActive() {
        return [
            SELECT MasterLabel, CodeGarantie__c, TypeGarantie__c
            FROM GarantieAssurance__mdt
            WHERE IsActive__c = true
            ORDER BY MasterLabel ASC
        ];
    }

    public static Map<String, GarantieAssurance__mdt> getActiveByCode() {
        Map<String, GarantieAssurance__mdt> byCode = new Map<String, GarantieAssurance__mdt>();
        for (GarantieAssurance__mdt g : getActive()) {
            if (g.CodeGarantie__c != null) byCode.put(g.CodeGarantie__c, g);
        }
        return byCode;
    }
}
