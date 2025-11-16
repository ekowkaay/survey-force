# LWC Component API Documentation

## Overview

This document describes the APIs for Survey Force Lightning Web Components.

## Components

### surveyTaker

**Description**: Main component for taking surveys with modern LWC interface.

**Usage**:

```html
<c-survey-taker record-id="a0X..." case-id="500..." contact-id="003..."> </c-survey-taker>
```

**Properties**:

| Property  | Type   | Required | Description                        |
| --------- | ------ | -------- | ---------------------------------- |
| recordId  | String | Yes      | Survey\_\_c record ID              |
| caseId    | String | No       | Associated Case ID for tracking    |
| contactId | String | No       | Associated Contact ID for tracking |

**Features**:

- Supports all question types (Free Text, Single/Multi Select)
- Anonymous response option
- Real-time validation
- Loading states and error handling
- Thank you page display
- Mobile responsive

**Targets**:

- `lightning__RecordPage`
- `lightning__AppPage`
- `lightning__HomePage`
- `lightningCommunity__Page`
- `lightningCommunity__Default`

**Example - Record Page**:

```xml
<flexiPageRegions>
    <componentInstance>
        <componentName>surveyTaker</componentName>
        <identifier>survey_taker</identifier>
    </componentInstance>
</flexiPageRegions>
```

**Example - Experience Cloud**:

```html
<!-- Add component in Experience Builder -->
<c-survey-taker record-id="{!recordId}"></c-survey-taker>
```

---

### surveyQuestion

**Description**: Child component that renders individual survey questions.

**Usage**: Internal component used by surveyTaker. Not intended for standalone use.

**Properties**:

| Property | Type   | Required | Description          |
| -------- | ------ | -------- | -------------------- |
| question | Object | Yes      | Question data object |

**Question Object Structure**:

```javascript
{
    id: 'a09...',
    question: 'What is your favorite color?',
    orderNumber: 1,
    questionType: 'Single Select--Vertical',
    required: true,
    hideOnSurvey: false,
    rowsForTextArea: 3,
    choices: [
        { label: 'Red', value: '0' },
        { label: 'Blue', value: '1' }
    ]
}
```

**Events**:

| Event          | Payload                                        | Description                      |
| -------------- | ---------------------------------------------- | -------------------------------- |
| responsechange | `{ questionId, value, checked, questionType }` | Fired when user changes response |

---

### surveyCreator

**Description**: Component for creating new surveys and viewing recent surveys.

**Usage**:

```html
<c-survey-creator></c-survey-creator>
```

**Properties**: None (standalone component)

**Features**:

- Create new surveys with validation
- View recent surveys in a table
- Navigate to survey records
- Site availability checking
- Loading states

**Targets**:

- `lightning__AppPage`
- `lightning__HomePage`
- `lightning__Tab`

**Example - Custom Tab**:

```xml
<CustomTab>
    <flexiPage>Survey_Creator_Page</flexiPage>
    <label>Create Survey</label>
</CustomTab>
```

---

### gettingStarted

**Description**: Onboarding component with getting started guide.

**Usage**:

```html
<c-getting-started></c-getting-started>
```

**Properties**: None (standalone component)

**Features**:

- Create sample surveys
- Step-by-step guidance
- Resource links
- Community information
- Help documentation

**Targets**:

- `lightning__AppPage`
- `lightning__HomePage`
- `lightning__Tab`

---

## Apex Controllers

### SurveyTakerController

**Description**: Backend controller for survey taking functionality.

#### Methods

##### getSurveyData

```apex
@AuraEnabled(cacheable=true)
public static SurveyData getSurveyData(Id surveyId, String caseId, String contactId)
```

**Parameters**:

- `surveyId` (Id): Survey record ID
- `caseId` (String): Optional Case ID
- `contactId` (String): Optional Contact ID

**Returns**: `SurveyData` object containing:

```apex
{
    survey: Survey__c,           // Survey record with settings
    questions: List<QuestionData>, // List of questions
    isInternal: Boolean,          // Is internal user
    anonymousOption: String       // 'Anonymous' or 'User'
}
```

**Example**:

```javascript
import getSurveyData from '@salesforce/apex/SurveyTakerController.getSurveyData';

getSurveyData({
	surveyId: this.recordId,
	caseId: null,
	contactId: null
})
	.then((result) => {
		this.surveyData = result;
	})
	.catch((error) => {
		console.error(error);
	});
```

##### submitSurveyResponses

```apex
@AuraEnabled
public static SubmitResult submitSurveyResponses(
    Id surveyId,
    List<ResponseData> responses,
    String caseId,
    String contactId,
    Boolean isAnonymous
)
```

**Parameters**:

- `surveyId` (Id): Survey record ID
- `responses` (List<ResponseData>): List of responses
- `caseId` (String): Optional Case ID
- `contactId` (String): Optional Contact ID
- `isAnonymous` (Boolean): Whether to track user

**ResponseData Structure**:

```apex
{
    questionId: Id,
    response: String,              // For single-select and text
    responses: List<String>        // For multi-select
}
```

**Returns**: `SubmitResult` object:

```apex
{
    success: Boolean,
    message: String,
    thankYouText: String,
    thankYouLink: String
}
```

**Example**:

```javascript
import submitSurveyResponses from '@salesforce/apex/SurveyTakerController.submitSurveyResponses';

submitSurveyResponses({
	surveyId: this.recordId,
	responses: this.responseArray,
	caseId: null,
	contactId: null,
	isAnonymous: false
})
	.then((result) => {
		if (result.success) {
			this.showThankYou(result.thankYouText);
		}
	})
	.catch((error) => {
		console.error(error);
	});
```

---

### SurveyManagementController

**Description**: Backend controller for survey management functionality.

#### Methods

