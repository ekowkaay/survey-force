# Survey Regeneration Guide

## Overview

The Survey Regeneration feature allows administrators to regenerate survey links and invitations for Training Request records when survey templates or questions have been updated. This ensures that participants receive surveys with the latest content.

## When to Use

Use the survey regeneration feature when:

- **Survey template questions have been updated** - You've modified the survey template and need existing Training Requests to use the new version
- **Survey content needs to be refreshed** - You need to redistribute surveys with updated content
- **Links need to be refreshed for security reasons** - You want to invalidate old links and generate new ones
- **Bulk regeneration is needed** - You have multiple Training Requests that need new survey links

## How It Works

The regeneration process:

1. **Deletes existing survey invitations** - All existing SurveyInvitation records for the selected Training Requests are deleted
2. **Generates new tokens** - Fresh tokens are generated for new survey invitations
3. **Creates new invitations** - New SurveyInvitation records are created with new tokens
4. **Updates URLs** - Training Request and Participant records are updated with new survey URLs
5. **Invalidates old links** - Previous survey links will no longer work

### Survey Types Regenerated

- **Participant Surveys** - Creates new invitations for all participants linked to the Training Request
- **Customer Surveys** - Creates a new invitation for the customer survey
- **Trainer Surveys** - Creates a new invitation for the trainer survey

## Usage Instructions

### Method 1: Using the Lightning Web Component (Recommended)

1. **Navigate to Survey Regeneration**
   - Go to the "Survey Regeneration" tab in the Survey Force app
   - OR click on "Regenerate Survey Links" quick action on a Training Request record page
   - OR launch with URL parameters: `?c__ids=id1,id2,id3` to pre-populate records

2. **Select Records**
   - **Option A: Search and Add** (Default)
     - Use the record picker to search for records by name
     - Click "Add Record" to add each selected record to the list
   - **Option B: Bulk ID Input** (Faster for multiple records)
     - Toggle "Use bulk ID input" to ON
     - Paste comma, semicolon, or newline-separated record IDs or names
     - Click "Parse and Add Records" to add them to the list
   - Selected records appear in a table below with the option to remove individual records or clear all

3. **Configure Advanced Settings (Optional)**
   - Leave "Use custom object settings" OFF for Training_Request__c defaults
   - Turn it ON to regenerate surveys for custom objects:
     - **Related Record Configuration**: Specify object API name and training type field
     - **Customer & Trainer Survey Fields**: Map survey URL fields on parent record
     - **Participant Configuration**: Map participant object and field relationships

4. **Select Survey Types**
   - Check the boxes for which survey types to regenerate:
     - ☑ Regenerate Participant Survey Links
     - ☑ Regenerate Customer Survey Links
     - ☑ Regenerate Trainer Survey Links
   - Default: All survey types are selected

5. **Review Your Selection**
   - Click "Next" to proceed to the confirmation screen
   - Review the summary:
     - Count of selected records
     - Object type being processed
     - Survey types enabled
     - Preview of selected records (for lists up to 20 records)
   - Review the warning about the irreversible action

6. **Confirm & Execute**
   - Click "Confirm & Regenerate" to execute
   - Watch the progress indicator showing processing steps
   - Wait for the operation to complete (typically 5-30 seconds depending on volume)

7. **View Results**
   - Review the results summary with detailed statistics:
     - Records processed, successful, and failed
     - Participant, customer, and trainer links generated
   - Check error details if any issues occurred
   - Review next steps guidance
   - Click "Regenerate More" to start a new regeneration

### Method 2: Using Apex (Advanced)

For developers or system administrators who need programmatic access:

```apex
// Create a regeneration request
SurveyRegenerationController.RegenerationRequest request = new SurveyRegenerationController.RegenerationRequest();
request.trainingRequestIds = new List<Id>{ 'a0X...' }; // Add Training Request IDs
request.regenerateParticipant = true;
request.regenerateCustomer = true;
request.regenerateTrainer = true;

// Execute regeneration
List<SurveyRegenerationController.RegenerationResult> results = 
    SurveyRegenerationController.regenerateSurveyLinks(
        new List<SurveyRegenerationController.RegenerationRequest>{ request }
    );

// Check results
SurveyRegenerationController.RegenerationResult result = results[0];
System.debug('Success: ' + result.success);
System.debug('Message: ' + result.message);
System.debug('Participant Links: ' + result.participantLinksGenerated);
System.debug('Customer Links: ' + result.customerLinksGenerated);
System.debug('Trainer Links: ' + result.trainerLinksGenerated);
```

