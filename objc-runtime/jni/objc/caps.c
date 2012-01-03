#include "objc/capabilities.h"
#include <stdint.h>

/**
 * Bitmask of all of the capabilities compiled into this version of the
 * runtime.
 */
static const int32_t caps =
	(1<<OBJC_CAP_EXCEPTIONS) |
	(1<<OBJC_CAP_SYNCRONIZE) |
	(1<<OBJC_CAP_PROPERTIES) |
	(1<<OBJC_CAP_PROPERTY_INTROSPECTION) |
	(1<<OBJC_CAP_OPTIONAL_PROTOCOLS) |
	(1<<OBJC_CAP_NONFRAGILE_IVARS) |
#ifdef TYPE_DEPENDENT_DISPATCH
	(1<<OBJC_CAP_TYPE_DEPENDENT_DISPATCH) |
#endif
#ifdef __OBJC_LOW_MEMORY__
	(1<<OBJC_CAP_LOW_MEMORY) |
#endif
	0;

int objc_test_capability(int x)
{
	if (x >= 32) { return 0; }
	if (caps & (1<<x)) { return 1; }
	return 0;
}
