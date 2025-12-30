# Survey Token URL Implementation Guide

## Overview
This document explains how unique survey invitation URLs with tokens are generated for Training Request surveys in the Survey Force application.

## Problem Statement
The original implementation was generating single-use tokens immediately when Training Requests were created and storing those token URLs in the Training Request fields. This approach was incorrect because:
1. Tokens are meant for one-time use by specific recipients
2. Storing a single token URL meant only one person could access the survey
3. When participants were created, they couldn't get unique tokens because the Training Request already had one

## Solution Architecture

### Survey Creation (Training Request)
When a Training Request is created:
1. Three surveys are automatically created:
   - Participant Survey
   - Customer Survey
   - Trainer Survey
2. Non-token URLs (with Survey IDs) are stored in Training Request fields:
   - `Participant_Survey__c`
   - `Customer_Survey__c`
   - `Trainer_Survey__c`
3. URL Format: `https://[site-url]/TakeSurvey?id=[SURVEY_ID]`

**Example:**
```
https://example.force.com/TakeSurvey?id=a0X5e000001ABc3DEF
```

### Token Generation (On-Demand)

#### For Participants
Tokens are automatically generated when participant records are created:

1. **Trigger:** `ParticipantsTrigger` fires on insert
2. **Handler:** `ParticipantsTriggerHandler.generateParticipantSurveys()`
3. **Process:**
   - Extracts Survey ID from Training Request's Participant_Survey__c URL
   - Calls `SurveyUtilities.generateParticipantSurveyLinks()`
   - Creates SurveyInvitation record with unique token
   - Updates Participant record with token URL
4. **Result:** Unique token URL stored in `Participant__c.Participant_Survey__c`
5. **URL Format:** `https://[site-url]/survey?token=[UNIQUE_TOKEN]`

**Example:**
```
https://example.my.site.com/survey?token=7c336c49-b2df-4384-f531-f1413cba7962
```

#### For Customers and Trainers
Tokens are generated on-demand using one of these methods:

##### Method 1: Using Flow with Invocable Action (Recommended)
1. Create a Flow (Screen Flow, Record-Triggered Flow, etc.)
2. Add Action: "Generate Survey Invitation"
3. Configure inputs:
   - Survey ID (from Training Request Customer_Survey__c or Trainer_Survey__c)
   - Training Request ID
   - Survey Type ("Customer" or "Trainer")
   - Recipient Email (optional)
   - Recipient Name (optional)
4. The action returns:
   - Success indicator
   - Survey URL with token
   - Token value
   - Invitation ID
   - Error message (if failed)

##### Method 2: Using Apex
```apex
// Extract Survey ID from Training Request
Id surveyId = /* extract from URL */;
Id trainingRequestId = /* Training Request ID */;

// Generate invitation
String tokenUrl = SurveyUtilities.generateSingleSurveyInvitation(
    surveyId, 
    trainingRequestId, 
    'Customer'
);
```

##### Method 3: Manual SurveyInvitation Creation
1. Create a SurveyInvitation__c record manually
2. Set Survey__c to the survey ID
3. Leave Token__c blank (will be auto-generated if not provided)
4. Set Status__c to 'Pending'
5. Query the record to get the token
6. Build URL: `https://[site-url]/survey?token=[TOKEN]`

## URL Formats

### Non-Token URL (Stored in Training Request)
```
https://[site-url]/TakeSurvey?id=[SURVEY_ID]
```
- Used for: Storing survey references
- Allows: Multiple unique tokens to be generated
- Not meant for: Direct access by end users

### Token URL (Generated for Recipients)
```
https://[site-url]/survey?token=[UNIQUE_TOKEN]
```
- Used for: One-time access by specific recipient
- Allows: Secure, trackable survey completion
- Each recipient gets: Their own unique token

## Site URL Configuration

Token URLs use the correct Experience Site base URL determined in this priority order:

1. **SiteURL Custom Metadata** (Highest Priority)
   - Configured per training type (EAP Training, Reseller Training, etc.)
   - Setup: Custom Metadata Type record > SiteURL__mdt
   - Example: `https://training.my.site.com`

2. **Site.getBaseUrl()** (Medium Priority)
   - Returns current Experience Site URL if running in site context
   - Example: `https://community.my.site.com`

3. **Org Domain URL** (Fallback)
   - Returns internal Salesforce org URL
   - Example: `https://myorg.my.salesforce.com`
   - **Note:** This should only be used for internal users, not external Experience Site users

## Data Model

### Survey__c
- Standard Survey object
- Contains questions and configuration

### Training_Request__c
- `Participant_Survey__c` (URL): Non-token URL to participant survey
- `Customer_Survey__c` (URL): Non-token URL to customer survey  
- `Trainer_Survey__c` (URL): Non-token URL to trainer survey

