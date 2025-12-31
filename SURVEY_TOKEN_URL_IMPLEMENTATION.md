# Survey Token URL Implementation Guide

## Overview

This document explains how unique survey invitation URLs with tokens are automatically generated for Training Request surveys in the Survey Force application.

## Problem Statement

The system needed to generate unique, secure survey URLs for multiple recipients accessing the same survey. The solution needed to support:

1. Automatic token generation for Customer and Trainer surveys
2. Unique tokens for each participant when they're added
3. Correct Experience Site base URLs

## Solution Architecture

### Survey Creation (Training Request)

When a Training Request is created:

1. Three surveys are automatically created:
   - Participant Survey
   - Customer Survey
   - Trainer Survey
2. Three Survey Invitation records are automatically created with unique tokens
3. Token-based URLs are stored in Training Request fields:
   - `Participant_Survey__c`
   - `Customer_Survey__c`
   - `Trainer_Survey__c`
4. URL Format: `https://[site-url]/survey?token=[UNIQUE_TOKEN]`

**Example:**

```
https://example.my.site.com/survey?token=7c336c49-b2df-4384-f531-f1413cba7962
```

### Token Generation (Automatic)

#### For Customer and Trainer Surveys

Tokens are automatically generated when Training Request is created:

1. **Trigger:** `TrainingRequestTrigger` fires on insert
2. **Handler:** `TrainingRequestTriggerHandler.createSurveysForTrainingRequests()`
3. **Process:**
   - Creates surveys for Participant, Customer, and Trainer
   - Calls `SurveyUtilities.generateSurveyInvitationsInBulk()`
   - Creates 3 SurveyInvitation records with unique tokens
   - Updates Training Request with token-based URLs
4. **Result:** Token URLs stored in Training Request fields for immediate use
5. **URL Format:** `https://[site-url]/survey?token=[UNIQUE_TOKEN]`

#### For Participants

Additional unique tokens are generated when participant records are created:

1. **Trigger:** `ParticipantsTrigger` fires on insert
2. **Handler:** `ParticipantsTriggerHandler.generateParticipantSurveys()`
3. **Process:**
   - Extracts Survey ID from Training Request's Participant_Survey\_\_c token URL
   - Calls `SurveyUtilities.generateParticipantSurveyLinks()`
   - Creates NEW SurveyInvitation record with unique token for this participant
   - Updates Participant record with their unique token URL
4. **Result:** Each participant gets their own unique token (different from Training Request token)
5. **URL Format:** `https://[site-url]/survey?token=[UNIQUE_TOKEN]`

**Example:**

```
https://example.my.site.com/survey?token=a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

#### Additional Token Generation (Optional)

If additional tokens are needed beyond the automatic ones, use one of these methods:

##### Method 1: Using Apex

```apex
// Extract Survey ID from token URL if needed
Id surveyId = /* extract from token URL via SurveyInvitation query */;
Id trainingRequestId = /* Training Request ID */;

// Generate additional invitation
String tokenUrl = SurveyUtilities.generateSingleSurveyInvitation(
    surveyId,
    trainingRequestId,
    'Customer'
);
```

##### Method 2: Manual SurveyInvitation Creation

1. Create a SurveyInvitation\_\_c record manually
2. Set Survey\_\_c to the survey ID (extract from existing token URL)
3. Leave Token\_\_c blank (will be auto-generated)
4. Set Status\_\_c to 'Pending'
5. Query the record to get the token
6. Build URL: `https://[site-url]/survey?token=[TOKEN]`

## URL Formats

### Token URL (Stored in Training Request and Participants)

```
https://[site-url]/survey?token=[UNIQUE_TOKEN]
```

- Used for: Direct access by end users
- Each token is: Unique, one-time use, cryptographically secure
- Training Request: Gets 3 tokens (one per survey type)
- Participants: Each gets their own unique token
- Additional tokens: Can be generated via Apex methods if needed
- Allows: Secure, trackable survey completion
- Each recipient gets: Their own unique token

## Site URL Configuration

Token URLs use the correct Experience Site base URL determined in this priority order:

1. **SiteURL Custom Metadata** (Highest Priority)
   - Configured per training type (EAP Training, Reseller Training, etc.)
   - Setup: Custom Metadata Type record > SiteURL\_\_mdt
   - Example: `https://training.my.site.com`

