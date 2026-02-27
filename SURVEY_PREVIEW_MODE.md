# Survey Preview Mode Documentation

## Overview

The Survey Preview Mode provides a comprehensive testing environment for survey creators to validate their surveys before sharing them with respondents. Preview mode offers clear visual indicators and powerful testing features without saving any responses to the database.

## Features

### 1. Enhanced Visual Indicators

#### Preview Banner
- **Location**: Sticky banner at the top of the survey
- **Design**: Yellow gradient background with amber border
- **Content**:
  - Preview icon
  - "Preview Mode" title
  - "Responses will not be saved" subtitle
- **Purpose**: Immediately communicates that the survey is in preview mode

#### Preview Watermark
- **Location**: Center of the screen, rotated 45 degrees
- **Design**: Large, semi-transparent "PREVIEW" text
- **Purpose**: Provides constant visual reminder throughout the survey experience
- **Note**: Non-intrusive - does not interfere with survey interaction

### 2. User Context Testing

Test how your survey appears to different user types:

#### Authenticated User (Default)
- Simulates logged-in Salesforce users
- Shows full survey experience with name option

#### Anonymous User
- Simulates users submitting without identification
- Tests anonymous submission flow

#### Guest User
- Simulates external users accessing via Community/Experience Cloud
- Tests token-based access scenarios

**How to Use**:
1. Click the user icon button in the preview banner
2. Select desired user context from dropdown
3. Survey behavior updates to reflect selected context

### 3. Mobile Preview Mode

Test responsive design and mobile user experience:

**How to Use**:
1. Click the mobile phone icon button in the preview banner
2. Survey container resizes to mobile dimensions (375px width)
3. Simulates smartphone viewport
4. Toggle again to return to desktop view

**Mobile Preview Styling**:
- Constrained width (375px)
- Border and shadow effects
- Centered layout
- Helps identify layout issues before deployment

### 4. Quick Return to Builder

Streamlined workflow for iterative survey development:

**How to Use**:
1. Click "Return to Builder" button in preview banner
2. Instantly navigates back to Survey Creator page
3. Maintains survey context (same survey loaded for editing)

**Benefits**:
- Reduces navigation time
- Supports rapid test-edit-test cycles
- Improves survey development efficiency

### 5. Non-Persistent Responses

**Behavior**:
- All survey interactions are tracked locally
- Submit button triggers preview-specific flow
- Success message displays without database save
- Toast notification confirms preview status

**User Feedback**:
- Clear messaging: "Preview Mode: This is a preview. Survey responses will not be saved."
- Thank you page displays as in production
- No SurveyTaker or SurveyQuestionResponse records created

### 6. Full Navigation Testing

All survey features remain functional in preview mode:

- ✅ Question navigation (Previous/Next buttons)
- ✅ Progress bar updates
- ✅ Form field validation
- ✅ Required field checks
- ✅ Anonymous submission selection
- ✅ All question types (Free Text, Single Select, Multi-Select)
- ✅ Keyboard accessibility (Arrow keys, Ctrl+Enter)

**Difference**: Navigation and validation work identically to production, only submission is prevented

## How to Enter Preview Mode

### From Survey Creator
1. Open a survey in Survey Creator
2. Click the "Preview" button in the header
3. Survey opens in new tab/page with preview mode active

### From Survey Template List
1. Navigate to Survey Template List
2. Locate desired survey
3. Click the overflow menu (⋮)
4. Select "Preview"
5. Survey opens in preview mode

### Via URL Parameter
- Manual URL construction: Add `c__preview=true` to Survey_Taker_Page URL
- Example: `/lightning/n/Survey_Taker_Page?c__recordId=a0X...&c__preview=true`

## Technical Implementation

### Components Modified
- **surveyTaker.js**: Added preview mode logic and handlers
- **surveyTaker.html**: Added preview banner and watermark UI
- **surveyTaker.css**: Added preview-specific styling

### Key Properties
- `isPreviewMode`: Boolean flag from URL parameter
- `previewUserContext`: Current user context selection
- `previewMobileMode`: Mobile preview toggle state

### CSS Classes
- `.preview-banner`: Sticky banner container
- `.preview-watermark`: Large rotated preview text
- `.mobile-preview`: Applied to survey shell in mobile mode
- Responsive styles for mobile devices

### Event Handlers
- `handlePreviewContextChange`: User context selection
- `handleMobileToggle`: Mobile preview toggle
- `handleReturnToBuilder`: Navigation back to creator
- Enhanced `handleSubmit`: Preview-aware submission logic

## Best Practices

### For Survey Creators

1. **Always Preview Before Sharing**
   - Validate all questions display correctly
   - Test required field validation
   - Verify thank you message appears
   - Check mobile responsiveness

2. **Test Different User Contexts**
   - Preview as Authenticated if survey is for internal users
   - Preview as Guest if using external invitations
   - Preview as Anonymous if responses should be anonymous

3. **Use Mobile Preview**
   - Toggle mobile preview for all surveys
   - Verify text fits within mobile viewport
   - Check button accessibility on small screens
   - Validate horizontal scroll doesn't occur

4. **Iterative Testing**
   - Use "Return to Builder" for quick edits
   - Test again after each change
   - Verify all question types before finalizing

### For Administrators

1. **User Training**
   - Educate survey creators on preview features
   - Emphasize preview mode doesn't save data
   - Demonstrate user context testing

2. **Quality Assurance**
   - Require preview testing before survey deployment
   - Review surveys in different contexts
   - Validate mobile experience

## Troubleshooting

### Preview Mode Not Activating
- **Check URL**: Ensure `c__preview=true` parameter is present
- **Check Navigation**: Use official Preview buttons, not manual URL construction
- **Clear Cache**: Browser cache may need clearing

### Return to Builder Not Working
- **Check Record ID**: Survey must have valid recordId
- **Check Permissions**: User must have access to Survey Creator
- **Check Page Configuration**: Survey_Creator_Page must be available

### Mobile Preview Not Displaying Correctly
- **Check Browser Zoom**: Reset zoom to 100%
- **Check Screen Size**: Desktop/tablet screen required for mobile preview
- **Toggle Off/On**: Sometimes toggle needs to be cycled

## Future Enhancements

Potential improvements for future releases:

1. **Device Presets**: Multiple device width options (iPhone, iPad, Android)
2. **Response Data Preview**: Sample data to visualize analytics
3. **Screenshot Capture**: Take screenshots for documentation
4. **Share Preview Link**: Generate temporary preview URLs for stakeholders
5. **Preview History**: Track preview sessions for audit trail

## Related Documentation

- [LWC Implementation Summary](./LWC_IMPLEMENTATION_SUMMARY.md)
- [Survey Force README](./readme.md)
- [Accessibility Features](./ACCESSIBILITY_FEATURES.md)
- [UI/UX Enhancements](./UI_UX_ENHANCEMENTS.md)

## Support

For issues or questions about preview mode:
1. Check this documentation
2. Review troubleshooting section
3. Contact Survey Force support team
4. Submit feedback via GitHub issues
