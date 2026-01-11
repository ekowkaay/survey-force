/**
 * @description Service class responsible for generating secure tokens for survey invitations.
 * Centralizes token generation logic to follow Single Responsibility Principle and DRY.
 * Uses cryptographic random generation for security.
 */
public class TokenGeneratorService {
	/**
	 * @description Generate a unique cryptographically secure token
	 * Uses AES key generation for randomness and formats as UUID-style string
	 * @return String A unique token in format XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
	 */
	public static String generateToken() {
		Blob randomBytes = Crypto.generateAesKey(128);
		String hexString = EncodingUtil.convertToHex(randomBytes);
		return formatAsUuid(hexString);
	}

	/**
	 * @description Format a hex string as UUID-style token
	 * @param hexString The hex string to format (32 characters expected)
	 * @return String Formatted token with hyphens
	 */
	@TestVisible
	private static String formatAsUuid(String hexString) {
		if (hexString.length() < 32) {
			throw new TokenGeneratorException('Invalid hex string length for UUID formatting');
		}

		return hexString.substring(0, 8) +
			'-' +
			hexString.substring(8, 12) +
			'-' +
			hexString.substring(12, 16) +
			'-' +
			hexString.substring(16, 20) +
			'-' +
			hexString.substring(20);
	}

	/**
	 * @description Generate multiple unique tokens efficiently
	 * @param count Number of tokens to generate (max 200)
	 * @return List<String> List of unique tokens
	 * @throws TokenGeneratorException if count exceeds maximum
	 */
	public static List<String> generateTokens(Integer count) {
		if (count == null || count < 1) {
			throw new TokenGeneratorException('Token count must be at least 1');
		}

		if (count > SurveyForceConstants.MAX_BULK_INVITATIONS) {
			throw new TokenGeneratorException('Cannot generate more than ' + SurveyForceConstants.MAX_BULK_INVITATIONS + ' tokens at once');
		}

		List<String> tokens = new List<String>();
		Set<String> uniqueTokens = new Set<String>();

		// Generate tokens and ensure uniqueness
		while (tokens.size() < count) {
			String token = generateToken();
			if (!uniqueTokens.contains(token)) {
				tokens.add(token);
				uniqueTokens.add(token);
			}
		}

		return tokens;
	}

	/**
	 * @description Validate if a string is a valid token format
	 * @param token The token string to validate
	 * @return Boolean true if token format is valid
	 */
	public static Boolean isValidTokenFormat(String token) {
		if (String.isBlank(token)) {
			return false;
		}

		// UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (36 characters with hyphens)
		if (token.length() != 36) {
			return false;
		}

		// Check hyphen positions (charAt returns Integer character code, 45 is '-')
		if (token.charAt(8) != 45 || token.charAt(13) != 45 || token.charAt(18) != 45 || token.charAt(23) != 45) {
			return false;
		}

		// Check for valid hex characters (simple validation)
		String hexPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
		return Pattern.matches(hexPattern, token);
	}

	/**
	 * @description Custom exception for token generation errors
	 */
	public class TokenGeneratorException extends Exception {
	}
}
