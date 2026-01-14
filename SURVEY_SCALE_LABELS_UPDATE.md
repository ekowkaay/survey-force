# Survey Scale Labels Update

## Overview

This update addresses the issue where survey questions with horizontal scale layouts were displaying numeric values (e.g., "1" and "5") instead of meaningful labels (e.g., "Very Difficult" and "Very Easy") at the ends of the scale.

## Changes Made

### 1. Documentation Updates

- **Updated code comments** in `surveyTaker.js` and `surveyTaker.css` to reflect the new recommended scale labels: "Very Difficult" / "Very Easy" instead of "Disagree" / "Strongly Agree"

- **Created comprehensive guide** (`SURVEY_SCALE_LABELS_GUIDE.md`) that explains:
  - How survey choice formatting works
  - How to properly configure scale questions
  - Examples of different scale types
  - Troubleshooting common issues
  - Technical implementation details

### 2. Data Migration Script

- **Created Apex script** (`scripts/apex/UpdateSurveyScaleLabels.apex`) to bulk update existing survey questions:
  - Finds all horizontal scale questions
  - Replaces "Disagree" with "Very Difficult"
  - Replaces "Strongly Agree" with "Very Easy"
  - Replaces numeric scales (1-5) with proper labels
  - Provides detailed logging of all changes

## Understanding the Issue

### Root Cause

The issue occurs when survey creators enter choices as simple numbers:
```
1
2
3
4
5
```

This results in:
- Button labels: "1", "2", "3", "4", "5" ✅ (correct)
- End labels: "1" (start) and "5" (end) ❌ (not meaningful)

### Solution

Use descriptive labels for the first and last choices:
```
Very Difficult
2
3
4
Very Easy
```

This results in:
- Button labels: "Very Difficult", "2", "3", "4", "Very Easy" ✅
- End labels: "Very Difficult" (start) and "Very Easy" (end) ✅

### How It Works

The choice parsing logic in `SurveyTakerController.parseChoices()`:
1. Splits the `Choices__c` field by newline (`\n`)
2. Creates an option for each line with:
   - `label`: The text from the line (displayed to users)
   - `value`: Numeric index 0, 1, 2, 3, 4 (stored in responses)

For horizontal scale layouts:
- The first choice's label is shown as the **start label** (left side)
- The last choice's label is shown as the **end label** (right side)
- All choice labels are shown as button text

## How to Update Existing Survey Questions

### Option 1: Run the Migration Script

1. Open Salesforce Developer Console
2. Debug > Open Execute Anonymous Window
3. Copy and paste the contents of `scripts/apex/UpdateSurveyScaleLabels.apex`
4. Check "Open Log"
5. Click "Execute"
6. Review the logs to see which questions were updated

### Option 2: Manual Update

1. Navigate to the Survey Question record in Salesforce
2. Edit the `Choices__c` field
3. Update the format as described above
4. Save the record

### Option 3: Data Loader

1. Export Survey Questions
2. Update the `Choices__c` field in your CSV
3. Import the updated records

## Best Practices Going Forward

When creating new horizontal scale questions:

1. **Always use descriptive labels** for the first and last choices
2. **Use numbers for middle options** to keep the scale simple
3. **Be consistent** across similar questions in your survey
4. **Preview your survey** to ensure labels display correctly

## Recommended Scale Formats

### Difficulty Scale
```
Very Difficult
2
3
4
Very Easy
```

### Agreement Scale
```
Strongly Disagree
2
3
4
Strongly Agree
```

### Satisfaction Scale
```
Very Dissatisfied
2
3
4
Very Satisfied
```

### Likelihood Scale
```
Very Unlikely
2
3
4
Very Likely
```

## Impact on Existing Data

- **Survey Questions**: Need to be updated (use migration script or manual update)
- **Survey Responses**: No impact - responses store numeric values which remain valid
- **Existing Surveys**: Will automatically display new labels after questions are updated

## Technical Notes

### Files Changed

1. `force-app/main/default/lwc/surveyTaker/surveyTaker.js`
   - Updated comments in `scaleStartLabel` and `scaleEndLabel` getters

2. `force-app/main/default/lwc/surveyTaker/surveyTaker.css`
   - Updated comment for scale end labels

3. `SURVEY_SCALE_LABELS_GUIDE.md` (new file)
   - Comprehensive guide for creating and updating scale questions

4. `scripts/apex/UpdateSurveyScaleLabels.apex` (new file)
   - Data migration script for bulk updates

### No Code Logic Changes

The actual parsing and display logic remains unchanged. This update:
- Provides documentation on proper usage
- Updates example labels in comments
- Provides tools to fix existing data

The code already supports descriptive labels correctly - the issue was with how survey creators were formatting their choices.

## Testing

After updating survey questions:

1. Open a survey with horizontal scale questions
2. Verify that meaningful labels appear at both ends of the scale
3. Verify that button text shows the choice labels
4. Submit a response and verify it's recorded correctly
5. Check survey results to ensure responses are displayed properly

## Support

For questions or issues related to this update:
1. Review the `SURVEY_SCALE_LABELS_GUIDE.md` for detailed information
2. Check the Apex script logs if using the migration script
3. Verify choice format matches the examples provided
