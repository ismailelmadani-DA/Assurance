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
     * @description      :   Récupère l’ID d’un RecordType par nom d’objet et nom de développeur
     * @method Name      :   getRecordTypeId
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   objectName => objectName (String)
     * @param            :   developerName => developerName (String)
     * @return           :   Id
     * -------------------------------------------------------------------------------------------------
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
            if(String.isNotBlank(objectName) && String.isNotBlank(developerName)){
                return Schema.getGlobalDescribe().get(objectName).getDescribe().getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
            }
            return null;
        } catch (Exception e) {
            // Handle the case where record type is not found
            System.debug('Error getting record type: ' + e.getMessage());
            return null;
        }
    }
       /**
     * @description      :   Récupère les informations de l’utilisateur courant (profil, habilitations, pays, responsable)
     * @method Name      :   getCurrentUserInfo
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @return           :   User
     * -------------------------------------------------------------------------------------------------
     **/
    public static User getCurrentUserInfo(){
        return [SELECT Id, Name, Email, ManagerId, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() limit 1];
    }
}