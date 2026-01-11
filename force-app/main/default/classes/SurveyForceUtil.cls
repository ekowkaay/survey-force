/**
 * @description Utility class providing common functionality for Survey Force application.
 * Implements dependency injection pattern for access controller to improve testability.
 */
public with sharing class SurveyForceUtil {
	/** Access controller instance - can be injected for testing */
	@TestVisible
	private static IAccessController accessControllerInstance;

	/**
	 * @description Get the current access controller instance.
	 * Uses dependency injection pattern to allow mock injection in tests.
	 * @return IAccessController The access controller instance
	 */
	public static IAccessController accessController {
		get {
			if (accessControllerInstance == null) {
				accessControllerInstance = new SFDCAccessController();
			}
			return accessControllerInstance;
		}
		private set {
			accessControllerInstance = value;
		}
	}

	/**
	 * @description Set access controller instance for dependency injection (primarily for testing)
	 * @param controller The access controller implementation to use
	 */
	@TestVisible
	private static void setAccessController(IAccessController controller) {
		accessControllerInstance = controller;
	}

	public static void log(String message) {
		System.debug('SURVEYFORCEUTIL LOG: ' + message);
	}

	/**
	 * Moved from old ReportFinderUtil class to consolidate utilities
	 */
	public static String findReportId(String reportName) {
		List<Report> myReport = [SELECT Id, Name FROM Report WHERE Name = :reportName];
		if (myReport.size() > 0) {
			return myReport[0].Id;
		}
		return null;
	}
}