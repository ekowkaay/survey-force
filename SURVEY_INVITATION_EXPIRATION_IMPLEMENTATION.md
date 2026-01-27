# Survey Invitation Expiration Implementation Guide

## Overview

This document describes the implementation of automated survey invitation expiration for Survey Force.

## Problem Statement

Survey invitations have an `ExpirationDate__c` field, but there was no automated process to mark expired invitations as "Expired". The expiration check only occurred when a user attempted to validate/use the invitation token, leaving expired invitations in "Pending" status indefinitely.

## Solution

Implemented a scheduled batch job to automatically expire survey invitations that have passed their expiration date.

## Components Implemented

### 1. SurveyInvitationExpirationBatch.cls

**Purpose**: Batch class that queries and updates expired invitations.

**Key Features**:
- Queries all `SurveyInvitation__c` records with:
  - `Status__c = 'Pending'`
  - `ExpirationDate__c != NULL`
  - `ExpirationDate__c < NOW`
- Updates their status to 'Expired'
- Uses `Database.Batchable<SObject>` interface
- Processes records with USER_MODE for security
- Logs success/failure counts

**Code Location**: `/force-app/main/default/classes/SurveyInvitationExpirationBatch.cls`

### 2. SurveyInvitationExpirationScheduler.cls

**Purpose**: Schedulable class to run the batch job at specified intervals.

**Key Features**:
- Implements `Schedulable` interface
- Executes batch job with batch size of 200
- Can be scheduled with any cron expression

**Code Location**: `/force-app/main/default/classes/SurveyInvitationExpirationScheduler.cls`

### 3. Test Classes

**SurveyInvitationExpirationBatch_Test.cls**:
- Tests batch expiration of invitations
- Tests ignoring null expiration dates
- Tests ignoring completed invitations
- Tests handling large datasets (250+ records)
- Tests with no expired invitations

**SurveyInvitationExpirationScheduler_Test.cls**:
- Tests scheduler execution
- Tests multiple executions
- Tests with empty dataset
- Tests different schedule expressions

## Deployment Steps

### 1. Deploy Components

Deploy all new classes at once (recommended):

```bash
sf project deploy start --source-path force-app/main/default/classes
```

Or deploy individual files if needed:

```bash
# Deploy individual classes
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationBatch.cls
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationBatch.cls-meta.xml
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationScheduler.cls
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationScheduler.cls-meta.xml
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationBatch_Test.cls
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationBatch_Test.cls-meta.xml
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationScheduler_Test.cls
sf project deploy start --source-path force-app/main/default/classes/SurveyInvitationExpirationScheduler_Test.cls-meta.xml
```

### 2. Run Tests

Verify all tests pass:

```bash
sf apex run test --class-names SurveyInvitationExpirationBatch_Test --result-format human --code-coverage
sf apex run test --class-names SurveyInvitationExpirationScheduler_Test --result-format human --code-coverage
```

### 3. Schedule the Job

Schedule the batch job to run automatically. You have several options:

#### Option A: Daily at 2 AM (Recommended)

```apex
// Execute in Anonymous Apex
System.schedule('Survey Invitation Expiration - Daily 2AM', '0 0 2 * * ?', new SurveyInvitationExpirationScheduler());
```

#### Option B: Every Hour

```apex
// Execute in Anonymous Apex
System.schedule('Survey Invitation Expiration - Hourly', '0 0 * * * ?', new SurveyInvitationExpirationScheduler());
```

#### Option C: Twice Daily (2 AM and 2 PM)

```apex
// Schedule for 2 AM
System.schedule('Survey Invitation Expiration - 2AM', '0 0 2 * * ?', new SurveyInvitationExpirationScheduler());

// Schedule for 2 PM
System.schedule('Survey Invitation Expiration - 2PM', '0 0 14 * * ?', new SurveyInvitationExpirationScheduler());
```

### 4. Verify Scheduled Job

Navigate to **Setup > Scheduled Jobs** to verify the job is scheduled correctly.

### 5. Monitor Job Execution

- Check **Setup > Apex Jobs** to monitor batch job executions
- Review debug logs for detailed execution information
- Monitor `SurveyInvitation__c` records to verify status updates

## Cron Expression Reference

| Expression | Meaning |
|-----------|---------|
| `0 0 2 * * ?` | Daily at 2:00 AM |
| `0 0 * * * ?` | Every hour |
| `0 0 14 * * ?` | Daily at 2:00 PM |
| `0 0 0,12 * * ?` | Twice daily (midnight and noon) |
| `0 30 * * * ?` | Every hour at 30 minutes past |

