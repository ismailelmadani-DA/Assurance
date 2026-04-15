/**
 * @description       : Contrôleur Apex de vues liste dynamiques basées sur le custom metadata ListView_Settings__mdt : construction SOQL dynamique avec pagination, recherche, tri, filtrage par propriétaire et visibilité par profil utilisateur
 * @author            : D&A Technologies
 * @group             : Controllers
 * @last modified on  : 02-07-2026
 * @last modified by  : D&A Technologies
 **/
public with sharing class DA_ListViewController {
    public static Map<String, List<ListView_Settings__mdt>> lvSettingsMap = new Map<String, List<ListView_Settings__mdt>>();
    
    // Constants for pagination
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE = 200;
    private static final Integer SALESFORCE_OFFSET_LIMIT = 2000;
    
    /**
     * @description      :   Récupère et met en cache la configuration des vues liste depuis le custom metadata
     * @method Name      :   getListViewSettingsMap
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @return           :   List<ListView_Settings__mdt>>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=true)
    public static Map<String, List<ListView_Settings__mdt>> getListViewSettingsMap() {
        if(!lvSettingsMap.isEmpty()){
            return lvSettingsMap;
        }
        
        for(ListView_Settings__mdt lv_Setting : [SELECT Id, DeveloperName, MasterLabel, sobjectName__c, listViewName__c, developerName__c, showMes__c,
                                               toDisplay__c, FieldsToShow__c, ObjectAPIName__c, labelOfFields__c, logo__c, whereClause__c,
                                               showOwnerFilter__c, visibleToProfiles__c, Ordre__c
                                               FROM ListView_Settings__mdt
                                               WHERE toDisplay__c = true
                                               ORDER BY Ordre__c ASC, sobjectName__c, listViewName__c])
        {
            if(!lvSettingsMap.containsKey(lv_Setting.sobjectName__c)){
                lvSettingsMap.put(lv_Setting.sobjectName__c, new List<ListView_Settings__mdt>());
            }
            lvSettingsMap.get(lv_Setting.sobjectName__c).add(lv_Setting);
        }
        return lvSettingsMap;
    }
    
    /**
     * @description      :   Retourne les objets disponibles pour l'utilisateur selon la visibilité de son profil
     * @method Name      :   getAvailableSObjects
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @return           :   List<ListView_Settings__mdt>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=true)
    public static List<ListView_Settings__mdt> getAvailableSObjects() {
        List<ListView_Settings__mdt> lvSettings = new List<ListView_Settings__mdt>();
        Map<String, List<ListView_Settings__mdt>> settingsMap = getListViewSettingsMap();
        
        String currentUserProfileId = DA_Utility.getCurrentUserInfo().Id;
        String currentUserProfileName = DA_Utility.getCurrentUserInfo().Profile.Name;
        
        for(String sObjectName : settingsMap.keySet()) {
            Boolean hasVisibleListView = false;
            
            for(ListView_Settings__mdt setting : settingsMap.get(sObjectName)) {
                if(isListViewVisibleToProfile(setting, currentUserProfileId, currentUserProfileName)) {
                    hasVisibleListView = true;
                    lvSettings.add(setting);
                }
            }
            
            if(!hasVisibleListView) {
                for(ListView_Settings__mdt setting : settingsMap.get(sObjectName)) {
                    if(setting.showMes__c == true) {
                        ListView_Settings__mdt myRecordsSetting = setting.clone();
                        myRecordsSetting.showOwnerFilter__c = true;
                        lvSettings.add(myRecordsSetting);
                        break;
                    }
                }
            }
        }
        
        return lvSettings;
    }
    
    /**
     * @description      :   Retourne les vues liste disponibles pour un objet selon le profil utilisateur
     * @method Name      :   getListViewsForSObject
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @return           :   List<ListView_Settings__mdt>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=true)
    public static List<ListView_Settings__mdt> getListViewsForSObject(String sObjectName) {
        List<ListView_Settings__mdt> allListViews = getListViewSettingsMap().get(sObjectName);
        List<ListView_Settings__mdt> result = new List<ListView_Settings__mdt>();
        
        if (allListViews != null) {
            String currentUserProfileId = DA_Utility.getCurrentUserInfo().Id;
            String currentUserProfileName = DA_Utility.getCurrentUserInfo().Profile.Name;
            
            for (ListView_Settings__mdt setting : allListViews) {
                if (isListViewVisibleToProfile(setting, currentUserProfileId, currentUserProfileName)) {
                    result.add(setting);
                }
            }
            
            String objectApiName = mapFrenchToEnglishObject(sObjectName);
            Boolean hasOwnerIdField = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().containsKey('OwnerId');
            
            Boolean showMesEnabled = false;
            for (ListView_Settings__mdt setting : allListViews) {
                if (setting.showMes__c == true) {
                    showMesEnabled = true;
                    break;
                }
            }
            
            if (result.isEmpty() && !allListViews.isEmpty() && hasOwnerIdField && showMesEnabled) {
                createMyRecordsViews(result, sObjectName);
            } else if (hasOwnerIdField && showMesEnabled) {
                createMyRecordsViews(result, sObjectName);
            }
        } else {
            result = new List<ListView_Settings__mdt>();
        }
        
        return result;
    }
    
    /**
     * @description      :   Vérifie si une vue liste est visible pour le profil utilisateur spécifié
     * @method Name      :   isListViewVisibleToProfile
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   setting => setting (ListView_Settings__mdt)
     * @param            :   profileId => profileId (String)
     * @param            :   profileName => profileName (String)
     * @return           :   Boolean
     * -------------------------------------------------------------------------------------------------
     **/
    private static Boolean isListViewVisibleToProfile(ListView_Settings__mdt setting, String profileId, String profileName) {
        if (String.isBlank(setting.visibleToProfiles__c)) {
            return true;
        }
        
        Set<String> excludedProfiles = new Set<String>();
        for (String profile : setting.visibleToProfiles__c.split(';')) {
            excludedProfiles.add(profile.trim().toLowerCase());
        }
        
        Boolean isExcluded = excludedProfiles.contains(profileId.toLowerCase()) ||
            excludedProfiles.contains(profileName.toLowerCase());
        
        return !isExcluded;
    }
    
    /**
     * @description      :   Crée une vue Mes enregistrements filtrée par propriétaire si elle n'existe pas
     * @method Name      :   createMyRecordsViews
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   existingViews => existingViews (List<ListView_Settings__mdt>)
     * @param            :   sObjectName => sObjectName (String)
     * @return           :   void
     * -------------------------------------------------------------------------------------------------
     **/
    private static void createMyRecordsViews(List<ListView_Settings__mdt> existingViews, String sObjectName) {
        Boolean hasMyRecordsView = false;
        for(ListView_Settings__mdt view : existingViews) {
            if((view.listViewName__c != null && view.listViewName__c.startsWith('Mes ')) ||
            (view.showOwnerFilter__c != null && view.showOwnerFilter__c == true)) {
                hasMyRecordsView = true;
                break;
            }
        }
        
        if(hasMyRecordsView) {
            return;
        }
        
        List<ListView_Settings__mdt> allViews = getListViewSettingsMap().get(sObjectName);
        Boolean showMesEnabled = false;
        ListView_Settings__mdt baseViewForMes = null;
        
        if (allViews != null) {
            for (ListView_Settings__mdt setting : allViews) {
                if (setting.showMes__c == true) {
                    showMesEnabled = true;
                    baseViewForMes = setting;
                    break;
                }
            }
        }
        
        if (!showMesEnabled) {
            return;
        }
        
        if(!existingViews.isEmpty()) {
            ListView_Settings__mdt baseView = existingViews[0];
            ListView_Settings__mdt myRecordsView = baseView.clone();
            myRecordsView.listViewName__c = 'Mes ' + PluralValue(sObjectName);
            myRecordsView.showOwnerFilter__c = true;
            existingViews.add(myRecordsView);
        } else if (baseViewForMes != null) {
            ListView_Settings__mdt myRecordsView = baseViewForMes.clone();
            myRecordsView.listViewName__c = 'Mes ' + PluralValue(sObjectName);
            myRecordsView.showOwnerFilter__c = true;
            existingViews.add(myRecordsView);
        }
    }
    
    /**
     * @description      :   Récupère les champs, métadonnées et informations de lookup pour une vue liste
     * @method Name      :   getFieldsForListView
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @param            :   listViewName => listViewName (String)
     * @return           :   Object>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFieldsForListView(String sObjectName, String listViewName) {
        List<ListView_Settings__mdt> listViewSettings = findListViewSettings(sObjectName, listViewName);
        
        List<String> fieldsList = new List<String>{'Id'};
        Map<String, String> customLabelsMap = new Map<String, String>();
        
        if (!listViewSettings.isEmpty() && String.isNotBlank(listViewSettings[0].FieldsToShow__c)) {
            fieldsList.addAll(listViewSettings[0].FieldsToShow__c.split(';'));
        } else {
            fieldsList.addAll(getDefaultFields(sObjectName));
        }
        
        String objectApiName = mapFrenchToEnglishObject(sObjectName);
        Boolean hasOwnerIdField = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().containsKey('OwnerId');
        
        if(!fieldsList.contains('OwnerId') && hasOwnerIdField) {
            fieldsList.add('OwnerId');
        }
        
        if (!listViewSettings.isEmpty() && String.isNotBlank(listViewSettings[0].labelOfFields__c)) {
            for (String labelMapping : listViewSettings[0].labelOfFields__c.split(';')) {
                List<String> parts = labelMapping.split(':');
                if (parts.size() == 2) {
                    customLabelsMap.put(parts[0].trim(), parts[1].trim());
                }
            }
        }
        
        Map<String, Object> fieldInfo = getFieldMetadataWithRelationships(objectApiName, fieldsList, customLabelsMap);
        
        Map<String, Map<String, Object>> fieldsMetadata = (Map<String, Map<String, Object>>)fieldInfo.get('fieldsMetadata');
        Map<String, Map<String, Object>> lookupInfo = (Map<String, Map<String, Object>>)fieldInfo.get('lookupInfo');
        List<String> lookupsList = (List<String>)fieldInfo.get('lookupFields');
        
        String logo = !listViewSettings.isEmpty() && String.isNotBlank(listViewSettings[0].logo__c)
            ? listViewSettings[0].logo__c
            : getDefaultLogo(sObjectName);
        
        Boolean isMyRecordsView = false;
        if (hasOwnerIdField) {
            if (!listViewSettings.isEmpty() && listViewSettings[0].showOwnerFilter__c != null) {
                isMyRecordsView = listViewSettings[0].showOwnerFilter__c;
            } else if (listViewName != null && listViewName.startsWith('Mes ')) {
                isMyRecordsView = true;
            }
        }
        
        return new Map<String, Object>{
            'fields' => fieldsList,
            'lookups' => lookupsList,
            'metadata' => fieldsMetadata,
            'lookupInfo' => lookupInfo,
            'customLabels' => customLabelsMap,
            'logo' => logo,
            'isMyRecordsView' => isMyRecordsView
        };
    }
    
    /**
     * @description      :   Retourne l'icône Lightning par défaut pour un type d'objet donné
     * @method Name      :   getDefaultLogo
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @return           :   String
     * -------------------------------------------------------------------------------------------------
     **/
    private static String getDefaultLogo(String sObjectName) {
        Map<String, String> logoMap = new Map<String, String>{
            'Compte' => 'standard:account',
            'Police d\'assurance' => 'standard:contract',
            'Sinistre' => 'standard:case',
            'Mission' => 'standard:task'
        };
        
        return logoMap.containsKey(sObjectName) ? logoMap.get(sObjectName) : 'standard:custom';
    }
    
    /**
     * @description      :   Récupère les métadonnées des champs incluant les relations, picklists et formules
     * @method Name      :   getFieldMetadataWithRelationships
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   objectApiName => objectApiName (String)
     * @param            :   fieldsList => fieldsList (List<String>)
     * @param            :   customLabelsMap => customLabelsMap (String>)
     * @return           :   Object>
     * -------------------------------------------------------------------------------------------------
     **/
    private static Map<String, Object> getFieldMetadataWithRelationships(String objectApiName, List<String> fieldsList, Map<String, String> customLabelsMap) {
        Map<String, Map<String, Object>> fieldsMetadata = new Map<String, Map<String, Object>>();
        Map<String, Map<String, String>> lookupInfo = new Map<String, Map<String, String>>();
        List<String> lookupFields = new List<String>();
        
        try {
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (String fieldName : fieldsList) {
                if (fieldName == 'Id') continue;
                
                if (fieldName.contains('.')) {
                    handleRelationshipField(fieldName, fieldsMetadata, lookupInfo, objectApiName, customLabelsMap);
                    continue;
                }
                
                if (!fieldMap.containsKey(fieldName)) continue;
                
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                String customLabel = customLabelsMap.containsKey(fieldName) ? customLabelsMap.get(fieldName) : null;
                
                Map<String, Object> fieldInfo = new Map<String, Object>{
                    'label' => customLabel != null ? customLabel : fieldDescribe.getLabel(),
                    'type' => String.valueOf(fieldDescribe.getType()),
                    'isReference' => fieldDescribe.getType() == Schema.DisplayType.REFERENCE
                };
                
                if (fieldDescribe.isCalculated()) {
                    fieldInfo.put('formula', true);
                    if (fieldDescribe.getType() == Schema.DisplayType.STRING && fieldDescribe.isHtmlFormatted()) {
                        fieldInfo.put('formulaType', 'HTML');
                    } else if (fieldDescribe.getType() == Schema.DisplayType.STRING) {
                        fieldInfo.put('formulaType', 'TEXT');
                    } else {
                        fieldInfo.put('formulaType', String.valueOf(fieldDescribe.getType()));
                    }
                }
                
                if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
                    List<Schema.SObjectType> referencedObjects = fieldDescribe.getReferenceTo();
                    if (!referencedObjects.isEmpty()) {
                        Schema.DescribeSObjectResult referencedObjectDescribe = referencedObjects[0].getDescribe();
                        String referencedObjectName = referencedObjectDescribe.getName();
                        
                        fieldInfo.put('referencedObject', referencedObjectName);
                        
                        Map<String, String> relationshipInfo = getObjectRelationshipFields(referencedObjectDescribe);
                        lookupInfo.put(fieldName, relationshipInfo);
                        
                        fieldInfo.put('nameField', relationshipInfo.get('nameField'));
                        fieldInfo.put('titleField', relationshipInfo.get('titleField'));
                        fieldInfo.put('relationshipName', fieldDescribe.getRelationshipName());
                        
                        lookupFields.add(fieldName);
                    }
                }
                
                if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST) {
                    fieldInfo.put('picklistValues', getPicklistValues(fieldDescribe));
                }
                
                if (fieldDescribe.getType() == Schema.DisplayType.MULTIPICKLIST) {
                    fieldInfo.put('picklistValues', getPicklistValues(fieldDescribe));
                }
                
                if (fieldDescribe.getType() == Schema.DisplayType.TEXTAREA) {
                    fieldInfo.put('isRichText', fieldDescribe.isHtmlFormatted());
                }
                
                fieldsMetadata.put(fieldName, fieldInfo);
            }
        } catch (Exception e) {
            System.debug('Error getting field metadata: ' + e.getMessage());
        }
        
        return new Map<String, Object>{
            'fieldsMetadata' => fieldsMetadata,
            'lookupInfo' => lookupInfo,
            'lookupFields' => lookupFields
        };
    }
    
    /**
     * @description      :   Récupère les valeurs actives d'un champ picklist
     * @method Name      :   getPicklistValues
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   fieldDescribe => fieldDescribe (Schema.DescribeFieldResult)
     * @return           :   String>>
     * -------------------------------------------------------------------------------------------------
     **/
    private static List<Map<String, String>> getPicklistValues(Schema.DescribeFieldResult fieldDescribe) {
        List<Map<String, String>> picklistValuesList = new List<Map<String, String>>();
        
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                picklistValuesList.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        
        return picklistValuesList;
    }
    
    /**
     * @description      :   Traite un champ relationnel en résolvant les métadonnées à travers les niveaux de relation
     * @method Name      :   handleRelationshipField
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   fieldPath => fieldPath (String)
     * @param            :   fieldsMetadata => fieldsMetadata (Object>>)
     * @param            :   lookupInfo => lookupInfo (String>>)
     * @param            :   objectApiName => objectApiName (String)
     * @param            :   customLabelsMap => customLabelsMap (String>)
     * @return           :   void
     * -------------------------------------------------------------------------------------------------
     **/
    private static void handleRelationshipField(String fieldPath, Map<String, Map<String, Object>> fieldsMetadata,
    Map<String, Map<String, String>> lookupInfo, String objectApiName,
    Map<String, String> customLabelsMap) {
        
        List<String> pathParts = fieldPath.split('\\.');
        if (pathParts.size() < 2 || pathParts.size() > 3) return;
        
        try {
            Schema.DescribeSObjectResult currentObjectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            
            String currentRelationshipName = pathParts[0];
            String finalFieldName = pathParts[pathParts.size() - 1];
            
            String firstRelationshipFieldApiName = '';
            Schema.DescribeSObjectResult firstReferencedObjectDescribe = null;
            
            for (Schema.SObjectField field : currentObjectDescribe.fields.getMap().values()) {
                Schema.DescribeFieldResult describeResult = field.getDescribe();
                if (describeResult.getRelationshipName() == currentRelationshipName) {
                    firstRelationshipFieldApiName = describeResult.getName();
                    List<Schema.SObjectType> referencedObjects = describeResult.getReferenceTo();
                    if (!referencedObjects.isEmpty()) {
                        firstReferencedObjectDescribe = referencedObjects[0].getDescribe();
                    }
                    break;
                }
            }
            
            if (String.isBlank(firstRelationshipFieldApiName) || firstReferencedObjectDescribe == null) return;
            
            String firstReferencedObjectName = firstReferencedObjectDescribe.getName();
            Schema.DescribeSObjectResult finalObjectDescribe = firstReferencedObjectDescribe;
            String finalObjectName = firstReferencedObjectName;
            
            if (pathParts.size() == 3) {
                String secondRelationshipName = pathParts[1];
                
                for (Schema.SObjectField field : firstReferencedObjectDescribe.fields.getMap().values()) {
                    Schema.DescribeFieldResult describeResult = field.getDescribe();
                    if (describeResult.getRelationshipName() == secondRelationshipName) {
                        List<Schema.SObjectType> referencedObjects = describeResult.getReferenceTo();
                        if (!referencedObjects.isEmpty()) {
                            finalObjectDescribe = referencedObjects[0].getDescribe();
                            finalObjectName = finalObjectDescribe.getName();
                        }
                        break;
                    }
                }
            }
            
            if (!finalObjectDescribe.fields.getMap().containsKey(finalFieldName)) return;
            
            Schema.DescribeFieldResult finalFieldDescribe = finalObjectDescribe.fields.getMap().get(finalFieldName).getDescribe();
            String customLabel = customLabelsMap.containsKey(fieldPath) ? customLabelsMap.get(fieldPath) : null;
            
            Map<String, Object> fieldInfo = new Map<String, Object>{
                'label' => customLabel != null ? customLabel : finalFieldDescribe.getLabel(),
                'type' => String.valueOf(finalFieldDescribe.getType()),
                'isReference' => false,
                'isRelationshipField' => true,
                'relationshipPath' => fieldPath,
                'finalFieldName' => finalFieldName,
                'finalObject' => finalObjectName,
                'relationshipDepth' => pathParts.size() - 1
            };
            
            if (pathParts.size() == 3) {
                fieldInfo.put('firstRelationshipName', pathParts[0]);
                fieldInfo.put('secondRelationshipName', pathParts[1]);
                fieldInfo.put('firstReferencedObject', firstReferencedObjectName);
                fieldInfo.put('secondReferencedObject', finalObjectName);
            } else {
                fieldInfo.put('relationshipName', pathParts[0]);
                fieldInfo.put('referencedObject', finalObjectName);
            }
            
            fieldsMetadata.put(fieldPath, fieldInfo);
            
            if (!lookupInfo.containsKey(firstRelationshipFieldApiName)) {
                Map<String, String> relationshipInfo = getObjectRelationshipFields(firstReferencedObjectDescribe);
                lookupInfo.put(firstRelationshipFieldApiName, relationshipInfo);
            }
            
        } catch (Exception e) {
            System.debug('Error handling relationship field: ' + e.getMessage());
        }
    }
    
    /**
     * @description      :   Récupère les champs nom et titre d'un objet référencé pour l'affichage des lookups
     * @method Name      :   getObjectRelationshipFields
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   objectDescribe => objectDescribe (Schema.DescribeSObjectResult)
     * @return           :   String>
     * -------------------------------------------------------------------------------------------------
     **/
    private static Map<String, String> getObjectRelationshipFields(Schema.DescribeSObjectResult objectDescribe) {
        Map<String, String> relationshipInfo = new Map<String, String>();
        String objectName = objectDescribe.getName();
        
        String nameField = getNameFieldForObject(objectName);
        relationshipInfo.put('nameField', nameField);
        
        String titleField = getTitleFieldForObject(objectName, objectDescribe);
        relationshipInfo.put('titleField', titleField);
        
        relationshipInfo.put('objectApiName', objectName);
        
        return relationshipInfo;
    }
    
    /**
     * @description      :   Retourne le champ nom principal d'un objet (Name, CaseNumber, etc.)
     * @method Name      :   getNameFieldForObject
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   objectName => objectName (String)
     * @return           :   String
     * -------------------------------------------------------------------------------------------------
     **/
    private static String getNameFieldForObject(String objectName) {
        Map<String, String> objectNameFields = new Map<String, String>{
            'Case' => 'CaseNumber',
            'Solution' => 'SolutionNumber',
            'Contract' => 'ContractNumber',
            'User' => 'Username',
            'KnowledgeArticle' => 'ArticleNumber',
            'Idea' => 'Title',
            'ContentDocument' => 'Title'
        };
        
        return objectNameFields.containsKey(objectName) ? objectNameFields.get(objectName) : 'Name';
    }
    
    /**
     * @description      :   Retourne le champ titre le plus pertinent pour l'affichage d'un objet
     * @method Name      :   getTitleFieldForObject
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   objectName => objectName (String)
     * @param            :   objectDescribe => objectDescribe (Schema.DescribeSObjectResult)
     * @return           :   String
     * -------------------------------------------------------------------------------------------------
     **/
    private static String getTitleFieldForObject(String objectName, Schema.DescribeSObjectResult objectDescribe) {
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        
        if (objectName == 'User' && fieldMap.containsKey('Name')) {
            return 'Name';
        }
        
        List<String> titleFieldCandidates = new List<String>{'Name', 'Title', 'Subject', 'Description', 'Label', 'FirstName', 'LastName'};
        
        for (String candidate : titleFieldCandidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        
        return getNameFieldForObject(objectName);
    }
    
    /**
     * @description      :   Recherche la configuration d'une vue liste par nom exact, DeveloperName ou correspondance partielle
     * @method Name      :   findListViewSettings
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @param            :   listViewName => listViewName (String)
     * @return           :   List<ListView_Settings__mdt>
     * -------------------------------------------------------------------------------------------------
     **/
    private static List<ListView_Settings__mdt> findListViewSettings(String sObjectName, String listViewName) {
        List<ListView_Settings__mdt> listViewSettings = new List<ListView_Settings__mdt>();
        List<ListView_Settings__mdt> allSettings = getListViewsForSObject(sObjectName);
        
        if (allSettings == null || allSettings.isEmpty()) {
            return listViewSettings;
        }
        
        for(ListView_Settings__mdt lv : allSettings) {
            if(lv.listViewName__c == listViewName) {
                listViewSettings.add(lv);
                return listViewSettings;
            }
        }
        
        for(ListView_Settings__mdt lv : allSettings) {
            if(lv.listViewName__c != null && listViewName != null &&
            lv.listViewName__c.equalsIgnoreCase(listViewName)) {
                listViewSettings.add(lv);
                return listViewSettings;
            }
        }
        
        for(ListView_Settings__mdt lv : allSettings) {
            if(lv.developerName__c == listViewName) {
                listViewSettings.add(lv);
                return listViewSettings;
            }
        }
        
        for(ListView_Settings__mdt lv : allSettings) {
            if(lv.listViewName__c != null && listViewName != null &&
            (lv.listViewName__c.contains(listViewName) || listViewName.contains(lv.listViewName__c))) {
                listViewSettings.add(lv);
                return listViewSettings;
            }
        }
        
        if(listViewName != null && listViewName.startsWith('Mes ')) {
            for(ListView_Settings__mdt lv : allSettings) {
                ListView_Settings__mdt modifiedSettings = lv.clone();
                modifiedSettings.showOwnerFilter__c = true;
                modifiedSettings.listViewName__c = listViewName;
                listViewSettings.add(modifiedSettings);
                return listViewSettings;
            }
        }
        
        return listViewSettings;
    }
    
    /**
     * @description      :   Retourne les champs par défaut à afficher pour un type d'objet donné
     * @method Name      :   getDefaultFields
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @return           :   List<String>
     * -------------------------------------------------------------------------------------------------
     **/
    private static List<String> getDefaultFields(String sObjectName) {
        String objectApiName = mapFrenchToEnglishObject(sObjectName);
        Boolean hasOwnerIdField = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().containsKey('OwnerId');
        
        if (sObjectName == 'Compte') {
            List<String> fields = new List<String>{'Name', 'Phone', 'Type', 'BillingCity'};
            if (hasOwnerIdField) fields.add('OwnerId');
            return fields;
        } else if (sObjectName == 'Police d\'assurance') {
            List<String> fields = new List<String>{'Name', 'EffectiveDate', 'ExpirationDate', 'Status'};
            if (hasOwnerIdField) fields.add('OwnerId');
            return fields;
        } else if (sObjectName == 'Sinistre') {
            List<String> fields = new List<String>{'ClaimNumber__c', 'GestionUnit__c', 'DateCreationDec__c', 'DateSurvenance__c'};
            if (hasOwnerIdField) fields.add('OwnerId');
            return fields;
        } else if (sObjectName == 'Mission') {
            List<String> fields = new List<String>{'NumeroDeLaMission__c', 'TypePrestataire__c', 'TypeMission__c', 'Prestataire__c'};
            if (hasOwnerIdField) fields.add('OwnerId');
            return fields;
        } else if (sObjectName == 'Offre__c') {
            return new List<String>{'Name', 'CreatedDate'};
        } else {
            List<String> fields = new List<String>{'Name'};
            if (hasOwnerIdField) fields.add('OwnerId');
            return fields;
        }
    }
    
    // =====================================================
    // BIDIRECTIONAL PAGINATION - MAIN METHOD
    // =====================================================
    
    /**
     * @description      :   Récupère les enregistrements paginés avec stratégie adaptative (offset, reverse, keyset)
     * @method Name      :   getRecordsForListViewPaginated
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @param            :   listViewName => listViewName (String)
     * @param            :   fields => fields (List<String>)
     * @param            :   pageSize => pageSize (Integer)
     * @param            :   pageNumber => pageNumber (Integer)
     * @return           :   Object>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getRecordsForListViewPaginated(
        String sObjectName,
    String listViewName,
    List<String> fields,
    Integer pageSize,
    Integer pageNumber
    ) {
        try {
            // Validate pagination parameters
            if (pageSize == null || pageSize <= 0) pageSize = DEFAULT_PAGE_SIZE;
            if (pageSize > MAX_PAGE_SIZE) pageSize = MAX_PAGE_SIZE;
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            
            String objectApiName = mapFrenchToEnglishObject(sObjectName);
            
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                throw new AuraHandledException('Object ' + objectApiName + ' does not exist or is not accessible');
            }
            
            // Validate fields
            List<String> validatedFields = validateAndGetFields(objectApiName, fields);
            
            // Get field configurations
            Map<String, Object> fieldsResult = getFieldsForListView(sObjectName, listViewName);
            Map<String, Map<String, String>> lookupInfo = (Map<String, Map<String, String>>)fieldsResult.get('lookupInfo');
            Map<String, Map<String, Object>> fieldsMetadata = (Map<String, Map<String, Object>>)fieldsResult.get('metadata');
            Boolean isMyRecordsView = (Boolean)fieldsResult.get('isMyRecordsView');
            
            // Get total count
            String countQuery = buildCountQuery(objectApiName, listViewName, sObjectName, isMyRecordsView);
            Integer totalRecords = Database.countQuery(countQuery);
            
            // Calculate pagination info
            Integer totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);
            if (totalPages == 0) totalPages = 1;
            
            // Validate page number
            if (pageNumber > totalPages) {
                pageNumber = totalPages;
            }
            
            // Calculate offset from start
            Integer offsetFromStart = (pageNumber - 1) * pageSize;
            
            // Calculate offset from end (how many records after the page we want)
            Integer offsetFromEnd = totalRecords - offsetFromStart - pageSize;
            if (offsetFromEnd < 0) offsetFromEnd = 0;
            
            List<SObject> records;
            
            System.debug('Total records: ' + totalRecords);
            System.debug('Page: ' + pageNumber + ', Offset from start: ' + offsetFromStart + ', Offset from end: ' + offsetFromEnd);
            
            // Choose the best pagination strategy
            if (offsetFromStart <= SALESFORCE_OFFSET_LIMIT) {
                // Strategy 1: Standard OFFSET from start (fast)
                System.debug('Using standard OFFSET pagination');
                records = getRecordsWithOffset(
                    objectApiName, validatedFields, fieldsMetadata, lookupInfo,
                listViewName, sObjectName, isMyRecordsView, pageSize, offsetFromStart, 'DESC'
                    );
            } else if (offsetFromEnd <= SALESFORCE_OFFSET_LIMIT) {
                // Strategy 2: REVERSE query from end (also fast)
                System.debug('Using REVERSE pagination from end');
                records = getRecordsFromEnd(
                    objectApiName, validatedFields, fieldsMetadata, lookupInfo,
                listViewName, sObjectName, isMyRecordsView, pageSize, offsetFromEnd, totalRecords, offsetFromStart
                    );
            } else {
                // Strategy 3: Keyset pagination for middle pages (handles any position)
                System.debug('Using KEYSET pagination for middle pages');
                records = getRecordsWithKeyset(
                    objectApiName, validatedFields, fieldsMetadata, lookupInfo,
                listViewName, sObjectName, isMyRecordsView, pageSize, offsetFromStart
                    );
            }
            
            return new Map<String, Object>{
                'records' => records,
                'totalRecords' => totalRecords,
                'totalPages' => totalPages,
                'currentPage' => pageNumber,
                'pageSize' => pageSize,
                'hasNextPage' => pageNumber < totalPages,
                'hasPreviousPage' => pageNumber > 1
            };
            
        } catch (Exception e) {
            System.debug('Error in getRecordsForListViewPaginated: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error querying data: ' + e.getMessage());
        }
    }
    
    /**
     * Strategy 1: Get records using standard OFFSET (for first ~40 pages)
     */
    private static List<SObject> getRecordsWithOffset(
        String objectApiName,
    List<String> validatedFields,
    Map<String, Map<String, Object>> fieldsMetadata,
    Map<String, Map<String, String>> lookupInfo,
    String listViewName,
    String sObjectName,
    Boolean isMyRecordsView,
    Integer pageSize,
    Integer offset,
    String sortDirection
    ) {
        String selectClause = buildSelectClause(objectApiName, validatedFields, fieldsMetadata, lookupInfo);
        String whereClause = buildWhereClause(objectApiName, listViewName, sObjectName, isMyRecordsView);
        String orderByField = getOrderByField(objectApiName);
        
        String query = selectClause + ' FROM ' + objectApiName;
        
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        
        query += ' ORDER BY ' + orderByField + ' ' + sortDirection + ', Id ' + sortDirection;
        query += ' LIMIT ' + pageSize;
        
        if (offset > 0) {
            query += ' OFFSET ' + offset;
        }
        
        System.debug('OFFSET Query: ' + query);
        return Database.query(query);
    }
    
    /**
     * Strategy 2: Get records from the END using reverse sort (for last ~40 pages)
     */
    private static List<SObject> getRecordsFromEnd(
        String objectApiName,
    List<String> validatedFields,
    Map<String, Map<String, Object>> fieldsMetadata,
    Map<String, Map<String, String>> lookupInfo,
    String listViewName,
    String sObjectName,
    Boolean isMyRecordsView,
    Integer pageSize,
    Integer offsetFromEnd,
    Integer totalRecords,
    Integer offsetFromStart
    ) {
        String selectClause = buildSelectClause(objectApiName, validatedFields, fieldsMetadata, lookupInfo);
        String whereClause = buildWhereClause(objectApiName, listViewName, sObjectName, isMyRecordsView);
        String orderByField = getOrderByField(objectApiName);
        
        // Calculate how many records to fetch
        // For the last page, there might be fewer records than pageSize
        Integer recordsOnThisPage = Math.min(pageSize, totalRecords - offsetFromStart);
        
        String query = selectClause + ' FROM ' + objectApiName;
        
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        
        // Query in ASC order (reverse of normal DESC)
        query += ' ORDER BY ' + orderByField + ' ASC, Id ASC';
        query += ' LIMIT ' + recordsOnThisPage;
        
        if (offsetFromEnd > 0) {
            query += ' OFFSET ' + offsetFromEnd;
        }
        
        System.debug('REVERSE Query: ' + query);
        List<SObject> results = Database.query(query);
        
        // Reverse the results to maintain DESC order
        List<SObject> reversed = new List<SObject>();
        for (Integer i = results.size() - 1; i >= 0; i--) {
            reversed.add(results[i]);
        }
        
        return reversed;
    }
    
    /**
     * Strategy 3: Keyset pagination for middle pages (when both offsets > 2000)
     * This is optimized to minimize query row consumption
     */
    private static List<SObject> getRecordsWithKeyset(
        String objectApiName,
    List<String> validatedFields,
    Map<String, Map<String, Object>> fieldsMetadata,
    Map<String, Map<String, String>> lookupInfo,
    String listViewName,
    String sObjectName,
    Boolean isMyRecordsView,
    Integer pageSize,
    Integer targetOffset
    ) {
        String baseWhereClause = buildWhereClause(objectApiName, listViewName, sObjectName, isMyRecordsView);
        String orderByField = getOrderByField(objectApiName);
        
        // Navigate to the target position using keyset pagination
        Id lastId = null;
        Object lastOrderValue = null;
        Integer currentPosition = 0;
        Integer maxIterations = 50; // Safety limit
        Integer iterations = 0;
        
        while (currentPosition < targetOffset && iterations < maxIterations) {
            iterations++;
            Integer remainingToSkip = targetOffset - currentPosition;
            Integer batchSize = Math.min(SALESFORCE_OFFSET_LIMIT, remainingToSkip);
            
            // Build query to find the record at the end of this batch
            String skipQuery = 'SELECT Id, ' + orderByField + ' FROM ' + objectApiName;
            
            List<String> whereConditions = new List<String>();
            if (String.isNotBlank(baseWhereClause)) {
                whereConditions.add(baseWhereClause);
            }
            
            if (lastId != null) {
                String keysetCondition = buildKeysetCondition(orderByField, lastOrderValue, lastId, 'DESC');
                whereConditions.add(keysetCondition);
            }
            
            if (!whereConditions.isEmpty()) {
                skipQuery += ' WHERE ' + String.join(whereConditions, ' AND ');
            }
            
            skipQuery += ' ORDER BY ' + orderByField + ' DESC, Id DESC';
            skipQuery += ' LIMIT 1 OFFSET ' + (batchSize - 1);
            
            System.debug('Skip query (iteration ' + iterations + '): ' + skipQuery);
            
            List<SObject> batchRecords = Database.query(skipQuery);
            
            if (batchRecords.isEmpty()) {
                System.debug('No more records to skip');
                break;
            }
            
            SObject lastRecord = batchRecords[0];
            lastId = lastRecord.Id;
            lastOrderValue = lastRecord.get(orderByField);
            
            currentPosition += batchSize;
            System.debug('Skipped to position: ' + currentPosition);
        }
        
        // Now fetch the actual page data
        String selectClause = buildSelectClause(objectApiName, validatedFields, fieldsMetadata, lookupInfo);
        String finalQuery = selectClause + ' FROM ' + objectApiName;
        
        List<String> finalWhereConditions = new List<String>();
        if (String.isNotBlank(baseWhereClause)) {
            finalWhereConditions.add(baseWhereClause);
        }
        
        if (lastId != null) {
            String keysetCondition = buildKeysetCondition(orderByField, lastOrderValue, lastId, 'DESC');
            finalWhereConditions.add(keysetCondition);
        }
        
        if (!finalWhereConditions.isEmpty()) {
            finalQuery += ' WHERE ' + String.join(finalWhereConditions, ' AND ');
        }
        
        finalQuery += ' ORDER BY ' + orderByField + ' DESC, Id DESC LIMIT ' + pageSize;
        
        System.debug('Final keyset query: ' + finalQuery);
        
        return Database.query(finalQuery);
    }
    
    /**
     * Build keyset condition for pagination
     */
    private static String buildKeysetCondition(String orderByField, Object lastOrderValue, Id lastId, String direction) {
        String lessThan = (direction == 'DESC') ? '<' : '>';
        
        if (lastOrderValue == null) {
            return 'Id ' + lessThan + ' \'' + lastId + '\'';
        }
        
        String condition;
        
        if (lastOrderValue instanceof Datetime) {
            Datetime dtValue = (Datetime)lastOrderValue;
            String formattedDt = dtValue.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            condition = '((' + orderByField + ' ' + lessThan + ' ' + formattedDt + ') OR ' +
                '(' + orderByField + ' = ' + formattedDt + ' AND Id ' + lessThan + ' \'' + lastId + '\'))';
        } else if (lastOrderValue instanceof Date) {
            Date dValue = (Date)lastOrderValue;
            String formattedDate = String.valueOf(dValue);
            condition = '((' + orderByField + ' ' + lessThan + ' ' + formattedDate + ') OR ' +
                '(' + orderByField + ' = ' + formattedDate + ' AND Id ' + lessThan + ' \'' + lastId + '\'))';
        } else {
            condition = 'Id ' + lessThan + ' \'' + lastId + '\'';
        }
        
        return condition;
    }
    
    /**
     * Get the order by field for an object
     */
    private static String getOrderByField(String objectApiName) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        return fieldMap.containsKey('CreatedDate') ? 'CreatedDate' : 'Id';
    }
    
    /**
     * Build the SELECT clause
     */
    private static String buildSelectClause(
        String objectApiName,
    List<String> fields,
    Map<String, Map<String, Object>> fieldsMetadata,
    Map<String, Map<String, String>> lookupInfo
    ) {
        Set<String> selectedFields = new Set<String>{'Id'};
        
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        Boolean hasOwnerIdField = fieldMap.containsKey('OwnerId');
        
        for (String field : fields) {
            if (field == 'Id') continue;
            if (field == 'OwnerId' && !hasOwnerIdField) continue;
            
            if (field.contains('.')) {
                selectedFields.add(field);
                continue;
            }
            
            if (!fieldMap.containsKey(field)) continue;
            
            selectedFields.add(field);
            
            if (field.endsWith('Id') && field != 'Id') {
                processLookupFieldForQuery(field, selectedFields, lookupInfo);
            } else if (fieldsMetadata != null && fieldsMetadata.containsKey(field) &&
            fieldsMetadata.get(field).containsKey('isReference') &&
            (Boolean)fieldsMetadata.get(field).get('isReference')) {
                processReferenceFieldForQuery(field, selectedFields, fieldsMetadata);
            }
        }
        
        return 'SELECT ' + String.join(new List<String>(selectedFields), ', ');
    }
    
    /**
     * Validate and get fields
     */
    private static List<String> validateAndGetFields(String objectApiName, List<String> fields) {
        List<String> validatedFields = new List<String>{'Id'};
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        Boolean hasOwnerIdField = fieldMap.containsKey('OwnerId');
        
        if (fieldMap.containsKey('CreatedDate')) {
            validatedFields.add('CreatedDate');
        }
        
        for (String field : fields) {
            field = field.trim();
            
            if (field == 'Id' || field == 'CreatedDate') continue;
            
            if (field.contains('.')) {
                validatedFields.add(field);
                continue;
            }
            
            if (field == 'OwnerId' && !hasOwnerIdField) continue;
            
            if (fieldMap.containsKey(field)) {
                validatedFields.add(field);
            }
        }
        
        return validatedFields;
    }
    
    /**
     * Build count query
     */
    private static String buildCountQuery(
        String objectApiName,
    String listViewName,
    String sObjectName,
    Boolean isMyRecordsView
    ) {
        String query = 'SELECT COUNT() FROM ' + objectApiName;
        String whereClause = buildWhereClause(objectApiName, listViewName, sObjectName, isMyRecordsView);
        
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        
        return query;
    }
    
    /**
     * Build WHERE clause
     */
    private static String buildWhereClause(
        String objectApiName,
    String listViewName,
    String sObjectName,
    Boolean isMyRecordsView
    ) {
        List<String> whereConditions = new List<String>();
        List<ListView_Settings__mdt> listViewSettings = findListViewSettings(sObjectName, listViewName);
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        Boolean hasOwnerIdField = fieldMap.containsKey('OwnerId');
        
        if (!listViewSettings.isEmpty() && String.isNotBlank(listViewSettings[0].developerName__c)) {
            if (fieldMap.containsKey('RecordTypeId')) {
                whereConditions.add('RecordType.DeveloperName = \'' + String.escapeSingleQuotes(listViewSettings[0].developerName__c) + '\'');
            }
        }
        
        if (!listViewSettings.isEmpty() && Schema.SObjectType.ListView_Settings__mdt.fields.getMap().containsKey('whereClause__c')) {
            String customWhereClause = (String)listViewSettings[0].get('whereClause__c');
            if (String.isNotBlank(customWhereClause)) {
                customWhereClause = customWhereClause.replace('{CURRENT_USER_ID}', UserInfo.getUserId());
                whereConditions.add(customWhereClause);
            }
        }
        
        if (isMyRecordsView && hasOwnerIdField) {
            whereConditions.add('OwnerId = \'' + UserInfo.getUserId() + '\'');
        }
        
        return String.join(whereConditions, ' AND ');
    }
    
    /**
     * Process lookup field for query
     */
    private static void processLookupFieldForQuery(String field, Set<String> selectedFields, Map<String, Map<String, String>> lookupInfo) {
        String relationshipName = field.substring(0, field.length() - 2);
        Map<String, String> relationInfo = lookupInfo != null ? lookupInfo.get(field) : null;
        
        if (relationInfo != null) {
            String nameField = relationInfo.get('nameField');
            String titleField = relationInfo.get('titleField');
            
            selectedFields.add(relationshipName + '.' + nameField);
            if (titleField != nameField) {
                selectedFields.add(relationshipName + '.' + titleField);
            }
        } else {
            selectedFields.add(relationshipName + '.Name');
        }
    }
    
    /**
     * Process reference field for query
     */
    public static void processReferenceFieldForQuery(String field, Set<String> selectedFields, Map<String, Map<String, Object>> fieldsMetadata) {
        Map<String, Object> fieldInfo = fieldsMetadata.get(field);
        
        if (fieldInfo.containsKey('relationshipName')) {
            String relationshipName = (String)fieldInfo.get('relationshipName');
            String nameField = fieldInfo.containsKey('nameField') ? (String)fieldInfo.get('nameField') : 'Name';
            String titleField = fieldInfo.containsKey('titleField') ? (String)fieldInfo.get('titleField') : nameField;
            
            selectedFields.add(relationshipName + '.' + nameField);
            if (titleField != nameField) {
                selectedFields.add(relationshipName + '.' + titleField);
            }
        }
    }
    
    /**
     * Map French object names to API names
     */
    private static String mapFrenchToEnglishObject(String frenchName) {
        if (String.isBlank(frenchName)) {
            return '';
        }
        
        if (getListViewSettingsMap().containsKey(frenchName) && !getListViewSettingsMap().get(frenchName).isEmpty()) {
            ListView_Settings__mdt firstSetting = getListViewSettingsMap().get(frenchName)[0];
            if (String.isNotBlank(firstSetting.ObjectAPIName__c)) {
                return firstSetting.ObjectAPIName__c;
            }
        }
        
        Map<String, String> manualMappings = new Map<String, String>{
            'Offre' => 'Offre__c',
            'Offre__c' => 'Offre__c'
        };
        
        if (manualMappings.containsKey(frenchName)) {
            return manualMappings.get(frenchName);
        }
        
        return frenchName;
    }
    
    /**
     * @description      :   Retourne la forme plurielle d'un mot français selon les règles grammaticales
     * @method Name      :   PluralValue
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   phrase => phrase (String)
     * @return           :   String
     * -------------------------------------------------------------------------------------------------
     **/
    public static String PluralValue(String phrase) {
        List<String> words = phrase.split(' ');
        List<String> pluralizedWords = new List<String>();
        
        for (String word : words) {
            if (word.toLowerCase().startsWith('d\'') || word.toLowerCase().startsWith('de ')) {
                pluralizedWords.add(word);
            } else if (word.endsWith('al')) {
                pluralizedWords.add(word.substring(0, word.length() - 2) + 'aux');
            } else if (word.endsWith('eau') || word.endsWith('eu')) {
                pluralizedWords.add(word + 'x');
            } else if (word.endsWith('s') || word.endsWith('x')) {
                pluralizedWords.add(word);
            } else {
                pluralizedWords.add(word + 's');
            }
        }
        
        return String.join(pluralizedWords, ' ');
    }
    
    // Legacy method for backward compatibility
    /**
     * @description      :   Méthode legacy retournant les enregistrements sans pagination avancée
     * @method Name      :   getRecordsForListView
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @param            :   listViewName => listViewName (String)
     * @param            :   fields => fields (List<String>)
     * @return           :   List<SObject>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecordsForListView(String sObjectName, String listViewName, List<String> fields) {
        Map<String, Object> result = getRecordsForListViewPaginated(sObjectName, listViewName, fields, 2000, 1);
        return (List<SObject>)result.get('records');
    }
    
    /**
     * @description      :   Récupère les enregistrements paginés avec recherche textuelle sur tous les champs
     * @method Name      :   getRecordsForListViewPaginatedWithSearch
     * @Author           :   D&A Technologies
     * @date             :   2026-02-07
     * @param            :   sObjectName => sObjectName (String)
     * @param            :   listViewName => listViewName (String)
     * @param            :   fields => fields (List<String>)
     * @param            :   pageSize => pageSize (Integer)
     * @param            :   pageNumber => pageNumber (Integer)
     * @param            :   searchTerm => searchTerm (String)
     * @return           :   Object>
     * -------------------------------------------------------------------------------------------------
     **/
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getRecordsForListViewPaginatedWithSearch(String sObjectName, String listViewName, List<String> fields, Integer pageSize, Integer pageNumber, String searchTerm) {
        try {
            if (pageSize == null || pageSize <= 0) pageSize = DEFAULT_PAGE_SIZE;
            if (pageSize > MAX_PAGE_SIZE) pageSize = MAX_PAGE_SIZE;
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            
            String objectApiName = mapFrenchToEnglishObject(sObjectName);
            
            if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
                throw new AuraHandledException('Object ' + objectApiName + ' does not exist or is not accessible');
            }
            
            List<String> validatedFields = validateAndGetFields(objectApiName, fields);
            
            Map<String, Object> fieldsResult = getFieldsForListView(sObjectName, listViewName);
            Map<String, Map<String, String>> lookupInfo = (Map<String, Map<String, String>>)fieldsResult.get('lookupInfo');
            Map<String, Map<String, Object>> fieldsMetadata = (Map<String, Map<String, Object>>)fieldsResult.get('metadata');
            Boolean isMyRecordsView = (Boolean)fieldsResult.get('isMyRecordsView');
            
            String baseWhereClause = buildWhereClause(objectApiName, listViewName, sObjectName, isMyRecordsView);
            
            String searchWhereClause = '';
            if (String.isNotBlank(searchTerm)) {
                searchWhereClause = buildSearchWhereClause(objectApiName, validatedFields, fieldsMetadata, searchTerm);
            }
            
            String finalWhereClause = combineWhereClauses(baseWhereClause, searchWhereClause);
            
            String countQuery = buildCountQueryWithWhere(objectApiName, finalWhereClause);
            System.debug('Count query: ' + countQuery);
            Integer totalRecords = Database.countQuery(countQuery);
            
            Integer totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);
            if (totalPages == 0) totalPages = 1;
            
            if (pageNumber > totalPages) {
                pageNumber = totalPages;
            }
            
            Integer offset = (pageNumber - 1) * pageSize;
            
            String selectClause = buildSelectClause(objectApiName, validatedFields, fieldsMetadata, lookupInfo);
            String orderByField = getOrderByField(objectApiName);
            
            String query = selectClause + ' FROM ' + objectApiName;
            
            if (String.isNotBlank(finalWhereClause)) {
                query += ' WHERE ' + finalWhereClause;
            }
            
            query += ' ORDER BY ' + orderByField + ' DESC, Id DESC';
            query += ' LIMIT ' + pageSize;
            
            if (offset > 0 && offset <= SALESFORCE_OFFSET_LIMIT) {
                query += ' OFFSET ' + offset;
            }
            
            System.debug('Main query: ' + query);
            List<SObject> records = Database.query(query);
            
            return new Map<String, Object>{
                'records' => records,
                'totalRecords' => totalRecords,
                'totalPages' => totalPages,
                'currentPage' => pageNumber,
                'pageSize' => pageSize,
                'hasNextPage' => pageNumber < totalPages,
                'hasPreviousPage' => pageNumber > 1,
                'searchTerm' => searchTerm
            };
            
        } catch (Exception e) {
            System.debug('Error in getRecordsForListViewPaginatedWithSearch: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error querying data: ' + e.getMessage());
        }
    }
    
    /**
     * Build search WHERE clause for SOQL
     * Searches across all text, picklist, and lookup fields
     */
    private static String buildSearchWhereClause(String objectApiName, List<String> fields, Map<String, Map<String, Object>> fieldsMetadata, String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return '';
        }
        
        String escapedSearchTerm = String.escapeSingleQuotes(searchTerm.trim());
        
        List<String> searchConditions = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        
        for (String field : fields) {
            if (field == 'Id') continue;
            
            // Gestion des champs liés déjà définis (ex: Account.Name)
            if (field.contains('.')) {
                // On suppose que le champ défini explicitement est correct
                searchConditions.add(field + ' LIKE \'%' + escapedSearchTerm + '%\'');
                continue;
            }
            
            if (!fieldMap.containsKey(field)) continue;
            
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(field).getDescribe();
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            if (isSearchableTextField(fieldType)) {
                searchConditions.add(field + ' LIKE \'%' + escapedSearchTerm + '%\'');
            }
            // 1. Pour les Picklists SIMPLES : On garde le LIKE
            else if (fieldType == Schema.DisplayType.PICKLIST) {
                searchConditions.add(field + ' LIKE \'%' + escapedSearchTerm + '%\'');
            }
            // 2. Pour les MULTI-PICKLISTS : On utilise INCLUDES
            else if (fieldType == Schema.DisplayType.MULTIPICKLIST) {
                // Note : INCLUDES ne supporte pas les jokers (%), il faudra que l'utilisateur tape la valeur exacte
                searchConditions.add(field + ' INCLUDES (\'' + escapedSearchTerm + '\')');
            }
            // Gestion dynamique du champ "Nom" pour les Lookups
            else if (fieldType == Schema.DisplayType.REFERENCE && field.endsWith('Id')) {
                String relationshipName = field.substring(0, field.length() - 2);
                
                // On récupère l'objet vers lequel pointe le lookup pour trouver son "Name Field" correct
                List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                if (!referenceTo.isEmpty()) {
                    String relatedObjectName = referenceTo[0].getDescribe().getName();
                    // Utilise la méthode utilitaire existante pour savoir si c'est Name, CaseNumber, etc.
                    String nameField = getNameFieldForObject(relatedObjectName);
                    searchConditions.add(relationshipName + '.' + nameField + ' LIKE \'%' + escapedSearchTerm + '%\'');
                } else {
                    // Fallback par défaut si impossible de déterminer l'objet
                    searchConditions.add(relationshipName + '.Name LIKE \'%' + escapedSearchTerm + '%\'');
                }
            }
            else if (isNumericField(fieldType) && isNumeric(escapedSearchTerm)) {
                try {
                    Decimal numericValue = Decimal.valueOf(escapedSearchTerm);
                    searchConditions.add(field + ' = ' + numericValue);
                } catch (Exception e) {
                    // Ignore conversion errors
                }
            }
        }
        
        if (searchConditions.isEmpty()) {
            return '';
        }
        
        return '(' + String.join(searchConditions, ' OR ') + ')';
    }
    
    /**
     * Check if field type is searchable text
     */
    private static Boolean isSearchableTextField(Schema.DisplayType fieldType) {
        return fieldType == Schema.DisplayType.STRING ||
            fieldType == Schema.DisplayType.TEXTAREA ||
            fieldType == Schema.DisplayType.EMAIL ||
            fieldType == Schema.DisplayType.PHONE ||
            fieldType == Schema.DisplayType.URL;
    }
    
    /**
     * Check if field type is numeric
     */
    private static Boolean isNumericField(Schema.DisplayType fieldType) {
        return fieldType == Schema.DisplayType.INTEGER ||
            fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.CURRENCY ||
            fieldType == Schema.DisplayType.PERCENT;
    }
    
    /**
     * Check if string is numeric
     */
    private static Boolean isNumeric(String value) {
        try {
            Decimal.valueOf(value);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Combine multiple WHERE clauses
     */
    private static String combineWhereClauses(String baseClause, String searchClause) {
        List<String> clauses = new List<String>();
        
        if (String.isNotBlank(baseClause)) {
            clauses.add('(' + baseClause + ')');
        }
        
        if (String.isNotBlank(searchClause)) {
            clauses.add('(' + searchClause + ')');
        }
        
        if (clauses.isEmpty()) {
            return '';
        }
        
        return String.join(clauses, ' AND ');
    }
    
    /**
     * Build count query with custom WHERE clause
     */
    private static String buildCountQueryWithWhere(String objectApiName, String whereClause) {
        String query = 'SELECT COUNT() FROM ' + objectApiName;
        
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        
        return query;
    }
}