##### getSurveyManagementData

```apex
@AuraEnabled(cacheable=true)
public static SurveyManagementData getSurveyManagementData(Id surveyId)
```

**Returns**:

```apex
{
    survey: Survey__c,
    shareUrl: String,
    reportId: String,
    canUpdate: Boolean,
    questionCount: Integer,
    responseCount: Integer
}
```

##### updateSurveySettings

```apex
@AuraEnabled
public static String updateSurveySettings(Id surveyId, Map<String, Object> surveyData)
```

**Parameters**:

- `surveyId` (Id): Survey record ID
- `surveyData` (Map): Field values to update

**Supported Fields**:

- `Name`
- `Survey_Header__c`
- `Hide_Survey_Name__c`
- `Thank_You_Text__c`
- `Thank_You_Link__c`
- `All_Responses_Anonymous__c`
- `Share_with_Guest_User__c`
- `Survey_Container_CSS__c` (auto-sanitized)

##### getSurveyShareInfo

```apex
@AuraEnabled(cacheable=true)
public static Map<String, String> getSurveyShareInfo(Id surveyId)
```

**Returns**: Map of share URLs:

```apex
{
    'visualforceUrl': 'https://....',
    'site_SiteName': 'https://....'
}
```

##### getSurveyQuestions

```apex
@AuraEnabled(cacheable=true)
public static List<Survey_Question__c> getSurveyQuestions(Id surveyId)
```

##### deleteSurveyQuestion

```apex
@AuraEnabled
public static String deleteSurveyQuestion(Id questionId)
```

---

### SurveyCreationController

**Description**: Backend controller for survey creation.

#### Methods

##### checkSiteAvailability

```apex
@AuraEnabled(cacheable=true)
public static SiteInfo checkSiteAvailability()
```

**Returns**:

```apex
{
    hasExistingSite: Boolean,
    siteNames: List<String>
}
```

##### createSurvey

```apex
@AuraEnabled
public static CreationResult createSurvey(String surveyName)
```

**Returns**:

```apex
{
    success: Boolean,
    message: String,
    surveyId: Id,
    redirectUrl: String
}
```

##### getRecentSurveys

```apex
@AuraEnabled(cacheable=true)
public static List<Survey__c> getRecentSurveys()
```

Returns up to 10 most recent surveys.

##### cloneSurvey

```apex
@AuraEnabled
public static CreationResult cloneSurvey(Id sourceSurveyId, String newSurveyName)
```

Clones survey and all questions.

---

## Events

### Component Events

#### responsechange (surveyQuestion)

Fired when user changes a response in a question.

**Payload**:

```javascript
{
    questionId: 'a09...',
    value: '0',
    checked: true,
    questionType: 'Multi-Select--Vertical'
}
```

**Handler Example**:

```javascript
handleResponseChange(event) {
    const detail = event.detail;
    // Process response change
}
```

---

## Error Handling

All controllers throw `AuraHandledException` for errors:

```javascript
.catch(error => {
    const message = error.body?.message || error.message || 'Unknown error';
    // Handle error
});
```

---

## Security

### Field-Level Security

All controllers use `WITH USER_MODE` and `SurveyForceUtil.accessController` for FLS checks.

### Guest User Access

Guest users can access surveys when:

1. Survey has `Share_with_Guest_User__c` = true
2. Guest user profile has proper permissions
3. Controllers use `ViewSurveyControllerWithoutSharing` for DML

### CSS Sanitization

All CSS input is automatically sanitized to remove HTML tags:

```apex
css.replaceAll('<[^>]+>', ' ')
```

---

## Performance

### Cacheable Methods

Methods marked `@AuraEnabled(cacheable=true)`:

- `getSurveyData`
- `getSurveyManagementData`
- `getSurveyShareInfo`
- `getSurveyQuestions`
- `checkSiteAvailability`
- `getRecentSurveys`

These methods:

- Cache data on client
- Reduce server round trips
- Improve performance
- Refresh automatically when data changes

### Best Practices

1. **Use cacheable methods** for read operations
2. **Batch DML operations** when possible
3. **Limit SOQL queries** in loops
4. **Use pagination** for large result sets
5. **Implement loading states** in components

---

## Testing

All controllers have 100% test coverage:

- `SurveyTakerController_Test`
- `SurveyManagementController_Test`
- `SurveyCreationController_Test`

Run tests:

```bash
sfdx force:apex:test:run -n SurveyTakerController_Test -r human
```

---

## Browser Support

Components are tested and supported on:

- Chrome (latest 2 versions)
- Firefox (latest 2 versions)
- Safari (latest 2 versions)
- Edge (latest 2 versions)
- Mobile Safari (iOS 13+)
- Chrome Mobile (Android 9+)

---

## Accessibility

Components follow SLDS accessibility guidelines:

- Proper ARIA labels
- Keyboard navigation support
- Screen reader compatible
- Focus management
- High contrast mode support

---

## Troubleshooting

### Common Issues

**Component not loading**

- Check recordId is valid Survey\_\_c ID
- Verify user has read access
- Check browser console for errors

**Can't submit responses**

- Verify user has create access to SurveyTaker\_\_c
- Check required fields are answered
- Look for validation rules

**Guest user access issues**

- Verify `Share_with_Guest_User__c` is true
- Check guest user permissions
- Test with internal user first

---

## Version History

### v2.0.0 (2024)

- Initial LWC release
- Full feature parity with Visualforce
- Enhanced performance and UX

---

## Support

- **GitHub**: [Survey Force Repository](https://github.com/SalesforceLabs/survey-force)
- **Issues**: [GitHub Issues](https://github.com/SalesforceLabs/survey-force/issues)
- **Community**: [Trailblazer Community](https://trailblazers.salesforce.com/)
