# Site Guest User Profile Configuration Guide

## Overview
This guide explains how to configure a site guest user profile to enable external users to view the survey taker page and submit responses via Experience Sites (formerly Communities).

## Prerequisites
- An Experience Site must be created and published
- Survey Force package must be installed
- The `surveyTaker` Lightning Web Component should be added to an Experience Site page

## Configuration Steps

### 1. Assign the Survey Force - Guest Permission Set

The easiest way to configure guest user access is to assign the `Survey_Force_Guest` permission set to your site's guest user profile:

1. Navigate to **Setup** → **Digital Experiences** → **All Sites**
2. Click on your site name
3. Click **Workspaces** → **Administration**
4. Click **Preferences** in the left sidebar
5. Under "Guest User Profile", click on the profile link (e.g., "Site Guest User")
6. Click **Permission Set Assignments**
7. Click **Assign Permission Sets**
8. Select **Survey Force - Guest**
9. Click **Assign**

### 2. What the Survey Force - Guest Permission Set Provides

The permission set grants the following access:

#### Apex Classes
- `SFDCAccessControlException` - Execute
- `SFDCAccessController` - Execute
- `SurveyForceUtil` - Execute
- `SurveyTakerController` - Execute (primary controller for survey taking)
- `ViewSurveyControllerWithoutSharing` - Execute (enables data access without sharing rules)

#### Object Permissions

##### Survey__c (Read Only)
- **Read**: Yes
- **Fields**: All necessary survey configuration fields

##### Survey_Question__c (Read Only)
- **Read**: Yes
- **Fields**: Question text, type, choices, order, required flag

##### SurveyTaker__c (Create and Read)
- **Create**: Yes (to record survey submission)
- **Read**: Yes
- **Fields**: Survey lookup, Case, Contact, User, Completed flag

##### SurveyQuestionResponse__c (Create and Read)
- **Create**: Yes (to record answers)
- **Read**: Yes
- **Fields**: Response text, Question lookup, Survey lookup

### 3. Manual Configuration (Alternative to Permission Set)

If you prefer to configure permissions manually instead of using the permission set, follow these steps:

#### 3.1 Object Access
Navigate to **Setup** → **Profiles** → **[Your Site Guest User Profile]** → **Object Settings**

Configure each object:

**Survey__c**
- Tab Settings: Tab Hidden
- Object Permissions:
  - Read: ✓
  - View All: ✗
  - Modify All: ✗
- Field Permissions: Read access to:
  - Name
  - Survey_Header__c
  - Hide_Survey_Name__c
  - Thank_You_Text__c
  - Thank_You_Link__c
  - All_Responses_Anonymous__c
  - Survey_Container_CSS__c
  - Share_with_Guest_User__c

**Survey_Question__c**
- Tab Settings: Tab Hidden
- Object Permissions:
  - Read: ✓
  - View All: ✗
- Field Permissions: Read access to:
  - Question__c
  - OrderNumber__c
  - Type__c
  - Required__c
  - Choices__c
  - Hide_on_Survey__c

**SurveyTaker__c**
- Tab Settings: Tab Hidden
- Object Permissions:
  - Read: ✓
  - Create: ✓
  - Edit: ✗
  - Delete: ✗
  - View All: ✗
- Field Permissions: Create/Edit access to:
  - Survey__c
  - Case__c
  - Contact__c
  - User__c
  - Completed__c

**SurveyQuestionResponse__c**
- Tab Settings: Tab Hidden
- Object Permissions:
  - Read: ✓
  - Create: ✓
  - Edit: ✗
  - Delete: ✗
  - View All: ✗
- Field Permissions: Create/Edit access to:
  - Survey_Question__c
  - SurveyTaker__c
  - Response__c
  - Question_Type__c
  - Survey__c

#### 3.2 Apex Class Access
Navigate to **Setup** → **Profiles** → **[Your Site Guest User Profile]** → **Enabled Apex Class Access**

Add the following classes:
- `SFDCAccessControlException`
- `SFDCAccessController`
- `SurveyForceUtil`
- `SurveyTakerController`
- `ViewSurveyControllerWithoutSharing`

### 4. Configure Survey for Guest Access

For each survey you want to make available to guest users:

1. Navigate to the Survey record
2. Check the **Share with Guest User** (or **Publicly Available**) checkbox
3. Save the record

**Important**: This field defaults to `false` for security. You must explicitly enable it for each survey that should be accessible to guest users.

### 5. Add surveyTaker Component to Experience Site

