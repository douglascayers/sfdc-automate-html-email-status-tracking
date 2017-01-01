/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
public without sharing class TaskEmailStatusBatchable implements Database.Batchable<SObject>, Schedulable {

    public Integer batchSize { get; set; }

    public TaskEmailStatusBatchable() {
        this( 200 );
    }

    public TaskEmailStatusBatchable( Integer batchSize ) {
        this.batchSize = batchSize;
    }

    // -------------------------------------

    public void execute( SchedulableContext context ) {

        System.debug( 'TaskEmailStatusBatchable.execute: context=' + context + ', batchSize=' + this.batchSize );

        Database.executeBatch( this, this.batchSize );

    }

    // -------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'TaskEmailStatusBatchable.start: context=' + context );

        HTML_Email_Status_Setting__c settings = HTML_Email_Status_Setting__c.getInstance();

        Integer daysAgoFilter = Integer.valueOf( settings.days_ago_filter__c );

        if ( daysAgoFilter == null ) {
            System.debug( LoggingLevel.WARN, 'No value for custom setting HTML_Email_Status_Setting__c.Days_Ago_Filter__c. Using default value of 30 days.' );
            daysAgoFilter = 30;
        }

        Date dateFilter = Date.today().addDays( -1 * Math.abs( daysAgoFilter ) );

        System.debug( 'dateFilter: ' + dateFilter );

        return Database.getQueryLocator([
            SELECT
                id, task_id__c, who_id__c
            FROM
                HTML_Email_Status__c
            WHERE
                (
                    sent_date__c >= :dateFilter
                    OR
                    last_open_date__c >= :dateFilter
                )
                AND
                who_id__c != null
        ]);
    }

    public void execute( Database.BatchableContext context, List<HTML_Email_Status__c> emailStatuses ) {

        System.debug( 'TaskEmailStatusBatchable.execute: context=' + context );

        String contactKeyPrefix = Contact.sObjectType.getDescribe().getKeyPrefix();
        String leadKeyPrefix = Lead.sObjectType.getDescribe().getKeyPrefix();

        Set<ID> taskIds = new Set<ID>();
        Set<ID> contactIds = new Set<ID>();
        Set<ID> leadIds = new Set<ID>();

        for ( HTML_Email_Status__c emailStatus : emailStatuses ) {

            String whoKeyPrefix = emailStatus.who_id__c.left( 3 );

            taskIds.add( emailStatus.task_id__c );

            if ( whoKeyPrefix == contactKeyPrefix ) {
                contactIds.add( emailStatus.who_id__c );
            }
            else if ( whoKeyPrefix == leadKeyPrefix ) {
                leadIds.add( emailStatus.who_id__c );
            }

        }

        System.debug( 'taskIds: ' + taskIds );
        System.debug( 'contactIds: ' + contactIds );
        System.debug( 'leadIds: ' + leadIds );

        // At this time, the EmailStatus object is not directly queryable.
        // Please vote for the idea here: https://success.salesforce.com/ideaView?id=08730000000ZzZUAA0)
        //
        // However, there's two workarounds I know of that will get us to this data:
        // 1. We can indirectly get to them by querying the child relationships of Contacts and Leads (Task.WhoId)
        //    http://salesforce.stackexchange.com/questions/47779/show-html-email-status-under-account/48442#48442
        // 2. Use Apex to run and parse a standard 'HTML Email Status' report.
        //
        // Unfortunately, option 2 would only ever show us data for emails sent by the current user, not all users.
        // http://www.simplysfdc.com/2015/11/salesforce-email-status.html
        //
        // So that leaves us with option 1.

        List<Task> tasksToUpdate = new List<Task>();
        List<HTML_Email_Status__c> emailStatusesToUpsert = new List<HTML_Email_Status__c>();

        Map<ID, EmailMessage> taskIdToEmailMessageMap = new Map<ID, EmailMessage>();
        for ( EmailMessage message : [
            SELECT
                id, activityId
            FROM
                EmailMessage
            WHERE
                activityId IN :taskIds
        ]) {
            taskIdToEmailMessageMap.put( message.activityId, message );
        }

        for ( Contact cont : [
            SELECT
                id,
                (
                    SELECT
                        id, taskId, createdDate, firstOpenDate, lastOpenDate, timesOpened, emailTemplateName
                    FROM
                        EmailStatuses
                    WHERE
                        taskId IN :taskIds
                )
            FROM
                Contact
            WHERE
                id IN :contactIds
        ]) {

            processEmailStatuses( cont.emailStatuses, tasksToUpdate, emailStatusesToUpsert, taskIdToEmailMessageMap );

        }

        for ( Lead ld : [
            SELECT
                id,
                (
                    SELECT
                        id, taskId, createdDate, firstOpenDate, lastOpenDate, timesOpened, emailTemplateName
                    FROM
                        EmailStatuses
                    WHERE
                        taskId IN :taskIds
                )
            FROM
                Lead
            WHERE
                id IN :leadIds
        ]) {

            processEmailStatuses( ld.emailStatuses, tasksToUpdate, emailStatusesToUpsert, taskIdToEmailMessageMap );

        }



        if ( tasksToUpdate.size() > 0 ) {
            update tasksToUpdate;
        }

        if ( taskIdToEmailMessageMap.size() > 0 ) {
            update taskIdToEmailMessageMap.values();
        }

        if ( emailStatusesToUpsert.size() > 0 ) {
            Database.upsert( emailStatusesToUpsert, HTML_Email_Status__c.Task_ID__c );
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'TaskEmailStatusBatchable.finish: context=' + context );

    }

    // -------------------------------------

    private void processEmailStatuses( List<EmailStatus> emailStatuses, List<Task> tasksToUpdate, List<HTML_Email_Status__c> emailStatusesToUpsert, Map<ID, EmailMessage> taskIdToEmailMessageMap ) {

        if ( emailStatuses != null && emailStatuses.size() > 0 ) {

            for ( EmailStatus status : emailStatuses ) {

                tasksToUpdate.add( new Task(
                    id = status.taskId,
                    email_status_sent_date__c = status.createdDate,
                    email_status_first_open_date__c = status.firstOpenDate,
                    email_status_last_open_date__c = status.lastOpenDate,
                    email_status_times_opened__c = status.timesOpened,
                    email_status_template_name__c = status.emailTemplateName
                ));

                emailStatusesToUpsert.add( new HTML_Email_Status__c(
                    task_id__c = status.taskId,
                    sent_date__c = status.createdDate,
                    first_open_date__c = status.firstOpenDate,
                    last_open_date__c = status.lastOpenDate,
                    times_opened__c = status.timesOpened,
                    email_template_name__c = status.emailTemplateName
                ));

                EmailMessage message = taskIdToEmailMessageMap.get( status.taskId );
                if ( message != null ) {
                    message.email_status_sent_date__c = status.createdDate;
                    message.email_status_first_open_date__c = status.firstOpenDate;
                    message.email_status_last_open_date__c = status.lastOpenDate;
                    message.email_status_times_opened__c = status.timesOpened;
                    message.email_status_template_name__c = status.emailTemplateName;
                }

            }

        }

    }

}