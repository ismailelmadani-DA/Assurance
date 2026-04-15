/**
 * @description       : Contrôleur Apex générique pour afficher n'importe quel objet Salesforce
 *                      avec des champs configurables depuis le builder de page Lightning.
 *                      Supporte les champs de relation (ex: Account.Name, Owner.Name).
 * @author            : D&A Technologies
 * @group             : Controllers
 * @last modified on  : 04-03-2026
 * @last modified by  : D&A Technologies
 **/
public with sharing class DA_GenericDataTableController {

    /**
     * @description      : Récupère les enregistrements d'un objet avec les champs spécifiés,
     *                     filtrés optionnellement par un champ de lookup vers l'enregistrement courant.
     * @method Name      : getRecords
     * @param objectApiName   : API Name de l'objet (ex: Case, InsurancePolicy__c)
     * @param fieldsString    : Champs séparés par virgule (ex: "CaseNumber,Status,Account.Name")
     * @param filterField     : Champ de filtre (ex: "Claim__c", "AccountId") - peut être vide
     * @param filterValue     : Valeur du filtre (ex: recordId courant)
     * @param recordTypeDeveloperName : DeveloperName du RecordType pour filtrer - peut être vide
     * @param orderByField    : Champ de tri (ex: "CreatedDate")
     * @param orderDirection  : Direction du tri (ASC / DESC)
     * @param limitSize       : Nombre max d'enregistrements à récupérer
     * @return            : List<SObject>
     **/
    @AuraEnabled(cacheable=false)
    public static List<SObject> getRecords(
        String objectApiName,
        String fieldsString,
        String filterField,
        String filterValue,
        String recordTypeDeveloperName,
        String orderByField,
        String orderDirection,
        Integer limitSize
    ) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldsString)) {
            throw new AuraHandledException('objectApiName et fieldsString sont obligatoires.');
        }

        // Nettoyer et valider les champs
        List<String> fields = cleanFields(fieldsString);
        if (fields.isEmpty()) {
            throw new AuraHandledException('Aucun champ valide fourni.');
        }

        // Construire la requête SOQL
        String soql = 'SELECT ' + String.join(fields, ', ');
        soql += ' FROM ' + String.escapeSingleQuotes(objectApiName);

        List<String> whereClauses = new List<String>();

        // Filtre par champ de lookup
        if (String.isNotBlank(filterField) && String.isNotBlank(filterValue)) {
            whereClauses.add(String.escapeSingleQuotes(filterField) + ' = \'' + String.escapeSingleQuotes(filterValue) + '\'');
        }

        // Filtre par RecordType
        if (String.isNotBlank(recordTypeDeveloperName)) {
            whereClauses.add('RecordType.DeveloperName = \'' + String.escapeSingleQuotes(recordTypeDeveloperName) + '\'');
        }

        if (!whereClauses.isEmpty()) {
            soql += ' WHERE ' + String.join(whereClauses, ' AND ');
        }

        // Tri
        if (String.isNotBlank(orderByField)) {
            String dir = (String.isNotBlank(orderDirection) && orderDirection.equalsIgnoreCase('ASC')) ? 'ASC' : 'DESC';
            soql += ' ORDER BY ' + String.escapeSingleQuotes(orderByField) + ' ' + dir;
        }

        // Limite
        Integer lim = (limitSize != null && limitSize > 0 && limitSize <= 2000) ? limitSize : 200;
        soql += ' LIMIT ' + lim;

        try {
            System.debug('SOQL générique: ' + soql);
            return Database.query(soql);
        } catch (Exception e) {
            System.debug('Erreur getRecords: ' + e.getMessage());
            throw new AuraHandledException('Erreur lors du chargement: ' + e.getMessage());
        }
    }

    /**
     * @description      : Compte le nombre d'enregistrements selon les mêmes filtres.
     * @method Name      : getRecordsCount
     **/
    @AuraEnabled(cacheable=false)
    public static Integer getRecordsCount(
        String objectApiName,
        String filterField,
        String filterValue,
        String recordTypeDeveloperName
    ) {
        if (String.isBlank(objectApiName)) return 0;

        String soql = 'SELECT COUNT() FROM ' + String.escapeSingleQuotes(objectApiName);
        List<String> whereClauses = new List<String>();

        if (String.isNotBlank(filterField) && String.isNotBlank(filterValue)) {
            whereClauses.add(String.escapeSingleQuotes(filterField) + ' = \'' + String.escapeSingleQuotes(filterValue) + '\'');
        }
        if (String.isNotBlank(recordTypeDeveloperName)) {
            whereClauses.add('RecordType.DeveloperName = \'' + String.escapeSingleQuotes(recordTypeDeveloperName) + '\'');
        }
        if (!whereClauses.isEmpty()) {
            soql += ' WHERE ' + String.join(whereClauses, ' AND ');
        }

        try {
            return Database.countQuery(soql);
        } catch (Exception e) {
            System.debug('Erreur getRecordsCount: ' + e.getMessage());
            return 0;
        }
    }

    /**
     * @description      : Récupère les labels traduits des picklists d'un objet pour un champ donné.
     * @method Name      : getPicklistLabelsForField
     * @param objectApiName : API Name de l'objet
     * @param fieldName     : API Name du champ picklist
     * @return            : Map<String, String> value => label
     **/
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getPicklistLabelsForField(String objectApiName, String fieldName) {
        Map<String, String> labels = new Map<String, String>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) return labels;

            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            if (!fieldMap.containsKey(fieldName)) return labels;

            Schema.DescribeFieldResult fieldResult = fieldMap.get(fieldName).getDescribe();
            if (fieldResult.getType() != Schema.DisplayType.PICKLIST &&
                fieldResult.getType() != Schema.DisplayType.MULTIPICKLIST) {
                return labels;
            }

            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.isActive()) {
                    labels.put(entry.getValue(), entry.getLabel());
                }
            }
        } catch (Exception e) {
            System.debug('Erreur getPicklistLabelsForField: ' + e.getMessage());
        }
        return labels;
    }

    /**
     * @description      : Retourne les métadonnées des champs d'un objet (label, type, isPicklist).
     * @method Name      : getFieldsMetadata
     * @param objectApiName : API Name de l'objet
     * @param fieldsString  : Champs séparés par virgule
     * @return            : List<Map<String, Object>>
     **/
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getFieldsMetadata(String objectApiName, String fieldsString) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(objectApiName) || String.isBlank(fieldsString)) return result;

        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) return result;

            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            List<String> fields = cleanFields(fieldsString);

            for (String field : fields) {
                Map<String, Object> meta = new Map<String, Object>();
                meta.put('apiName', field);

                // Champ de relation ex: Account.Name
                if (field.contains('.')) {
                    List<String> parts = field.split('\\.');
                    meta.put('label', parts[parts.size() - 1]);
                    meta.put('type', 'TEXT');
                    meta.put('isPicklist', false);
                    meta.put('isDate', false);
                    meta.put('isDateTime', false);
                    meta.put('isRelationship', true);
                } else if (fieldMap.containsKey(field.toLowerCase())) {
                    Schema.DescribeFieldResult dfr = fieldMap.get(field.toLowerCase()).getDescribe();
                    String fieldType = dfr.getType().name();
                    meta.put('label', dfr.getLabel());
                    meta.put('type', fieldType);
                    meta.put('isPicklist', fieldType == 'PICKLIST' || fieldType == 'MULTIPICKLIST');
                    meta.put('isDate', fieldType == 'DATE');
                    meta.put('isDateTime', fieldType == 'DATETIME');
                    meta.put('isRelationship', false);
                } else {
                    meta.put('label', field);
                    meta.put('type', 'TEXT');
                    meta.put('isPicklist', false);
                    meta.put('isDate', false);
                    meta.put('isDateTime', false);
                    meta.put('isRelationship', false);
                }
                result.add(meta);
            }
        } catch (Exception e) {
            System.debug('Erreur getFieldsMetadata: ' + e.getMessage());
        }
        return result;
    }
    

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private static List<String> cleanFields(String fieldsString) {
        List<String> cleaned = new List<String>();
        for (String f : fieldsString.split(',')) {
            String trimmed = f.trim();
            if (String.isNotBlank(trimmed)) {
                cleaned.add(trimmed);
            }
        }
        return cleaned;
    }
}