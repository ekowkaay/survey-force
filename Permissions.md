# Survey Force Permission Sets Documentation

## Overview

This document describes all permission sets available in the Survey Force application and their intended use cases.

## Permission Set Structure

Permission sets in Survey Force follow a consistent naming convention:

**Format**: `SurveyForce_[Component]_[AccessLevel]`

- **SurveyForce**: Application prefix
- **Component**: Descriptive name of the functionality
- **AccessLevel**: Read | Write | Full | Execute | Admin

## Available Permission Sets

### 1. Survey Force - SuperAdmin

**API Name**: `Survey_Force_SuperAdmin`

**Purpose**: Full administrative access to all Survey Force features

**Grants Access To**:
- All Survey Force objects (Create, Read, Edit, Delete)
- All Apex classes
- All Visualforce pages
- All Lightning Web Components
- All flows and processes

**Assign To**:
- System Administrators
- Survey Force Application Owners
- Users responsible for configuring the application

---

### 2. Survey Force - Admin

**API Name**: `Survey_Force_Admin`

**Purpose**: Administrative access for managing surveys and viewing responses

**Grants Access To**:
- Survey objects (Create, Read, Edit, Delete)
- Survey Question objects (Create, Read, Edit, Delete)
- Survey Taker objects (Read)
- Survey Question Response objects (Read)
- Survey Invitation objects (Create, Read, Edit, Delete)
- Survey creation and editing components

**Assign To**:
- Survey administrators
- Team leads who create and manage surveys
- Marketing/training coordinators

---

### 3. Survey Force - Guest

**API Name**: `Survey_Force_Guest`

**Purpose**: Minimal access for external survey takers via Experience Sites/Communities

**Grants Access To**:
- Survey objects (Read only)
- Survey Question objects (Read only)
- Survey Taker objects (Create, Read, Edit)
- Survey Question Response objects (Create)
- Survey Invitation objects (Read, Edit - for status updates)

**Assign To**:
- Experience Site/Community guest users
- Public survey taker profiles

**Important**: This permission set should be assigned to the Site/Community Guest User profile for anonymous survey access.

---

### 4. SurveyForce Survey Regeneration Execute

**API Name**: `SurveyForce_SurveyRegeneration_Execute`

**Purpose**: Grants execute access to survey regeneration functionality for refreshing survey links when templates are updated

**Grants Access To**:
- `SurveyRegenerationController` Apex class (Execute)
- Training_Request__c object (Read, Edit)
  - Participant_Survey__c field (Read, Edit)
  - Customer_Survey__c field (Read, Edit)
  - Trainer_Survey__c field (Read, Edit)
  - Training_Type__c field (Read)
- SurveyInvitation__c object (Create, Read, Edit, Delete)
  - Survey__c field (Read, Edit)
  - Token__c field (Read, Edit)
  - Status__c field (Read, Edit)
  - Email__c field (Read, Edit)
  - ParticipantName__c field (Read, Edit)
  - RelatedRecordId__c field (Read, Edit)
- Survey__c object (Read)
- Participants__c object (Read, Edit)
  - Training_Request__c field (Read)
  - Participant_Survey__c field (Read, Edit)
  - Participant_Name__c field (Read)
  - Email__c field (Read)

**Assign To**:
- Survey administrators who need to regenerate survey links
- Training coordinators who manage survey templates
- System administrators performing bulk survey updates

**Use Case**: When survey templates or questions are updated, administrators can regenerate survey links and invitations for existing Training Requests to ensure participants receive the latest survey version.

**Associated Tools**:
- "Regenerate Survey Links" Flow
- "Regenerate Survey Links" Quick Action on Training_Request__c

---

## Permission Set Dependencies

### Survey_Force_SuperAdmin
- **Includes**: All permissions from Admin and Guest
- **License**: Salesforce
- **Dependencies**: None

### Survey_Force_Admin
- **Includes**: Core survey management permissions
- **License**: Salesforce
- **Dependencies**: None

