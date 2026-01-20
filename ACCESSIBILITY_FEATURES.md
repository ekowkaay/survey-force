# Survey Force - Accessibility Features

## Overview

Survey Force is designed to be accessible to all users, including those using assistive technologies. This document outlines the accessibility features and keyboard shortcuts available in the application.

---

## WCAG 2.1 AA Compliance

Survey Force strives to meet WCAG 2.1 Level AA standards for accessibility.

### Key Accessibility Features

✅ **Screen Reader Support**

- Proper ARIA labels on all interactive elements
- Semantic HTML structure (header, main, nav, role attributes)
- Live regions for dynamic content updates
- Progress announcements for survey navigation
- Required field indicators properly announced

✅ **Keyboard Navigation**

- Full keyboard accessibility (no mouse required)
- Logical tab order throughout all components
- Focus management when navigating between questions
- Keyboard shortcuts for common actions
- Visual focus indicators on all interactive elements

✅ **Visual Design**

- High contrast color schemes
- Minimum 4.5:1 contrast ratio for text
- Clear visual focus indicators
- Descriptive error messages
- Progress indicators with numerical values

✅ **Responsive Design**

- Mobile-friendly layouts
- Touch-friendly interactive elements
- Scalable text and UI components
- Flexible layouts that adapt to screen size

---

## Keyboard Shortcuts

### Survey Taking (surveyTaker Component)

| Shortcut               | Action            | Description                              |
| ---------------------- | ----------------- | ---------------------------------------- |
| `→` or `↓`             | Next Question     | Move to the next question                |
| `←` or `↑`             | Previous Question | Move to the previous question            |
| `Ctrl+Enter` (Windows) | Submit Survey     | Submit the survey (on last question)     |
| `Cmd+Enter` (Mac)      | Submit Survey     | Submit the survey (on last question)     |
| `Tab`                  | Navigate Forward  | Move to the next interactive element     |
| `Shift+Tab`            | Navigate Backward | Move to the previous interactive element |
| `Space`                | Select/Toggle     | Select checkbox or radio button          |
| `Enter`                | Activate Button   | Click the focused button                 |

**Notes:**

- Arrow key navigation works when not typing in text fields
- Keyboard shortcuts are disabled in preview mode
- Focus automatically moves to the current question after navigation

### Survey Creation (surveyCreator Component)

_Coming soon: Keyboard shortcuts will be added to the survey creator for power users_

Planned shortcuts:

- `Ctrl/Cmd+S` - Save survey
- `Ctrl/Cmd+Q` - Add new question
- `Ctrl/Cmd+P` - Preview survey
- `Escape` - Close modal dialogs

---

## Screen Reader Support

Survey Force has been tested with the following screen readers:

### Recommended Screen Readers

| Screen Reader | Browser         | Operating System | Support Level   |
| ------------- | --------------- | ---------------- | --------------- |
| NVDA          | Firefox, Chrome | Windows          | ✅ Full Support |
| JAWS          | Chrome, Edge    | Windows          | ✅ Full Support |
| VoiceOver     | Safari          | macOS/iOS        | ✅ Full Support |
| TalkBack      | Chrome          | Android          | ✅ Full Support |

### Screen Reader Features

**Question Navigation:**

- Questions are announced with their number and total count
- Required fields are properly identified
- Help text is associated with questions via `aria-describedby`
- Progress updates are announced in real-time

**Form Controls:**

- Radio buttons announce selection state
- Checkboxes announce checked/unchecked state
- Text inputs announce their labels and help text
- Buttons announce their purpose and state (enabled/disabled)

**Error Messages:**

- Errors are announced immediately via `aria-live` regions
- Error messages include actionable guidance
- Focus moves to error location when appropriate

**Progress Indicators:**

- Progress bar announces current progress percentage
- Question counter is available to screen readers
- Completion status is announced on submission

---

## Component-Specific Accessibility

### surveyTaker Component

**ARIA Attributes:**

```html
<section role="main" aria-labelledby="survey-title" aria-describedby="survey-description">
	<h1 id="survey-title">Survey Title</h1>
	<p id="survey-description">Survey description</p>

	<div role="progressbar" aria-valuenow="50" aria-valuemin="0" aria-valuemax="100" aria-label="Survey progress: Question 5 of 10">
		<!-- Progress bar -->
	</div>

	<div role="heading" aria-level="2" id="question-title">
		1. Your question here
		<abbr class="slds-required" title="required" aria-label="required">*</abbr>
	</div>

	<div role="navigation" aria-label="Survey navigation">
		<button aria-label="Go to previous question" aria-disabled="false">Back</button>
		<button aria-label="Go to next question">Next</button>
	</div>
</section>
```

