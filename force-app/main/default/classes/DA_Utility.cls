public with sharing class DA_Utility {

    /*
     * Method for building Queries this one for standard queries
     */
    public static String buildStandardQuery(String objectName, Set<String> fields, String whereClause) {
        String query = 'SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM ' + objectName;
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        return query;
    }

    /*
     * Method for building Queries this one for queries with WHERE Clause
     */
    public static String buildOrderByClause(String sortBy, String sortDirection, Set<String> validFields, String defaultSort) {
        return 'ORDER BY ' + (String.isNotBlank(sortBy) && validFields.contains(sortBy) ?
            sortBy + ' ' + (sortDirection == 'asc' ? 'ASC' : 'DESC') : defaultSort);
    }

    /**
     * @description      :   Recherche générique par LIKE sur un champ donné
     * @param fields     :   Champs à retourner (ex: 'Id, Name')
     * @param sObjectName:   Nom de l'objet (ex: 'Account')
     * @param searchField:   Champ sur lequel chercher (ex: 'Name')
     * @param searchTerm :   Terme de recherche (le % est ajouté automatiquement)
     * @param extraConditions : Conditions supplémentaires ou null
     * @param limitCount :   Nombre max de résultats (défaut 10)
     * @return           :   List<SObject>
     **/
    public static List<SObject> query(String fields, String sObjectName, String conditions, String orderBy, Integer limitCount) {
        String soql = 'SELECT ' + fields + ' FROM ' + sObjectName;
        if (String.isNotBlank(conditions)) {
            soql += ' WHERE ' + conditions;
        }
        if (String.isNotBlank(orderBy)) {
            soql += ' ORDER BY ' + orderBy;
        }
        if (limitCount != null && limitCount > 0) {
            soql += ' LIMIT ' + limitCount;
        }
        return Database.query(soql);
    }

    public static List<SObject> search(String fields, String sObjectName, String searchField, String searchTerm, String conditions, Integer limitCount) {
        if (String.isBlank(searchTerm)) {
            return new List<SObject>();
        }
        String safeTerm = String.escapeSingleQuotes(searchTerm.trim()) + '%';
        String soql = 'SELECT ' + fields + ' FROM ' + sObjectName
            + ' WHERE ' + searchField + ' LIKE \'' + safeTerm + '\'';
        if (String.isNotBlank(conditions)) {
            soql += ' AND ' + conditions;
        }
        soql += ' ORDER BY ' + searchField + ' ASC';
        if (limitCount != null && limitCount > 0) {
            soql += ' LIMIT ' + limitCount;
        }
        return Database.query(soql);
    }

    /**
     * Récupère un enregistrement unique par son Id.
     */
    public static SObject getById(String fields, String sObjectName, Id recordId) {
        if (recordId == null) return null;
        String safeId = String.escapeSingleQuotes(String.valueOf(recordId));
        List<SObject> results = query(fields, sObjectName, 'Id = \'' + safeId + '\'', null, 1);
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Supprime un enregistrement par son Id.
     */
    public static void deleteById(String sObjectName, Id recordId) {
        if (recordId == null) return;
        SObject record = Schema.getGlobalDescribe().get(sObjectName).newSObject(recordId);
        delete record;
    }

    /**
     * @description      :   Récupère l'ID d'un RecordType par nom d'objet et nom de développeur
     * @method Name      :   getRecordTypeId
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   objectName => objectName (String)
     * @param            :   developerName => developerName (String)
     * @return           :   Id
     **/
    public static SObject addByRecordType(String sObjectName, String developerName, Map<String, Object> fieldValues) {
        Id rtId = getRecordTypeId(sObjectName, developerName);
        SObject record = Schema.getGlobalDescribe().get(sObjectName).newSObject();
        if (rtId != null) {
            record.put('RecordTypeId', rtId);
        }
        if (fieldValues != null) {
            for (String fieldName : fieldValues.keySet()) {
                record.put(fieldName, fieldValues.get(fieldName));
            }
        }
        insert record;
        return record;
    }

    public static SObject updateByRecordType(String sObjectName, String developerName, Id recordId, Map<String, Object> fieldValues) {
        Id rtId = getRecordTypeId(sObjectName, developerName);
        SObject record = Schema.getGlobalDescribe().get(sObjectName).newSObject(recordId);
        if (rtId != null) {
            record.put('RecordTypeId', rtId);
        }
        if (fieldValues != null) {
            for (String fieldName : fieldValues.keySet()) {
                record.put(fieldName, fieldValues.get(fieldName));
            }
        }
        update record;
        return record;
    }

    public static Id getRecordTypeId(String objectName, String developerName) {
        try {
            if (String.isNotBlank(objectName) && String.isNotBlank(developerName)) {
                return Schema.getGlobalDescribe()
                    .get(objectName)
                    .getDescribe()
                    .getRecordTypeInfosByDeveloperName()
                    .get(developerName)
                    .getRecordTypeId();
            }
            return null;
        } catch (Exception e) {
            System.debug('Error getting record type: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description      :   Récupère les informations de l'utilisateur courant (profil, habilitations, pays, responsable)
     * @method Name      :   getCurrentUserInfo
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @return           :   User
     **/
    public static User getCurrentUserInfo() {
        return [SELECT Id, Name, Email, ManagerId, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    // ═══════════════════════════════════════════════════════════════
    // PICKLISTS — Méthodes génériques réutilisables
    // ═══════════════════════════════════════════════════════════════

    /**
     * @description      :   Retourne les valeurs actives d'une picklist simple
     * @Author           :   D&A Technologies
     * @param objectName :   API name de l'objet  (ex: 'InsurancePolicy__c')
     * @param fieldName  :   API name du champ picklist (ex: 'Canal__c')
     * @return           :   List<Map<String, String>> — chaque map contient 'label' et 'value'
     **/
    public static List<Map<String, String>> getPicklistValues(String objectName, String fieldName) {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        try {
            Schema.DescribeFieldResult fieldDesc = Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap()
                .get(fieldName)
                .getDescribe();

            for (Schema.PicklistEntry e : fieldDesc.getPicklistValues()) {
                if (e.isActive()) {
                    opts.add(new Map<String, String>{
                        'label' => e.getLabel(),
                        'value' => e.getValue()
                    });
                }
            }
        } catch (Exception e) {
            System.debug('DA_Utility.getPicklistValues error ['
                + objectName + '.' + fieldName + ']: ' + e.getMessage());
        }
        return opts;
    }

    /**
     * @description            :   Retourne les valeurs actives d'une picklist dépendante,
     *                             groupées par valeur du champ contrôlant.
     * @Author                 :   D&A Technologies
     * @param objectName       :   API name de l'objet
     * @param controllingField :   API name du champ contrôlant (ex: 'Brand__c')
     * @param dependentField   :   API name du champ dépendant  (ex: 'ModelePicklist__c')
     * @return                 :   Map<String, List<Map<String, String>>>
     *                             clé    = valeur du champ contrôlant
     *                             valeur = liste {label, value} du champ dépendant
     **/
    public static Map<String, List<Map<String, String>>> getDependentPicklistValues(
        String objectName,
        String controllingField,
        String dependentField
    ) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap();

            List<Schema.PicklistEntry> ctrlEntries = fieldMap.get(controllingField)
                .getDescribe().getPicklistValues();
            List<Schema.PicklistEntry> depEntries  = fieldMap.get(dependentField)
                .getDescribe().getPicklistValues();

            // Initialiser une entrée vide pour chaque valeur active du contrôlant
            for (Schema.PicklistEntry ctrl : ctrlEntries) {
                if (ctrl.isActive()) {
                    result.put(ctrl.getValue(), new List<Map<String, String>>());
                }
            }

            // Distribuer les valeurs dépendantes selon le bitmask 'validFor'
            for (Schema.PicklistEntry dep : depEntries) {
                if (!dep.isActive()) continue;

                Map<String, Object> depMap   = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(dep));
                String              validFor = (String) depMap.get('validFor');
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
                            'label' => dep.getLabel(),
                            'value' => dep.getValue()
                        });
                    }
                }
            }
        } catch (Exception e) {
            System.debug('DA_Utility.getDependentPicklistValues error ['
                + objectName + ' ' + controllingField + ' → ' + dependentField + ']: ' + e.getMessage());
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé — conversion hex → entier (utilisé par getDependentPicklistValues)
    // ─────────────────────────────────────────────────────────────
    private static Integer hexToInt(String hex) {
        Integer result = 0;
        for (Integer i = 0; i < hex.length(); i++) {
            Integer c     = hex.charAt(i);
            Integer digit = (c >= 48 && c <= 57)  ? c - 48
                          : (c >= 97 && c <= 102) ? c - 87
                          : (c >= 65 && c <= 70)  ? c - 55 : 0;
            result = result * 16 + digit;
        }
        return result;
    }

    /**
 * @description      :   Compte le nombre d'enregistrements selon des conditions optionnelles
 * @Author           :   D&A Technologies
 * @param sObjectName:   Nom de l'objet (ex: 'Evenement__c')
 * @param conditions :   Clause WHERE sans le mot-clé WHERE, ou null pour tout compter
 * @return           :   Integer — nombre d'enregistrements correspondants
 **/
public static Integer count(String sObjectName, String conditions) {
    String soql = 'SELECT COUNT() FROM ' + sObjectName;
    if (String.isNotBlank(conditions)) {
        soql += ' WHERE ' + conditions;
    }
    return Database.countQuery(soql);
}
}