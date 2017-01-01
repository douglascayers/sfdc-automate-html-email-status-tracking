/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
trigger TaskEmailStatusTrigger on Task ( after insert, after update, before delete ) {

    TaskEmailStatusTriggerHandler handler = new TaskEmailStatusTriggerHandler();

    if ( Trigger.isInsert || Trigger.isUpdate ) {

        handler.upsertEmailStatuses( Trigger.new, Trigger.oldMap );

    } else if ( Trigger.isDelete ) {

        handler.deleteEmailStatuses( Trigger.old );

    }

}