### Participants__c
- `Training_Request__c` (Lookup): Related Training Request
- `Participant_Survey__c` (URL): Unique token URL for this participant

### SurveyInvitation__c
- `Survey__c` (Lookup): The survey
- `Token__c` (Text): Unique token (UUID format)
- `Status__c` (Picklist): Pending, Completed, Expired
- `RelatedRecordId__c` (Text): Training Request ID or other related record
- `Email__c` (Email): Recipient email (optional)
- `ParticipantName__c` (Text): Recipient name (optional)

## Example Flow: Generate Customer Survey Invitation

### Flow Configuration
1. **Object:** Training_Request__c
2. **Trigger:** Record is updated
3. **Condition:** Customer_Survey__c is not blank AND Customer_Email__c is not blank

### Flow Elements
1. **Decision:** Check if invitation already exists
   - Query SurveyInvitation__c WHERE RelatedRecordId__c = {!$Record.Id} AND ParticipantName__c = 'Customer Survey'
   
2. **Action:** Generate Survey Invitation (if not exists)
   - Action: Generate Survey Invitation
   - Survey ID: Extract from Customer_Survey__c
   - Training Request ID: {!$Record.Id}
   - Survey Type: 'Customer'
   - Recipient Email: {!$Record.Customer_Email__c}
   - Recipient Name: {!$Record.Customer_Name__c}

3. **Assignment:** Store token URL (if needed)
   - Could update a custom field on Training Request
   - Or send email with the token URL

4. **Send Email:** Email the survey link to customer
   - To: {!$Record.Customer_Email__c}
   - Body: Contains {!InvitationResult.surveyUrl}

## Security Considerations

1. **Token Uniqueness:** Each token is a cryptographically generated UUID
2. **One-Time Use:** Tokens should be marked as 'Completed' after survey submission
3. **Expiration:** Configure expiration days in SurveySettings__c custom setting
4. **Sharing:** SurveyInvitation records respect user/sharing settings
5. **Guest Access:** Experience Site guest users can access surveys via token without authentication

## Troubleshooting

### "URL No Longer Exists" Error
**Cause:** Token URL points to wrong base URL or token is invalid/expired

**Solutions:**
1. Verify SiteURL custom metadata is configured correctly
2. Check token exists in SurveyInvitation__c
3. Verify token Status__c is 'Pending' (not 'Completed' or 'Expired')
4. Ensure Experience Site has /survey page configured with surveyTaker component

### Token URLs Not Working in Experience Site
**Cause:** Experience Site page not configured

**Solution:**
1. Go to Experience Builder
2. Create or navigate to survey page
3. Ensure URL is `/survey`
4. Add `surveyTaker` LWC component
5. Publish site

### Participants Not Getting Unique URLs
**Cause:** ParticipantsTrigger not firing or Training Request survey URL is blank

**Solution:**
1. Verify Training Request has Participant_Survey__c populated
2. Check ParticipantsTrigger is active
3. Review debug logs for errors in ParticipantsTriggerHandler

## Best Practices

1. **Always use Invocable Action in Flows** for generating Customer/Trainer invitations
2. **Don't share token URLs publicly** - each is meant for one recipient
3. **Monitor SurveyInvitation records** for completed/expired tokens
4. **Configure appropriate expiration** in SurveySettings__c
5. **Test token URLs** in the actual Experience Site before sending to users
6. **Use meaningful names** in ParticipantName__c for tracking
7. **Track related records** using RelatedRecordId__c for reporting

## Testing

### Unit Tests
- `SurveyUtilities_Test.cls`: Tests bulk token generation
- `TrainingRequestTriggerHandler_Test.cls`: Tests survey creation without tokens
- `ParticipantsTriggerHandler_Test.cls`: Tests participant token generation
- `GenerateSurveyInvitationAction_Test.cls`: Tests Invocable Action

### Manual Testing Steps
1. Create a Training Request
2. Verify three survey URLs (non-token) are created
3. Create a Participant record
4. Verify participant gets unique token URL
5. Create a Flow to generate Customer invitation
6. Verify unique token URL is generated
7. Access token URL in Experience Site
8. Verify survey loads correctly
9. Submit survey
10. Verify token status changes to 'Completed'

## Additional Resources

- Salesforce Documentation: [Experience Sites](https://help.salesforce.com/s/articleView?id=sf.networks_overview.htm)
- Salesforce Documentation: [Lightning Web Components](https://developer.salesforce.com/docs/component-library/overview/components)
- Survey Force README: `readme.md`
- LWC Migration Guide: `LWC_MIGRATION_GUIDE.md`
