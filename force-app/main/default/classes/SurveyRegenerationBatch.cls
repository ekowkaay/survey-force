/**
 * @description Batch class for asynchronous survey invitation regeneration.
 * Processes survey regeneration in batches to handle large datasets that exceed
 * the synchronous regeneration limit. Implements Database.Batchable and Database.Stateful
 * to maintain state across batch iterations.
 */
public class SurveyRegenerationBatch implements Database.Batchable<SurveyRegenerationController.SurveyData>, Database.Stateful {
	private List<SurveyRegenerationController.SurveyData> surveysToProcess;
	private Integer successCount = 0;
	private Integer failureCount = 0;
	private List<String> errors = new List<String>();

	/**
	 * @description Constructor
	 * @param surveysToProcess List of surveys to regenerate invitations for
	 */
	public SurveyRegenerationBatch(List<SurveyRegenerationController.SurveyData> surveysToProcess) {
		this.surveysToProcess = surveysToProcess;
	}

	/**
	 * @description Start method - returns the surveys to process
	 * @param bc BatchableContext
	 * @return Iterable<SurveyRegenerationController.SurveyData>
	 */
	public Iterable<SurveyRegenerationController.SurveyData> start(Database.BatchableContext bc) {
		return this.surveysToProcess;
	}

	/**
	 * @description Execute method - processes each batch of surveys
	 * @param bc BatchableContext
	 * @param scope List of surveys in this batch
	 */
	public void execute(Database.BatchableContext bc, List<SurveyRegenerationController.SurveyData> scope) {
		// Extract survey IDs and types from the scope
		List<String> surveyIds = new List<String>();
		List<String> surveyTypes = new List<String>();

		for (SurveyRegenerationController.SurveyData survey : scope) {
			surveyIds.add(survey.surveyId);
			surveyTypes.add(survey.surveyType);
		}

		// Call the synchronous regeneration method for this batch
		SurveyRegenerationController.RegenerationResult result = SurveyRegenerationController.regenerateSurveyInvitationsSynchronous(surveyIds, surveyTypes);

		// Accumulate results
		if (result != null) {
			successCount += result.successCount;
			failureCount += result.failureCount;
			if (result.errors != null && !result.errors.isEmpty()) {
				errors.addAll(result.errors);
			}
		}
	}

	/**
	 * @description Finish method - logs completion status
	 * @param bc BatchableContext
	 */
	public void finish(Database.BatchableContext bc) {
		// Log completion
		String message = 'Batch survey regeneration completed. Success: ' + successCount + ', Failures: ' + failureCount;
		if (!errors.isEmpty()) {
			message += '. Errors: ' + String.join(errors, '; ');
		}
		SurveyForceUtil.log('SurveyRegenerationBatch:finish() - ' + message);

		// Could add email notification here if needed
		// Or update a custom object to track batch job status
	}
}