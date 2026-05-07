// ═══════════════════════════════════════════════════════════════
// EM007_InsurancePolicy — Event Manager (écriture uniquement)
// ═══════════════════════════════════════════════════════════════
public with sharing class EM007_InsurancePolicy {

    // ─────────────────────────────────────────────────────────────
    // Account
    // ─────────────────────────────────────────────────────────────

    /**
     * @description : Crée un Account assuré (RecordType Passager)
     */
    public static Account insertAccount(Account acc) {
        insert acc;
        return acc;
    }

    /**
     * @description : Met à jour un Account assuré existant
     */
    public static Account updateAccount(Account acc) {
        update acc;
        return acc;
    }

    // ─────────────────────────────────────────────────────────────
    // InsurancePolicy__c
    // ─────────────────────────────────────────────────────────────

    /**
     * @description : Insère une nouvelle police
     */
    public static InsurancePolicy__c insertPolice(InsurancePolicy__c police) {
        insert police;
        return police;
    }

    /**
     * @description : Met à jour une police existante (lien véhicule, résiliation...)
     */
    public static InsurancePolicy__c updatePolice(InsurancePolicy__c police) {
        update police;
        return police;
    }

    // ─────────────────────────────────────────────────────────────
    // Vehicule__c
    // ─────────────────────────────────────────────────────────────

    /**
     * @description : Insère un nouveau véhicule
     */
    public static Vehicule__c insertVehicule(Vehicule__c vehicule) {
        insert vehicule;
        return vehicule;
    }

    /**
     * @description : Met à jour un véhicule existant (réaffectation de police)
     */
    public static Vehicule__c updateVehicule(Vehicule__c vehicule) {
        update vehicule;
        return vehicule;
    }

    // ─────────────────────────────────────────────────────────────
    // InsurancePolicyCoverage__c
    // ─────────────────────────────────────────────────────────────

    /**
     * @description : Insère en masse les garanties d'une police
     */
    public static void insertCoverages(List<InsurancePolicyCoverage__c> coverages) {
        if (coverages != null && !coverages.isEmpty()) {
            insert coverages;
        }
    }
}