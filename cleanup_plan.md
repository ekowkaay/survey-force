# Survey Package Cleanup Plan

## Objective
Review current survey package architecture and remove components that are not relevant or needed for the LWC build.

## Analysis Summary
1. Current project contains both Visualforce and LWC components
2. Several Visualforce controller classes need to be removed
3. Some components are redundant or no longer needed for LWC implementation

## Cleanup Steps
1. Remove Visualforce controller classes from force-app/main/default/classes/
2. Remove corresponding test classes
3. Review and clean up any remaining Visualforce references
4. Validate LWC components are intact and functional
5. Update package manifest if needed

## Components to Remove
From remove_visualforce_classes_todo.md:
- SurveyAndQuestionController.cls and .cls-meta.xml
- SurveyTakerController.cls and .cls-meta.xml
- ViewShareSurveyComponentController.cls and .cls-meta.xml
- ViewSurveyResultsComponentController.cls and .cls-meta.xml
- ViewSurveyController.cls and .cls-meta.xml
- SurveyBuilderController.cls and .cls-meta.xml
- SurveyManagerController.cls and .cls-meta.xml
- SurveyTemplateController.cls and .cls-meta.xml
- SurveyCreationController.cls and .cls-meta.xml
- SurveySitesUtil.cls and .cls-meta.xml
- SurveyTestingUtil.cls and .cls-meta.xml
- SurveyManagementController.cls and .cls-meta.xml
