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

        tsk = [ SELECT id, whoId, createdDate FROM Task WHERE id = :tsk.id ];

        Task_Email_Status_Date__c statusDate = [ SELECT id, task_id__c, who_id__c, date__c FROM Task_Email_Status_Date__c WHERE task_id__c = :tsk.id ];

        System.debug( tsk );
        System.debug( statusDate );

        System.assert( tsk.createdDate.date().isSameDay( statusDate.date__c ) );
        System.assertEquals( tsk.whoId, statusDate.who_id__c );

        delete tsk;

        System.assertEquals( 0, [ SELECT count() FROM Task_Email_Status_Date__c WHERE task_id__c = :tsk.id ] );

        Test.stopTest();

    }

}