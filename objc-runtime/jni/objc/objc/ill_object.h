#ifndef __LIBOBJC_ILL_OBJECT_H_INCLUDED__
#define __LIBOBJC_ILL_OBJECT_H_INCLUDED__

#include "objc/runtime.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef CHECK_ILL_OBJECTS

#define IS_ILL_POINTER(pointer) \
	( \
	 ((uintptr_t)(pointer)) < 0x10000 || \
	 (((uintptr_t)(pointer)) >= 0xDEAD0000 && ((uintptr_t)(pointer)) <= 0xDEADFFFF) \
	)

#define IS_ILL_OBJECT(object) \
	is_ill_object(object, 0)

/* If object is ill logs message and returns YES (or breaks in debug).
 * Example: if (CHECK_ILL_OBJECT_WHEN(obj, "doing math")) { ... }
 */
#define CHECK_ILL_OBJECT_WHEN(object, whenFormat, ...) ({ \
		char* why_ill = NULL; \
		BOOL ill = is_ill_object(object, &why_ill); \
		if (ill) \
		{ \
			RELEASE_LOG("ILLOBJECT %p (%s) encountered when " whenFormat " | %s:%d", \
				object, why_ill, ##__VA_ARGS__, __FILE__, __LINE__); \
			DEBUG_BREAK(); \
			if (why_ill) \
			{ \
				free(why_ill); \
			} \
		} \
		ill; \
	})

/* If class is ill logs message and returns YES (or breaks in debug).
 * Example: if (CHECK_ILL_CLASS_WHEN(cls, "getting imp")) { ... }
 */
#define CHECK_ILL_CLASS_WHEN(clazz, whenFormat, ...) ({ \
		BOOL ill = IS_ILL_POINTER(clazz); \
		if (ill) \
		{ \
			RELEASE_LOG("ILLOBJECT %p (class) encountered when " whenFormat " | %s:%d", \
				clazz, ##__VA_ARGS__, __FILE__, __LINE__); \
			DEBUG_BREAK(); \
		} \
		ill; \
	})

BOOL is_ill_object(id object, char** why_ill);
void defer_object_free(id object);

#else // !CHECK_ILL_OBJECTS

#define IS_ILL_POINTER(pointer) NO
#define IS_ILL_OBJECT(receiver) NO
#define CHECK_ILL_OBJECT_WHEN(object, whenFormat, ...) NO
#define CHECK_ILL_CLASS_WHEN(clazz, whenFormat, ...) NO

#endif // !CHECK_ILL_OBJECTS

#ifdef __cplusplus
}
#endif

#endif // __LIBOBJC_ILL_OBJECT_H_INCLUDED__
