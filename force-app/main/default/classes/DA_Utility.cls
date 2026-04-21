public with sharing class DA_Utility {
    /**
     * @description      :   Récupère les informations de l’utilisateur courant (profil, habilitations, pays, responsable)
     * @method Name      :   getCurrentUserInfo
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @return           :   User
     * -------------------------------------------------------------------------------------------------
     **/
    public static User getCurrentUserInfo(){
        return [SELECT Id, Name, Email, Profile.Name,ManagerId, Manager.Name, Manager.Profile.Name FROM User WHERE Id = :UserInfo.getUserId() limit 1];
    }
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
     * @description      :   Recherche générique par LIKE sur un champ donné via DM_DataManager
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
}