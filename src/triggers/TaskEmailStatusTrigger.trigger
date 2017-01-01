/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
trigger TaskEmailStatusTrigger on Task ( before insert ) {

    new TaskEmailStatusTriggerHandler().handle( Trigger.new );

}