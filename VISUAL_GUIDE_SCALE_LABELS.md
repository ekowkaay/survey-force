# Visual Guide: Survey Scale Labels

## Before (Incorrect) ❌

### What Users See
When survey questions use numeric choices:

```
Survey Question: "How would you rate the difficulty of this training?"

Choices Field: 1\n2\n3\n4\n5
```

**Survey Display:**
```
How would you rate the difficulty of this training?

1 ←――――――――――――――→ 5
   [1] [2] [3] [4] [5]
```

**Problems:**
- "1" and "5" don't provide context
- Users must guess what 1 means vs what 5 means
- Inconsistent with survey design best practices

---

## After (Correct) ✅

### What Users See
When survey questions use descriptive labels:

```
Survey Question: "How would you rate the difficulty of this training?"

Choices Field: Very Difficult\n2\n3\n4\nVery Easy
```

**Survey Display:**
```
How would you rate the difficulty of this training?

Very Difficult ←――――――――――――――→ Very Easy
   [Very Difficult] [2] [3] [4] [Very Easy]
```

**Benefits:**
- Clear context for what each end represents
- Users immediately understand the scale direction
- Follows survey design best practices
- More meaningful data collection

---

## Side-by-Side Comparison

### Numeric Scale (Before)
```
┌─────────────────────────────────────────────────┐
│ How satisfied are you with the training?       │
│                                                 │
│ 1 ◄────────────────────────────────────► 5    │
│   [1]    [2]    [3]    [4]    [5]              │
│                                                 │
│ ⚠️ User thinks: "Does 1 mean good or bad?"     │
└─────────────────────────────────────────────────┘
```

### Labeled Scale (After)
```
┌─────────────────────────────────────────────────┐
│ How satisfied are you with the training?       │
│                                                 │
│ Very Dissatisfied ◄──────────► Very Satisfied  │
│   [Very Dissatisfied] [2] [3] [4]              │
│                        [Very Satisfied]         │
│                                                 │
│ ✅ User thinks: "Clear! I was very satisfied."  │
└─────────────────────────────────────────────────┘
```

---

## Real Examples

### Example 1: Difficulty Scale

❌ **Before:**
```
Choices: 1\n2\n3\n4\n5
Display: 1 ←→ 5
```

✅ **After:**
```
Choices: Very Difficult\n2\n3\n4\nVery Easy
Display: Very Difficult ←→ Very Easy
```

### Example 2: Agreement Scale

❌ **Before:**
```
Choices: 1\n2\n3\n4\n5
Display: 1 ←→ 5
```

✅ **After:**
```
Choices: Strongly Disagree\n2\n3\n4\nStrongly Agree
Display: Strongly Disagree ←→ Strongly Agree
```

### Example 3: Quality Scale

❌ **Before:**
```
Choices: 1\n2\n3\n4\n5
Display: 1 ←→ 5
```

✅ **After:**
```
Choices: Very Poor\n2\n3\n4\nExcellent
Display: Very Poor ←→ Excellent
```

---

## How to Update

### In Salesforce UI

1. Navigate to Survey Question record
2. Click "Edit"
3. Find "Choices" field
4. Change from:
   ```
   1
   2
   3
   4
   5
   ```
5. To:
   ```
   Very Difficult
   2
   3
   4
   Very Easy
   ```
6. Click "Save"

### Result
Survey will immediately show proper labels at scale endpoints!

---

## Key Takeaway

🎯 **The first and last choices define the scale meaning**

- First choice = Start label (left side)
- Last choice = End label (right side)
- Middle choices = Button labels only

✅ Always use descriptive text for first and last choices
✅ Use numbers for middle choices to keep it simple
✅ Match the labels to your question context

---

## Testing Your Changes

After updating a survey question:

1. Navigate to the survey in preview mode
2. Find your updated question
3. Verify you see meaningful labels at both ends
4. Try selecting different values
5. Submit a test response
6. Check that response is recorded correctly

**Example Test:**

Before: "1 ◄────────► 5"  
After: "Very Difficult ◄────────► Very Easy" ✅

If you still see numbers, double-check:
- Question Type is "Single Select--Horizontal"
- Choices field has descriptive text for first/last lines
- No extra spaces or formatting issues in Choices field

---

For more details, see:
- `SURVEY_SCALE_LABELS_GUIDE.md` - Complete formatting guide
- `SURVEY_SCALE_LABELS_UPDATE.md` - Technical implementation
- `scripts/apex/UpdateSurveyScaleLabels.apex` - Bulk update script
