/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
trigger TaskEmailStatusTrigger on Task ( after insert, before delete ) {

    TaskEmailStatusTriggerHandler handler = new TaskEmailStatusTriggerHandler();

    if ( Trigger.isInsert ) {

        handler.insertStatusDates( Trigger.new );

    } else if ( Trigger.isDelete ) {

        handler.deleteStatusDates( Trigger.old );

    }

}