/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
public class TaskEmailStatusTriggerHandler {

    /**
     * Designed to be invoked during 'before insert' or 'before update' trigger events.
     */
    public void handle( List<Task> newTasks ) {

        for ( Task newTask : newTasks ) {

            if ( newTask.taskSubtype == 'Email' ) {
                newTask.email_status_sent_date__c = DateTime.now();
            }

        }

    }

}