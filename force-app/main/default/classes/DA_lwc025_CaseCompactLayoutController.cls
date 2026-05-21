public with sharing class DA_lwc025_CaseCompactLayoutController {

    private static final String RT_DECLARATION = 'Declaration';
    private static final String RT_MISSION     = 'Mission';
    private static final String RT_REQUETE     = 'Requete';

    public class FieldItem {
        @AuraEnabled public String  fieldPath    { get; set; }
        @AuraEnabled public String  label        { get; set; }
        @AuraEnabled public String  fieldType    { get; set; }
        @AuraEnabled public Boolean isLookup     { get; set; }
        @AuraEnabled public Boolean isDateTime   { get; set; }
        @AuraEnabled public String  lookupId     { get; set; }
        @AuraEnabled public String  displayValue { get; set; }
    }

    public class ActionItem {
        @AuraEnabled public String name     { get; set; }
        @AuraEnabled public String label    { get; set; }
        @AuraEnabled public String variant  { get; set; }
        @AuraEnabled public String iconName { get; set; }
    }

    public class CompactData {
        @AuraEnabled public String           caseId              { get; set; }
        @AuraEnabled public String           objectApiName       { get; set; }
        @AuraEnabled public String           caseNumber          { get; set; }
        @AuraEnabled public String           recordTypeName      { get; set; }
        @AuraEnabled public String           headerLabel         { get; set; }
        @AuraEnabled public String           iconName            { get; set; }
        @AuraEnabled public String           typeRequete         { get; set; }
        @AuraEnabled public String           declarationOwnerId  { get; set; } // ✅ AJOUT
        @AuraEnabled public String           reaffecterAId       { get; set; } // ✅ AJOUT
        @AuraEnabled public String           requeteInitialeId   { get; set; } // ✅ AJOUT
        @AuraEnabled public Decimal          lastWizardStep      { get; set; }
        @AuraEnabled public List<FieldItem>  fields              { get; set; }
        @AuraEnabled public List<ActionItem> actions             { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static CompactData getRecordData(
            Id     recordId,
            String objectApiName,
            String fieldsCsv,
            String recordTypeName) {

        if (recordId == null)
            throw new AuraHandledException('recordId est requis.');
        if (String.isBlank(objectApiName))
            throw new AuraHandledException('Object API Name est requis. Configurez-le dans le Lightning App Builder.');
        if (String.isBlank(fieldsCsv))
            throw new AuraHandledException('Le champ Champs (CSV) est requis. Configurez-le dans le Lightning App Builder.');
        if (String.isBlank(recordTypeName))
            throw new AuraHandledException('Le champ Record Type est requis. Configurez-le dans le Lightning App Builder.');

        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjType == null)
            throw new AuraHandledException('Objet inconnu : ' + objectApiName);

        Map<String, Schema.SObjectField> fieldMap = sobjType.getDescribe().fields.getMap();
        List<String> requestedFields = parseFields(fieldsCsv);
        Boolean      isCase          = (objectApiName == 'Case');

        Set<String> soqlFields = buildSoqlFields(requestedFields, fieldMap, isCase);
        SObject     record     = queryRecord(recordId, objectApiName, soqlFields, isCase, fieldMap);

        if (record == null)
            throw new AuraHandledException('Enregistrement introuvable.');

        CompactData data    = new CompactData();
        data.caseId         = record.Id;
        data.objectApiName  = objectApiName;
        data.recordTypeName = recordTypeName;
        data.headerLabel    = headerLabelFor(recordTypeName);
        data.iconName       = iconFor(recordTypeName);
        data.actions        = buildActions(recordTypeName, record);
        data.fields         = buildFieldsDynamic(record, fieldMap, requestedFields);

        if (isCase) {
            data.caseNumber = ((Case) record).CaseNumber;
            try {
                Object typeReq   = record.get('TypeRequete__c');
                data.typeRequete = (typeReq != null) ? String.valueOf(typeReq) : null;
            } catch (Exception e) {
                data.typeRequete = null;
            }

            // ✅ AJOUT — declarationOwnerId toujours rempli pour les Cases
            try {
                Object ownerId = record.get('OwnerId');
                data.declarationOwnerId = (ownerId != null) ? String.valueOf(ownerId) : null;
            } catch (Exception e) {
                data.declarationOwnerId = null;
            }

            // ✅ AJOUT — reaffecterAId uniquement pour Declaration
            if (recordTypeName == RT_DECLARATION) {
                data.reaffecterAId = resolveReaffecterAId(recordId);
                data.requeteInitialeId = resolveRequeteInitialeId(recordId);
                try {
                    Object step = record.get('LastWizardStep__c');
                    data.lastWizardStep = (step != null) ? (Decimal) step : null;
                } catch (Exception e) {
                    data.lastWizardStep = null;
                }
            }

        } else {
            try {
                Object nameVal  = record.get('Name');
                data.caseNumber = (nameVal != null) ? String.valueOf(nameVal) : String.valueOf(record.Id);
            } catch (Exception e) {
                data.caseNumber = String.valueOf(record.Id);
            }
        }

        return data;
    }

    // ✅ AJOUT — cherche la Requête de réaffectation "En cours" liée à la Déclaration
    private static String resolveReaffecterAId(Id declarationId) {
        try {
            List<Case> requetes = [
                SELECT Id, ReaffecterA__c
                FROM Case
                WHERE Declaration_Liee__c = :declarationId
                  AND TypeRequete__c     = 'Réaffecter la déclaration'
                  AND CategorieRequete__c = 'Réaffectation'
                  AND Status             = 'En cours'
                LIMIT 1
            ];
            if (!requetes.isEmpty() && requetes[0].ReaffecterA__c != null) {
                return String.valueOf(requetes[0].ReaffecterA__c);
            }
        } catch (Exception e) {
            // champ inexistant ou pas d'accès → on ignore
        }
        return null;
    }


    private static String resolveRequeteInitialeId(Id declarationId) {
    try {
        List<Case> requetes = [
            SELECT Id, CreatedById
            FROM Case
            WHERE Declaration_Liee__c = :declarationId
              AND TypeRequete__c      = 'Réaffecter la déclaration'
              AND CategorieRequete__c = 'Réaffectation'
              AND Status              = 'Initiale'
            LIMIT 1
        ];
        if (!requetes.isEmpty()) {
            return String.valueOf(requetes[0].Id);
        }
    } catch (Exception e) { }
    return null;
}

private static String resolveRequeteInitialeCreatedById(Id declarationId) {
    try {
        List<Case> requetes = [
            SELECT Id, CreatedById
            FROM Case
            WHERE Declaration_Liee__c = :declarationId
              AND TypeRequete__c      = 'Réaffecter la déclaration'
              AND CategorieRequete__c = 'Réaffectation'
              AND Status              = 'Initiale'
            LIMIT 1
        ];
        if (!requetes.isEmpty()) {
            return String.valueOf(requetes[0].CreatedById);
        }
    } catch (Exception e) { }
    return null;
}



    private static Set<String> buildSoqlFields(
            List<String> requestedFields,
            Map<String, Schema.SObjectField> fieldMap,
            Boolean isCase) {

        Set<String> soqlFields = new Set<String>{ 'Id' };

        for (String fieldPath : requestedFields) {
            if (fieldPath.contains('.')) {
                soqlFields.add(fieldPath);
                String relName   = fieldPath.split('\\.')[0];
                String lookupApi = resolveLookupApi(relName, fieldMap);
                if (lookupApi != null) soqlFields.add(lookupApi);
            } else {
                soqlFields.add(fieldPath);
                Schema.SObjectField f = fieldMap.get(fieldPath.toLowerCase());
                if (f != null) {
                    Schema.DescribeFieldResult dfr = f.getDescribe();
                    if (dfr.getType() == Schema.DisplayType.REFERENCE) {
                        String relName = dfr.getRelationshipName();
                        if (String.isNotBlank(relName)) soqlFields.add(relName + '.Name');
                    }
                }
            }
        }

        if (isCase) {
            soqlFields.add('CaseNumber');
            soqlFields.add('RecordTypeId');
            soqlFields.add('RecordType.DeveloperName');
            soqlFields.add('OwnerId');              // ✅ AJOUT
            soqlFields.add('TypeRequete__c');
            soqlFields.add('CategorieRequete__c');
            soqlFields.add('LastWizardStep__c');
        }

        return soqlFields;
    }

    private static List<String> parseFields(String csv) {
        List<String> out = new List<String>();
        for (String s : csv.split(',')) {
            String t = s.trim();
            if (String.isNotBlank(t)) out.add(t);
        }
        return out;
    }

    private static SObject queryRecord(
            Id recordId,
            String objectApiName,
            Set<String> soqlFields,
            Boolean isCase,
            Map<String, Schema.SObjectField> fieldMap) {

        if (!isCase && fieldMap.containsKey('name')) soqlFields.add('Name');

        String soql = 'SELECT '
            + String.join(new List<String>(soqlFields), ', ')
            + ' FROM '  + objectApiName
            + ' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1';
        try {
            List<SObject> rows = Database.query(soql);
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception e) {
            throw new AuraHandledException('Erreur SOQL : ' + e.getMessage());
        }
    }

    private static List<FieldItem> buildFieldsDynamic(
            SObject record,
            Map<String, Schema.SObjectField> fieldMap,
            List<String> fields) {

        List<FieldItem> items = new List<FieldItem>();
        for (String fieldPath : fields) {
            items.add(fieldPath.contains('.')
                ? buildRelationshipItem(record, fieldMap, fieldPath)
                : buildSimpleItem(record, fieldMap, fieldPath));
        }
        return items;
    }

    private static FieldItem buildSimpleItem(
            SObject record,
            Map<String, Schema.SObjectField> fieldMap,
            String fieldPath) {

        Schema.SObjectField        f   = fieldMap.get(fieldPath.toLowerCase());
        Schema.DescribeFieldResult dfr = (f != null) ? f.getDescribe() : null;
        String             label       = (dfr != null) ? dfr.getLabel() : fieldPath;
        Schema.DisplayType dt          = (dfr != null) ? dfr.getType()  : Schema.DisplayType.STRING;

        if (f == null && fieldPath.equalsIgnoreCase('CreatedDate')) {
            Object raw;
            try { raw = record.get('CreatedDate'); } catch (Exception e) { raw = null; }
            return dateTimeItem(fieldPath, 'Date de création', raw);
        }

        Object raw;
        try { raw = record.get(fieldPath); } catch (Exception e) { raw = null; }

        if (dt == Schema.DisplayType.DATETIME || dt == Schema.DisplayType.DATE) {
            return dateTimeItem(fieldPath, label, raw);
        }

        if (dt == Schema.DisplayType.REFERENCE) {
            Id     lookupId     = (raw instanceof Id) ? (Id) raw : null;
            String displayValue = null;
            if (lookupId != null && dfr != null) {
                String relName = dfr.getRelationshipName();
                if (String.isNotBlank(relName)) {
                    try {
                        SObject related = record.getSObject(relName);
                        if (related != null) {
                            Object nameVal = related.get('Name');
                            displayValue = (nameVal != null) ? String.valueOf(nameVal) : null;
                        }
                    } catch (Exception e) { /* ignore */ }
                }
            }
            if (String.isBlank(displayValue) && lookupId != null) displayValue = String.valueOf(lookupId);
            return lookupItem(fieldPath, label, lookupId, displayValue);
        }

        return textItem(fieldPath, label, (raw != null) ? String.valueOf(raw) : null);
    }

    private static FieldItem buildRelationshipItem(
            SObject record,
            Map<String, Schema.SObjectField> fieldMap,
            String fieldPath) {

        List<String> parts      = fieldPath.split('\\.');
        String relationshipName = parts[0];
        String childField       = (parts.size() > 1) ? parts[1] : 'Name';

        String lookupFieldApi = resolveLookupApi(relationshipName, fieldMap);
        Schema.DescribeFieldResult dfr = (lookupFieldApi != null
            && fieldMap.containsKey(lookupFieldApi.toLowerCase()))
            ? fieldMap.get(lookupFieldApi.toLowerCase()).getDescribe() : null;
        String label = (dfr != null) ? dfr.getLabel() : relationshipName;

        Id lookupId = null;
        if (lookupFieldApi != null) {
            try {
                Object raw = record.get(lookupFieldApi);
                lookupId = (raw instanceof Id) ? (Id) raw : null;
            } catch (Exception e) { /* ignore */ }
        }

        String displayValue = null;
        try {
            SObject related = record.getSObject(relationshipName);
            if (related != null) {
                Object v = related.get(childField);
                displayValue = (v != null) ? String.valueOf(v) : null;
            }
        } catch (Exception e) { /* ignore */ }

        if (String.isBlank(displayValue) && lookupId != null) displayValue = String.valueOf(lookupId);
        return lookupItem(fieldPath, label, lookupId, displayValue);
    }

    private static String resolveLookupApi(String relationshipName, Map<String, Schema.SObjectField> fieldMap) {
        if (relationshipName.endsWith('__r'))
            return relationshipName.substring(0, relationshipName.length() - 3) + '__c';
        String candidate = relationshipName + 'Id';
        if (fieldMap.containsKey(candidate.toLowerCase())) return candidate;
        for (Schema.SObjectField f : fieldMap.values()) {
            Schema.DescribeFieldResult dfr = f.getDescribe();
            String rel = dfr.getRelationshipName();
            if (String.isNotBlank(rel) && rel.equalsIgnoreCase(relationshipName)) return dfr.getName();
        }
        return null;
    }

    private static String headerLabelFor(String rt) {
        if (rt == RT_DECLARATION) return 'Déclaration';
        if (rt == RT_MISSION)     return 'Mission';
        if (rt == RT_REQUETE)     return 'Requête';
        return rt;
    }

    private static String iconFor(String rt) {
        if (rt == RT_DECLARATION) return 'standard:case';
        if (rt == RT_MISSION)     return 'standard:task';
        if (rt == RT_REQUETE)     return 'standard:question_feed';
        return 'standard:record';
    }

    private static List<ActionItem> buildActions(String rt, SObject record) {
        List<ActionItem> actions = new List<ActionItem>();

        if (rt == RT_DECLARATION) {
            actions.add(action('continueDeclaration', 'Poursuivre la déclaration', 'brand',   'utility:forward'));
            actions.add(action('reassign',            'Réaffecter',                'neutral', 'utility:user'));

        } else if (rt == RT_MISSION) {
            actions.add(action('cancel', 'Annuler',  'destructive', 'utility:close'));
            actions.add(action('close',  'Clôturer', 'brand',       'utility:check'));

        } else if (rt == RT_REQUETE) {

            String typeReq      = null;
            String categorieReq = null;
            try {
                Object t = record.get('TypeRequete__c');
                Object c = record.get('CategorieRequete__c');
                typeReq      = (t != null) ? String.valueOf(t) : null;
                categorieReq = (c != null) ? String.valueOf(c) : null;
            } catch (Exception e) {
                typeReq      = null;
                categorieReq = null;
            }

            if (typeReq == 'Réaffecter la déclaration'
                && categorieReq == 'Réaffectation') {
                actions.add(action('validateReassign', 'Valider la réaffectation', 'brand',       'utility:check'));
                actions.add(action('rejectReassign',   'Rejeter la réaffectation', 'destructive', 'utility:close'));
            } else {
                actions.add(action('close',    'Clôturer',          'brand',   'utility:check'));
                actions.add(action('reassign', 'Réaffecter',        'neutral', 'utility:refresh'));
                actions.add(action('takeOver', 'Prendre en charge', 'success', 'utility:user'));
            }
        }
        return actions;
    }

    @AuraEnabled
    public static void closeCase(Id recordId) {
        if (recordId == null) throw new AuraHandledException('recordId est requis.');
        try { update new Case(Id = recordId, Status = 'Clôturé'); }
        catch (Exception e) { throw new AuraHandledException('Erreur clôture : ' + e.getMessage()); }
    }

    @AuraEnabled
    public static void cancelCase(Id recordId) {
        if (recordId == null) throw new AuraHandledException('recordId est requis.');
        try { update new Case(Id = recordId, Status = 'Annulé'); }
        catch (Exception e) { throw new AuraHandledException('Erreur annulation : ' + e.getMessage()); }
    }

    @AuraEnabled
    public static void takeOverCase(Id recordId) {
        if (recordId == null) throw new AuraHandledException('recordId est requis.');
        try { update new Case(Id = recordId, OwnerId = UserInfo.getUserId(), Status = 'En cours'); }
        catch (Exception e) { throw new AuraHandledException('Erreur prise en charge : ' + e.getMessage()); }
    }

    private static FieldItem textItem(String path, String label, String value) {
        FieldItem fi = new FieldItem();
        fi.fieldPath    = path;   fi.label        = label;
        fi.fieldType    = 'STRING'; fi.isLookup   = false;
        fi.isDateTime   = false;  fi.displayValue = String.isBlank(value) ? null : value;
        return fi;
    }

    private static FieldItem lookupItem(String path, String label, Id lookupId, String displayValue) {
        FieldItem fi = new FieldItem();
        fi.fieldPath    = path;   fi.label    = label;
        fi.fieldType    = 'REFERENCE'; fi.isLookup = true; fi.isDateTime = false;
        fi.lookupId     = (lookupId != null) ? String.valueOf(lookupId) : null;
        fi.displayValue = String.isBlank(displayValue)
                          ? (lookupId != null ? String.valueOf(lookupId) : null) : displayValue;
        return fi;
    }

    private static FieldItem dateTimeItem(String path, String label, Object rawValue) {
        FieldItem fi = new FieldItem();
        fi.fieldPath  = path; fi.label      = label;
        fi.fieldType  = 'DATETIME'; fi.isLookup = false; fi.isDateTime = true;
        fi.displayValue = parseDateToIso(rawValue);
        return fi;
    }

    private static ActionItem action(String name, String label, String variant, String iconName) {
        ActionItem a = new ActionItem();
        a.name = name; a.label = label; a.variant = variant; a.iconName = iconName;
        return a;
    }

    private static String parseDateToIso(Object rawObj) {
        if (rawObj == null) return null;
        if (rawObj instanceof DateTime)
            return ((DateTime) rawObj).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        if (rawObj instanceof Date) {
            Date d = (Date) rawObj;
            return DateTime.newInstanceGmt(d.year(), d.month(), d.day(), 0, 0, 0)
                           .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        }
        try {
            return DateTime.valueOf(String.valueOf(rawObj))
                           .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        } catch (Exception e) { return String.valueOf(rawObj); }
    }
}