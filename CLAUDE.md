# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Survey Force is a Salesforce unmanaged package providing a survey platform built on Lightning Web Components (LWC) and Apex. It supports internal surveys and external guest-user surveys via Experience Sites.

- **API Version**: 58.0 (Spring 2024)
- **Package**: Unmanaged (no namespace)
- **Source directory**: `force-app/`

## Commands

### Code Formatting

```bash
# Format all files
npm run prettier

# Verify formatting (used by CI)
npm run prettier:verify
```

Prettier runs automatically as a pre-commit hook via Husky. CI (`ci.yml`) runs `prettier:verify` on every push to `force-app/**`.

### Salesforce CLI

Always use `sf` (not `sfdx` — it is deprecated):

```bash
# Deploy source to org
sf project deploy start --source-dir force-app

# Deploy a single file
sf project deploy start --source-file force-app/main/default/classes/MyClass.cls

# Run Apex tests (single class)
sf apex run test --class-names MyClass_Test --result-format human --synchronous

# Run all Apex tests
sf apex run test --result-format human --synchronous

# Open org
sf org open

# Pull changes from org
sf project retrieve start --source-dir force-app
```

### Development Setup

```bash
npm install   # Install Prettier, Husky, lint-staged
```

## Architecture

### Data Model

Nine custom objects form the core data model:

| Object | Purpose |
|--------|---------|
| `Survey__c` | Survey template definition |
| `Survey_Question__c` | Questions within a survey |
| `SurveyTaker__c` | Respondent session records |
| `SurveyQuestionResponse__c` | Individual answers |
| `SurveyInvitation__c` | Invitations with expiration |
| `Participants__c` | Participant tracking |
| `SurveySettings__c` | App-level configuration |
| `Training_Request__c` | Training/request tracking |
| `SiteURL__mdt` | Custom metadata for site URL config |

### Apex Backend (`force-app/main/default/classes/`)

Controllers expose `@AuraEnabled` methods consumed by LWC:
- `SurveyTakerController` — survey-taking flow
- `SurveyCreationController` — create/clone surveys
- `SurveyTemplateController` — list/manage surveys
- `SurveyInvitationController` — invitation management
- `SurveyRegenerationController` — survey regeneration

Async/batch processing:
- `SurveyInvitationExpirationBatch` + `SurveyInvitationExpirationScheduler` — automated expiration
- `SurveyRegenerationBatch` — bulk regeneration

Trigger pattern — one trigger per object, logic in handler class:
- `ParticipantsTriggerHandler`, `SurveyQuestionTriggerHandler`, `TrainingRequestTriggerHandler`

Guest user access uses `ViewSurveyControllerWithoutSharing.cls` (explicitly `without sharing`) to allow Experience Site guest users to access surveys. For each survey to be publicly available, `Share_with_Guest_User__c` must be checked on the Survey record (defaults to `false`).

Shared utilities: `SurveyUtilities`, `SurveyForceUtil`, `SurveyForceConstants` (enums/constants), `TokenGeneratorService`.

Test classes use `_Test` suffix and a shared `SurveyTestingUtil` for test data creation.

### LWC Frontend (`force-app/main/default/lwc/`)

- `surveyTaker` — main survey-taking UI (used on Lightning pages and Experience Sites)
- `surveyTemplateList` — survey dashboard with CRUD actions
- `surveyCreator` — create/clone surveys
- `surveyForceHome` — operations hub home page
- `surveyInvitations` — invitation management
- `surveyAnalyticsDashboard` — analytics and reporting
- `surveyRegenerationWizard` — regeneration flow
- `surveyQuestion` — internal reusable question renderer (used by `surveyTaker`)
- `gettingStarted` — onboarding tab

## Coding Standards

These standards are enforced via `.github/copilot-instructions.md`:

### Apex
- Use `with sharing` on all classes (except `ViewSurveyControllerWithoutSharing`)
- Run DML/SOQL in USER_MODE: `[SELECT Id FROM Survey__c WITH USER_MODE]` and `Database.insert(records, AccessLevel.USER_MODE)`
- Never use `@future` — use `Queueable` with `System.Finalizer` instead
- Bulkify all code — no SOQL/DML inside loops
- Use enums (`ALL_CAPS_SNAKE_CASE`) over string constants
- Use Database methods with exception handling for DML
- No `System.debug()` in production code
- No hardcoded IDs or URLs
- ApexDocs required on all classes and methods

### Triggers
- One trigger per object
- Static boolean flag to prevent recursion
- All logic delegated to handler class

### LWC
- Follow SLDS guidelines; use `slds-*` utility classes
- Event handlers named `handle*` (e.g., `handleButtonClick`)
- Use computed getters for derived UI state instead of `@track` where possible
- Use `@wire` for reactive data from Apex; use `refreshApex` for manual refresh
- Use `lightning-record-edit-form` for record creates/updates

### Permissions
- Create a permission set for every new feature
- Naming: `[AppPrefix]_[Component]_[AccessLevel]` (e.g., `SurveyForce_Survey_Read`)
- Never combine read and delete in the same permission set
- Document all permission sets in a `Permissions.md` file

### Metadata
- Always create XML metadata files alongside new Apex (`.cls-meta.xml`), triggers (`.trigger-meta.xml`), and objects (`.object-meta.xml`)
- Use MCP tools (if available via `https://github.com/salesforcecli/mcp`) before Salesforce CLI commands
