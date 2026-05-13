// ═══════════════════════════════════════════════════════════════
// EM007_InsurancePolicy — Event Manager (écriture uniquement)
// ═══════════════════════════════════════════════════════════════
public with sharing class EM007_InsurancePolicy {

    // ─────────────────────────────────────────────────────────────
    // Account
    // ─────────────────────────────────────────────────────────────

    public static Account insertAccount(Account acc) {
        insert acc;
        return acc;
    }

    public static Account updateAccount(Account acc) {
        update acc;
        return acc;
    }

    // ─────────────────────────────────────────────────────────────
    // InsurancePolicy__c
    // ─────────────────────────────────────────────────────────────

    public static InsurancePolicy__c insertPolice(InsurancePolicy__c police) {
        insert police;
        return police;
    }

    public static InsurancePolicy__c updatePolice(InsurancePolicy__c police) {
        update police;
        return police;
    }

    // ─────────────────────────────────────────────────────────────
    // Vehicule__c
    // ─────────────────────────────────────────────────────────────

    public static Vehicule__c insertVehicule(Vehicule__c vehicule) {
        insert vehicule;
        return vehicule;
    }

    public static Vehicule__c updateVehicule(Vehicule__c vehicule) {
        update vehicule;
        return vehicule;
    }

    // ─────────────────────────────────────────────────────────────
    // InsurancePolicyCoverage__c
    // ─────────────────────────────────────────────────────────────

    public static void insertCoverages(List<InsurancePolicyCoverage__c> coverages) {
        if (coverages != null && !coverages.isEmpty()) {
            insert coverages;
        }
    }
}