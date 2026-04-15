When writing or reviewing Salesforce code and metadata in this project, ALWAYS enforce the following D&A Technologies development standards (Normes de Developpement Salesforce). These rules apply to naming, project structure, code conventions, and configuration.

---

## 1. CONVENTIONS DE NOMMAGE - General Principles

- Respect existing conventions if already defined on the project.
- Do NOT use underscores in API Names (Objects, Fields, List Views...) except as a prefix or for technical fields.
- Replace accented characters in API Names (e.g. "Element" not "Element").
- Avoid abbreviations (risk of misinterpretation).
- Always fill in the Description field for custom fields.

---

## 2. OBJECTS

- **Label**: One or more words, singular, first letter of each word capitalized.
- **API Name**: UpperCamelCase, singular, no underscores (except prefix).
- **Description**: Should be filled in.

| Example | Correct API | Incorrect API |
|---|---|---|
| Element De Facture | `ElementDeFacture__c` | `El_ment_De_Facture__c`, `Element_De_Facture__c` |

---

## 3. FIELDS

- **Label**: One or more words, first letter capitalized, names must be clear and meaningful.
- **API Name**: UpperCamelCase, no underscores (except prefix).
- **Description**: Must be filled with a brief explanation (business or technical).
- **Help Text**: Can be filled on demand or client validation.

| Example | Correct API | Incorrect API |
|---|---|---|
| Id Externe | `IdExterne__c` | `Id_Externe__c` |

### Technical Fields
- Prefix: `TECH_` (uppercase)
- Naming: `TECH_` + UpperCamelCase, no underscores after prefix.
- Description must explain the technical purpose.

| Example | Correct API | Incorrect API |
|---|---|---|
| Is Valid | `TECH_IsValid__c` | `Is_Valid__c` |

---

## 4. RECORD TYPES

- **Label**: First letter of each word capitalized.
- **API Name**: UpperCamelCase, no underscores, no abbreviations.
- **Description**: Mandatory.

| Example | Correct API | Incorrect API |
|---|---|---|
| Business Account | `BusinessAccount` | `Business_Account` |

---

## 5. PAGE LAYOUTS & COMPACT LAYOUTS

- **Page Layout**: `PP_ObjectName[_Function]`
- **Compact Layout**: `PC_ObjectName[_Function]`

| Example | Correct | Incorrect |
|---|---|---|
| Default Invoice layout | `PP_Facture` | `Facture Layout` |
| Invoice for portal profile | `PP_Facture_Portail` | `Presentation Facture 2` |

---

## 6. VALIDATION RULES

- Format: `VRXXX_[FieldName/FieldGroup] [Rule Applied]`
- Single field: `VR001_Shipping Postal Code Is Required`
- Multi-field: `VR002_Billing Address Must Be Complete`
- Description is mandatory.

---

## 7. LIGHTNING PAGES

- Object page: `LP_ObjectName[_Function]`
- Home page: `LP_Home[_Function]`
- Other: `LP_Function`

| Example | Correct | Incorrect |
|---|---|---|
| Home (commercial profile) | `LP_Home_Commercial` | `Home1` |
| Account page (default) | `LP_Account` | `Account_Lightning_Page` |

---

## 8. CONFIGURATION NORMS

- **Custom fields**: Do NOT mark "Required" at field level. Use page layout / lightning page to enforce required. Reason: external data feeds and test class failures.
- **Picklists**: Use Global Value Sets if values are shared across objects/fields. Picklist API values used in code must be defined as constants in the Constants class or EM classes. Only modify the label, avoid changing the API name.
- **Flows**: Only ONE trigger flow per object.

---

## 9. CODE CONVENTIONS - General Principles

- No hardcoded IDs, picklist values, or URLs.
- DRY: Use Service Managers and Utility classes.
- No SOQL/SOSL/DML/@future calls inside loops.
- Check `System.isBatch()` / `System.isFuture()` before calling future methods or batches.
- Indentation: 4 spaces.
- Opening `{` at end of line, closing `}` on its own line with correct indentation.
- `for`, `if/else`, `while` blocks must always use `{` and `}`.
- Add a CLASS_NAME constant: `private static final String CLASS_NAME = MyClass.class.getName();`

---

## 10. DOCUMENTATION (Cartouches)

Every class and method must have a documentation header (cartouche):

```apex
/**
 * @description : Description of the class/component
 * @author      : Author Name
 * @group       : Group/category
 * @last modified on  : DD-MM-YYYY
 * @last modified by  : Author Name
 * Modifications Log
 * Ver   Date         Author          Modification
 * 1.0   DD-MM-YYYY   Author Name    Initial Version
 **/
```

Methods must also have:
```apex
/**
 * @description
 * @author Author Name | DD-MM-YYYY
 * @param paramName
 * @return ReturnType
 **/
```

---

