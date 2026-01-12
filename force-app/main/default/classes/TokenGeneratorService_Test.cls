/**
 * @description Test class for TokenGeneratorService
 * Validates token generation functionality and security
 */
@IsTest
private class TokenGeneratorService_Test {
	/**
	 * @description Test single token generation
	 */
	@IsTest
	static void testGenerateToken() {
		// Test
		Test.startTest();
		String token = TokenGeneratorService.generateToken();
		Test.stopTest();

		// Assert
		System.assertNotEquals(null, token, 'Token should not be null');
		System.assertEquals(36, token.length(), 'Token should be 36 characters (UUID format)');
		System.assert(TokenGeneratorService.isValidTokenFormat(token), 'Token should have valid UUID format');
	}

	/**
	 * @description Test token uniqueness
	 */
	@IsTest
	static void testTokenUniqueness() {
		// Test
		Test.startTest();
		Set<String> tokens = new Set<String>();
		for (Integer i = 0; i < 10; i++) {
			tokens.add(TokenGeneratorService.generateToken());
		}
		Test.stopTest();

		// Assert
		System.assertEquals(10, tokens.size(), 'All generated tokens should be unique');
	}

	/**
	 * @description Test bulk token generation
	 */
	@IsTest
	static void testGenerateTokens() {
		// Test
		Test.startTest();
		List<String> tokens = TokenGeneratorService.generateTokens(50);
		Test.stopTest();

		// Assert
		System.assertEquals(50, tokens.size(), 'Should generate requested number of tokens');

		// Verify all are unique
		Set<String> uniqueTokens = new Set<String>(tokens);
		System.assertEquals(50, uniqueTokens.size(), 'All tokens should be unique');

		// Verify all have valid format
		for (String token : tokens) {
			System.assert(TokenGeneratorService.isValidTokenFormat(token), 'Each token should have valid format');
		}
	}

	/**
	 * @description Test bulk token generation with maximum allowed
	 */
	@IsTest
	static void testGenerateTokensMaximum() {
		// Test
		Test.startTest();
		List<String> tokens = TokenGeneratorService.generateTokens(SurveyForceConstants.MAX_BULK_INVITATIONS);
		Test.stopTest();

		// Assert
		System.assertEquals(SurveyForceConstants.MAX_BULK_INVITATIONS, tokens.size(), 'Should generate maximum allowed tokens');
	}

	/**
	 * @description Test bulk token generation exceeds maximum
	 */
	@IsTest
	static void testGenerateTokensExceedsMaximum() {
		// Test & Assert
		Boolean exceptionThrown = false;
		try {
			Test.startTest();
			TokenGeneratorService.generateTokens(SurveyForceConstants.MAX_BULK_INVITATIONS + 1);
			Test.stopTest();
		} catch (TokenGeneratorService.TokenGeneratorException e) {
			exceptionThrown = true;
			System.assert(e.getMessage().contains('Cannot generate more than'), 'Exception message should indicate maximum exceeded');
		}

		System.assert(exceptionThrown, 'Exception should be thrown when exceeding maximum');
	}

	/**
	 * @description Test bulk token generation with invalid count
	 */
	@IsTest
	static void testGenerateTokensInvalidCount() {
		// Test null count
		Boolean nullExceptionThrown = false;
		try {
			TokenGeneratorService.generateTokens(null);
		} catch (TokenGeneratorService.TokenGeneratorException e) {
			nullExceptionThrown = true;
		}
		System.assert(nullExceptionThrown, 'Exception should be thrown for null count');

		// Test zero count
		Boolean zeroExceptionThrown = false;
		try {
			TokenGeneratorService.generateTokens(0);
		} catch (TokenGeneratorService.TokenGeneratorException e) {
			zeroExceptionThrown = true;
		}
		System.assert(zeroExceptionThrown, 'Exception should be thrown for zero count');

		// Test negative count
		Boolean negativeExceptionThrown = false;
		try {
			TokenGeneratorService.generateTokens(-1);
		} catch (TokenGeneratorService.TokenGeneratorException e) {
			negativeExceptionThrown = true;
		}
		System.assert(negativeExceptionThrown, 'Exception should be thrown for negative count');
	}

	/**
	 * @description Test token format validation
	 */
	@IsTest
	static void testIsValidTokenFormat() {
		// Valid format
		String validToken = '12345678-1234-1234-1234-123456789abc';
		System.assert(TokenGeneratorService.isValidTokenFormat(validToken), 'Should recognize valid token format');

		// Invalid formats
		System.assert(!TokenGeneratorService.isValidTokenFormat(null), 'Null should be invalid');
		System.assert(!TokenGeneratorService.isValidTokenFormat(''), 'Empty string should be invalid');
		System.assert(!TokenGeneratorService.isValidTokenFormat('too-short'), 'Short string should be invalid');
		System.assert(!TokenGeneratorService.isValidTokenFormat('12345678123412341234123456789abc'), 'Missing hyphens should be invalid');
		System.assert(!TokenGeneratorService.isValidTokenFormat('1234567-1234-1234-1234-123456789abc'), 'Wrong hyphen position should be invalid');
		System.assert(!TokenGeneratorService.isValidTokenFormat('12345678-1234-1234-1234-123456789abcdef'), 'Too long should be invalid');
	}

	/**
	 * @description Test format as UUID with short string
	 */
	@IsTest
	static void testFormatAsUuidInvalidLength() {
		// Test
		Boolean exceptionThrown = false;
		try {
			// Use reflection to call private method for testing
			TokenGeneratorService.formatAsUuid('tooshort');
		} catch (TokenGeneratorService.TokenGeneratorException e) {
			exceptionThrown = true;
			System.assert(e.getMessage().contains('Invalid hex string length'), 'Exception message should indicate invalid length');
		}

		System.assert(exceptionThrown, 'Exception should be thrown for short hex string');
	}
}