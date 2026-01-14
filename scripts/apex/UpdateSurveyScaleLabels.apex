/**
 * Data migration script to update survey question choices from numeric scales 
 * with "Disagree"/"Strongly Agree" labels to "Very Difficult"/"Very Easy" labels.
 * 
 * This script can be executed in the Salesforce Developer Console using Execute Anonymous.
 * 
 * Usage:
 * 1. Open Developer Console
 * 2. Debug > Open Execute Anonymous Window
 * 3. Paste this entire script
 * 4. Check "Open Log"
 * 5. Click "Execute"
 * 
 * The script will:
 * - Find all horizontal scale survey questions
 * - Update choices that start with "Disagree" or "1" to start with "Very Difficult"
 * - Update choices that end with "Strongly Agree" or "5" to end with "Very Easy"
 * - Log all changes for review
 */

// Track updates for logging
List<Survey_Question__c> questionsToUpdate = new List<Survey_Question__c>();
Integer totalProcessed = 0;
Integer totalUpdated = 0;

try {
    // Query all horizontal scale survey questions
    List<Survey_Question__c> questions = [
        SELECT Id, Name, Question__c, Choices__c, Type__c, OrderNumber__c, Survey__r.Name
        FROM Survey_Question__c
        WHERE Type__c = 'Single Select--Horizontal'
        AND Choices__c != null
        WITH USER_MODE
        ORDER BY Survey__r.Name, OrderNumber__c
    ];
    
    System.debug('Found ' + questions.size() + ' horizontal scale questions to process');
    
    for (Survey_Question__c sq : questions) {
        totalProcessed++;
        String originalChoices = sq.Choices__c;
        String newChoices = null;
        Boolean needsUpdate = false;
        
        // Split choices into lines
        List<String> choiceLines = originalChoices.split('\n');
        if (choiceLines.size() < 2) {
            continue; // Skip if not enough choices
        }
        
        // Get first and last choice (trimmed)
        String firstChoice = choiceLines[0].trim();
        String lastChoice = choiceLines[choiceLines.size() - 1].trim();
        
        // Pattern 1: Replace "Disagree" with "Very Difficult"
        if (firstChoice.equalsIgnoreCase('Disagree') || 
            firstChoice.equalsIgnoreCase('Strongly Disagree')) {
            choiceLines[0] = 'Very Difficult';
            needsUpdate = true;
            System.debug('Survey: ' + sq.Survey__r.Name + ' | Question: ' + sq.Question__c);
            System.debug('  Replacing first choice "' + firstChoice + '" with "Very Difficult"');
        }
        
        // Pattern 2: Replace "Strongly Agree" with "Very Easy"
        if (lastChoice.equalsIgnoreCase('Strongly Agree') || 
            lastChoice.equalsIgnoreCase('Agree')) {
            choiceLines[choiceLines.size() - 1] = 'Very Easy';
            needsUpdate = true;
            System.debug('Survey: ' + sq.Survey__r.Name + ' | Question: ' + sq.Question__c);
            System.debug('  Replacing last choice "' + lastChoice + '" with "Very Easy"');
        }
        
        // Pattern 3: Replace numeric scales "1...5" with "Very Difficult...Very Easy"
        if (firstChoice.equals('1') && lastChoice.equals('5')) {
            choiceLines[0] = 'Very Difficult';
            choiceLines[choiceLines.size() - 1] = 'Very Easy';
            needsUpdate = true;
            System.debug('Survey: ' + sq.Survey__r.Name + ' | Question: ' + sq.Question__c);
            System.debug('  Replacing numeric scale (1-5) with "Very Difficult" to "Very Easy"');
        }
        
        // If updates needed, reconstruct choices string
        if (needsUpdate) {
            sq.Choices__c = String.join(choiceLines, '\n');
            questionsToUpdate.add(sq);
            totalUpdated++;
            
            System.debug('  Original: ' + originalChoices.replaceAll('\n', ' | '));
            System.debug('  Updated:  ' + sq.Choices__c.replaceAll('\n', ' | '));
            System.debug('---');
        }
    }
    
    // Perform the update
    if (!questionsToUpdate.isEmpty()) {
        System.debug('\n========================================');
        System.debug('UPDATING ' + questionsToUpdate.size() + ' QUESTIONS');
        System.debug('========================================\n');
        
        update questionsToUpdate;
        
        System.debug('SUCCESS: Updated ' + totalUpdated + ' of ' + totalProcessed + ' survey questions');
        System.debug('\nUpdated questions:');
        for (Survey_Question__c sq : questionsToUpdate) {
            System.debug('  - ' + sq.Survey__r.Name + ': ' + sq.Question__c);
        }
    } else {
        System.debug('No survey questions needed updates. All scales are already using the correct labels.');
    }
    
} catch (DmlException e) {
    System.debug('ERROR during update: ' + e.getMessage());
    if (e.getNumDml() > 0) {
        System.debug('Failed records: ' + e.getDmlMessage(0));
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}

System.debug('\n========================================');
System.debug('SUMMARY');
System.debug('========================================');
System.debug('Total Questions Processed: ' + totalProcessed);
System.debug('Total Questions Updated: ' + totalUpdated);
System.debug('========================================');