1. Open **Experience Builder** for your site
2. Create a new page or navigate to an existing page (e.g., `/survey`)
3. Add the **surveyTaker** Lightning Web Component to the page
4. Configure the component:
   - If using token-based URLs, no configuration needed (token comes from URL parameter)
   - If using survey ID directly, set the **recordId** property
5. **Publish** the site

### 6. Testing Guest User Access

#### Test Token-Based URL
1. Generate a survey invitation with token using one of these methods:
   - Automatic: Create a Training Request (generates tokens automatically)
   - Manual: Create a `SurveyInvitation__c` record
   - Apex: Use `SurveyInvitationController.createInvitation()`
   
2. Copy the generated URL (format: `https://yoursite.force.com/survey?token=xxxxx`)

3. Open the URL in an incognito/private browser window (to simulate guest access)

4. Verify:
   - Survey loads without errors
   - All questions display correctly
   - You can select answers
   - Submit button works
   - Thank you message displays after submission

#### Test Direct Survey Access (Optional)
1. Get a Survey record ID
2. Navigate to `https://yoursite.force.com/survey?c__recordId=<SurveyId>`
3. Verify survey loads and can be submitted

### 7. Troubleshooting

#### Error: "Survey not found or not available"
**Cause**: Survey record's "Share with Guest User" field is not checked, or guest user doesn't have read access to the survey object.

**Solution**:
1. Check the "Share with Guest User" field on the Survey record
2. Verify guest user profile has Read permission on Survey__c object
3. Verify `ViewSurveyControllerWithoutSharing` class is accessible to guest user

#### Error: "Insufficient privileges"
**Cause**: Guest user profile lacks necessary object or field permissions.

**Solution**:
1. Verify all object permissions listed in Section 3.1 are granted
2. Check that all Apex classes in Section 3.2 are enabled
3. Consider assigning the `Survey_Force_Guest` permission set instead of manual configuration

#### Error: "Unable to create SurveyTaker__c record"
**Cause**: Guest user doesn't have Create permission on SurveyTaker__c object.

**Solution**:
1. Verify guest user profile has Create permission on SurveyTaker__c
2. Verify guest user profile has Create permission on SurveyQuestionResponse__c
3. Check field-level security for all required fields

#### Token URL not working
**Cause**: Invalid token, expired token, or already used token.

**Solution**:
1. Check the SurveyInvitation__c record status (should be "Pending")
2. Verify the token hasn't expired (check ExpirationDate__c field)
3. Generate a new invitation token if needed
4. Ensure the Experience Site has a page at `/survey` path

#### Error: "Secure guest user record access" issues
**Cause**: "Secure guest user record access" is enabled for the site, which restricts guest user data access.

**Solution**:
This is already handled! The Survey Force application uses `ViewSurveyControllerWithoutSharing` class to bypass sharing rules for guest users. No additional configuration needed.

**Important**: Do NOT create sharing rules for Survey objects with the guest user - the without sharing class handles this automatically.

## Security Considerations

### Default Security Posture
- Surveys are **NOT** publicly accessible by default
- The "Share with Guest User" field must be explicitly checked for each survey
- This prevents accidental exposure of internal surveys to external users

### Token-Based Access
- Tokens are cryptographically secure (UUID format)
- Each token is unique and single-use
- Tokens can expire based on configuration
- Token status changes to "Completed" after submission
- Expired or completed tokens cannot be reused

### Guest User Limitations
- Guest users can only:
  - Read survey configurations that are marked as publicly available
  - Create their own SurveyTaker and SurveyQuestionResponse records
  - Submit responses anonymously (no user attribution)
- Guest users cannot:
  - View other users' survey responses
  - Edit or delete existing records
  - Access surveys not marked as publicly available
  - View survey analytics or reports

### Best Practices
1. Only enable "Share with Guest User" for surveys intended for external users
2. Use token-based URLs for better security and tracking
3. Configure token expiration dates appropriately
4. Monitor SurveyInvitation__c records for suspicious activity
5. Review guest user profile permissions periodically
6. Test guest access in incognito/private browser before sharing URLs
7. Use HTTPS for all survey URLs (automatic with Experience Sites)

## Additional Resources

- [Salesforce Experience Sites Documentation](https://help.salesforce.com/s/articleView?id=sf.networks_overview.htm)
- [Guest User Access in Experience Sites](https://help.salesforce.com/s/articleView?id=sf.networks_guest_user.htm)
- [Secure Guest User Record Access](https://help.salesforce.com/s/articleView?id=sf.networks_secure_guest_user_sharing.htm)
- Survey Force README: `readme.md`
- Survey Token URL Implementation: `SURVEY_TOKEN_URL_IMPLEMENTATION.md`
