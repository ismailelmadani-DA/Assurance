/*********************************************************************************
* @author         D&A Technologies
* @description    Trigger for Account object
* @date           21-05-2026
* @group          Trigger
**********************************************************************************/
trigger DA_AccountTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	if(Trigger.isAfter) {
        if(Trigger.isInsert) {
            DA_AccountTriggerHandler.handleAfterInsert(Trigger.new);
        }
        
        if(Trigger.isUpdate) {
            DA_AccountTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        
        if(Trigger.isDelete) {
            DA_AccountTriggerHandler.handleAfterDelete(Trigger.old);
        }
        
        if(Trigger.isUndelete) {
            DA_AccountTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}