## 11. METHODS & VARIABLES NAMING

- **Methods**: camelCase, must start with a verb. Example: `setOpportunityStatus`
- **Variables**: camelCase, meaningful names. Example: `accountList`
- **Constants**: UPPER_CASE with underscores. Example: `FIXED_RATE`
- **Picklist constants**: `PCKL_[FIELDNAME]_[VALUE]` in uppercase. Example: `PCKL_STATUT_VALIDE`
- Define picklist values in the Constants class or Entity Manager classes.

### Method Rules
- Start each method with a "Start method" log.
- End each method with an "End method" log.
- Methods must support bulk operations (accept collections, not single objects).

---

## 12. DESIGN PATTERN - Layered Architecture

The project follows a strict layered architecture:

```
SCH001_Scheduler  -->  BAT001_BatchName
EntityTrigger     -->  TH001_EntityName    (Facade layer)
                       LWC001_CmpName
                            |
                   SM001_ServiceName       (Service Manager layer)
                            |
                   EM001_EntityName        (Entity Manager layer)
                            |
                   DM001_EntityName        (Data Manager layer)
                            |
                   DM000_sObjectDescriber, UtilityClasses, Wrappers, ApexTestDataFactory
```

---

## 13. APEX CLASS NAMING CONVENTIONS

| Type | Pattern | Rules |
|---|---|---|
| Data Manager | `DMXXX_ObjectName` | Contains SOQL, Callouts, DML. One object per class. 100% coverage. |
| Entity Manager | `EMXXX_ObjectName` | No SOQL/Callouts. Accesses only one DM. Contains picklist API values & record type IDs. 100% coverage. |
| Service Manager | `SMXXX_ServiceName` | No SOQL/Callouts. Contains business logic. Accesses only EMs. Must be covered by tests. |
| Trigger Handler | `TH_ObjectName` | - |
| Scheduler | `SCHXXX_SchedulerName` | Same number as related batch when linked. |
| Batch | `BATXXX_BatchName` | Same number as related scheduler when linked. |
| Web Service | `WSXXX_WebServiceName` | - |
| Wrapper | `WRXXX_WrapperName` | Example: `WR001_Facturation` |
| Aura Controller | `LCXXX_ControllerName` | Same name as the component. |
| LWC Controller | `LWCXXX_ControllerName` | Same name as the component. |
| VF Controller | `VFXXX_VisualforceName` | Same name as the page. |
| Aura Component | `LCXXX_[Function]` | PascalCase |
| LWC Component | `lwcXXX_[Function]` | camelCase |
| Visualforce Page | `VFXXX_[Function]` | PascalCase |

- Numbers are incremented.
- EM and DM linked to the same object share the same number.

---

## 14. CONSTANTS CLASS

- Contains all constants: Object API names, global picklist values, profile names, queue/group names.
- No methods.
- No test class needed.

---

## 15. TEST CLASSES

- **Naming**: `[TestedClassName]_TEST`
- Tests verify functional AND technical behavior (Governor Limits).
- Must pass on all environments (sandbox, scratch orgs).
- Fix failing tests before deployment.
- Tests are isolated and independent, covering positive AND negative cases.
- **Coverage target: 90%** (minimum 75% for production deployment).
- New features must not reduce coverage.
- One Apex class = at least one test class.
- One Apex method = at least one test method.
- `seeAllData=true` is FORBIDDEN.
- Use: `@testSetup`, `TestFactory`, `@isTest` (not `testMethod`), `System.assert*`, `Test.startTest()`/`Test.stopTest()`, `System.runAs()`.
- Bulk testing: minimum 20 records, 200+ for triggers.
- Re-run tests after adding validation rules or required fields.

---

## 16. MOCK CLASSES

- **Naming**: `MOCKXXX_ClassName`
- Simulates external system calls.
- Only called by test classes.
- Must be tagged with `@isTest`.

---

## 17. TEST DATA FACTORY

- One single class per project: `ApexTestDataFactory`
- Used for test record initialization.
- Only called by test classes.
- Tagged with `@isTest`.

---

## 18. TRIGGERS

- **Naming**: `[ObjectName]Trigger`
- One trigger per object.
- No logic in the trigger - call the Trigger Handler.
- All triggers must be covered by tests.

---

## 19. SOQL BEST PRACTICES

- Never put queries inside loops.
- Be selective in SOQL queries (use WHERE clauses).
- Prefer Maps over Lists when possible.
- Avoid unnecessary record assignment (use SOQL for-loop for large datasets):
  ```apex
  // Preferred for large datasets:
  for (Account acc : [SELECT Id, Name FROM Account WHERE Name = 'Test']) {
      // process
  }
  ```

---

## 20. API CALLS

- Use **Named Credentials** for endpoints (not hardcoded URLs).
  - Specifies endpoint URL
  - Authentication method
  - Headers
