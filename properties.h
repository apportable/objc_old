
enum PropertyAttributeKind 
{
	/**
	 * Property has no attributes.
	 */
	OBJC_PR_noattr    = 0x00,
	/**
	 * The property is declared read-only.
	 */
	OBJC_PR_readonly  = (1<<0),
	/**
	 * The property has a getter.
	 */
	OBJC_PR_getter    = (1<<1),
	/**
	 * The property has assign semantics.
	 */
	OBJC_PR_assign    = (1<<2),
	/**
	 * The property is declared read-write.
	 */
	OBJC_PR_readwrite = (1<<3),
	/**
	 * Property has retain semantics.
	 */
	OBJC_PR_retain    = (1<<4),
	/**
	 * Property has copy semantics.
	 */
	OBJC_PR_copy      = (1<<5),
	/**
	 * Property is marked as non-atomic.
	 */
	OBJC_PR_nonatomic = (1<<6),
	/**
	 * Property has setter.
	 */
	OBJC_PR_setter    = (1<<7)
};

/**
 * Structure used for property enumeration.  Note that property enumeration is
 * currently quite broken on OS X, so achieving full compatibility there is
 * impossible.  Instead, we strive to achieve com
 */
struct objc_property
{
	/**
	 * Name of this property.
	 */
	const char *name;
	/**
	 * Attributes for this property.  Made by ORing together
	 * PropertyAttributeKinds.
	 */
	const char attributes;
	/**
	 * Flag set if the property is synthesized.
	 */
	const char isSynthesized;
	/**
	 * Name of the set method for this property.
	 */
	const char *setter_name;
	/**
	 * Type encoding of the setter for this property.
	 */
	const char *setter_types;
	/**
	 * Name of the getter for this property.
	 */
	const char *getter_name;
	/**
	 * Type encoding for the get method for this property.
	 */
	const char *getter_types;
};

/**
 * List of property inrospection data.
 */
struct objc_property_list
{
	/**
	 * Number of properties in this array.
	 */
	int count;
	/* 
	 * UNUSED.  In future, categories will be allowed to add properties and
	 * then this will be used to link the declarations together.
	 */
	struct objc_property_list *next; 
	/**
	 * List of properties.
	 */
	struct objc_property properties[1];
};

