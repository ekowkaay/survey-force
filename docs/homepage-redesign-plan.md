# Survey Force Homepage Redesign Plan (LWC)

## Goals
- Convert the homepage into an operations hub that highlights readiness, actions, and recent activity.
- Preserve the existing Action Center concept while making it dynamic and context-aware.
- Keep analytics on the Survey Analytics tab and operational signals on the homepage/dashboard.

## Proposed Homepage Sections

### 1. Dynamic Hero / Status Banner
**Purpose:** Replace the static welcome hero with a context-driven status summary.
- Example headline: “3 surveys ready to launch” or “2 surveys need attention.”
- Single primary CTA based on highest priority state (e.g., “Review drafts”).

### 2. Action Center (Contextual CTAs)
**Purpose:** Replace the static workflow tiles with prioritized actions.
- Draft completion CTA when drafts exist.
- “Generate Links” CTA when surveys are ready but have no responses.
- “View Survey Dashboard” CTA when active surveys exist.

### 3. Operational Snapshot
**Purpose:** Quick health metrics for at-a-glance status.
- Metrics: Drafts, Ready to Launch, Active, Stalled, Awaiting Responses.
- Mirrors readiness logic already introduced on the Survey Dashboard.

### 4. Recent Activity Feed
**Purpose:** Show latest operational events to increase daily utility.
- “Survey created,” “Survey published,” “Link generated,” “Responses received.”
- Limit to last 5 events with timestamps.

### 5. Guided Onboarding / Resources
**Purpose:** Replace generic resource cards with progress-driven guidance.
- Checklist of onboarding tasks.
- Best-practice tips based on the stage (drafting vs. active vs. analytics).

## Data Requirements

### Survey Summary
- `Survey__c.Id`
- `Survey__c.Name`
- `Survey__c.CreatedDate`
- `Survey__c.Questions__c`
- `Survey__c.Completed_Surveys__c`

### Activity Signals (if available)
- Survey lifecycle events (created/published)
- Link generation events (Survey Link Generator)
- Response submission timestamps (SurveyTaker__c.CreatedDate)

### Derived Metrics
- Drafts = `Questions__c == 0`
- Ready = `Questions__c > 0` AND `Completed_Surveys__c == 0` AND not stalled
- Active = `Completed_Surveys__c > 0`
- Stalled = `Questions__c > 0` AND `Completed_Surveys__c == 0` AND CreatedDate older than threshold

## Component Splits

### `surveyForceHome`
**Role:** Container orchestration + layout.
- Fetches data from Apex and computes derived metrics.
- Routes to child components.

### `surveyHomeHero`
**Role:** Dynamic banner with headline + primary CTA.

### `surveyHomeActionCenter`
**Role:** Contextual CTAs with adaptive ordering.

### `surveyHomeSnapshot`
**Role:** Readiness metric cards.

### `surveyHomeActivityFeed`
**Role:** Recent activity list.

### `surveyHomeGuidedResources`
**Role:** Checklist + contextual learning resources.

## Apex / Data Layer Notes
- Reuse `SurveyTemplateController.getAllSurveys` for baseline survey metrics.
- If activity feed requires additional objects, create a new Apex method (e.g., `SurveyHomeController.getRecentActivity`).
- For response activity, leverage `SurveyTaker__c` data (already used in analytics).

## UX Recommendations
- Maintain the current visual style but reduce hero height to emphasize actionable panels.
- Keep mobile-first grid layout; allow the Action Center and Snapshot to stack on small screens.
- Ensure each section gracefully handles empty states.

## Implementation Checklist (for later PR)
- [ ] Define Apex data needs + create new method if required.
- [ ] Split homepage into child components.
- [ ] Introduce dynamic hero + Action Center logic.
- [ ] Add operational snapshot cards.
- [ ] Add recent activity feed.
- [ ] Update resources/checklist into a guided onboarding component.

