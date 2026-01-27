/**
 * Controller for the Survey Force Home page
 * Provides survey summary data, metrics, and recent activity
 */
public with sharing class SurveyHomeController {
	/**
	 * Get comprehensive home page data including surveys and metrics
	 * Fetches all surveys with security checks and calculates operational metrics
	 * @return HomeData wrapper containing all home page information
	 */
	@AuraEnabled(cacheable=true)
	public static HomeData getHomePageData() {
		try {
			HomeData data = new HomeData();

			// Get all surveys with required fields
			List<Schema.SobjectField> surveyFields = new List<Schema.SobjectField>{
				Schema.Survey__c.fields.Name,
				Schema.Survey__c.fields.CreatedDate,
				Schema.Survey__c.fields.Questions__c,
				Schema.Survey__c.fields.Completed_Surveys__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), surveyFields);

			List<Survey__c> allSurveys = [
				SELECT Id, Name, CreatedDate, Questions__c, Completed_Surveys__c
				FROM Survey__c
				WITH USER_MODE
				ORDER BY CreatedDate DESC
			];

			// Calculate metrics
			data.totalSurveys = allSurveys.size();
			data.drafts = 0;
			data.readyToLaunch = 0;
			data.active = 0;
			data.stalled = 0;

			// Define stalled threshold (30 days)
			DateTime stalledThreshold = DateTime.now().addDays(-30);

			for (Survey__c survey : allSurveys) {
				Integer questionCount = Integer.valueOf(survey.Questions__c != null ? survey.Questions__c : 0);
				Integer responseCount = Integer.valueOf(survey.Completed_Surveys__c != null ? survey.Completed_Surveys__c : 0);

				if (questionCount == 0) {
					data.drafts++;
				} else if (responseCount > 0) {
					data.active++;
				} else if (survey.CreatedDate < stalledThreshold) {
					data.stalled++;
				} else {
					data.readyToLaunch++;
				}
			}

			// Get recent activity
			data.activities = getRecentActivity();

			return data;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyHomeController:getHomePageData(): ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
			throw new AuraHandledException('An unexpected error occurred while loading home page data. Please contact your administrator.');
		}
	}

	/**
	 * Get recent survey activity events
	 * @return List of activity records
	 */
	private static List<Activity> getRecentActivity() {
		List<Activity> activities = new List<Activity>();

		try {
			// Get recently created surveys
			List<Schema.SobjectField> surveyFields = new List<Schema.SobjectField>{
				Schema.Survey__c.fields.Name,
				Schema.Survey__c.fields.CreatedDate,
				Schema.Survey__c.fields.Questions__c
			};
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.Survey__c.getSobjectType(), surveyFields);

			List<Survey__c> recentSurveys = [
				SELECT Id, Name, CreatedDate, Questions__c
				FROM Survey__c
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 3
			];

			for (Survey__c survey : recentSurveys) {
				Activity act = new Activity();
				act.id = survey.Id;
				act.message = 'Survey created: ' + survey.Name;
				act.timestamp = survey.CreatedDate;
				Integer questionCount = Integer.valueOf(survey.Questions__c != null ? survey.Questions__c : 0);
				act.type = questionCount > 0 ? 'published' : 'created';
				activities.add(act);
			}

			// Get recent survey responses
			List<Schema.SobjectField> takerFields = new List<Schema.SobjectField>{ Schema.SurveyTaker__c.fields.Survey__c, Schema.SurveyTaker__c.fields.CreatedDate };
			SurveyForceUtil.accessController.assertAuthorizedToView(Schema.SurveyTaker__c.getSobjectType(), takerFields);

			List<SurveyTaker__c> recentResponses = [
				SELECT Id, Survey__c, Survey__r.Name, CreatedDate
				FROM SurveyTaker__c
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 2
			];

			for (SurveyTaker__c taker : recentResponses) {
				Activity act = new Activity();
				act.id = taker.Id;
				act.message = 'Response received for: ' + taker.Survey__r.Name;
				act.timestamp = taker.CreatedDate;
				act.type = 'response';
				activities.add(act);
			}

			// Sort all activities by timestamp descending
			activities.sort();

			// Return only the 5 most recent
			if (activities.size() > 5) {
				return new List<Activity>(activities).subList(0, 5);
			}

			return activities;
		} catch (Exception e) {
			SurveyForceUtil.log('SurveyHomeController:getRecentActivity(): ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
			return new List<Activity>();
		}
	}

	/**
	 * Wrapper class for home page data
	 */
	public class HomeData {
		@AuraEnabled
		public Integer totalSurveys { get; set; }
		@AuraEnabled
		public Integer drafts { get; set; }
		@AuraEnabled
		public Integer readyToLaunch { get; set; }
		@AuraEnabled
		public Integer active { get; set; }
		@AuraEnabled
		public Integer stalled { get; set; }
		@AuraEnabled
		public List<Activity> activities { get; set; }

		public HomeData() {
			this.totalSurveys = 0;
			this.drafts = 0;
			this.readyToLaunch = 0;
			this.active = 0;
			this.stalled = 0;
			this.activities = new List<Activity>();
		}
	}

	/**
	 * Wrapper class for activity data
	 */
	public class Activity implements Comparable {
		@AuraEnabled
		public String id { get; set; }
		@AuraEnabled
		public String message { get; set; }
		@AuraEnabled
		public DateTime timestamp { get; set; }
		@AuraEnabled
		public String type { get; set; }

		public Integer compareTo(Object compareTo) {
			Activity compareToActivity = (Activity) compareTo;
			if (timestamp == compareToActivity.timestamp) {
				return 0;
			}
			if (timestamp < compareToActivity.timestamp) {
				return 1;
			}
			return -1;
		}
	}
}