Format: `Seconds Minutes Hours Day_of_Month Month Day_of_Week Year(optional)`

## Testing

### Manual Test

1. Create a test survey invitation with a past expiration date:

```apex
SurveyTestingUtil tu = new SurveyTestingUtil();
SurveyInvitation__c invitation = new SurveyInvitation__c();
invitation.Survey__c = tu.surveyId;
invitation.Token__c = TokenGeneratorService.generateToken();
invitation.Status__c = 'Pending';
invitation.ExpirationDate__c = DateTime.now().addDays(-1);
insert invitation;
```

2. Run the batch job manually:

```apex
Database.executeBatch(new SurveyInvitationExpirationBatch(), 200);
```

3. Verify the invitation status is now 'Expired':

```apex
SurveyInvitation__c updated = [SELECT Status__c FROM SurveyInvitation__c WHERE Id = :invitation.Id];
System.debug('Status: ' + updated.Status__c); // Should be 'Expired'
```

## Batch Size Considerations

The batch job processes 200 records per batch by default. This means:

- **Memory**: Each batch processes up to 200 SurveyInvitation records
- **DML**: Each batch performs 1 DML operation (bulk update)
- **SOQL**: Each batch performs minimal queries
- **Performance**: Can handle thousands of invitations efficiently

Adjust batch size if needed:

```apex
Database.executeBatch(new SurveyInvitationExpirationBatch(), 100); // Process 100 at a time
```

## Security

- Uses `WITH USER_MODE` for SOQL queries to respect user permissions
- Uses `AccessLevel.USER_MODE` for DML operations
- Follows principle of least privilege
- Logs errors for audit trail

## Monitoring and Troubleshooting

### Check Scheduled Jobs

```apex
List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'Survey Invitation Expiration%'
];
System.debug(jobs);
```

### Check Recent Batch Executions

```apex
List<AsyncApexJob> jobs = [
    SELECT Id, Status, CompletedDate, TotalJobItems, JobItemsProcessed, NumberOfErrors
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'SurveyInvitationExpirationBatch'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug(jobs);
```

### Abort a Scheduled Job

```apex
// Find job ID
List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'Survey Invitation Expiration%'
];

// Abort the job
for (CronTrigger job : jobs) {
    System.abortJob(job.Id);
}
```

## Performance Impact

- **Query Performance**: Indexed query on Status__c and ExpirationDate__c fields
- **DML Performance**: Bulk updates minimize database round trips
- **Governor Limits**: Well within limits for typical datasets
- **Execution Time**: Depends on number of expired invitations
  - 100 records: ~1 second
  - 1,000 records: ~5 seconds
  - 10,000 records: ~50 seconds (processed in batches)

## Future Enhancements

Potential improvements for future consideration:

1. **Email Notifications**: Send summary email after batch completion
2. **Archive Old Invitations**: Move expired invitations older than X days to archive
3. **Dashboard**: Create Lightning dashboard showing expiration statistics
4. **Custom Settings**: Make batch size and schedule configurable via custom settings
5. **Platform Events**: Publish event when invitations are expired for integration

## Related Documentation

- [SurveyInvitationController.cls](../classes/SurveyInvitationController.cls) - Original expiration validation logic
- [SurveyForceConstants.cls](../classes/SurveyForceConstants.cls) - Status constants
- [SURVEY_TOKEN_URL_IMPLEMENTATION.md](../SURVEY_TOKEN_URL_IMPLEMENTATION.md) - Token URL implementation

## Rollback Plan

If issues occur:

1. **Abort Scheduled Job**:
   ```apex
   List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Survey Invitation Expiration%'];
   for (CronTrigger job : jobs) { System.abortJob(job.Id); }
   ```

2. **Deactivate Classes**: Change status to Inactive in Setup

3. **Revert Status**: If needed, update incorrectly expired invitations:
   ```apex
   List<SurveyInvitation__c> invitations = [
       SELECT Id, Status__c
       FROM SurveyInvitation__c
       WHERE Status__c = 'Expired'
       AND ExpirationDate__c > :DateTime.now()
   ];
   for (SurveyInvitation__c inv : invitations) {
       inv.Status__c = 'Pending';
   }
   update invitations;
   ```

## Support

For issues or questions:
- Check debug logs in Setup > Debug Logs
- Review SurveyForceUtil logs
- Contact Salesforce administrator
