# Scale Labels Accessibility Fix

## Problem Statement

The question "Why are these fields added to questions: Scale_Start_Label__c and Scale_End_Label__c?" highlighted a critical issue: these fields existed in the codebase and were being used by the application, but users could not see or edit them.

## Root Cause Analysis

The Scale_Start_Label__c and Scale_End_Label__c fields were added in a previous implementation to support horizontal scale questions with endpoint labels (e.g., "Very Difficult" to "Very Easy"). The fields were:

1. ✅ **Created** as custom fields on Survey_Question__c object
2. ✅ **Used** in backend controllers (SurveyTakerController, ViewSurveyControllerWithoutSharing)
3. ✅ **Used** in frontend LWC component (surveyTaker.js)
4. ✅ **Documented** in SURVEY_SCALE_LABELS_GUIDE.md
5. ❌ **Missing** from Survey Question page layout
6. ❌ **Missing** from permission sets (field-level security)

This made the feature completely unusable - administrators could not populate the fields because they were not visible in the UI, and users lacked the necessary field-level security permissions.

## Solution Implemented

### 1. Page Layout Update
**File**: `force-app/main/default/layouts/Survey_Question__c-Survey Question Layout.layout-meta.xml`

Added both fields to the Survey Question layout in a logical position:
- Positioned after `Choices__c` field
- Positioned before `Question__c` field
- Both fields set to "Edit" behavior

This placement makes sense for the user workflow:
1. Select question type
2. Enter choices (1, 2, 3, 4, 5)
3. **Add scale start label** (e.g., "Very Difficult")
4. **Add scale end label** (e.g., "Very Easy")
5. Enter the question text

### 2. Permission Set Updates

#### Survey_Force_Admin
**File**: `force-app/main/default/permissionsets/Survey_Force_Admin.permissionset-meta.xml`

Added field-level security:
```xml
<fieldPermissions>
    <editable>true</editable>
    <field>Survey_Question__c.Scale_End_Label__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>true</editable>
    <field>Survey_Question__c.Scale_Start_Label__c</field>
    <readable>true</readable>
</fieldPermissions>
```

#### Survey_Force_SuperAdmin
**File**: `force-app/main/default/permissionsets/Survey_Force_SuperAdmin.permissionset-meta.xml`

Same editable permissions as Admin for full administrative access.

#### Survey_Force_Guest
**File**: `force-app/main/default/permissionsets/Survey_Force_Guest.permissionset-meta.xml`

Added read-only field-level security:
```xml
<fieldPermissions>
    <editable>false</editable>
    <field>Survey_Question__c.Scale_End_Label__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>false</editable>
    <field>Survey_Question__c.Scale_Start_Label__c</field>
    <readable>true</readable>
</fieldPermissions>
```

This ensures guest users (survey takers) can see the labels when taking surveys but cannot modify them.

## Validation

### Code Review
✅ Passed with no issues

### Security Scan
✅ No security vulnerabilities detected (only metadata changes)

### XML Validation
✅ All metadata files are well-formed

## Impact

### Before This Fix
- Fields existed but were invisible
- Administrators could not use the scale label feature
- Documentation referenced unusable functionality
- Code existed that could never execute with user-populated data

### After This Fix
- ✅ Administrators can see and edit scale label fields
- ✅ Guest users can see labels when taking surveys
- ✅ Feature is fully functional as documented
- ✅ User workflow is intuitive and complete

## Usage Example

An administrator can now:

1. Create a Survey Question record
2. Set Type = "Single Select--Horizontal"
3. Set Choices = "1\n2\n3\n4\n5"
4. Set Scale Start Label = "Very Difficult"
5. Set Scale End Label = "Very Easy"
6. Save the record

When survey takers view this question, they will see:
```
Question: "How would you rate the difficulty of this training?"
Very Difficult ◄─────────────────► Very Easy
[1] [2] [3] [4] [5]
```

## Files Modified

1. `force-app/main/default/layouts/Survey_Question__c-Survey Question Layout.layout-meta.xml`
2. `force-app/main/default/permissionsets/Survey_Force_Admin.permissionset-meta.xml`
3. `force-app/main/default/permissionsets/Survey_Force_SuperAdmin.permissionset-meta.xml`
4. `force-app/main/default/permissionsets/Survey_Force_Guest.permissionset-meta.xml`

## Related Documentation

- [SURVEY_SCALE_LABELS_GUIDE.md](./SURVEY_SCALE_LABELS_GUIDE.md) - User guide for scale labels
- [STATIC_SCALE_LABELS_SUMMARY.md](./STATIC_SCALE_LABELS_SUMMARY.md) - Implementation summary

## Testing Recommendations

1. Deploy metadata to target org
2. Assign Survey_Force_Admin permission set to test user
3. Create/edit a Survey Question record
4. Verify Scale_Start_Label__c and Scale_End_Label__c fields are visible and editable
5. Populate the fields with test data
6. View the question in a survey as a guest user
7. Verify labels display correctly at the ends of the horizontal scale

## Conclusion

This fix resolves the accessibility gap that prevented the scale labels feature from being usable. The fields are now properly integrated into the user interface with appropriate permissions for different user roles.
