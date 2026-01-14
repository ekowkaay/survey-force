# Survey Scale Labels Guide

## Overview

This guide explains how to configure static scale labels for horizontal scale survey questions to display meaningful guidance like "Very Difficult" and "Very Easy" at the ends of the scale.

## New Static Label Fields

Survey questions now have dedicated fields for scale endpoint labels:
- **Scale Start Label** (`Scale_Start_Label__c`) - Displayed on the left side of horizontal scales
- **Scale End Label** (`Scale_End_Label__c`) - Displayed on the right side of horizontal scales

These labels help respondents understand what each end of the scale represents.

## How It Works

### Before (Without Static Labels)
When scale labels were not set, the scale appeared without context:
```
Question: "How would you rate the difficulty of this training?"
[1] [2] [3] [4] [5]
```

### After (With Static Labels)
With static scale labels configured:
```
Question: "How would you rate the difficulty of this training?"
Very Difficult ◄─────────────────► Very Easy
[1] [2] [3] [4] [5]
```

The static labels provide clear context without being part of the selectable choices.

## Configuring Scale Labels

### Creating a New Scale Question

1. Create or edit a Survey Question record
2. Set **Type** to "Single Select--Horizontal"
3. Enter the numeric choices in **Choices** field:
   ```
   1
   2
   3
   4
   5
   ```
4. Set **Scale Start Label** to describe the lowest value (e.g., "Very Difficult")
5. Set **Scale End Label** to describe the highest value (e.g., "Very Easy")
6. Save the record

### Result
Survey respondents will see:
- Clear labels at both ends of the scale showing what each extreme means
- Numeric buttons (1, 2, 3, 4, 5) to make their selection
- Easy understanding of the scale direction and meaning

## Recommended Scale Labels

### Difficulty Scale
- **Start**: Very Difficult
- **End**: Very Easy

### Agreement Scale
- **Start**: Strongly Disagree
- **End**: Strongly Agree

### Satisfaction Scale
- **Start**: Very Dissatisfied
- **End**: Very Satisfied

### Likelihood Scale
- **Start**: Very Unlikely
- **End**: Very Likely

### Quality Scale
- **Start**: Very Poor
- **End**: Excellent

## Technical Details

### Architecture

**Survey_Question__c Fields:**
- `Scale_Start_Label__c` (Text, 255) - Static label for scale start
- `Scale_End_Label__c` (Text, 255) - Static label for scale end
- `Choices__c` (Long Text Area) - Numeric choices (1, 2, 3, 4, 5)

**Data Flow:**
1. Question record stores static labels separate from choices
2. `SurveyTakerController` fetches both labels and choices
3. `surveyTaker` LWC displays labels at scale endpoints
4. Choices remain numeric for clarity (1, 2, 3, 4, 5)
5. Response stores the selected numeric value

### Display Logic

For horizontal scale layouts in the `surveyTaker` LWC component:
- `scaleStartLabel`: Returns `currentQuestion.scaleStartLabel`
- `scaleEndLabel`: Returns `currentQuestion.scaleEndLabel`
- `hasScaleEndLabels`: Returns true if either label is set
- Button labels: Show numeric values from `Choices__c`

### Benefits of Static Labels

1. **Separation of Concerns**: Labels provide context, choices provide values
2. **Clarity**: Numeric choices (1-5) are easier to understand than mixed values
3. **Consistency**: All scale questions can use standard 1-5 format
4. **Flexibility**: Labels can be changed without affecting choice structure
5. **User Guidance**: Clear indication of what each end of the scale means

## Best Practices

1. **Always Set Both Labels**: For horizontal scales, set both start and end labels
2. **Be Descriptive**: Use clear, meaningful labels that describe the extremes
3. **Keep Choices Numeric**: Use simple numbers (1, 2, 3, 4, 5) for the choices
4. **Be Consistent**: Use the same scale type for similar questions
5. **Match Question Context**: Ensure labels align with what the question asks

## Examples

### Example 1: Training Difficulty

**Question**: "How would you rate the difficulty of this training?"
- **Scale Start Label**: Very Difficult
- **Scale End Label**: Very Easy
- **Choices**: 1\n2\n3\n4\n5

### Example 2: Content Quality

**Question**: "How would you rate the quality of the training materials?"
- **Scale Start Label**: Very Poor
- **Scale End Label**: Excellent
- **Choices**: 1\n2\n3\n4\n5

### Example 3: Recommendation Likelihood

**Question**: "How likely are you to recommend this training?"
- **Scale Start Label**: Very Unlikely
- **Scale End Label**: Very Likely
- **Choices**: 1\n2\n3\n4\n5

## Troubleshooting

**Q: I don't see the Scale Start/End Label fields**  
A: Deploy the metadata to add these fields to your org. They are new custom fields on Survey_Question__c.

**Q: Do I need to update existing questions?**  
A: Yes, edit existing horizontal scale questions to add the appropriate scale labels.

**Q: What if I don't set the labels?**  
A: The scale will display without endpoint labels, showing only the numeric choices.

**Q: Can I use different scales for different questions?**  
A: Yes! Each question has its own Scale Start/End Label fields, so you can customize per question.

**Q: Do the labels affect existing responses?**  
A: No. Responses store the numeric value selected (e.g., "0", "1", "2", "3", "4"), which remains valid.

## Migration from Old Approach

If you previously had labels embedded in the Choices field:

### Old Format (No Longer Recommended)
```
Choices__c: Very Difficult\n2\n3\n4\nVery Easy
```

### New Format (Recommended)
```
Scale Start Label: Very Difficult
Scale End Label: Very Easy  
Choices__c: 1\n2\n3\n4\n5
```

**Benefits:**
- Cleaner separation between labels and values
- Easier to maintain and update
- More consistent user experience
- Better data quality
