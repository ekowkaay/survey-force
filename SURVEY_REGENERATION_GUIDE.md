# Survey Regeneration Feature

## Overview

The Survey Regeneration feature provides administrators with a streamlined wizard interface to regenerate survey invitations in bulk for Training Requests. This feature allows admins to upload Training Request IDs via file or manual entry, select which survey types to regenerate, and automatically create new invitations while cleaning up old ones.

## Key Features

### 1. File Upload Wizard
- **Multi-format Support**: Upload Training Request IDs in .txt or .csv files
- **Flexible Parsing**: Automatically handles comma-separated, newline-separated, or space-separated IDs
- **Manual Entry Option**: Paste IDs directly into a text area if you don't have a file
- **Validation**: Validates Salesforce ID format (15 or 18 characters) before processing

### 2. Survey Type Selection
- **Granular Control**: Select which survey types to regenerate:
  - **Customer Surveys**: Single-invitation surveys for customer feedback
  - **Trainer Surveys**: Single-invitation surveys for trainer evaluation
  - **Participant Surveys**: Multi-invitation surveys for all participants in a training
- **Multi-select**: Regenerate multiple survey types simultaneously

### 3. Smart Invitation Regeneration
- **Automatic Cleanup**: Deletes existing pending invitations before creating new ones
- **Participant Support**: For participant surveys, automatically creates invitations for all associated participants
- **Preserves Completed Data**: Only deletes pending invitations; completed responses remain intact
- **Bulk Processing**: Handles multiple Training Requests and surveys efficiently

### 4. Enhanced User Experience
- **4-Step Wizard**: Clear progress indicator showing upload → select → confirm → complete
- **Real-time Feedback**: Live validation and error messaging at each step
- **Preview & Confirmation**: Review exactly which surveys will be regenerated before proceeding
- **Success/Failure Reporting**: Detailed results showing successful regenerations and any errors
- **Responsive Design**: Works seamlessly on desktop and mobile devices

## Usage Guide

### Accessing the Feature

1. Navigate to the **Survey Force** app in Salesforce
2. Click on the **Survey Regeneration** tab
3. The Survey Regeneration Wizard will open

### Step 1: Upload Training Request IDs

**Option A: File Upload**
1. Click "Upload Training Request IDs"
2. Select a .txt or .csv file containing Training Request IDs
3. The system will automatically parse and validate the IDs
4. View the count of successfully parsed IDs

**Option B: Manual Entry**
1. Paste Training Request IDs into the "Or paste IDs manually" text area
2. IDs can be separated by commas, spaces, or newlines
3. The system will automatically parse and validate the IDs

**Example Input Formats:**
```
# Comma-separated
a0X1234567890ABC, a0X1234567890DEF, a0X1234567890GHI

# Newline-separated
a0X1234567890ABC
a0X1234567890DEF
a0X1234567890GHI

# Space-separated
a0X1234567890ABC a0X1234567890DEF a0X1234567890GHI
```

### Step 2: Select Survey Types

1. Check the boxes for the survey types you want to regenerate:
   - ☐ **Customer Surveys**: Regenerate customer feedback surveys
   - ☐ **Trainer Surveys**: Regenerate trainer evaluation surveys
   - ☐ **Participant Surveys**: Regenerate participant surveys (includes all participants)

2. The system will search for surveys matching your criteria
3. View the count of surveys found
4. Click "Next" to review

### Step 3: Confirm Regeneration

1. Review the summary statistics:
   - Number of surveys to regenerate
   - Number of Training Requests affected

2. Review the detailed table of surveys:
   - Training Request name
   - Survey name
   - Survey type

3. **Important Warning**: Read the warning message carefully:
   - Existing **pending** invitations will be deleted
   - Completed invitations will **not** be affected
   - New invitations will be created

4. Click "Regenerate Invitations" to proceed

### Step 4: Complete

1. View the regeneration results:
   - Success count
   - Failure count
   - Error details (if any)

2. Click "Start New Regeneration" to process more Training Requests