**Focus Management:**

- Focus automatically moves to the current question title after navigation
- Focus moves to anonymous selection heading when reaching that step
- Focus is managed appropriately for modals and overlays

**Live Regions:**

- Current question number announced when changed
- Progress updates announced
- Error messages announced immediately
- Success messages announced on submission

### surveyCreator Component

**Form Labels:**

- All form fields have proper labels
- Help text associated with fields via `lightning-helptext`
- Required fields clearly marked

**Modal Dialogs:**

- Proper `role="dialog"` and `aria-modal="true"`
- Focus trap within modal
- Close button properly labeled
- Focus returns to trigger element on close

---

## Testing for Accessibility

### Browser Extensions

**Recommended Tools:**

1. **axe DevTools** (Chrome/Firefox)
   - Automated accessibility testing
   - Identifies WCAG violations
   - Provides remediation guidance

2. **WAVE** (Chrome/Firefox)
   - Visual accessibility evaluation
   - Highlights issues directly on page
   - Color contrast checking

3. **Lighthouse** (Chrome DevTools)
   - Built into Chrome
   - Accessibility audit included
   - Performance and best practices

### Manual Testing Checklist

✅ **Keyboard Navigation:**

- [ ] Can access all interactive elements via Tab key
- [ ] Focus order is logical and predictable
- [ ] Focus indicators are clearly visible
- [ ] No keyboard traps
- [ ] Shortcuts work as documented

✅ **Screen Reader Testing:**

- [ ] All content is announced properly
- [ ] Labels are associated correctly
- [ ] Landmarks are defined (header, main, nav)
- [ ] Heading hierarchy is logical (h1 → h2 → h3)
- [ ] Dynamic content changes are announced

✅ **Visual Testing:**

- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] Focus indicators are visible
- [ ] Text is readable at 200% zoom
- [ ] No information conveyed by color alone
- [ ] Forms have clear error states

✅ **Mobile Testing:**

- [ ] Touch targets are at least 44x44 pixels
- [ ] Text is legible on small screens
- [ ] Horizontal scrolling is not required
- [ ] Forms are easy to complete on mobile

---

## Known Limitations

### Current Limitations

1. **Rich Text Formatting**: Survey headers and questions currently support plain text only. Rich text editing will be added in a future release.

2. **File Upload**: File upload questions are not yet supported. This feature is planned for a future release.

3. **Drag and Drop**: Question reordering via drag and drop is not yet keyboard accessible. A keyboard-accessible alternative will be provided.

4. **Complex Charts**: Analytics charts may have limited screen reader support. Alternative text summaries are provided where possible.

### Future Improvements

The following accessibility enhancements are planned:

- **Enhanced Keyboard Navigation**: Additional keyboard shortcuts for survey creator
- **High Contrast Mode**: Dedicated high contrast theme
- **Font Size Controls**: User-adjustable font sizes
- **Read Aloud**: Audio narration option for surveys
- **Translation Support**: Multi-language accessibility
- **Advanced Screen Reader Features**: Enhanced announcements and descriptions

---

## Reporting Accessibility Issues

If you encounter any accessibility issues or have suggestions for improvements:

1. **GitHub Issues**: [Report an issue](https://github.com/SalesforceLabs/survey-force/issues)
2. **Include Details**:
   - Screen reader and version (if applicable)
   - Browser and version
   - Operating system
   - Steps to reproduce
   - Expected vs. actual behavior
3. **Severity**: Indicate if the issue prevents you from using the feature

---

## Additional Resources

### WCAG Guidelines

- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM WCAG Checklist](https://webaim.org/standards/wcag/checklist)

### Screen Readers

- [NVDA (Free)](https://www.nvaccess.org/)
- [JAWS](https://www.freedomscientific.com/products/software/jaws/)
- [VoiceOver (Built-in on Mac/iOS)](https://support.apple.com/guide/voiceover/welcome/mac)

### Testing Tools

- [axe DevTools](https://www.deque.com/axe/devtools/)
- [WAVE](https://wave.webaim.org/extension/)
- [Lighthouse](https://developers.google.com/web/tools/lighthouse)

### Salesforce Accessibility

- [Salesforce Accessibility](https://www.salesforce.com/company/legal/508_accessibility/)
- [Lightning Design System Accessibility](https://www.lightningdesignsystem.com/accessibility/overview/)

---

**Last Updated**: January 2026  
**Version**: 1.0  
**Compliance Level**: WCAG 2.1 Level AA (In Progress)