## Bulk Operations Best Practices

The regeneration process is fully bulkified and can handle large volumes of data efficiently. However, follow these best practices:

### Recommended Limits

- **Single Transaction**: Up to 200 Training Request records per execution
- **Participants**: No limit - the process handles all participants for selected Training Requests
- **Survey Invitations**: Automatically bulkified to handle large volumes

### Performance Considerations

1. **SOQL Queries**: The process uses efficient SOQL queries to minimize governor limit usage
   - One query for Training Requests
   - One query for Participants
   - One query for existing Survey Invitations
   - One query for Survey metadata

2. **DML Operations**: All DML operations are bulkified
   - Single delete for all existing invitations
   - Single insert for all new invitations
   - Single update for all Training Requests
   - Single update for all Participants

3. **Processing Time**: 
   - Small batches (1-10 records): < 5 seconds
   - Medium batches (10-50 records): 5-15 seconds
   - Large batches (50-200 records): 15-30 seconds

### Batch Processing Strategy

For very large volumes (>200 Training Requests):

1. **Split into batches** - Process in batches of 200 records
2. **Monitor results** - Check the results after each batch
3. **Handle errors** - Address any errors before proceeding to the next batch

## Permissions Required

Users must have the following permission set assigned:

- **SurveyForce Survey Regeneration Execute** - Grants access to:
  - `SurveyRegenerationController` Apex class
  - Training_Request__c object (Read/Edit)
  - SurveyInvitation__c object (Create/Read/Edit/Delete)
  - Survey__c object (Read)
  - Participants__c object (Read/Edit)
  - All required field-level permissions

### Assigning Permissions

1. Navigate to Setup > Permission Sets
2. Find "SurveyForce Survey Regeneration Execute"
3. Click "Manage Assignments"
4. Add users who need to regenerate surveys

## Important Warnings

⚠️ **This action cannot be undone**
- Once survey links are regenerated, old links are permanently invalidated
- Participants will need to use the new links to complete surveys
- Any in-progress surveys using old links will not be accessible

⚠️ **Communicate with participants**
- Notify participants that new survey links will be sent
- Old links will no longer work
- Provide the new links promptly

⚠️ **Plan your regeneration**
- Choose an appropriate time when participants are not actively taking surveys
- Consider bulk regenerating during off-hours
- Test with a small batch first

## Troubleshooting

### Common Issues

**Problem**: "No Training Requests found"
- **Solution**: Verify the Training Request IDs are correct and exist in the system

**Problem**: "Survey template not found"
- **Solution**: Ensure survey templates exist with the correct names:
  - "Participant Survey Template - English"
  - "Customer Survey Template"
  - "Trainer Survey Template"

**Problem**: "Insufficient permissions"
- **Solution**: Assign the "SurveyForce Survey Regeneration Execute" permission set to the user

**Problem**: "No participants found"
- **Solution**: This is expected if the Training Request has no participants. Customer and Trainer surveys will still be regenerated.

**Problem**: Bulk ID input not parsing correctly
- **Solution**: 
  - Ensure IDs are valid 15 or 18-character Salesforce IDs
  - Separate IDs with commas, semicolons, or new lines
  - Remove any extra spaces or special characters
  - Try adding records one at a time to identify invalid IDs

**Problem**: Custom object settings not working
- **Solution**:
  - Verify all field API names are correct (case-sensitive)
  - Check that you have access to the custom object and fields
  - Use field-level help icons for guidance on each field
  - Test with a single record first before bulk operations

**Problem**: Selected records cleared accidentally
- **Solution**: 
  - The system now confirms before clearing when toggling custom settings
  - Re-add records using bulk input or record picker
  - Consider using URL parameters to pre-populate: `?c__ids=id1,id2,id3`

