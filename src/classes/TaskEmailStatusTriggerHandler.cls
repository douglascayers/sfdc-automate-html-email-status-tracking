/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
public class TaskEmailStatusTriggerHandler {

    public void insertStatusDates( List<Task> tasks ) {

        System.debug( 'inserting task email status dates' );

        List<Task_Email_Status_Date__c> statusDates = new List<Task_Email_Status_Date__c>();

        for ( Task tsk : tasks ) {

            if ( tsk.taskSubtype == 'Email' && String.isNotBlank( tsk.whoId ) ) {
                statusDates.add( new Task_Email_Status_Date__c(
                    task_id__c = tsk.id,
                    who_id__c = tsk.whoId,
                    date__c = tsk.createdDate.date()
                ));
            }

        }

        System.debug( 'tasks: ' + tasks );
        System.debug( 'statusDates: ' + statusDates );

        if ( statusDates.size() > 0 ) {
            insert statusDates;
        }

    }

    public void deleteStatusDates( List<Task> tasks ) {

        System.debug( 'deleting task email status dates' );

        Set<String> taskIds = new Set<String>();
        for ( Task tsk : tasks ) {
            taskIds.add( tsk.id );
            taskIds.add( String.valueOf( tsk.id ).left( 15 ) );
        }

        delete [ SELECT id FROM Task_Email_Status_Date__c WHERE task_id__c IN :taskIds ];

    }

}