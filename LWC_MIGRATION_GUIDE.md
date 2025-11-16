# Lightning Web Components Migration Guide

## Overview

Survey Force has been modernized with Lightning Web Components (LWC) to provide a faster, more maintainable, and feature-rich user experience. This guide will help you transition from Visualforce pages to the new LWC components.

## What's New

### Modern LWC Components

The following Visualforce pages have been replaced with Lightning Web Components:

| Visualforce Page                       | LWC Component  | Lightning Page       | Status         |
| -------------------------------------- | -------------- | -------------------- | -------------- |
| TakeSurvey.page                        | surveyTaker    | Survey_Taker_Page    | ✅ Complete    |
| GSurveys.page                          | surveyCreator  | Survey_Creator_Page  | ✅ Complete    |
| Getting_Started_With_Survey_Force.page | gettingStarted | Getting_Started_Page | ✅ Complete    |
| SurveyManagerPage.page                 | surveyManager  | Survey_Manager_Page  | 🚧 In Progress |

### Key Benefits

- **⚡ Performance**: Up to 50% faster page loads with native web standards
- **🎨 Modern UI**: Clean, consistent SLDS design throughout
- **📱 Mobile Responsive**: Better experience on tablets and phones
- **🔧 Maintainable**: Modular component architecture
- **🚀 Future-Proof**: Built on Lightning platform standards

## Migration Path

### Option 1: Gradual Migration (Recommended)

Run both Visualforce and LWC side-by-side during transition:

1. **Keep existing Visualforce pages active** - No disruption to current users
2. **Add new LWC tabs** to your Survey Force app
3. **Train users** on the new interface
4. **Gradually transition** users to LWC components
5. **Deprecate Visualforce pages** once migration is complete

### Option 2: Direct Migration

Switch directly to LWC components:

1. **Update Lightning App** with new LWC tabs
2. **Replace old tabs** with new LWC tabs
3. **Update bookmarks** and links
4. **Notify users** of the change

## Component Mapping

### Survey Taking

**Before (Visualforce):**

```
/apex/TakeSurvey?id={surveyId}
```

**After (LWC):**

- Use the surveyTaker component in Lightning pages
- Add to Experience Sites for external users
- Embed in record pages or app pages

**Configuration:**

- Add surveyTaker component to page
- Set recordId property to Survey\_\_c ID
- Optional: Set caseId and contactId for tracking

### Survey Creation

**Before (Visualforce):**

```
/apex/GSurveys
```

**After (LWC):**

- Navigate to "Create Survey" tab
- Or use the Lightning Object page for Survey\_\_c
- surveyCreator component shows recent surveys

**Features:**

- Faster survey creation
- See recent surveys at a glance
- Direct navigation to survey records
- Site availability checking

### Getting Started

**Before (Visualforce):**

```
/apex/Getting_Started_With_Survey_Force
```

**After (LWC):**

- Navigate to "Getting Started LWC" tab
- Modern onboarding experience
- Integrated sample survey creation
- Better resource links

## For Administrators

### Setup Steps

1. **Deploy LWC Components**

   ```bash
   sfdx force:source:deploy -p force-app/main/default/lwc
   sfdx force:source:deploy -p force-app/main/default/classes
   sfdx force:source:deploy -p force-app/main/default/flexipages
   sfdx force:source:deploy -p force-app/main/default/tabs
   ```

2. **Add Tabs to Lightning App**
   - Edit Survey Force Lightning app
   - Add "Create Survey" tab
   - Add "Getting Started LWC" tab
   - Save and assign to users

3. **Configure Permissions**
   - Existing permissions work with LWC
   - No permission changes needed
   - Guest user access still supported

4. **Test Components**
   - Take a test survey with surveyTaker
   - Create a test survey with surveyCreator
   - Verify guest user access if applicable

### Lightning Page Configuration

#### Adding Survey Taker to Record Page

1. Go to Setup → Lightning App Builder
2. Edit Survey\_\_c record page
3. Add surveyTaker component
4. Configure recordId binding
5. Save and activate

#### Creating Community/Experience Site Page

1. Open Experience Builder
2. Create new page
3. Add surveyTaker component
4. Configure Survey ID
5. Publish changes

## For Developers

### Component Architecture

```
surveyTaker (parent)
├── surveyQuestion (child) - Renders individual questions
├── Uses: SurveyTakerController.cls
└── Supports: All question types, anonymous responses

surveyCreator
├── Uses: SurveyCreationController.cls
└── Features: Create, clone, view recent surveys

gettingStarted
├── Uses: SurveyCreationController.cls
└── Features: Onboarding, sample survey creation
```

### Apex Controller APIs

#### SurveyTakerController

