# LWC Package vs Full Package Comparison

## Package Contents

### LWC-Only Package (`force-app-lwc/`)

**Total Size**: ~70 files (minimal deployment)

#### Included:
- ✅ **4 LWC Components**
  - surveyTaker
  - surveyQuestion
  - surveyCreator
  - gettingStarted

- ✅ **9 Apex Classes** (6 production + 3 test)
  - SurveyTakerController
  - SurveyCreationController
  - SurveyForceUtil
  - SFDCAccessController
  - SFDCAccessControlException
  - ViewSurveyControllerWithoutSharing
  - SurveyTestingUtil (test data factory)
  - SurveyTakerController_Test
  - SurveyCreationController_Test
  - SFDCAccessControllerTest
  - SurveyTestingUtil_Test

- ✅ **4 Custom Objects** (with all fields)
  - Survey__c (with 7 fields)
  - Survey_Question__c (with 8 fields)
  - SurveyTaker__c (with 5 fields)
  - SurveyQuestionResponse__c (with 5 fields)

- ✅ **2 Custom Labels**
  - LABS_SF_Survey_Submitted_Thank_you
  - LABS_SF_You_have_already_taken_this_survey

- ✅ **Documentation**
  - LWC_PACKAGE_README.md
  - Package manifest (package.xml)

### Full Package (`force-app/`)

**Total Size**: ~200+ files

#### Everything in LWC Package PLUS:

- ❌ **Visualforce Pages** (6 pages)
  - Getting_Started_With_Survey_Force.page
  - GSurveys.page
  - SurveyManagerPage.page
  - SurveyPage.page
  - TakeSurvey.page
  - And others

- ❌ **Visualforce Controllers** (~20 additional Apex classes)
  - ViewSurveyController
  - GSurveysController
  - SurveyManagerController
  - SurveyManagementController
  - ViewSurveyResultsComponentController
  - LexInputFieldCompCtrl
  - CSUtils
  - SurveySitesUtil
  - And their test classes

- ❌ **Visualforce Components** (4 components)
  - LexInputField.component
  - uiMessage.component
  - viewShareSurveyComponent.component
  - viewSurveyResultsComponent.component

- ❌ **Static Resources** (2 resources)
  - SurveyForce (zip archive)
  - SurveyForce_UserGuide.pdf

- ❌ **Lightning Pages** (3 flexipages)
  - Survey_Taker_Page.flexipage
  - Survey_Creator_Page.flexipage
  - Getting_Started_Page.flexipage

- ❌ **Custom Tabs** (7 tabs)
  - Getting_Started_With_Survey_Force
  - Create_Survey
  - Getting_Started_LWC
  - Survey__c standard tab
  - And others

- ❌ **Applications** (1 app)
  - Survey_Force.app

- ❌ **Permission Sets** (3 permission sets)
  - Survey_Force_SuperAdmin
  - Survey_Force_Admin
  - Survey_Force_Guest

- ❌ **Page Layouts** (4 layouts)
  - Survey__c layouts
  - Survey_Question__c layouts
  - SurveyTaker__c layouts
  - SurveyQuestionResponse__c layouts

- ❌ **Compact Layouts**

- ❌ **List Views** (additional views)

- ❌ **Reports & Dashboards**
  - Survey with Questions and Responses report
  - Report types
  - Related folders

- ❌ **Custom Labels** (40+ additional labels)
  - All other Survey Force labels not used by LWC

- ❌ **Triggers**
  - SFSurveyQuestionTrigger

- ❌ **Flows**

- ❌ **Content Assets**

## Key Differences

### What You Get With LWC-Only Package:
1. **Modern UI**: All 4 Lightning Web Components
2. **Core Functionality**: Survey taking and creation
3. **Minimal Footprint**: Only essential metadata
4. **Quick Deployment**: Fewer files = faster deployment
5. **Clean Install**: No legacy Visualforce code
6. **Security**: All required security classes included
7. **Test Coverage**: 100% coverage for included classes

### What You DON'T Get:
1. **Legacy Visualforce UI**: No old survey pages
2. **Pre-configured Lightning Pages**: Need to create your own
3. **Pre-configured Tabs**: Need to create your own
4. **Permission Sets**: Need to create or configure manually
5. **Page Layouts**: Uses standard layouts only
6. **Sample Application**: Need to add components to your own app
7. **Reports**: Need to create custom reports
8. **Additional Controllers**: Only LWC-specific controllers

## Use Cases

### Choose LWC-Only Package When:
- ✅ You want modern LWC components only
- ✅ You're building a new implementation
- ✅ You want minimal metadata footprint
- ✅ You plan to customize page layouts yourself
- ✅ You don't need Visualforce pages
- ✅ You want to integrate into existing apps

### Choose Full Package When:
- ✅ You want ready-to-use Survey Force application
- ✅ You need Visualforce pages for compatibility
- ✅ You want pre-configured tabs and pages
- ✅ You want sample reports and dashboards
- ✅ You want permission sets included
- ✅ You're upgrading from previous version
- ✅ You want the complete out-of-box experience

## Migration Path

### From Full Package to LWC-Only:
If you currently have the full package installed, you generally **don't need** to switch to LWC-only package. The LWC-only package is designed for:
- New installations that only want LWC components
- Integrations where minimal footprint is important
- Organizations with existing survey infrastructure

### From LWC-Only to Full Package:
1. Deploy additional metadata from full package
2. No data migration needed (same objects/fields)
3. Configure new permission sets
4. Add tabs and pages as needed

## Installation Size Comparison

| Metric | LWC-Only | Full Package |
|--------|----------|--------------|
| Apex Classes | 11 | 30+ |
| LWC Components | 4 | 4 |
| VF Pages | 0 | 6+ |
| VF Components | 0 | 4 |
| Custom Objects | 4 | 4 |
| Static Resources | 0 | 2 |
| Lightning Pages | 0 | 3 |
| Tabs | 0 | 7+ |
| Permission Sets | 0 | 3 |
| Custom Labels | 2 | 42 |
| **Total Files** | ~70 | 200+ |

## Deployment Time Estimate

- **LWC-Only Package**: 2-5 minutes
- **Full Package**: 10-20 minutes

## Support

Both packages are part of the same Survey Force project and have the same:
- GitHub repository
- Community support
- Documentation
- Update schedule

Choose the package that best fits your needs!

---

**Recommendation**: 
- **New users**: Start with LWC-Only if you only need modern components
- **Existing users**: Stay with Full Package unless you have specific reasons to minimize footprint
- **Integrators**: Use LWC-Only for cleaner integration into existing apps
