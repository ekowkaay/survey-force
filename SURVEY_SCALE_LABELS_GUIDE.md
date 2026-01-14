# Survey Scale Labels Guide

## Overview

This guide explains how to properly configure survey question choices for horizontal scale layouts (e.g., 1-5 rating scales) to display meaningful end labels like "Very Difficult" and "Very Easy".

## Problem Description

When creating survey questions with horizontal scale layouts, if you enter choices as simple numbers (e.g., `1\n2\n3\n4\n5`), the scale will display numeric values at both ends instead of meaningful labels.

### Incorrect Format
```
1
2
3
4
5
```

**Result:** Displays "1" at the start and "5" at the end of the scale, which doesn't provide context for respondents.

### Correct Format
```
Very Difficult
2
3
4
Very Easy
```

**Result:** Displays "Very Difficult" at the start and "Very Easy" at the end of the scale, providing clear context for the rating.

## How Survey Choices Work

When you create a survey question in Survey Force:

1. The `Choices__c` field stores choices as newline-separated text
2. Each line becomes a choice option with:
   - **Label**: The text displayed to the user (e.g., "Very Difficult", "2", "3")
   - **Value**: A numeric index starting from 0 (e.g., "0", "1", "2")

3. For horizontal scale layouts:
   - The **first choice's label** is displayed as the start label (left side)
   - The **last choice's label** is displayed as the end label (right side)
   - The button text for each choice shows its label

## Recommended Scale Formats

### Difficulty Scale (1-5)
```
Very Difficult
2
3
4
Very Easy
```

### Agreement Scale (1-5)
```
Strongly Disagree
2
3
4
Strongly Agree
```

### Satisfaction Scale (1-5)
```
Very Dissatisfied
2
3
4
Very Satisfied
```

### Likelihood Scale (1-5)
```
Very Unlikely
2
3
4
Very Likely
```

### Quality Scale (1-5)
```
Very Poor
2
3
4
Excellent
```

## Updating Existing Survey Questions

If you have existing survey questions that use numeric labels like "1" and "5", you can update them:

### Option 1: Manual Update via Salesforce UI

1. Navigate to the Survey Question record
2. Edit the `Choices__c` field
3. Replace:
   ```
   1
   2
   3
   4
   5
   ```
   With:
   ```
   Very Difficult
   2
   3
   4
   Very Easy
   ```
4. Save the record

### Option 2: Bulk Update via Data Loader

1. Export all Survey Questions where `Type__c = 'Single Select--Horizontal'`
2. Filter records in Excel/CSV where `Choices__c` equals exactly "1\n2\n3\n4\n5" (you may need to use Find/Replace)
3. Update the `Choices__c` field with the new format: "Very Difficult\n2\n3\n4\nVery Easy"
4. Import the updated records back into Salesforce

**Note**: The "\n" represents actual newline characters in the field. In Excel, this will appear as line breaks within the cell.

### Option 3: Apex Script (Execute Anonymous)

```apex
// Update all survey questions with numeric scale choices to use "Very Difficult" / "Very Easy" labels
List<Survey_Question__c> questionsToUpdate = new List<Survey_Question__c>();

for (Survey_Question__c sq : [
    SELECT Id, Choices__c, Type__c
    FROM Survey_Question__c
    WHERE Type__c = 'Single Select--Horizontal'
    AND Choices__c != null
    WITH USER_MODE
]) {
    // Check if choices match exact numeric scale format
    String trimmedChoices = sq.Choices__c.trim();
    if (trimmedChoices.equals('1\n2\n3\n4\n5')) {
        sq.Choices__c = 'Very Difficult\n2\n3\n4\nVery Easy';
        questionsToUpdate.add(sq);
    }
}

if (!questionsToUpdate.isEmpty()) {
    update questionsToUpdate;
    System.debug('Updated ' + questionsToUpdate.size() + ' survey questions');
} else {
    System.debug('No survey questions found to update');
}
```

## Best Practices

1. **Use Descriptive Labels**: Always use meaningful text for the first and last choices in a scale
2. **Keep Numbers for Middle Options**: Use simple numbers (2, 3, 4) for middle options to keep the scale clear
3. **Be Consistent**: Use the same scale format across similar questions in your survey
4. **Test Your Surveys**: Preview your survey after creating questions to ensure labels display correctly
5. **Document Your Scales**: Document which scales you use for different question types for consistency

## Technical Details

### Choice Parsing

Choices are parsed in the `SurveyTakerController.parseChoices()` method:
- Splits `Choices__c` field by newline (`\n`)
- Creates an `OptionData` object for each non-blank line
- Sets `label` to the trimmed choice text
- Sets `value` to the numeric index (0, 1, 2, 3, 4)

### Display Logic

For horizontal scale layouts in the `surveyTaker` LWC component:
- `scaleStartLabel`: Returns `choices[0].label`
- `scaleEndLabel`: Returns `choices[last].label`
- Button text: Shows `choice.label`
- Button value: Uses `choice.value` (numeric index)

## Troubleshooting

**Q: Why do I see numbers instead of labels at the ends of my scale?**  
A: Your choices are set to simple numbers (1, 2, 3, 4, 5). Update the first and last choices to descriptive labels.

**Q: Can I use different labels for different questions?**  
A: Yes! Each question can have its own choice labels. Use labels that best fit your question.

**Q: Do I need to update existing survey responses?**  
A: No. Existing responses store the numeric value (0-4), which remains valid even after changing labels.

**Q: What if I want more or fewer than 5 options?**  
A: You can use any number of options. Just ensure the first and last have descriptive labels:
```
Very Difficult
2
Very Easy
```
or
```
Very Difficult
2
3
4
5
6
7
Very Easy
```
