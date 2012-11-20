#include <objc/runtime.h>
#include "uthash.h"

typedef struct {
    id object;
    void *zone;
    unsigned int retainCount;
    UT_hash_handle hh;
} object_ref;

#define OBJC_IS_TAGGED_PTR(PTR) ((uintptr_t)(PTR) & 0x1)

static pthread_mutex_t entryLock = PTHREAD_MUTEX_INITIALIZER;
static object_ref *objectEntries = NULL;

id _objc_rootInit(id obj)
{
	return id;
}

id _objc_rootAllocWithZone(Class cls, void *zone)
{
	id object = class_createInstance(cls, 0);
	object_ref *entry = malloc(sizeof(object_ref));
	entry->object = object;
	entry->zone = zone;
	entry->retainCount = 1;
	pthread_mutex_lock(&entryLock);
    HASH_ADD_PTR(objectEntries, object, entry);
    pthread_mutex_unlock(&entryLock);
	return object;
}

id _objc_rootRetain(id obj)
{
	if (OBJC_IS_TAGGED_PTR(obj))
	{
		return obj;
	}
	else
	{
		object_ref *entry = NULL;
		pthread_mutex_lock(&entryLock);
    	HASH_FIND_PTR(objectEntries, &obj, entry);
    	if (entry != nil)
    	{
    		entry->retainCount++;
    	}
    	pthread_mutex_unlock(&entryLock);
		return obj;
	}
}

void _objc_rootRelease(id obj)
{
	if (OBJC_IS_TAGGED_PTR(obj))
	{
		return;
	}
	else
	{
		object_ref *entry = NULL;
		pthread_mutex_lock(&entryLock);
    	HASH_FIND_PTR(objectEntries, &obj, entry);
    	if (entry != nil)
    	{
    		entry->retainCount--;
    	}
    	pthread_mutex_unlock(&entryLock);
	}
}

BOOL _objc_rootReleaseWasZero(id obj)
{
	if (OBJC_IS_TAGGED_PTR(obj))
	{
		return NO;
	}
	else
	{
		BOOL wasZero = NO;
		object_ref *entry = NULL;
		pthread_mutex_lock(&entryLock);
    	HASH_FIND_PTR(objectEntries, &obj, entry);
    	if (entry != nil)
    	{
    		entry->retainCount--;
    		wasZero = entry->retainCount == 0;
    	}
    	pthread_mutex_unlock(&entryLock);
    	return wasZero;
	}
}

void _objc_rootDealloc(id obj)
{
	if (OBJC_IS_TAGGED_PTR(obj))
	{
		return;
	}
	else
	{
	    object_dispose(obj);
	}
}

void _objc_rootFinalize(id obj)
{
	
}

void *_objc_rootZone(id obj)
{
	void *zone = NULL;
	object_ref *entry = NULL;
	pthread_mutex_lock(&entryLock);
	HASH_FIND_PTR(objectEntries, &obj, entry);
	if (entry != nil)
	{
		zone = entry->zone;
	}
	pthread_mutex_unlock(&entryLock);
	return zone;
}

unsigned int _objc_rootHash(id obj)
{
	return (unsigned int)obj;
}

unsigned int _objc_rootRetainCount(id obj)
{
	int retainCount = -1;
	object_ref *entry = NULL;
	pthread_mutex_lock(&entryLock);
	HASH_FIND_PTR(objectEntries, &obj, entry);
	if (entry != nil)
	{
		retainCount = entry->retainCount;
	}
	pthread_mutex_unlock(&entryLock);
	return retainCount;
}
