public with sharing class EM_GarantiesSinistre {

    /**
     * @description : Construit la liste finale des garanties
     *                RC en premier, puis touchées, puis non touchées
     */
    public static List<Map<String, Object>> build(
        List<GarantieAssurance__mdt>      mdtList,
        Map<String, ClaimCoverage__c>     touchedByCode,
        String                            rcCode
    ) {
        Map<String, Object>           rcEntry      = null;
        List<Map<String, Object>>     touchees     = new List<Map<String, Object>>();
        List<Map<String, Object>>     nonTouchees  = new List<Map<String, Object>>();

        for (GarantieAssurance__mdt g : mdtList) {
            String  code    = g.CodeGarantie__c;
            Boolean isRC    = code == rcCode;
            Boolean touchee = isRC || touchedByCode.containsKey(code);

            Map<String, Object> row = new Map<String, Object>{
                'id'      => touchedByCode.containsKey(code)
                                ? (Object) touchedByCode.get(code).Id
                                : (Object) code,
                'code'    => code,
                'nom'     => g.MasterLabel,
                'type'    => g.TypeGarantie__c,
                'touchee' => touchee,
                'isRC'    => isRC
            };

            if (isRC) {
                rcEntry = row;
            } else if (touchee) {
                touchees.add(row);
            } else {
                nonTouchees.add(row);
            }
        }

        // Tri final : RC → touchées → non touchées
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (rcEntry != null) result.add(rcEntry);
        result.addAll(touchees);
        result.addAll(nonTouchees);
        return result;
    }
}