## Technical Details

### Apex Controller: SurveyRegenerationController

**Methods:**
- `parseTrainingRequestIds(String fileContent)`: Parses IDs from file content
- `getSurveysForRegeneration(List<String> trainingRequestIds, List<String> surveyTypes)`: Retrieves surveys to regenerate
- `regenerateSurveyInvitations(List<String> surveyIds, List<String> surveyTypes)`: Deletes old invitations and creates new ones

**Key Features:**
- Bulkified operations for governor limit compliance
- User-mode security enforcement (WITH USER_MODE)
- Field-level security checks via SurveyForceUtil.accessController
- Comprehensive error handling and logging

### Lightning Web Component: surveyRegenerationWizard

**Component Structure:**
- **HTML**: Multi-step wizard with progress indicator
- **JavaScript**: State management, file handling, and Apex integration
- **CSS**: SLDS-compliant styling with animations and responsive design

**Key Features:**
- File upload with FileReader API
- Real-time validation
- Dynamic UI updates
- Toast notifications for user feedback

### Permission Set: SurveyApp_Regeneration_Admin

**Grants Access To:**
- SurveyRegenerationController Apex class
- Survey Regeneration tab

**Assignment:**
Assign this permission set to users who need to regenerate survey invitations.

## Best Practices

1. **Test First**: Before regenerating invitations for production data, test with a small set of Training Request IDs

2. **Verify Survey Types**: Double-check which survey types you've selected before confirming

3. **Participant Surveys**: When regenerating participant surveys, ensure all participants have been added to the Training Request first

4. **Timing**: Regenerate invitations when participants haven't started taking surveys yet to avoid confusion

5. **Communication**: Notify participants when new survey links are generated, as old links will no longer work

## Troubleshooting

### Common Issues

**Issue**: "No surveys found for the selected types"
- **Solution**: Verify that the Training Requests have surveys created for the selected types. Check the Training Request fields: Participant_Survey__c, Customer_Survey__c, Trainer_Survey__c

**Issue**: "Invalid ID" errors
- **Solution**: Ensure IDs are valid Salesforce IDs (15 or 18 characters). Remove any special characters or extra whitespace

**Issue**: "No participants found for survey"
- **Solution**: For participant surveys, verify that participants have been added to the Training Request before regenerating

**Issue**: Regeneration fails for some surveys
- **Solution**: Check the error messages in the completion step. Common causes:
  - Permission issues: Ensure you have the SurveyApp_Regeneration_Admin permission set
  - Data issues: Verify the Training Request and Survey records exist

## Security Considerations

1. **User Mode Enforcement**: All queries and DML operations run in user mode (WITH USER_MODE)
2. **FLS Checks**: Field-level security is enforced via SurveyForceUtil.accessController
3. **Permission Set Required**: Users must have the SurveyApp_Regeneration_Admin permission set
4. **Completed Invitations Protected**: Only pending invitations are deleted; completed responses remain intact

## Governor Limits

The feature is designed to handle large datasets efficiently:
- **Bulkified Queries**: All SOQL queries are bulkified
- **Bulkified DML**: All insert/update/delete operations are bulkified
- **Batch Processing**: Large sets of Training Requests are processed efficiently

**Recommended Limits:**
- Maximum Training Request IDs per regeneration: **1000**
- System automatically validates and processes in bulk

## Future Enhancements

Potential improvements for future releases:
1. Email notification to participants when invitations are regenerated
2. Schedule regeneration for future dates
3. Export regeneration history/audit log
4. Support for custom object IDs beyond Training Requests
5. Advanced filtering options (by date, status, etc.)

## Support

For issues or questions:
1. Check the error messages in the wizard
2. Verify permission set assignment
3. Review the troubleshooting section above
4. Contact your Salesforce administrator

## Version History

**Version 1.0** (Current)
- Initial release
- File upload with CSV/TXT support
- Multi-survey type selection
- Bulk regeneration for Customer, Trainer, and Participant surveys
- Comprehensive error handling and reporting
