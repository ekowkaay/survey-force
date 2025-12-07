
public with sharing class SurveyUtilities {

    public static String createSurvey(Id parentId, String surveyType, String lang, String surveyName) {
        Survey__c newSurvey;
        List<Survey__c> surveyTemplate;
        List<Survey_Question__c> listQsNewSurvey = new List<Survey_Question__c>();
        List<Survey_Question__c> listQs;
        String siteURL, surveyTemplateName;
        surveyTemplateName = getSurveyTemplateName(surveyType, lang);

//        surveyTemplate = Database.query(EAP_Utilities.getSelectAllQuery('Survey__c', '') + ' WHERE Name = :surveyTemplateName Limit 1' );
        surveyTemplate = [SELECT Id, Name FROM Survey__c WHERE Name = :surveyTemplateName];
        Training_Request__c tReq = [SELECT Id, Training_Type__c FROM Training_Request__c WHERE Id = :parentId LIMIT 1];

        System.debug('EK---------survey=' + surveyTemplate);
        System.debug('EK---------TemplateName=' + surveyTemplateName);
        System.debug('EK---------parentId=' + parentId);
//        //if(recordType != 'Onsite'){
//        if((recordType != 'Onsite') && (recordType != 'Telephonic')){
//            tReq = Database.query(EAP_Utilities.getSelectAllQuery('Training_Request__c','Organization__r.Name,recordType.Name') + ' WHERE Id = :parentId LIMIT 1');
//        }


        if (surveyTemplate != null && surveyTemplate.size() > 0) {
            Id tempId = surveyTemplate[0].Id;
            listQs = Database.query(EAP_Utilities.getSelectAllQuery('Survey_Question__c', '') + ' WHERE Survey__c = :tempId');

            Map<String, SiteURL__c> csSite = SiteURL__c.getAll();
            if (csSite.get('Training').URL__c != null || csSite.get('Reseller Training').URL__c != null) {
                if (tReq.Training_Type__c == 'EAP Training') {
                    siteURL = csSite.get('EAP Training').URL__c;
                } else {
                    siteURL = csSite.get('Reseller Training').URL__c;
                }

                newSurvey = surveyTemplate[0].clone();
                newSurvey.Name = surveyName;
                newSurvey.Training_Request__c = parentId;

                insert newSurvey;

                for (Survey_Question__c q : listQs) {
                    Survey_Question__c newQ = q.clone();
                    newQ.Survey__c = newSurvey.Id;
                    listQsNewSurvey.add(newQ);
                }
                if (listQsNewSurvey.size() > 0) {
                    insert listQsNewSurvey;
                }

                String surveyURL = siteURL + '/TakeSurvey?id=' + newSurvey.Id;

                System.debug('SurveyURL---' + surveyURL);
                return surveyURL;
            }
        }
        return null;
    }


    public static String getSurveyTemplateName(String surveyType, String lang) {
        String templateName;
        if (surveyType == 'Participant' && lang == 'English') {
            templateName = 'PartcipantSurveyTemplate';
        } else if (surveyType == 'Participant' && lang == 'Spanish') {

            templateName = 'PartcipantSurveyTemplate Spanish';
        } else if (surveyType == 'Customer') {
            templateName = 'CustomerSurveyTemplate';
        } else if (surveyType == 'Trainer') {
            templateName = 'TrainerSurveyTemplate';
        }

        System.debug('template--->' + templateName);

        return templateName;
    }

}