### Error Recovery

If regeneration fails for some records:

1. **Review error details** - Check the error message in the results screen
2. **Fix the issue** - Address the underlying problem (e.g., missing surveys, permissions)
3. **Retry** - Run the regeneration again for the failed records only
4. **Contact support** - If the issue persists, contact your Salesforce administrator

## Security Considerations

### Token Security

- New tokens are generated using a cryptographically secure random generator
- Tokens are unique and cannot be guessed
- Old tokens are immediately invalidated upon regeneration

### Data Access

- Users can only regenerate surveys for Training Requests they have access to
- Record-level security is enforced (sharing rules apply)
- Field-level security is enforced for all operations

### Audit Trail

- All regeneration operations are logged in Salesforce debug logs
- Field history tracking (if enabled) will show changes to survey URL fields
- Consider enabling field history tracking on:
  - Training_Request__c.Participant_Survey__c
  - Training_Request__c.Customer_Survey__c
  - Training_Request__c.Trainer_Survey__c

## User Experience Improvements (January 2026)

The Lightning Web Component has been enhanced with several UX improvements for a better user experience:

### Bulk Input Options
- **Toggle Between Input Methods**: Switch between record picker (search) and bulk ID input
- **Paste Multiple IDs**: Enter comma, semicolon, or newline-separated record IDs or names
- **Instant Parsing**: One-click parsing and validation of bulk entries
- **Record Preview**: View selected records in a table with individual remove options

### Enhanced Confirmation
- **Selection Summary**: See count, object type, and survey types before confirming
- **Record Preview**: View the first 10-20 selected records in badge format
- **Clear Warnings**: Better visual hierarchy for irreversible action warnings
- **Easy Navigation**: Back button to return and modify selections

### Better Loading Feedback
- **Progress Messages**: Dynamic loading messages showing processing status
- **Step Breakdown**: Visual list of processing steps being performed
- **Processing Count**: Know how many records are being processed
- **Estimated Context**: Understand what's happening during execution

### Improved Advanced Settings
- **Field Grouping**: Logical sections for Related Record, Customer/Trainer, and Participant settings
- **Contextual Help**: Field-level help text explains each configuration option
- **Visual Hierarchy**: Icons and headings make sections easy to scan
- **Responsive Layout**: Better mobile and tablet support with breakpoints

### Enhanced Error Handling
- **Structured Errors**: Better formatting with monospace font for technical details
- **Actionable Guidance**: "What to do next" section with recovery steps
- **Visual Emphasis**: Warning theme with accent border for visibility
- **Scrollable Details**: Long error messages scroll independently

### Accessibility Enhancements
- **ARIA Labels**: Screen reader support throughout the component
- **Live Regions**: Status updates announced to assistive technologies
- **Semantic HTML**: Proper heading hierarchy and landmark roles
- **Keyboard Navigation**: Full keyboard support for all interactions

### Safety Features
- **Confirmation Dialog**: Warns before clearing selected records when toggling settings
- **Data Loss Prevention**: Protects against accidental record list clearing
- **URL Parameter Support**: Direct linking with pre-populated record IDs

## Extension for Other Objects

The regeneration controller is designed to be extensible. To add support for other custom objects:

1. **Implement the data structure**
   - Ensure the object has survey URL fields
   - Ensure there's a way to extract survey IDs from URLs

2. **Create a new invocable method** (optional)
   - Copy the pattern from `SurveyRegenerationController`
   - Adjust the SOQL queries and logic for your object

3. **Create a new flow** (optional)
   - Clone the "Regenerate Survey Links" flow
   - Adjust the screens and variables for your object

4. **Update permission sets**
   - Grant access to your custom object
   - Grant field-level permissions for survey fields

## Support

For additional assistance:

- **Documentation**: Review the Salesforce object documentation
- **Administrator**: Contact your Salesforce administrator
- **Developer**: Review the source code in `SurveyRegenerationController.cls`

## Version History

- **v1.0** (January 2026) - Initial release
  - Support for Training Request regeneration
  - Bulk operations support
  - Screen flow integration
  - Comprehensive error handling
