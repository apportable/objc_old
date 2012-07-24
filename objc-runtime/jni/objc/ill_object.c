#ifdef CHECK_ILL_OBJECTS

#include "objc/ill_object.h"
#include "dtable.h"
#include <stdio.h>

/***** pointer set *****/

static int pointer_compare(const void* pointer1, void* pointer2)
{
	return pointer1 == pointer2;
}
static int32_t pointer_hash(const void* pointer)
{
	int32_t hash =  (int32_t)(uintptr_t)pointer;
	hash = (hash + 0x7ed55d16) + (hash << 12);
	hash = (hash ^ 0xc761c23c) ^ (hash >> 19);
	hash = (hash + 0x165667b1) + (hash << 5);
	hash = (hash + 0xd3a2646c) ^ (hash << 9);
	hash = (hash + 0xfd7046c5) + (hash << 3);
	hash = (hash ^ 0xb55a4f09) ^ (hash >> 16);
	return hash;
}

#define MAP_TABLE_NAME pointer_set
#define MAP_TABLE_COMPARE_FUNCTION pointer_compare
#define MAP_TABLE_HASH_KEY pointer_hash
#define MAP_TABLE_HASH_VALUE pointer_hash
#define MAP_TABLE_NO_LOCK

#include "hash_table.h"

#undef MAP_TABLE_NAME
#undef MAP_TABLE_COMPARE_FUNCTION
#undef MAP_TABLE_HASH_KEY
#undef MAP_TABLE_HASH_VALUE
#undef MAP_TABLE_NO_LOCK

/***** deferred objects *****/

const time_t defer_timeout_seconds = 5;
const size_t max_deferred_objects = 10000;

typedef struct
{
	time_t time;
	id object;
} deferred_object;

pthread_mutex_t deferred_mutex = PTHREAD_MUTEX_INITIALIZER;
static deferred_object deferred_objects[max_deferred_objects] = {0};
static pointer_set_table* deferred_object_set = NULL;
static size_t next_deferred_object_index = 0;

static void destroy_deferred_object(deferred_object* dobject)
{
	pointer_set_remove(deferred_object_set, dobject->object);
	free(dobject->object);
}

static BOOL free_deferred_object(size_t index, time_t current_time)
{
	deferred_object* dobject = (deferred_objects + index);
	if (dobject->object && (current_time - dobject->time) > defer_timeout_seconds)
	{
		destroy_deferred_object(dobject);
		dobject->object = NULL;
		return YES;
	}
	return NO;
}

static void set_deferred_object(size_t index, id object, time_t current_time)
{
	deferred_object* dobject = (deferred_objects + index);
	if (dobject->object)
	{
		destroy_deferred_object(dobject);
	}
	dobject->time = current_time;
	dobject->object = object;
	pointer_set_insert(deferred_object_set, object);
}

void defer_object_free(id object)
{
	free(object);
	return;
	// if (CHECK_ILL_OBJECT_WHEN(object, "deferring object's free"))
	// {
	// 	return;
	// }
	// pthread_mutex_lock(&deferred_mutex);
	// if (!deferred_object_set)
	// {
	// 	deferred_object_set = pointer_set_create((max_deferred_objects * 5) / 4);
	// }
	// time_t current_time = time(0);
	// for (size_t i = 0; i != next_deferred_object_index; ++i)
	// {
	// 	if (!free_deferred_object(i, current_time))
	// 	{
	// 		break;
	// 	}
	// }
	// for (size_t i = next_deferred_object_index + 1; i < max_deferred_objects; ++i)
	// {
	// 	if (!free_deferred_object(i, current_time))
	// 	{
	// 		break;
	// 	}
	// }
	// set_deferred_object(next_deferred_object_index, object, current_time);
	// if (++next_deferred_object_index == max_deferred_objects)
	// {
	// 	next_deferred_object_index = 0;
	// }
	// pthread_mutex_unlock(&deferred_mutex);
}

static BOOL is_object_free_deferred(id object, const char** class_name)
{
	return NO;
	// BOOL result = NO;
	// *class_name = NULL;
	// pthread_mutex_lock(&deferred_mutex);
	// if (deferred_object_set && pointer_set_table_get(deferred_object_set, object))
	// {
	// 	BOOL found = NO;
	// 	for (size_t i = 0; i != max_deferred_objects; ++i)
	// 	{
	// 		if (deferred_objects[i].object == object)
	// 		{
	// 			found = YES;
	// 			break;
	// 		}
	// 	}
	// 	if (found)
	// 	{
	// 		result = YES;
	// 		*class_name = ""; //class_getName(object_getClass(object));
	// 	}
	// }
	// pthread_mutex_unlock(&deferred_mutex);
	// return result;
}

/***** ill objects *****/

BOOL is_ill_object(id object, char** why_ill)
{
	#define WHY_ILL(object, format) ({ \
			BOOL ill = IS_ILL_POINTER(object); \
			if (why_ill && asprintf(why_ill, format, object) == -1) \
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

