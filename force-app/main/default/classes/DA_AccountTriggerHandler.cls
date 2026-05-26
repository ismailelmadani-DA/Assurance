/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : DA_AccountTriggerHandler
 * Author          : D&A Technologies
 * Created Date    : May 21, 2026
 * Last Modified On: May 21, 2026
 * Description     : This class is a handler of the trigger DA_AccountTrigger
 *  
 */

public class DA_AccountTriggerHandler {

	/**
    * @description      :   function of after insert procces
    * @method Name      :   handleAfterInsert
    * @Author           :   D&A Technologies
    * @date             :   2025-05-02 
    * @param            :   newList => List of new Account records
    * @return           :   void
    **/
    public static void handleAfterInsert(List<Account> newList) {
        System.debug('METHOD_NAME : handleAfterInsert');
    }
    
    /**
    * @description      :   function of after update procces
    * @method Name      :   handleAfterUpdate
    * @Author           :   D&A Technologies
    * @date             :   2025-05-02 
    * @param            :   newList => List of new Account records
    * @param            :   oldMap => Map of old Account records
    * @return           :   void
    **/
    public static void handleAfterUpdate(List<Account> newList, Map<Id, Account> oldMap) {
        System.debug('METHOD_NAME : handleAfterUpdate');
    }
    
    /**
    * @description      :   function of after delete procces
    * @method Name      :   handleAfterDelete
    * @Author           :   D&A Technologies
    * @date             :   2025-05-02 
    * @param            :   oldList => List of deleted Account records
    * @return           :   void
    **/
    public static void handleAfterDelete(List<Account> oldList) {
        System.debug('METHOD_NAME : handleAfterDelete');
    }
    
    /**
    * @description      :   function of after undelete procces
    * @method Name      :   handleAfterUndelete
    * @Author           :   D&A Technologies
    * @date             :   2025-05-02 
    * @param            :   newList => List of undeleted Account records
    * @return           :   void
    **/
    public static void handleAfterUndelete(List<Account> newList) {
        System.debug('METHOD_NAME : handleAfterUndelete');
    }
  
    
   

}