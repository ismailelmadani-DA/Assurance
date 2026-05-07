/**
 * @description  : Controller LWC — Historique des véhicules d'un passager
 * @author       : D&A Technologies
 * @date         : 2026-04-23
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

            return buildWrappers(directCps);

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

    private static VehicleWrapper resolveVehicle(ClaimParticipant__c cp) {

        String role = cp.Roles__c;
        System.debug('    CP=' + cp.Id + ' | Rôle=[' + role + ']');

        Id     vId     = null;
        String immat   = null;
        String name    = null;
        String brand   = null;
        String model   = null;
        String owner   = null;
        Id     ownerId = null;

        // ── Priorité 1 : rôle explicitement renseigné ────────────────────────
        if (role == ROLE_ASSURED) {
            if (cp.Claim__r?.Vehicule__c != null) {
                vId     = cp.Claim__r.Vehicule__c;
                immat   = cp.Claim__r.Vehicule__r?.RegistrationNumber__c;
                name    = cp.Claim__r.Vehicule__r?.Name;
                brand   = cp.Claim__r.Vehicule__r?.Brand__c;
                model   = cp.Claim__r.Vehicule__r?.ModelePicklist__c != null
                          ? cp.Claim__r.Vehicule__r.ModelePicklist__c
                          : cp.Claim__r.Vehicule__r?.Modele__c;
                owner   = cp.Claim__r.Vehicule__r?.ProprietaireDuVehicule__r?.Name;
                ownerId = cp.Claim__r.Vehicule__r?.ProprietaireDuVehicule__c;
            } else {
                System.debug('    SKIP (Passager assuré) : Claim__r.Vehicule__c null');
                return null;
            }

        } else if (role == ROLE_ADVERSE || role == ROLE_OTHER) {
            if (cp.Vehicule__c != null) {
                vId     = cp.Vehicule__c;
                immat   = cp.Vehicule__r?.RegistrationNumber__c;
                name    = cp.Vehicule__r?.Name;
                brand   = cp.Vehicule__r?.Brand__c;
                model   = cp.Vehicule__r?.ModelePicklist__c != null
                          ? cp.Vehicule__r.ModelePicklist__c
                          : cp.Vehicule__r?.Modele__c;
                owner   = cp.Vehicule__r?.ProprietaireDuVehicule__r?.Name;
                ownerId = cp.Vehicule__r?.ProprietaireDuVehicule__c;
            } else {
                System.debug('    SKIP (' + role + ') : Vehicule__c null');
                return null;
            }

        // ── Priorité 2 : rôle absent ou non reconnu → fallback ───────────────
        } else {
            if (cp.Vehicule__c != null) {
                System.debug('    FALLBACK A : Vehicule__c direct');
                vId     = cp.Vehicule__c;
                immat   = cp.Vehicule__r?.RegistrationNumber__c;
                name    = cp.Vehicule__r?.Name;
                brand   = cp.Vehicule__r?.Brand__c;
                model   = cp.Vehicule__r?.ModelePicklist__c != null
                          ? cp.Vehicule__r.ModelePicklist__c
                          : cp.Vehicule__r?.Modele__c;
                owner   = cp.Vehicule__r?.ProprietaireDuVehicule__r?.Name;
                ownerId = cp.Vehicule__r?.ProprietaireDuVehicule__c;

            } else if (cp.Claim__r?.Vehicule__c != null) {
                System.debug('    FALLBACK B : Claim__r.Vehicule__r');
                vId     = cp.Claim__r.Vehicule__c;
                immat   = cp.Claim__r.Vehicule__r?.RegistrationNumber__c;
                name    = cp.Claim__r.Vehicule__r?.Name;
                brand   = cp.Claim__r.Vehicule__r?.Brand__c;
                model   = cp.Claim__r.Vehicule__r?.ModelePicklist__c != null
                          ? cp.Claim__r.Vehicule__r.ModelePicklist__c
                          : cp.Claim__r.Vehicule__r?.Modele__c;
                owner   = cp.Claim__r.Vehicule__r?.ProprietaireDuVehicule__r?.Name;
                ownerId = cp.Claim__r.Vehicule__r?.ProprietaireDuVehicule__c;
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
        w.brandModel         = buildBrandModel(brand, model);
        w.ownerName          = owner;
        w.ownerId            = ownerId;
        w.isDriver           = cp.isDriver__c == true;
        w.claimId            = cp.Claim__c;
        w.claimName          = cp.Claim__r?.Name;
        w.role               = String.isNotBlank(role) ? role : '—';
        return w;
    }

    private static String buildBrandModel(String brand, String model) {
        Boolean hasBrand = String.isNotBlank(brand);
        Boolean hasModel = String.isNotBlank(model);
        if (hasBrand && hasModel) return brand + ' ' + model;
        if (hasBrand)             return brand;
        if (hasModel)             return model;
        return '—';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BUILD WRAPPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static List<VehicleWrapper> buildWrappers(List<ClaimParticipant__c> participants) {
        Map<Id, VehicleWrapper> vehicleMap = new Map<Id, VehicleWrapper>();

        for (ClaimParticipant__c cp : participants) {
            VehicleWrapper w = resolveVehicle(cp);
            if (w == null) continue;

            if (!vehicleMap.containsKey(w.vehicleId)) {
                vehicleMap.put(w.vehicleId, w);
            } else if (cp.isDriver__c == true) {
                vehicleMap.get(w.vehicleId).isDriver = true;
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
        @AuraEnabled public String  brandModel;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public Id      ownerId;
        @AuraEnabled public Boolean isDriver;
        @AuraEnabled public Id      claimId;
        @AuraEnabled public String  claimName;
        @AuraEnabled public String  role;
    }
}