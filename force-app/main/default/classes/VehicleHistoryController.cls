/**
 * @description  : Controller LWC — Historique des véhicules d'un passager
 * @author       : D&A Technologies
 * @date         : 2026-04-23
 *
 * LOGIQUE DE RÉSOLUTION DU VÉHICULE :
 * ─────────────────────────────────────────────────────────────────────────
 *  Priorité 1 — Rôle explicite renseigné sur le CP :
 *    • "Passager assuré"               → Claim__r.Vehicule__r
 *    • "Passager adverse" / "Autres partie" → Vehicule__r (direct sur CP)
 *
 *  Priorité 2 — Rôle absent ou non reconnu (fallback) :
 *    • Vehicule__c direct renseigné    → Vehicule__r
 *    • Sinon                           → Claim__r.Vehicule__r
 *    • Aucun véhicule résolvable       → SKIP
 * ─────────────────────────────────────────────────────────────────────────
 */
public with sharing class VehicleHistoryController {

    private static final String ROLE_ASSURED  = 'Passager assuré';
    private static final String ROLE_ADVERSE  = 'Passager adverse';
    private static final String ROLE_OTHER    = 'Autres partie';

    @AuraEnabled(cacheable=true)
    public static List<VehicleWrapper> getVehicleHistory(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('accountId est requis.');
            }

            System.debug('>>> [VehicleHistory] accountId = ' + accountId);

            List<ClaimParticipant__c> directCps =
                DM_VehicleHistory.getParticipantsByAccount(accountId);
            System.debug('>>> [VehicleHistory] Lien direct : ' + directCps.size());

            List<ClaimParticipant__c> indirectCps =
                DM_VehicleHistory.getParticipantsByPassager(accountId);
            System.debug('>>> [VehicleHistory] Lien indirect : ' + indirectCps.size());

            Map<Id, ClaimParticipant__c> mergedMap = new Map<Id, ClaimParticipant__c>();
            for (ClaimParticipant__c cp : directCps)   mergedMap.put(cp.Id, cp);
            for (ClaimParticipant__c cp : indirectCps) mergedMap.put(cp.Id, cp);

            System.debug('>>> [VehicleHistory] Total fusionné : ' + mergedMap.size());

            return buildWrappers(mergedMap.values());

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('>>> [VehicleHistory] ERREUR : ' + e.getMessage());
            throw new AuraHandledException(
                'Erreur lors du chargement des véhicules : ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RÉSOLUTION DU VÉHICULE
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Résout les données véhicule d'un CP selon la priorité :
     * 1. Rôle explicite  →  source déterminée par le rôle
     * 2. Fallback        →  Vehicule__c direct, sinon Claim__r.Vehicule__r
     * Retourne null si aucun véhicule n'est résolvable (CP à ignorer).
     */
    private static VehicleWrapper resolveVehicle(ClaimParticipant__c cp) {

        String role = cp.Roles__c;
        System.debug('    CP=' + cp.Id + ' | Rôle=[' + role + ']');

        Id     vId    = null;
        String immat  = null;
        String name   = null;
        String brand  = null;
        String model  = null;
        String owner  = null;

        // ── Priorité 1 : rôle explicitement renseigné ────────────────────────
        if (role == ROLE_ASSURED) {
            // Passager assuré → véhicule du sinistre
            if (cp.Claim__r?.Vehicule__c != null) {
                vId   = cp.Claim__r.Vehicule__c;
                immat = cp.Claim__r.Vehicule__r?.RegistrationNumber__c;
                name  = cp.Claim__r.Vehicule__r?.Name;
                brand = cp.Claim__r.Vehicule__r?.Brand__c;
                model = cp.Claim__r.Vehicule__r?.ModelePicklist__c != null
                        ? cp.Claim__r.Vehicule__r.ModelePicklist__c
                        : cp.Claim__r.Vehicule__r?.Modele__c;
                owner = cp.Claim__r.Vehicule__r?.ProprietaireDuVehicule__r != null
                        ? cp.Claim__r.Vehicule__r.ProprietaireDuVehicule__r.Name : '';
            } else {
                System.debug('    SKIP (Passager assuré) : Claim__r.Vehicule__c null');
                return null;
            }

        } else if (role == ROLE_ADVERSE || role == ROLE_OTHER) {
            // Passager adverse / Autres partie → véhicule direct sur le CP
            if (cp.Vehicule__c != null) {
                vId   = cp.Vehicule__c;
                immat = cp.Vehicule__r?.RegistrationNumber__c;
                name  = cp.Vehicule__r?.Name;
                brand = cp.Vehicule__r?.Brand__c;
                model = cp.Vehicule__r?.ModelePicklist__c != null
                        ? cp.Vehicule__r.ModelePicklist__c
                        : cp.Vehicule__r?.Modele__c;
                owner = cp.Vehicule__r?.ProprietaireDuVehicule__r != null
                        ? cp.Vehicule__r.ProprietaireDuVehicule__r.Name : '';
            } else {
                System.debug('    SKIP (' + role + ') : Vehicule__c null');
                return null;
            }

        // ── Priorité 2 : rôle absent ou non reconnu → fallback ───────────────
        } else {
            if (cp.Vehicule__c != null) {
                // Fallback A : véhicule direct sur le CP
                System.debug('    FALLBACK A : Vehicule__c direct');
                vId   = cp.Vehicule__c;
                immat = cp.Vehicule__r?.RegistrationNumber__c;
                name  = cp.Vehicule__r?.Name;
                brand = cp.Vehicule__r?.Brand__c;
                model = cp.Vehicule__r?.ModelePicklist__c != null
                        ? cp.Vehicule__r.ModelePicklist__c
                        : cp.Vehicule__r?.Modele__c;
                owner = cp.Vehicule__r?.ProprietaireDuVehicule__r != null
                        ? cp.Vehicule__r.ProprietaireDuVehicule__r.Name : '';

            } else if (cp.Claim__r?.Vehicule__c != null) {
                // Fallback B : véhicule via le sinistre
                System.debug('    FALLBACK B : Claim__r.Vehicule__r');
                vId   = cp.Claim__r.Vehicule__c;
                immat = cp.Claim__r.Vehicule__r?.RegistrationNumber__c;
                name  = cp.Claim__r.Vehicule__r?.Name;
                brand = cp.Claim__r.Vehicule__r?.Brand__c;
                model = cp.Claim__r.Vehicule__r?.ModelePicklist__c != null
                        ? cp.Claim__r.Vehicule__r.ModelePicklist__c
                        : cp.Claim__r.Vehicule__r?.Modele__c;
                owner = cp.Claim__r.Vehicule__r?.ProprietaireDuVehicule__r != null
                        ? cp.Claim__r.Vehicule__r.ProprietaireDuVehicule__r.Name : '';
            } else {
                System.debug('    SKIP : aucun véhicule résolvable sur CP=' + cp.Id);
                return null;
            }
        }

        System.debug('    RÉSOLU → Véhicule=' + vId + ' | Immat=' + immat);

        VehicleWrapper w     = new VehicleWrapper();
        w.vehicleId          = vId;
        w.vehicleName        = name;
        w.registrationNumber = immat;
        w.brand              = brand;
        w.model              = model;
        w.ownerName          = owner;
        w.isDriver           = cp.isDriver__c == true;
        w.claimId            = cp.Claim__c;
        w.claimName          = cp.Claim__r?.Name;
        w.role               = String.isNotBlank(role) ? role : '—';
        return w;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BUILD WRAPPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static List<VehicleWrapper> buildWrappers(List<ClaimParticipant__c> participants) {
        // Clé = vehicleId + '_' + claimId  →  un même véhicule peut figurer
        // dans plusieurs sinistres distincts
        Map<String, VehicleWrapper> vehicleMap = new Map<String, VehicleWrapper>();

        for (ClaimParticipant__c cp : participants) {

            VehicleWrapper w = resolveVehicle(cp);
            if (w == null) continue;

            String mapKey = String.valueOf(w.vehicleId) + '_' + String.valueOf(cp.Claim__c);

            if (!vehicleMap.containsKey(mapKey)) {
                vehicleMap.put(mapKey, w);
            } else {
                // Si un autre CP du même sinistre indique conducteur → on promeut
                if (cp.isDriver__c == true) {
                    vehicleMap.get(mapKey).isDriver = true;
                }
            }
        }

        System.debug('>>> [VehicleHistory] Wrappers construits : ' + vehicleMap.size());
        return vehicleMap.values();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPER
    // ─────────────────────────────────────────────────────────────────────────

    public class VehicleWrapper {
        @AuraEnabled public Id      vehicleId;
        @AuraEnabled public String  vehicleName;
        @AuraEnabled public String  registrationNumber;
        @AuraEnabled public String  brand;
        @AuraEnabled public String  model;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public Boolean isDriver;
        @AuraEnabled public Id      claimId;
        @AuraEnabled public String  claimName;
        @AuraEnabled public String  role;
    }
}