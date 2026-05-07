public with sharing class ClaimCompactLayoutController {

                    public class FieldItem {
                        @AuraEnabled public String  fieldPath    { get; set; }
                        @AuraEnabled public String  label        { get; set; }
                        @AuraEnabled public String  fieldType    { get; set; }
                        @AuraEnabled public Boolean required     { get; set; }
                        @AuraEnabled public Boolean isLookup     { get; set; }
                        @AuraEnabled public Boolean isDateTime   { get; set; }
                        @AuraEnabled public String  lookupId     { get; set; }
                        @AuraEnabled public String  displayValue { get; set; }
                    }

                    public class ClaimData {
                        @AuraEnabled public String          claimName { get; set; }
                        @AuraEnabled public List<FieldItem> fields    { get; set; }
                    }

                    private static final Map<String, String[]> LOOKUP_CONFIG = new Map<String, String[]>{
                        'Account__c'      => new String[]{ 'Case__r.AccountId',   'Case__r.Account.Name'              },
                        'Vehicule__c'     => new String[]{ 'Vehicule__c',         'Vehicule__r.RegistrationNumber__c' },
                        'PolicyNumber__c' => new String[]{ 'PolicyNumber__c',     'PolicyNumber__r.PolicyNumber__c'   },
                            'EvenementAssocie__c'  => new String[]{ 'EvenementAssocie__c',          'EvenementAssocie__r.Name'          }

                    };

                    private static final Set<String> DATETIME_OVERRIDE = new Set<String>{
                        'DateOfOccurrence__c'
                    };

                    private static final List<String> TRAVERSAL_FIELDS = new List<String>{
                        'Case__c',
                        'Case__r.AccountId',
                        'Case__r.Account.Name',
                        'Vehicule__c',
                        'Vehicule__r.RegistrationNumber__c',
                        'PolicyNumber__c',
                        'PolicyNumber__r.PolicyNumber__c',
                        'DateOfOccurrence__c',
                        'EvenementAssocie__c',
                'EvenementAssocie__r.Name'
                    };

                    @AuraEnabled(cacheable=true)
                    public static ClaimData getClaimData(Id recordId) {

                        // 1. Membres du Field Set
                        List<Schema.FieldSetMember> members = DM006_Claim.getCompactFieldSetMembers();
                        if (members.isEmpty()) {
                            throw new AuraHandledException('Field Set "Claim_Compact_Layout" introuvable ou vide.');
                        }

                        // 2. Construction des champs pour DA_Utility
                        Set<String> fieldApiNames = new Set<String>{ 'Id', 'Name' };
                        for (Schema.FieldSetMember m : members) {
                            fieldApiNames.add(m.getFieldPath());
                        }
                        fieldApiNames.addAll(TRAVERSAL_FIELDS);

                        // Séparer directs et traversées
                        Set<String> directFields   = new Set<String>();
                        Set<String> traversalPaths = new Set<String>();
                        for (String f : fieldApiNames) {
                            if (f.contains('.')) {
                                traversalPaths.add(f);
                            } else {
                                directFields.add(f);
                            }
                        }

                        List<String> allFields = new List<String>(directFields);
                        allFields.addAll(new List<String>(traversalPaths));

                    // 3. Requête via DM006_Claim.getById()
        String fieldsStr = String.join(allFields, ', ');

        Claim__c record;
        try {
            record = DM006_Claim.getById(fieldsStr, recordId);
            if (record == null) throw new AuraHandledException('Sinistre introuvable.');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur SOQL : ' + e.getMessage());
        }
                        // 4. Construction des FieldItems dans l'ordre du Field Set
                        List<FieldItem> fieldList = new List<FieldItem>();

                        for (Schema.FieldSetMember m : members) {
                            String path       = m.getFieldPath();
                            String memberType = String.valueOf(m.getType()).toUpperCase();

                            FieldItem fi  = new FieldItem();
                            fi.fieldPath  = path;
                            fi.label      = m.getLabel();
                            fi.fieldType  = memberType;
                            fi.required   = m.getRequired() || m.getDbRequired();
                            fi.isDateTime = false;
                            fi.isLookup   = false;

                            if (DATETIME_OVERRIDE.contains(path)) {
                                fi.isDateTime   = true;
                                Object rawVal   = record.get(path);
                                fi.displayValue = rawVal != null ? parseDateToIso(rawVal) : null;

                            } else if (LOOKUP_CONFIG.containsKey(path)) {
                                fi.isLookup     = true;
                                String[] cfg    = LOOKUP_CONFIG.get(path);
                                fi.lookupId     = resolveTraversal(record, cfg[0]);
                                fi.displayValue = resolveTraversal(record, cfg[1]);

                            } else if (memberType == 'REFERENCE') {
                                fi.isLookup     = true;
                                Object raw      = record.get(path);
                                fi.lookupId     = raw != null ? String.valueOf(raw) : null;
                                fi.displayValue = fi.lookupId;

                            } else if (memberType == 'DATE' || memberType == 'DATETIME') {
                                fi.isDateTime   = true;
                                Object rawVal   = record.get(path);
                                fi.displayValue = rawVal != null ? parseDateToIso(rawVal) : null;

                            } else {
                                Object val      = record.get(path);
                                fi.displayValue = val != null ? String.valueOf(val) : null;
                            }

                            fieldList.add(fi);
                        }

                        ClaimData result = new ClaimData();
                        result.claimName = record.Name;
                        result.fields    = fieldList;
                        return result;
                    }

                    // ── Helpers ────────────────────────────────────────────────────────────────

                    private static String resolveTraversal(Claim__c record, String path) {
                        try {
                            List<String> parts = path.split('\\.');
                            if (parts.size() == 1) {
                                Object val = record.get(parts[0]);
                                return val != null ? String.valueOf(val) : null;
                            }
                            if (parts.size() == 2) {
                                SObject rel = record.getSObject(parts[0]);
                                if (rel == null) return null;
                                Object val  = rel.get(parts[1]);
                                return val != null ? String.valueOf(val) : null;
                            }
                            if (parts.size() == 3) {
                                SObject rel1 = record.getSObject(parts[0]);
                                if (rel1 == null) return null;
                                SObject rel2 = rel1.getSObject(parts[1]);
                                if (rel2 == null) return null;
                                Object val   = rel2.get(parts[2]);
                                return val != null ? String.valueOf(val) : null;
                            }
                            return null;
                        } catch (Exception e) {
                            System.debug('### resolveTraversal [' + path + '] : ' + e.getMessage());
                            return null;
                        }
                    }

                    private static String parseDateToIso(Object rawObj) {
                        if (rawObj instanceof DateTime) {
                            return ((DateTime) rawObj).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                        }
                        if (rawObj instanceof Date) {
                            Date d = (Date) rawObj;
                            return DateTime.newInstanceGmt(d.year(), d.month(), d.day(), 0, 0, 0)
                                        .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                        }
                        String raw = String.valueOf(rawObj);
                        try {
                            return DateTime.valueOf(raw).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                        } catch (Exception ex) {
                            return raw;
                        }
                    }
                }