### Survey_Force_Guest
- **Includes**: Minimal survey-taking permissions
- **License**: None (can be used with Guest User License)
- **Dependencies**: Must be assigned to Site/Community Guest User

### SurveyForce_SurveyRegeneration_Execute
- **Includes**: Survey regeneration permissions only
- **License**: Salesforce
- **Dependencies**: Requires base Survey Force objects to be accessible
- **Recommended Combination**: Assign with Survey_Force_Admin for full survey management capabilities

---

## Permission Assignment Guidelines

### System Administrators
Assign:
- Survey_Force_SuperAdmin

### Survey Managers/Administrators
Assign:
- Survey_Force_Admin
- SurveyForce_SurveyRegeneration_Execute (if managing survey templates)

### Training Coordinators
Assign:
- Survey_Force_Admin (if they create surveys)
- SurveyForce_SurveyRegeneration_Execute (if they manage training requests and surveys)

### Survey Takers (Internal Users)
Assign:
- No special permission set needed if surveys are accessed via direct links

### External Survey Takers (Experience Site/Community)
Assign to Guest User Profile:
- Survey_Force_Guest

---

## Object Permissions Summary

| Object | SuperAdmin | Admin | Guest | Regeneration Execute |
|--------|-----------|-------|-------|---------------------|
| Survey__c | Full | Full | Read | Read |
| Survey_Question__c | Full | Full | Read | - |
| Survey_Taker__c | Full | Read | Create/Read/Edit | - |
| Survey_Question_Response__c | Full | Read | Create | - |
| SurveyInvitation__c | Full | Full | Read/Edit | Create/Read/Edit/Delete |
| Training_Request__c | Full | - | - | Read/Edit |
| Participants__c | Full | - | - | Read/Edit |

---

## Security Best Practices

1. **Principle of Least Privilege**: Assign only the permissions needed for each role
2. **Regular Audits**: Review permission set assignments quarterly
3. **Guest User Security**: Carefully review Survey_Force_Guest permissions before enabling public access
4. **Sensitive Data**: Consider additional security measures for surveys containing sensitive data
5. **Field-Level Security**: Use field-level security for additional data protection beyond object-level permissions

---

## Permission Set Groups

Consider creating Permission Set Groups for common user roles:

### Survey Administrator Group
- Survey_Force_Admin
- SurveyForce_SurveyRegeneration_Execute

### Training Manager Group
- Survey_Force_Admin
- SurveyForce_SurveyRegeneration_Execute
- (Additional training-related permission sets)

---

## Troubleshooting Permission Issues

### "Insufficient Privileges" Error
- **Cause**: User lacks object or field-level permissions
- **Solution**: Assign appropriate permission set or check sharing rules

### Cannot Regenerate Surveys
- **Cause**: Missing SurveyForce_SurveyRegeneration_Execute permission set
- **Solution**: Assign the permission set to the user

### Cannot Access Survey Link Generator
- **Cause**: Tab not visible or no read access to Survey objects
- **Solution**: Assign Survey_Force_Admin permission set

### Guest Users Cannot Take Surveys
- **Cause**: Survey_Force_Guest not assigned to Site Guest User
- **Solution**: Assign permission set to the Guest User profile via Site settings

---

## Additional Resources

- [Survey Regeneration Guide](./SURVEY_REGENERATION_GUIDE.md) - Detailed guide on using the regeneration feature
- [Installation Guide](./INSTALLATION.md) - Complete installation instructions
- [LWC Migration Guide](./LWC_MIGRATION_GUIDE.md) - Information about Lightning Web Components

---

## Version History

- **v1.0** (January 2026) - Added SurveyForce_SurveyRegeneration_Execute permission set
- **v0.9** - Initial documentation of existing permission sets

---

## Support

For questions about permissions or access issues:
1. Review this documentation
2. Check Salesforce debug logs for specific error messages
3. Contact your Salesforce administrator
4. Review field-level security and sharing rules