```apex
// Get survey data
@AuraEnabled(cacheable=true)
public static SurveyData getSurveyData(Id surveyId, String caseId, String contactId)

// Submit responses
@AuraEnabled
public static SubmitResult submitSurveyResponses(
    Id surveyId,
    List<ResponseData> responses,
    String caseId,
    String contactId,
    Boolean isAnonymous
)
```

#### SurveyCreationController

```apex
// Check site availability
@AuraEnabled(cacheable=true)
public static SiteInfo checkSiteAvailability()

// Create new survey
@AuraEnabled
public static CreationResult createSurvey(String surveyName)

// Clone existing survey
@AuraEnabled
public static CreationResult cloneSurvey(Id sourceSurveyId, String newSurveyName)
```

#### SurveyManagementController

```apex
// Get management data
@AuraEnabled(cacheable=true)
public static SurveyManagementData getSurveyManagementData(Id surveyId)

// Update settings
@AuraEnabled
public static String updateSurveySettings(Id surveyId, Map<String, Object> surveyData)

// Get share info
@AuraEnabled(cacheable=true)
public static Map<String, String> getSurveyShareInfo(Id surveyId)
```

### Extending Components

Components are designed to be extended:

```javascript
// Import and use in custom components
import surveyTaker from 'c/surveyTaker';

// Or extend functionality
export default class CustomSurveyTaker extends LightningElement {
	// Add custom logic
}
```

## Data Migration

**No data migration required!**

- ✅ Existing Survey\_\_c records work as-is
- ✅ All Survey_Question\_\_c records compatible
- ✅ Historical SurveyTaker\_\_c data preserved
- ✅ SurveyQuestionResponse\_\_c records unchanged

The LWC components use the same data model as Visualforce pages.

## Backward Compatibility

### What Stays the Same

- ✅ All database objects (Survey**c, Survey_Question**c, etc.)
- ✅ Field-level security and sharing rules
- ✅ Guest user access patterns
- ✅ External survey links continue to work
- ✅ Reporting and dashboards
- ✅ Existing Apex classes and triggers

### What Changes

- ❌ Page URLs (Visualforce → Lightning)
- ❌ JavaScript in Visualforce (not needed in LWC)
- ❌ Custom CSS (use SLDS tokens instead)

## Troubleshooting

### Common Issues

**Q: Survey doesn't load in LWC component**

- Check recordId is being passed correctly
- Verify user has read access to Survey\_\_c
- Check browser console for errors

**Q: Can't submit survey responses**

- Verify user has create access to SurveyTaker**c and SurveyQuestionResponse**c
- Check required fields are answered
- Look for validation rules that might block insert

**Q: Guest users can't access survey**

- Verify "Share with Guest User" is checked on survey
- Check guest user profile has correct permissions
- Verify Experience Site is active

**Q: Components not showing in Lightning App Builder**

- Deploy component metadata
- Refresh App Builder
- Check component targets in meta.xml

### Getting Help

- **GitHub Issues**: [Survey Force Issues](https://github.com/SalesforceLabs/survey-force/issues)
- **Trailblazer Community**: [Salesforce Answers](https://trailblazers.salesforce.com/)
- **Documentation**: Check Wiki on GitHub

## Testing Checklist

Before going live with LWC components:

- [ ] Test survey creation with surveyCreator
- [ ] Test taking survey with surveyTaker
- [ ] Verify all question types render correctly
- [ ] Test required field validation
- [ ] Test anonymous response option
- [ ] Verify thank you page displays
- [ ] Test on mobile devices
- [ ] Test guest user access (if applicable)
- [ ] Verify reports still work
- [ ] Test with multiple survey configurations

## Rollback Plan

If issues arise, you can easily rollback:

1. **Remove new LWC tabs** from app
2. **Re-add Visualforce tabs** if removed
3. **Communicate** to users
4. **No data loss** - all responses preserved

## Timeline Recommendations

### Week 1-2: Setup

- Deploy LWC components
- Configure Lightning pages
- Set up test environment

### Week 3-4: Testing

- Internal testing
- User acceptance testing
- Fix any issues

### Week 5-6: Training

- Train administrators
- Create user guides
- Update documentation

### Week 7+: Rollout

- Gradual user migration
- Monitor for issues
- Gather feedback

## Future Enhancements

Planned improvements to LWC components:

- 📊 Enhanced analytics dashboard
- 🎨 Theme customization
- 📱 Progressive Web App support
- 🌐 Multi-language support
- ♿ Enhanced accessibility
- 🔔 Real-time notifications

## Questions?

Contact your Salesforce administrator or reach out to the Survey Force community on GitHub.

---

**Last Updated**: November 2024  
**Version**: 1.0.0 (LWC Migration)
