/*********************************************************************************
* @author         D&A Technologies
* @description    Trigger for Case object - Cloture Requetes Reaffectation
* @date           21-05-2026
* @group          Trigger
**********************************************************************************/
trigger ClotureRequetesReaffectation on Case (after update) {
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            DA_ClotureRequetesReaffectationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}