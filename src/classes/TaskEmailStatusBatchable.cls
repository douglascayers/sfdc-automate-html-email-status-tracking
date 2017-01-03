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
        //
        // To do that then we will query all the Tasks that represent emails (TaskSubType = 'Email')
        // and use the Task.WhoId to determine the Contacts and Leads that have been sent emails
        // so that we can turn around and query those objects and obtain the EmailStatus via sub-queries.
        // This approach means we do not know when the last time an EmailStatus was updated so
        // even if this job runs daily we can't just have our main query say "grab all the records updated yesterday".
        // We are querying on Tasks and they aren't updated when EmailStatus is updated, hence why we're here
        // talking in the first place. So, I introduced the concept of "how many days matter to you?" to our equation.
        //
        // In the custom setting Task_Email_Status_Setting__c there is a field that tells us how many days
        // since a task email was either (a) sent or (b) last opened do we want to query in this batchable.
        // This lets us apply some semblance of a date filter to amount of records returned to then check if
        // they have an email status and if so has it been updated.
        // The default is check tasks that have been sent or last opened in the last 30 days.
        // If a recipient has not opened the email in 30 days then it falls off the radar for monitoring.
        // On the other hand, if the recipient does open within the window that resets the time frame for
        // another 30 days (or however many days the custom setting value is).
        // If to your company 30 days is too many or too few days to consider the email "active" or "hot"
        // then adjust the custom setting as necessary.

        Task_Email_Status_Setting__c settings = Task_Email_Status_Setting__c.getInstance();

        Integer daysAgoFilter = Integer.valueOf( settings.days_ago_filter__c );

        if ( daysAgoFilter == null ) {
            System.debug( LoggingLevel.WARN, 'No value for custom setting Task_Email_Status_Setting__c.Days_Ago_Filter__c. Using default value of 30 days.' );
            daysAgoFilter = 30;
        }

        Date dateFilter = Date.today().addDays( -1 * Math.abs( daysAgoFilter ) );

        System.debug( 'dateFilter: ' + dateFilter );

        return Database.getQueryLocator([
            SELECT
                id, task_id__c, who_id__c, date__c
            FROM
                Task_Email_Status_Date__c
            WHERE
                date__c >= :dateFilter
            ORDER BY
                task_id__c,
                who_id__c
        ]);
    }

    public void execute( Database.BatchableContext context, List<Task_Email_Status_Date__c> statusDates ) {

        System.debug( 'TaskEmailStatusBatchable.execute: context=' + context );

        String contactKeyPrefix = Contact.sObjectType.getDescribe().getKeyPrefix();
        String leadKeyPrefix = Lead.sObjectType.getDescribe().getKeyPrefix();

        Map<ID, Task> taskIdToTaskMap = new Map<ID, Task>();
        Map<ID, EmailMessage> taskIdToEmailMessageMap = new Map<ID, EmailMessage>();
        Map<ID, Task_Email_Status_Date__c> taskIdToStatusDateMap = new Map<ID, Task_Email_Status_Date__c>();

        Set<ID> contactIds = new Set<ID>();
        Set<ID> leadIds = new Set<ID>();

        for ( Task_Email_Status_Date__c statusDate : statusDates ) {

            String whoKeyPrefix = String.valueOf( statusDate.who_id__c ).left( 3 );

            taskIdToTaskMap.put( statusDate.task_id__c, new Task( id = statusDate.task_id__c ) );

            if ( whoKeyPrefix == contactKeyPrefix ) {
                contactIds.add( statusDate.who_id__c );
            }
            else if ( whoKeyPrefix == leadKeyPrefix ) {
                leadIds.add( statusDate.who_id__c );
            }

        }

        for ( EmailMessage message : [
            SELECT
                id, activityId
            FROM
                EmailMessage
            WHERE
                activityId IN :taskIdToTaskMap.keySet()
        ]) {
            taskIdToEmailMessageMap.put( message.activityId, message );
        }

        System.debug( 'taskIdToTaskMap: ' + taskIdToTaskMap );
        System.debug( 'taskIdToEmailMessageMap: ' + taskIdToEmailMessageMap );
        System.debug( 'contactIds: ' + contactIds );
        System.debug( 'leadIds: ' + leadIds );

        for ( Contact cont : [
            SELECT
                id,
                (
                    SELECT
                        id, taskId, createdDate, firstOpenDate, lastOpenDate, timesOpened, emailTemplateName
                    FROM
                        EmailStatuses
                    WHERE
                        taskId IN :taskIdToTaskMap.keySet()
                )
            FROM
                Contact
            WHERE
                id IN :contactIds
        ]) {

            processEmailStatuses( cont.emailStatuses, taskIdToTaskMap, taskIdToEmailMessageMap, taskIdToStatusDateMap );

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
                        taskId IN :taskIdToTaskMap.keySet()
                )
            FROM
                Lead
            WHERE
                id IN :leadIds
        ]) {

            processEmailStatuses( ld.emailStatuses, taskIdToTaskMap, taskIdToEmailMessageMap, taskIdToStatusDateMap );

        }

        if ( taskIdToTaskMap.size() > 0 ) {
            update taskIdToTaskMap.values();
        }

        if ( taskIdToEmailMessageMap.size() > 0 ) {
            update taskIdToEmailMessageMap.values();
        }

        if ( taskIdToStatusDateMap.size() > 0 ) {
            update taskIdToStatusDateMap.values();
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'TaskEmailStatusBatchable.finish: context=' + context );

    }

    // -------------------------------------

    /**
     * Iterates the EmailStatus records then applies field updates
     * to the tasks and email messages in the passed map arguments.
     *
     * We push the field updates to both tasks and email messages because
     * we don't know if any given org does or does not have Enhanced Email
     * enabled and so we don't know if users will be looking at a task or
     * email message page layout or reports when checking the status.
     *
     * Also, this gives more flexibility to admins if they need to build
     * workflow automation around task or email message objects based on these values.
     */
    @TestVisible
    private void processEmailStatuses( List<EmailStatus> emailStatuses, Map<ID, Task> taskIdToTaskMap, Map<ID, EmailMessage> taskIdToEmailMessageMap, Map<ID, Task_Email_Status_Date__c> taskIdToStatusDateMap ) {

        if ( emailStatuses != null && emailStatuses.size() > 0 ) {

            for ( EmailStatus status : emailStatuses ) {

                Task tsk = taskIdToTaskMap.get( status.taskId );
                if ( tsk != null ) {
                    tsk.email_status_sent_date__c = status.createdDate;
                    tsk.email_status_first_open_date__c = status.firstOpenDate;
                    tsk.email_status_last_open_date__c = status.lastOpenDate;
                    tsk.email_status_times_opened__c = status.timesOpened;
                    tsk.email_status_template_name__c = status.emailTemplateName;
                }

                EmailMessage message = taskIdToEmailMessageMap.get( status.taskId );
                if ( message != null ) {
                    message.email_status_sent_date__c = status.createdDate;
                    message.email_status_first_open_date__c = status.firstOpenDate;
                    message.email_status_last_open_date__c = status.lastOpenDate;
                    message.email_status_times_opened__c = status.timesOpened;
                    message.email_status_template_name__c = status.emailTemplateName;
                }

                Task_Email_Status_Date__c statusDate = taskIdToStatusDateMap.get( status.taskId );
                if ( statusDate != null ) {
                    DateTime maxDateTime = ( status.lastOpenDate > status.createdDate ) ? status.lastOpenDate : status.createdDate;
                    statusDate.date__c = ( maxDateTime != null ) ? maxDateTime.date() : null;
                }

            }

        }

    }

}