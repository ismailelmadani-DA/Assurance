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
}