2. **Site.getBaseUrl()** (Medium Priority)
   - Returns current Experience Site URL if running in site context
   - Example: `https://community.my.site.com`

3. **Org Domain URL** (Fallback)
   - Returns internal Salesforce org URL
   - Example: `https://myorg.my.salesforce.com`
   - **Note:** This should only be used for internal users, not external Experience Site users

## Data Model

### Survey\_\_c

- Standard Survey object
- Contains questions and configuration

### Training_Request\_\_c

- `Participant_Survey__c` (URL): Token-based URL to participant survey (auto-generated)
- `Customer_Survey__c` (URL): Token-based URL to customer survey (auto-generated)
- `Trainer_Survey__c` (URL): Token-based URL to trainer survey (auto-generated)

### Participants\_\_c

- `Training_Request__c` (Lookup): Related Training Request
- `Participant_Survey__c` (URL): Unique token URL for this specific participant (auto-generated)

### SurveyInvitation\_\_c

- `Survey__c` (Lookup): The survey
- `Token__c` (Text): Unique token (UUID format)
- `Status__c` (Picklist): Pending, Completed, Expired
- `RelatedRecordId__c` (Text): Training Request ID or other related record
- `Email__c` (Email): Recipient email (optional)
- `ParticipantName__c` (Text): Recipient name (optional)

## Example: Generate Additional Customer Survey Invitation

This is optional - Customer surveys already have a token URL in the Training Request. Use this only if you need additional tokens for the same survey.

You can use the Apex method `SurveyUtilities.generateSingleSurveyInvitation()` to create additional survey invitations programmatically. For example:

```apex
// Extract Survey ID from token URL if needed
Id surveyId = /* extract from token URL via SurveyInvitation query */;
Id trainingRequestId = /* Training Request ID */;

// Generate additional invitation
String tokenUrl = SurveyUtilities.generateSingleSurveyInvitation(
    surveyId,
    trainingRequestId,
    'Customer'
);

// Use the tokenUrl in email or store it in a custom field
```

## Security Considerations

1. **Token Uniqueness:** Each token is a cryptographically generated UUID
2. **One-Time Use:** Tokens should be marked as 'Completed' after survey submission
3. **Expiration:** Configure expiration days in SurveySettings\_\_c custom setting
4. **Sharing:** SurveyInvitation records respect user/sharing settings
5. **Guest Access:** Experience Site guest users can access surveys via token without authentication

## Troubleshooting

### "URL No Longer Exists" Error

**Cause:** Token URL points to wrong base URL or token is invalid/expired

**Solutions:**

1. Verify SiteURL custom metadata is configured correctly
2. Check token exists in SurveyInvitation\_\_c
3. Verify token Status\_\_c is 'Pending' (not 'Completed' or 'Expired')
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

1. Verify Training Request has Participant_Survey\_\_c populated
2. Check ParticipantsTrigger is active
3. Review debug logs for errors in ParticipantsTriggerHandler

## Best Practices

1. **Use SurveyUtilities methods** for generating additional survey invitations if needed beyond the automatic ones
2. **Don't share token URLs publicly** - each is meant for one recipient
3. **Monitor SurveyInvitation records** for completed/expired tokens
4. **Configure appropriate expiration** in SurveySettings\_\_c
5. **Test token URLs** in the actual Experience Site before sending to users
6. **Use meaningful names** in ParticipantName\_\_c for tracking
7. **Track related records** using RelatedRecordId\_\_c for reporting

## Testing

### Unit Tests

- `SurveyUtilities_Test.cls`: Tests bulk token generation
- `TrainingRequestTriggerHandler_Test.cls`: Tests survey creation and automatic token generation
- `ParticipantsTriggerHandler_Test.cls`: Tests participant token generation

### Manual Testing Steps

1. Create a Training Request
2. Verify three token-based survey URLs are automatically created
3. Create a Participant record
4. Verify participant gets unique token URL
5. Access token URL in Experience Site
6. Verify survey loads correctly
7. Submit survey
8. Verify token status changes to 'Completed'

## Additional Resources

- Salesforce Documentation: [Experience Sites](https://help.salesforce.com/s/articleView?id=sf.networks_overview.htm)
- Salesforce Documentation: [Lightning Web Components](https://developer.salesforce.com/docs/component-library/overview/components)
- Survey Force README: `readme.md`
- LWC Migration Guide: `LWC_MIGRATION_GUIDE.md`
