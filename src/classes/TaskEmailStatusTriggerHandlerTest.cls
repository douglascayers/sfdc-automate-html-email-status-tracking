/**
 * Developed by Doug Ayers
 * douglascayers.com
 */
@isTest
private class TaskEmailStatusTriggerHandlerTest {

    @isTest
    static void test_handler() {

        Account acct = new Account(
            name = 'Salesforce'
        );

        insert acct;

        Contact cont = new Contact(
            accountId = acct.id,
            firstName = 'Marc',
            lastName = 'Benioff',
            email = 'ceo@salesforce.com'
        );

        insert cont;

        Test.startTest();

        Task tsk = new Task(
            subject = 'Test Email',
            whatId = acct.id,
            whoId = cont.id,
            taskSubType = 'Email'
        );

        insert tsk;

        Test.stopTest();

        tsk = [ SELECT id, createdDate, email_status_sent_date__c FROM Task WHERE id = :tsk.id ];

        System.assert( tsk.createdDate.isSameDay( tsk.email_status_sent_date__c ) );

    }

}