#ifdef CHECK_ILL_OBJECTS

#include <stdio.h>
#include <string.h>
#include "objc/ill_object.h"
#include "dtable.h"
#include "uthash.h"

const time_t defer_timeout_seconds = 20;
const size_t max_deferred_objects = 10000;
const size_t min_object_size = 4;
const size_t max_object_size = 64;

typedef struct
{
	id object;
	const char* class_name;
	time_t time;
	UT_hash_handle hh;
} deferred_object;

typedef struct
{
	Class clazz;
	UT_hash_handle hh;
} dobject_class;

pthread_mutex_t deferred_mutex = PTHREAD_MUTEX_INITIALIZER;
static deferred_object deferred_objects[max_deferred_objects] = {0};
static deferred_object* deferred_object_map = NULL;
static deferred_object* deferred_object_above = deferred_objects;
static deferred_object* next_deferred_object = deferred_objects;
static deferred_object* deferred_object_below = deferred_objects;

pthread_mutex_t non_deferrable_object_classes_mutex = PTHREAD_MUTEX_INITIALIZER;
static dobject_class* non_deferrable_object_classes = NULL;

static BOOL is_deferrable_object_class(Class clazz)
{
	// Check object size.
	size_t instance_size = class_getInstanceSize(clazz);
	if (instance_size <= min_object_size || instance_size > max_object_size)
	{
		return NO;
	}
	
	// Check prefix.
	static const char* prefixes[] = {
		"GSMutable",
		"GSC",
		"UI",
		"CG",
		"Java",
		NULL
	};
	const char* class_name = class_getName(clazz);
	for (const char** i = prefixes; *i; ++i)
	{
		if (!strncmp(*i, class_name, strlen(*i)))
		{
			return NO;
		}
	}
	
	// Check specific cases.
	pthread_mutex_lock(&non_deferrable_object_classes_mutex);
	if (!non_deferrable_object_classes)
	{
		static const char* class_names[] = {
			"GSAutoreleasedMemory",
			"GSInlineArray",
			"GSSizeValue",
			"GSPointValue",
			"GSValue",
			"NSDataMalloc",
			"NSMutableDataMalloc",
			"NSGDate",
			"NSMethodSignature",
			"NSFloatNumber",
			"NSIntNumber",
			"NSDecimalNumber",
			"CCTexture2D",
			NULL
		};
		for (const char** i = class_names; *i; ++i)
		{
			dobject_class* dclazz = (dobject_class*)malloc(sizeof(dobject_class));
			dclazz->clazz = objc_getClass(*i);
			HASH_ADD_PTR(non_deferrable_object_classes, clazz, dclazz);
		}
	}
	pthread_mutex_unlock(&non_deferrable_object_classes_mutex);
		
	dobject_class* dclass = NULL;
	HASH_FIND_PTR(non_deferrable_object_classes, &clazz, dclass);
	return (dclass == NULL);
}

static void destroy_deferred_object(deferred_object* dobject)
{
	HASH_DEL(deferred_object_map, dobject);
	dobject->object->isa = 0xDEADFACE;
	free(dobject->object);
}

static BOOL free_deferred_object(deferred_object* dobject, time_t current_time)
{
	if (dobject->object && (current_time - dobject->time) > defer_timeout_seconds)
	{
		destroy_deferred_object(dobject);
		dobject->object = NULL;
		return YES;
	}
	return NO;
}

static void set_deferred_object(deferred_object* dobject, id object)
{
	if (dobject->object)
	{
		destroy_deferred_object(dobject);
	}
	dobject->object = object;
	HASH_ADD_PTR(deferred_object_map, object, dobject);
}

void defer_object_free(id object)
{
	if (CHECK_ILL_OBJECT_WHEN(object, "deferring object's free"))
	{
		return;
	}
	
	Class object_class = object_getClass(object);
	if (!is_deferrable_object_class(object_class))
	{
		free(object);
		return;
	}

	const char * class_name = class_getName(object_class);
	
	/* No objc runtime calls are allowed past mutex lock! */
	
	pthread_mutex_lock(&deferred_mutex);
	time_t current_time = time(0);
	
	// Free timed out objects above 'next' pointer.
	for (; deferred_object_above != next_deferred_object; ++deferred_object_above)
	{
		if (!free_deferred_object(deferred_object_above, current_time))
		{
			break;
		}
	}
	
	// Free timed out objects below 'next' pointer.
	deferred_object* const deferred_objects_end = deferred_objects + max_deferred_objects;
	for (; deferred_object_below != deferred_objects_end; ++deferred_object_below)
	{
		if (!free_deferred_object(deferred_object_below, current_time))
		{
			break;
		}
	}
	// Move 'below' pointer anyway, since we are going to write to 'next' pointer.
	if (deferred_object_below == next_deferred_object)
	{
		deferred_object_below++;
	}
	
	set_deferred_object(next_deferred_object, object);
	next_deferred_object->time = current_time;
	next_deferred_object->class_name = class_name;
	
	// Flip 'next' pointer adjusting 'below' and 'above' pointers.
	if (++next_deferred_object == deferred_objects_end)
	{
		next_deferred_object = deferred_objects;
		deferred_object_below = deferred_object_above;
		deferred_object_above = deferred_objects;
	}
	
	pthread_mutex_unlock(&deferred_mutex);
}

static BOOL is_object_free_deferred(id object, const char** class_name)
{
	BOOL result = NO;
	if (class_name)
	{
		*class_name = NULL;
	}
	
	pthread_mutex_lock(&deferred_mutex);
	
	if (deferred_object_map)
	{
		deferred_object* dobject = NULL;
		HASH_FIND_PTR(deferred_object_map, &object, dobject);
		if (dobject)
		{
			result = YES;
			if (class_name)
			{
				*class_name = dobject->class_name;
			}
		}
	}
	
	pthread_mutex_unlock(&deferred_mutex);
	return result;
}

/***** ill objects *****/

BOOL is_ill_object(id object, char** why_ill)
{
	#define WHY_ILL(object, format) ({ \
			BOOL ill = IS_ILL_POINTER(object); \
			if (ill && why_ill && asprintf(why_ill, format, object) == -1) \
			{ \
				*why_ill = strdup("ill pointer"); \
			} \
			ill; \
		})

	if (why_ill)
	{
		*why_ill = NULL;
	}
	if (!object)
	{
		return NO;
	}
	if (WHY_ILL(object, "ill pointer") ||
		WHY_ILL(object->isa, "isa is %p") ||
		WHY_ILL(object->isa->dtable, "isa->dtable is %p"))
	{
		return YES;
	}
	const char* class_name = NULL;
	if (is_object_free_deferred(object, &class_name))
	{
		if (why_ill && asprintf(why_ill, "deallocated %s object", class_name) == -1)
		{
			*why_ill = strdup(class_name);
		}
		return YES;
	}
	return NO;
	
	#undef WHY_ILL
}

#endif // CHECK_ILL_OBJECTS
