/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
public without sharing class TaskEmailStatusTriggerHandler {

    public void upsertEmailStatuses( List<Task> newTasks, Map<ID, Task> oldMap ) {

        List<HTML_Email_Status__c> emailStatusesToUpsert = new List<HTML_Email_Status__c>();

        for ( Task newTask : newTasks ) {

            Task oldTask = ( oldMap != null ) ? oldMap.get( newTask.id ) : null;

            Boolean isNew = ( oldTask == null );
            Boolean whoIdChanged = ( oldTask != null && oldTask.whoId != newTask.whoId );
            Boolean isEmailType = ( newTask.taskSubtype == 'Email' );

            if ( ( isNew || whoIdChanged ) && isEmailType ) {
                emailStatusesToUpsert.add( new HTML_Email_Status__c(
                    task_id__c = newTask.id,
                    who_id__c = newTask.whoId,
                    sent_date__c = newTask.createdDate
                ));
            }

        }

        if ( emailStatusesToUpsert.size() > 0 ) {
            Database.upsert( emailStatusesToUpsert, HTML_Email_Status__c.Task_ID__c );
        }

    }

    public void deleteEmailStatuses( List<Task> tasks ) {

        Set<ID> taskIds = new Set<ID>();
        for ( Task tsk : tasks ) {
            taskIds.add( tsk.id );
        }

        delete [ SELECT id FROM HTML_Email_Status__c WHERE task_id__c IN :taskIds ];

    }

}