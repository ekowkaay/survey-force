/**
 * @description Interface for field-level security and CRUD operations validation.
 * Defines contract for access control implementations, allowing for dependency injection
 * and easier testing through mocking. Follows Interface Segregation Principle by providing
 * focused methods for specific security concerns.
 */
public interface IAccessController {
	/**
	 * @description Verify user has permission to view specified object and fields
	 * @param objectType The SObjectType to check
	 * @param fields List of fields to check for read access
	 * @throws SFDCAccessControlException if access is denied
	 */
	void assertAuthorizedToView(Schema.SObjectType objectType, List<Schema.SObjectField> fields);

	/**
	 * @description Verify user has permission to create specified object with fields
	 * @param objectType The SObjectType to check
	 * @param fields List of fields to check for create access
	 * @throws SFDCAccessControlException if access is denied
	 */
	void assertAuthorizedToCreate(Schema.SObjectType objectType, List<Schema.SObjectField> fields);

	/**
	 * @description Verify user has permission to update specified object with fields
	 * @param objectType The SObjectType to check
	 * @param fields List of fields to check for update access
	 * @throws SFDCAccessControlException if access is denied
	 */
	void assertAuthorizedToUpdate(Schema.SObjectType objectType, List<Schema.SObjectField> fields);

	/**
	 * @description Verify user has permission to delete specified object
	 * @param objectType The SObjectType to check
	 * @return Boolean true if authorized
	 * @throws SFDCAccessControlException if access is denied
	 */
	Boolean assertAuthorizedToDelete(Schema.SObjectType objectType);

	/**
	 * @description Check if user has permission to view specified object and fields without throwing exception
	 * @param objectType The SObjectType to check
	 * @param fields List of fields to check for read access
	 * @return Boolean true if authorized, false otherwise
	 */
	Boolean isAuthorizedToView(Schema.SObjectType objectType, List<Schema.SObjectField> fields);

	/**
	 * @description Check if user has permission to create specified object with fields without throwing exception
	 * @param objectType The SObjectType to check
	 * @param fields List of fields to check for create access
	 * @return Boolean true if authorized, false otherwise
	 */
	Boolean isAuthorizedToCreate(Schema.SObjectType objectType, List<Schema.SObjectField> fields);

	/**
	 * @description Check if user has permission to update specified object with fields without throwing exception
	 * @param objectType The SObjectType to check
	 * @param fields List of fields to check for update access
	 * @return Boolean true if authorized, false otherwise
	 */
	Boolean isAuthorizedToUpdate(Schema.SObjectType objectType, List<Schema.SObjectField> fields);

	/**
	 * @description Check if user has permission to delete specified object without throwing exception
	 * @param objectType The SObjectType to check
	 * @return Boolean true if authorized, false otherwise
	 */
	Boolean isAuthorizedToDelete(Schema.SObjectType objectType);

	/**
	 * @description Get list of fields that are viewable by current user
	 * @param objectType The SObjectType to check
	 * @return List of viewable fields
	 */
	List<Schema.SObjectField> getViewableFields(Schema.SObjectType objectType);

	/**
	 * @description Get list of fields that are creatable by current user
	 * @param objectType The SObjectType to check
	 * @return List of creatable fields
	 */
	List<Schema.SObjectField> getCreatableFields(Schema.SObjectType objectType);

	/**
	 * @description Get list of fields that are updateable by current user
	 * @param objectType The SObjectType to check
	 * @return List of updateable fields
	 */
	List<Schema.SObjectField> getUpdateableFields(Schema.SObjectType objectType);
}
